-- Игроки: выбор класса, стартовое снаряжение, голод, холод, подбор добычи, действия (еда, фонарик, бинт), урон по игроку.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Remotes)
local Items = require(Shared.Items)
local Weapons = require(Shared.Weapons)
local Armor = require(Shared.Armor)
local Classes = require(Shared.Classes)
local Config = require(Shared.Config)
local World = require(Shared.World)
local Rules = require(Shared.Rules)
local Inventory = require(Shared.Inventory)

local PlayerService = {}
local S -- ссылки на остальные сервисы
local State

local FOOD_ORDER = { "gfish", "feast", "soup", "cmeat", "cfish", "honey", "apple", "berry", "meat", "fish" }

local function newState(player: Player)
	return {
		player = player,
		class = nil,
		inv = Inventory.new(Items, 1),
		hunger = 100,
		warmth = 100,
		blood = 0,
		buffs = {},
		cd = {},
		mag = {},
		reloadUntil = {},
		flashlight = 0, -- 0 нет, 1 старый, 2 сильный
		lightOn = false,
		lightCharge = 0,
		torchUntil = 0,
		flags = {},
		trees = 0,
		inBush = false,
		eaten = {},
		combo = 0,
		knowsBiome = false,
		tasks = { vampKills = 0, chests = 0, volcano = 0 },
		ticketsGiven = {},
		dirty = true,
	}
end

function PlayerService.get(player: Player)
	return State.players[player]
end

function PlayerService.sync(ps)
	ps.dirty = true
end

local function sendState(ps)
	local snap = ps.inv:snapshot()
	local run = State.run
	Remotes.State:FireClient(ps.player, {
		inv = snap,
		class = ps.class,
		hunger = ps.hunger,
		warmth = ps.warmth,
		blood = ps.blood,
		bloodMax = Rules.BLOOD_MAX,
		mag = ps.mag,
		lightOn = ps.lightOn,
		flashlight = ps.flashlight,
		day = run.day,
		phase = Rules.phase(run.clock, Config.DAY_LENGTH),
		night = Rules.isNight(run.clock, Config.DAY_LENGTH),
		raid = run.raid,
		fire = { level = run.camp.level, fuel = run.camp.fuel },
		biome = ps.knowsBiome and run.biome.name or nil,
		diamonds = (S.Data.get(ps.player) or {}).diamonds or 0,
	})
	ps.dirty = false
end

-- Выдать награду по описанию {weapon=, item=, n=, armor=, bag=, flashlight=, flag=, extra=}
function PlayerService.grant(ps, give)
	local parts = {}
	if give.weapon then
		if ps.inv:addWeapon(give.weapon, Weapons.ORDER) then
			table.insert(parts, Weapons[give.weapon].name)
		end
	end
	if give.item then
		PlayerService.give(ps, give.item, give.n or 1)
		table.insert(parts, Items[give.item].name .. " ×" .. (give.n or 1))
	end
	if give.armor then
		if ps.inv:equipArmor(give.armor, Armor) then
			table.insert(parts, Armor[give.armor].name)
		end
	end
	if give.extra then
		ps.inv.extras[give.extra] = true
		table.insert(parts, Armor.EXTRA[give.extra].name)
	end
	if give.bag then
		if ps.inv:setBag(give.bag) then
			table.insert(parts, Items.BAGS[give.bag].name)
		end
	end
	if give.flashlight then
		ps.flashlight = math.max(ps.flashlight, give.flashlight)
		table.insert(parts, give.flashlight == 2 and "Сильный фонарик" or "Старый фонарик")
	end
	if give.flag then
		ps.flags[give.flag] = true
		table.insert(parts, give.flag == "rod" and "Удочка" or "Дудочка")
	end
	PlayerService.applyCharacter(ps)
	PlayerService.sync(ps)
	return table.concat(parts, ", ")
end

-- Положить предмет; если не влезло — уронить рядом
function PlayerService.give(ps, id: string, n: number)
	local put, left = ps.inv:add(id, n)
	if left > 0 then
		local root = ps.player.Character and ps.player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			S.Drops.spawn(root.Position + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)), id, left, 2.5)
		end
		State.notify(ps.player, "Мешок полон! Отнеси добычу в лагерь", "warn")
	end
	PlayerService.sync(ps)
	return put
end

function PlayerService.applyCharacter(ps)
	local char = ps.player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or not ps.class then
		return
	end
	local cls = Classes.byId[ps.class]
	local speed = 16
	if ps.class == "woodsman" then
		speed *= 1.12
	end
	local arm = Armor[ps.inv.armor]
	if arm and arm.heavy then
		speed *= 0.92
	end
	if ps.buffs.spd and ps.buffs.spd > os.clock() then
		speed *= 1.18
	end
	hum.WalkSpeed = speed
	hum.UseJumpPower = true
	hum.JumpPower = ps.inv.extras.frogBoots and 80 or 50
	local maxHp = 100 + ((cls.kit and cls.kit.hp) or 0) + (ps.flags.grow or 0) * 2
	if hum.MaxHealth ~= maxHp then
		hum.MaxHealth = maxHp
	end
	-- фонарик: свет в голове
	local head = char:FindFirstChild("Head")
	if head then
		local light = head:FindFirstChild("Flashlight")
		if not light then
			light = Instance.new("SpotLight")
			light.Name = "Flashlight"
			light.Face = Enum.NormalId.Front
			light.Parent = head
		end
		light.Enabled = ps.lightOn
		light.Range = ps.flashlight == 2 and 60 or 40
		light.Angle = ps.flashlight == 2 and 55 or 40
		light.Brightness = 4
	end
end

local function giveKit(ps)
	local cls = Classes.byId[ps.class]
	local kit = cls.kit or {}
	ps.inv = Inventory.new(Items, 1)
	ps.inv:add("berry", 3)
	ps.inv:add("torch", 2)
	for _, w in ipairs(kit.weapons or {}) do
		ps.inv:addWeapon(w, Weapons.ORDER)
	end
	for id, n in pairs(kit.items or {}) do
		ps.inv:add(id, n)
	end
	if kit.armor then
		ps.inv:equipArmor(kit.armor, Armor)
	end
	if kit.flashlight then
		ps.flashlight = kit.flashlight
	end
	if kit.rod then
		ps.flags.rod = true
	end
	if kit.flute then
		ps.flags.flute = true
	end
	if kit.kettle then
		ps.flags.kettle = true
	end
	if kit.walls then
		State.run.camp.walls = true
	end
	for _, w in ipairs(ps.inv.weapons) do
		local def = Weapons[w]
		if def.mag then
			ps.mag[w] = def.mag
		end
	end
end

local function sendClassList(player: Player)
	local prof = S.Data.get(player)
	local list = {}
	for _, c in ipairs(Classes) do
		table.insert(list, {
			id = c.id,
			name = c.name,
			desc = c.desc,
			cost = c.cost,
			color = c.color,
			unlocked = S.Data.isUnlocked(player, c.id, c.cost),
			days = prof and prof.classDays[c.id] or 0,
		})
	end
	Remotes.ClassList:FireClient(player, list, prof and prof.diamonds or 0)
end

local function onChoose(player: Player, classId, buy)
	local ps = State.players[player]
	local cls = type(classId) == "string" and Classes.byId[classId]
	if not ps or not cls or ps.class then
		return
	end
	if not S.Data.isUnlocked(player, cls.id, cls.cost) then
		if buy and S.Data.buy(player, cls.id, cls.cost) then
			State.notify(player, "Класс «" .. cls.name .. "» куплен за " .. cls.cost .. " 💎", "good")
		else
			State.notify(player, "Не хватает алмазов: нужно " .. cls.cost .. " 💎", "warn")
			sendClassList(player)
			return
		end
	end
	ps.class = cls.id
	giveKit(ps)
	player:LoadCharacter()
	State.notify(player, "Ты " .. cls.name .. ". Загляни на стенд пропавших детей у костра: узнаешь, кто за тобой охотится", "good")
end

local function onCharacter(ps, char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	task.defer(function()
		PlayerService.applyCharacter(ps)
		hum.Health = hum.MaxHealth
	end)
	hum.Died:Connect(function()
		-- при смерти тяжёлая добыча из мешка падает на месте
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			for id, n in pairs(ps.inv.items) do
				if not Items[id].free then
					S.Drops.spawn(root.Position, id, n, 0)
					ps.inv.items[id] = nil
				end
			end
		end
		ps.hunger = math.max(ps.hunger, 60)
		State.notify(ps.player, "Ты погиб. Добыча из мешка осталась на месте гибели", "warn")
		PlayerService.sync(ps)
	end)
end

-- Урон по игроку (от мобов, Хранителей, ловушек)
function PlayerService.damage(ps, dmg: number, source)
	local char = ps.player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local arm = Armor[ps.inv.armor] or Armor.none
	local reduce = arm.reduce
	if ps.class == "defender" and S.Camp.inCamp(char:GetPivot().Position) then
		reduce = 1 - (1 - reduce) * 0.7
	end
	-- азарт-щит: рулетка
	if ps.class == "gamble" and State.rng() < 0.42 then
		local r = State.rng()
		if r < 0.35 then
			State.popup(char:GetPivot().Position + Vector3.new(0, 4, 0), "БЛОК!", Color3.fromRGB(255, 211, 107))
			return
		elseif r < 0.65 and source and source.hp then
			S.Mobs.damage(source, dmg * 2, { player = ps })
			State.popup(char:GetPivot().Position + Vector3.new(0, 4, 0), "ОТРАЖЕНИЕ!", Color3.fromRGB(255, 211, 107))
			return
		end
	end
	local final = Rules.damageTaken(dmg, {
		armorReduce = reduce,
		debuff = State.run.debuff or 0,
		tough = ps.buffs.tough and ps.buffs.tough > os.clock(),
	})
	hum:TakeDamage(final)
	State.popup(char:GetPivot().Position + Vector3.new(0, 3, 0), "-" .. math.floor(final), Color3.fromRGB(255, 107, 107))
	-- шипы брони джунглей
	if arm.thorns and source and source.hp then
		S.Mobs.damage(source, 8, { player = ps, poison = true, dot = true })
	end
end

function PlayerService.heal(ps, n: number)
	local hum = ps.player.Character and ps.player.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.Health = math.min(hum.MaxHealth, hum.Health + n)
	end
end

local function eat(ps)
	if ps.class == "cyborg" then
		if ps.inv:remove("battery", 1) then
			ps.hunger = math.min(100, ps.hunger + 45)
			State.notify(ps.player, "Батарейка: +45 энергии")
		else
			State.notify(ps.player, "Нет батареек для подзарядки", "warn")
		end
		return
	end
	for _, id in ipairs(FOOD_ORDER) do
		if ps.inv:has(id) then
			local def = Items[id]
			if ps.hunger > 94 and not def.heal then
				State.notify(ps.player, "Ты сыт")
				return
			end
			ps.inv:remove(id, 1)
			local v = def.food
			if ps.class == "cook" and ps.inv:has("spice") and not def.raw then
				ps.inv:remove("spice", 1)
				v *= 1.6
			end
			ps.hunger = math.min(100, ps.hunger + v)
			if def.heal then
				PlayerService.heal(ps, def.heal)
			end
			if def.raw and ps.class ~= "glutton" then
				PlayerService.damage(ps, 6)
				State.notify(ps.player, def.name .. ": живот болит! Лучше пожарь у костра", "warn")
			else
				State.notify(ps.player, "Съел: " .. def.name)
			end
			if ps.class == "glutton" and not ps.eaten[id] then
				ps.eaten[id] = true
				local opts = { "str", "spd", "regen", "tough" }
				local b = opts[State.rint(1, #opts)]
				ps.buffs[b] = os.clock() + 90
				State.notify(ps.player, "Обжора впервые пробует это блюдо: бонус на 90 с", "good")
			end
			PlayerService.sync(ps)
			return
		end
	end
	State.notify(ps.player, "Нет еды. Охоться на кроликов или собирай ягоды", "warn")
end

local function onAction(player: Player, action, arg)
	local ps = State.players[player]
	if ps and action == "class" and not ps.class then
		sendClassList(player)
		return
	end
	if not ps or not ps.class then
		return
	end
	if action == "eat" then
		eat(ps)
	elseif action == "bandage" then
		if ps.inv:remove("bandage", 1) then
			PlayerService.heal(ps, 35)
		else
			State.notify(player, "Нет бинтов", "warn")
		end
	elseif action == "flashlight" then
		if ps.flashlight == 0 then
			if ps.torchUntil < os.clock() and ps.inv:remove("torch", 1) then
				ps.torchUntil = os.clock() + Config.DAY_LENGTH
				S.Combat.attachTorch(ps)
				State.notify(player, "Факел зажжён")
			else
				State.notify(player, "Нет фонарика и факелов", "warn")
			end
		else
			if not ps.lightOn and ps.lightCharge <= 0 then
				if ps.class ~= "cyborg" and not ps.inv:remove("battery", 1) then
					State.notify(player, "Нет батареек", "warn")
					return
				end
				ps.lightCharge = Config.DAY_LENGTH * (ps.flashlight == 2 and 1.4 or 0.8)
			end
			ps.lightOn = not ps.lightOn
		end
		PlayerService.applyCharacter(ps)
	elseif action == "tame" then
		S.Structures.startTame(ps)
	elseif action == "throw" and typeof(arg) == "Vector3" then
		S.Combat.throw(ps, arg)
	end
	PlayerService.sync(ps)
end

local function tick(dt: number)
	local run = State.run
	for plr, ps in pairs(State.players) do
		if ps.class then
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				local pos = root.Position
				-- голод
				local drain = Config.HUNGER_PER_DAY / Config.DAY_LENGTH * dt * (ps.class == "glutton" and 1.3 or 1)
				ps.hunger = math.max(0, ps.hunger - drain)
				if ps.hunger <= 0 then
					hum:TakeDamage(2 * dt)
				elseif ps.hunger > 60 and hum.Health < hum.MaxHealth then
					hum.Health = math.min(hum.MaxHealth, hum.Health + (S.Camp.inLight(pos) and 1.8 or 0.6) * dt)
				end
				if ps.burnUntil and ps.burnUntil > os.clock() and ps.class ~= "pyro" then
					hum:TakeDamage(5 * dt)
				end
				if ps.poisonUntil and ps.poisonUntil > os.clock() then
					hum:TakeDamage(4 * dt * (ps.inv.extras.jhat and 0.4 or 1))
				end
				if ps.buffs.regen and ps.buffs.regen > os.clock() then
					hum.Health = math.min(hum.MaxHealth, hum.Health + 4 * dt)
				end
				-- холод
				local zone = World.zoneAt(pos.X, pos.Z)
				local arm = Armor[ps.inv.armor] or Armor.none
				local rate = 0
				if ps.class ~= "ice" then
					if zone == "winter" then
						local inCastle = (State.flat(pos) - Vector3.new(World.STRUCTURES.winterCastle.x, 0, World.STRUCTURES.winterCastle.z)).Magnitude < 60
						if inCastle then
							rate = arm.coldCastle and 0 or (arm.coldOutside and 7 or 14)
						else
							rate = arm.coldOutside and 0 or 6
						end
					end
				end
				if rate > 0 then
					ps.warmth = math.max(0, ps.warmth - rate * dt)
					if ps.warmth <= 0 then
						hum:TakeDamage(3 * dt)
					end
				else
					ps.warmth = math.min(100, ps.warmth + 15 * dt)
				end
				-- фонарик тратит заряд
				if ps.lightOn then
					ps.lightCharge -= dt
					if ps.lightCharge <= 0 then
						if ps.class ~= "cyborg" and ps.inv:remove("battery", 1) then
							ps.lightCharge = Config.DAY_LENGTH * (ps.flashlight == 2 and 1.4 or 0.8)
						elseif ps.class == "cyborg" then
							ps.lightCharge = 30
							ps.hunger = math.max(0, ps.hunger - 3)
						else
							ps.lightOn = false
							PlayerService.applyCharacter(ps)
							State.notify(plr, "Батарейки кончились", "warn")
						end
					end
				end
				-- перезарядка магазинов
				for w, t in pairs(ps.reloadUntil) do
					if os.clock() >= t then
						ps.reloadUntil[w] = nil
						ps.mag[w] = Weapons[w].mag
						ps.dirty = true
					end
				end
				-- в лагере тяжёлая добыча сама ложится на склад
				if S.Camp.inCamp(pos) then
					S.Camp.deposit(ps)
				end
				ps.inBush = S.WorldBuilder.inBush(pos)
				S.Drops.pickup(ps, pos)
			end
			if ps.dirty then
				sendState(ps)
			end
		end
	end
end

function PlayerService.init(services)
	S = services
	State = S.State
end

function PlayerService.start()
	Players.RespawnTime = 5
	Players.CharacterAutoLoads = false
	local function added(player: Player)
		local ps = newState(player)
		State.players[player] = ps
		S.Data.load(player)
		player.CharacterAdded:Connect(function(char)
			onCharacter(ps, char)
			-- автоматический респаун после смерти
			local hum = char:WaitForChild("Humanoid")
			hum.Died:Connect(function()
				task.wait(Players.RespawnTime)
				if player.Parent then
					player:LoadCharacter()
				end
			end)
		end)
		sendClassList(player)
	end
	Players.PlayerAdded:Connect(added)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(added, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		S.Data.release(player)
		State.players[player] = nil
	end)
	Remotes.ChooseClass.OnServerEvent:Connect(onChoose)
	Remotes.Action.OnServerEvent:Connect(onAction)
	Remotes.ClassList.OnServerEvent:Connect(function(player)
		sendClassList(player)
	end)

	local acc, syncAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		syncAcc += dt
		if acc >= 0.25 then
			tick(acc)
			acc = 0
		end
		if syncAcc >= 1 then
			syncAcc = 0
			for _, ps in pairs(State.players) do
				ps.dirty = true
			end
		end
	end)
end

return PlayerService
