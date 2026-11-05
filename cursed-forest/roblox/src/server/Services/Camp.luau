-- Лагерь: костёр (топливо, уровень, радиус света), склад, крафт, улучшения.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Config = require(Shared.Config)
local Recipes = require(Shared.Recipes)
local Weapons = require(Shared.Weapons)

local Camp = {}
local S, State
local fireModel, firePart, fireLight, fireFx
Camp.storage = {} -- общий склад лагеря: id -> количество

function Camp.init(services)
	S = services
	State = S.State
end

function Camp.radius(): number
	local c = State.run.camp
	local base = Recipes.FIRE_BASE_RADIUS
	for _, r in ipairs(Recipes.FIRE) do
		if c.level >= r.level then
			base = r.radius
		end
	end
	local f = c.fuel <= 0 and 0.25 or math.clamp(0.45 + c.fuel / 45, 0.45, 1)
	return base * f
end

function Camp.inCamp(pos: Vector3): boolean
	return Vector3.new(pos.X, 0, pos.Z).Magnitude < Config.CAMP_RADIUS
end

function Camp.inLight(pos: Vector3): boolean
	return Vector3.new(pos.X, 0, pos.Z).Magnitude < Camp.radius()
end

function Camp.deposit(ps)
	local moved = 0
	for id, n in pairs(ps.inv.items) do
		if not Items[id].free then
			Camp.storage[id] = (Camp.storage[id] or 0) + n
			ps.inv.items[id] = nil
			moved += n
		end
	end
	if moved > 0 then
		State.notify(ps.player, "Добыча сложена на склад лагеря (" .. moved .. ")")
		S.PlayerService.sync(ps)
	end
end

-- общий кошелёк: склад + мешок игрока
local function have(ps, id)
	return (Camp.storage[id] or 0) + ps.inv:count(id)
end
local function canPay(ps, cost)
	for id, n in pairs(cost) do
		if have(ps, id) < n then
			return false
		end
	end
	return true
end
local function pay(ps, cost)
	if not canPay(ps, cost) then
		return false
	end
	for id, n in pairs(cost) do
		local fromStore = math.min(Camp.storage[id] or 0, n)
		Camp.storage[id] = (Camp.storage[id] or 0) - fromStore
		if Camp.storage[id] <= 0 then
			Camp.storage[id] = nil
		end
		if n - fromStore > 0 then
			ps.inv:remove(id, n - fromStore)
		end
	end
	return true
end
Camp.have, Camp.canPay, Camp.pay = have, canPay, pay

local function costText(ps, cost)
	local t = {}
	for id, n in pairs(cost) do
		table.insert(t, Items[id].icon .. have(ps, id) .. "/" .. n)
	end
	return table.concat(t, " ")
end
Camp.costText = costText

function Camp.openFire(ps, tab: string?)
	tab = tab or "fire"
	local c = State.run.camp
	local buttons = {
		{ id = "tab:fire", label = "🔥 Костёр", tab = true, on = tab == "fire" },
		{ id = "tab:craft", label = "🛠 Верстак", tab = true, on = tab == "craft" },
		{ id = "tab:store", label = "📦 Склад", tab = true, on = tab == "store" },
	}
	local text
	if tab == "fire" then
		text = string.format("Костёр, уровень %d. Топливо %d%%. Радиус света %d.\nЧем больше света, тем дальше держатся Олень и вампиры.", c.level, math.floor(c.fuel), math.floor(Camp.radius()))
		table.insert(buttons, { id = "fuel1", label = "Подбросить 1 🪵 (+12%)", enabled = have(ps, "wood") >= 1 and c.fuel < 100 })
		table.insert(buttons, { id = "fuel5", label = "Подбросить 5 🪵", enabled = have(ps, "wood") >= 1 and c.fuel < 100 })
		local raw = have(ps, "meat") + have(ps, "fish")
		table.insert(buttons, { id = "cook", label = "Пожарить мясо и рыбу (" .. raw .. ")", enabled = raw > 0 })
		for _, r in ipairs(Recipes.FIRE) do
			if r.level == c.level + 1 then
				table.insert(buttons, { id = "upgrade", label = (r.great and "Великий Костёр " or "Улучшить до ур. " .. r.level .. " ") .. costText(ps, r.cost), enabled = canPay(ps, r.cost) })
			end
		end
	elseif tab == "craft" then
		text = "Крафт берёт ресурсы со склада лагеря и из твоего мешка."
		for _, r in ipairs(Recipes.CRAFT) do
			table.insert(buttons, { id = "craft:" .. r.id, label = r.name .. "  " .. costText(ps, r.cost), enabled = canPay(ps, r.cost) })
		end
	else
		local t = {}
		for id, n in pairs(Camp.storage) do
			table.insert(t, Items[id].icon .. " " .. Items[id].name .. ": " .. n)
		end
		table.sort(t)
		text = #t > 0 and table.concat(t, "\n") or "Склад пуст"
	end
	S.Structures.openPanel(ps, "fire", "Лагерь выживших", text, buttons)
end

function Camp.action(ps, actionId: string)
	local c = State.run.camp
	if actionId:sub(1, 4) == "tab:" then
		return Camp.openFire(ps, actionId:sub(5))
	end
	if actionId == "fuel1" or actionId == "fuel5" then
		local n = math.min(actionId == "fuel1" and 1 or 5, have(ps, "wood"))
		if n > 0 and pay(ps, { wood = n }) then
			c.fuel = math.min(100, c.fuel + 12 * n)
		end
	elseif actionId == "cook" then
		local m, f = have(ps, "meat"), have(ps, "fish")
		pay(ps, { meat = m, fish = f })
		if m > 0 then
			ps.inv:add("cmeat", m)
		end
		if f > 0 then
			ps.inv:add("cfish", f)
		end
		State.notify(ps.player, "Пожарено: " .. m .. " мяса, " .. f .. " рыбы", "good")
	elseif actionId == "upgrade" then
		for _, r in ipairs(Recipes.FIRE) do
			if r.level == c.level + 1 and pay(ps, r.cost) then
				c.level = r.level
				c.fuel = 100
				State.notify(nil, r.great and "Великий Костёр зажжён! Дождитесь сотой ночи" or "Костёр улучшен до уровня " .. r.level, "good")
			end
		end
	elseif actionId:sub(1, 6) == "craft:" then
		local id = actionId:sub(7)
		for _, r in ipairs(Recipes.CRAFT) do
			if r.id == id and pay(ps, r.cost) then
				local msg = S.PlayerService.grant(ps, r.give)
				State.notify(ps.player, "Готово: " .. (msg ~= "" and msg or r.name), "good")
			end
		end
		S.PlayerService.sync(ps)
		return Camp.openFire(ps, "craft")
	end
	S.PlayerService.sync(ps)
	Camp.openFire(ps, "fire")
end

function Camp.build(parent: Instance)
	fireModel = Instance.new("Model")
	fireModel.Name = "Campfire"
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local stone = Instance.new("Part")
		stone.Size = Vector3.new(1.4, 0.8, 1.4)
		stone.Anchored = true
		stone.Material = Enum.Material.Slate
		stone.Color = Color3.fromRGB(110, 110, 110)
		stone.Position = Vector3.new(math.cos(a) * 3, 0.4, math.sin(a) * 3)
		stone.Parent = fireModel
	end
	firePart = Instance.new("Part")
	firePart.Name = "Logs"
	firePart.Size = Vector3.new(3, 0.8, 3)
	firePart.Anchored = true
	firePart.Material = Enum.Material.Wood
	firePart.Color = Color3.fromRGB(90, 60, 35)
	firePart.Position = Vector3.new(0, 0.4, 0)
	firePart.Parent = fireModel
	fireFx = Instance.new("Fire")
	fireFx.Size = 6
	fireFx.Heat = 10
	fireFx.Parent = firePart
	fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 160, 80)
	fireLight.Brightness = 3
	fireLight.Shadows = true
	fireLight.Parent = firePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Костёр и лагерь"
	prompt.ObjectText = "Лагерь"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = firePart
	prompt.Triggered:Connect(function(player)
		local ps = S.PlayerService.get(player)
		if ps and ps.class then
			Camp.openFire(ps, "fire")
		end
	end)
	fireModel.Parent = parent
end

function Camp.tick(dt: number)
	local c = State.run.camp
	local burn = 100 / (Config.DAY_LENGTH * 1.6) * dt
	for _, ps in pairs(State.players) do
		if ps.class == "pyro" then
			burn *= 0.6
			break
		end
	end
	if State.run.finale then
		burn *= 2.2
	end
	local before = c.fuel
	c.fuel = math.max(0, c.fuel - burn)
	if before > 20 and c.fuel <= 20 then
		State.notify(nil, "Костёр затухает! Подбросьте дров", "warn")
	end
	if fireLight then
		fireLight.Range = math.min(60, Camp.radius() * 0.6)
		fireFx.Size = 3 + c.level * 1.5 * math.clamp(c.fuel / 60, 0.2, 1)
		if c.level >= 5 then
			fireFx.Color = Color3.fromRGB(160, 230, 255)
		end
	end
end

return Camp
