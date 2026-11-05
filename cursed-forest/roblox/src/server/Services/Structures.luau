-- Постройки и события из записей: стенд, тотем, торговец, вулкан, плавильня, зал культа, замок оккультистов,
-- церковь, склеп, карнавал, зимний замок и ледяная глыба, эльф, пещера, храмы джунглей, озеро с лягушками,
-- корабль пришельцев, сундуки, слуги некроманта, лава, приручение. Окна (панели) общие: сервер шлёт кнопки, клиент рисует.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local World = require(Shared.World)
local Items = require(Shared.Items)
local Weapons = require(Shared.Weapons)
local Armor = require(Shared.Armor)
local Loot = require(Shared.Loot)
local Rules = require(Shared.Rules)
local Recipes = require(Shared.Recipes)
local Config = require(Shared.Config)
local MobDefs = require(Shared.Mobs)

local Structures = {}
local S, State
local part, prompt
local lavaZones = {}
local trader = { active = false, model = nil, untilDay = 0, nextDay = 2 }

local KIDS = {
	{ "Маша", "7 лет", "красная куртка" }, { "Тимур", "9 лет", "рюкзак с динозавром" }, { "Соня", "6 лет", "жёлтые сапожки" },
	{ "Артём", "11 лет", "синяя кепка" }, { "Лера", "8 лет", "заяц-игрушка" }, { "Паша", "10 лет", "веснушки и свисток" },
}

local function pos(id: string): Vector3
	local s = World.STRUCTURES[id]
	return Vector3.new(s.x, 0, s.z)
end

local function near(ps, id: string, r: number): boolean
	local root = ps.player.Character and ps.player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (State.flat(root.Position) - pos(id)).Magnitude < r
end

---------------------------------------------------------------- панели
function Structures.openPanel(ps, id: string, title: string, text: string, buttons)
	ps.panel = id
	Remotes.Panel:FireClient(ps.player, { id = id, title = title, text = text, buttons = buttons or {} })
end

local handlers = {}

local function grantEntry(ps, e)
	-- e = {"item", id, min, max} | {"weapon", id, plus=} | {"armor", id} | {"extra", id} | {"bag", tier}
	local kind, id = e[1], e[2]
	local give = {}
	if kind == "item" then
		give.item, give.n = id, State.rint(e[3] or 1, e[4] or e[3] or 1)
	elseif kind == "weapon" then
		give.weapon = id
	elseif kind == "armor" then
		give.armor = id
	elseif kind == "extra" then
		give.extra = id
	elseif kind == "bag" then
		give.bag = id
	end
	local msg = S.PlayerService.grant(ps, give)
	if e.plus then
		for item, n in pairs(e.plus) do
			S.PlayerService.give(ps, item, n)
			msg ..= ", " .. Items[item].name .. " ×" .. n
		end
	end
	if kind == "weapon" and Weapons[id].mag then
		ps.mag[id] = Weapons[id].mag
	end
	return msg
end
Structures.grantEntry = grantEntry

---------------------------------------------------------------- билетики карнавала (3 задания)
local TASKS = {
	{ id = "vampKills", need = 10, text = "Убей 10 вампиров" },
	{ id = "chests", need = 5, text = "Открой 5 сундуков" },
	{ id = "volcano", need = 5, text = "Брось 5 туш в вулкан" },
}
local function checkTickets(ps)
	for _, t in ipairs(TASKS) do
		if not ps.ticketsGiven[t.id] and (ps.tasks[t.id] or 0) >= t.need then
			ps.ticketsGiven[t.id] = true
			S.PlayerService.give(ps, "ticket", 1)
			State.notify(ps.player, "Задание выполнено: " .. t.text .. ". Получен билетик карнавала 🎟️", "good")
		end
	end
end

function Structures.onVampireKilled(ps)
	checkTickets(ps)
end

---------------------------------------------------------------- сундуки
function Structures.openChest(ps, c)
	local tier = c.tier
	if ps.class == "gamble" and tier ~= "infected" then
		tier = Rules.gambleTier(tier, State.rng)
		State.notify(ps.player, tier == c.tier and "Азарт: без изменений" or "Азарт: сундук стал " .. (tier == "ruby" and "рубиновым" or tier == "gold" and "золотым" or "обычным"))
	end
	local got = {}
	local tbl = Loot.CHEST[c.zone] or Loot.CHEST.forest
	local rolls = 2 + (ps.class == "explorer" and 1 or 0) + (tier ~= "common" and 1 or 0)
	for _ = 1, rolls do
		local e = Rules.pickWeighted(tbl, State.rng)
		table.insert(got, grantEntry(ps, e))
	end
	local extra = Loot.TIER_EXTRA[tier]
	if extra then
		if tier == "common" then
			local e = Rules.rollChance(extra, State.rng)
			if e and not ps.inv:hasWeapon(e[2]) then
				table.insert(got, grantEntry(ps, e))
			end
		else
			table.insert(got, grantEntry(ps, extra[State.rint(1, #extra)]))
		end
	end
	ps.tasks.chests += 1
	checkTickets(ps)
	State.notify(ps.player, "Сундук: " .. table.concat(got, "; "), "good")
end

---------------------------------------------------------------- строительные помощники
local function structFolder()
	return S.WorldBuilder.root.Structures
end

local function sign(at: Vector3, text: string)
	local p = part({ Size = Vector3.new(6, 4, 0.5), Position = at + Vector3.new(0, 3, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(138, 106, 66) })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = Color3.fromRGB(240, 230, 200)
	t.Parent = gui
	gui.Parent = p
	p.Parent = structFolder()
	return p
end

local function tower(at: Vector3, size: Vector3, color: Color3, material)
	local p = part({ Size = size, Position = at + Vector3.new(0, size.Y / 2, 0), Color = color, Material = material or Enum.Material.Cobblestone })
	p.Parent = structFolder()
	return p
end

local function aliveTag(tag)
	return S.Mobs.aliveWith("tag", tag)
end

local function spawnWave(center: Vector3, kinds, count: number, tag, radius: number?)
	for i = 1, count do
		local a = i / count * math.pi * 2 + State.rng()
		local r = (radius or 25) * (0.6 + State.rng() * 0.5)
		S.Mobs.spawn(kinds[(i - 1) % #kinds + 1], center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), { tag = tag, wave = true, important = true, home = center, leash = 200 })
	end
end

---------------------------------------------------------------- стенд пропавших детей
local function openBoard(ps)
	ps.knowsBiome = true
	local b = State.run.biome
	local lines = {}
	for _, k in ipairs(KIDS) do
		table.insert(lines, "🧒 " .. k[1] .. ", " .. k[2] .. ". Приметы: " .. k[3])
	end
	local text = table.concat(lines, "\n")
		.. "\n\n— За стендом —\nТвой биом: " .. b.name .. "\nОхотится на тебя: " .. b.hunterName .. ". " .. b.hint
		.. "\nКаждую ночь выходит ещё и Олень. Убить их нельзя."
		.. "\n\nЛавовый биом: вулкан, плавильня, зал культа, замок оккультистов.\nАлые земли: церковь, склеп вампиров, карнавал.\nЗимние горы: зимний замок, эльф.\nДжунгли: 4 малых храма и главный храм.\nОзеро: лягушки и водоворот (8 ключей).\nПещера: летучая мышь и Король пещерных оккультистов."
	Structures.openPanel(ps, "board", "Стенд пропавших детей", text, {})
	S.PlayerService.sync(ps)
end

---------------------------------------------------------------- тотем
local function openTotem(ps)
	local buttons = {}
	for i, t in ipairs(Recipes.TOTEM) do
		table.insert(buttons, { id = "t" .. i, label = Items[t.pelt].icon .. " " .. t.name .. "  (" .. S.Camp.have(ps, t.pelt) .. ")", enabled = S.Camp.have(ps, t.pelt) >= 1 })
	end
	Structures.openPanel(ps, "totem", "Тотем Скорняка", "Одна шкура — один предмет. Шкуры берутся со склада и из мешка.", buttons)
end
handlers.totem = function(ps, action)
	local i = tonumber(action:sub(2))
	local t = i and Recipes.TOTEM[i]
	if t and S.Camp.pay(ps, { [t.pelt] = 1 }) then
		ps.flags.totem = true
		State.notify(ps.player, "Тотем: " .. S.PlayerService.grant(ps, t.give), "good")
	end
	openTotem(ps)
end

---------------------------------------------------------------- тайный торговец
local function openTrader(ps)
	local buttons = {}
	local discount = ps.class == "bunbit" and 1 or 0
	for i, t in ipairs(Recipes.TRADER) do
		local price = math.max(1, t.price - discount)
		table.insert(buttons, { id = "b" .. i, label = t.name .. "  🐾" .. price, enabled = ps.inv:count("paw") >= price })
	end
	Structures.openPanel(ps, "trader", "Тайный торговец", "«Лапки, путник. Только лапки кролика.» У тебя: 🐾 " .. ps.inv:count("paw"), buttons)
end
handlers.trader = function(ps, action)
	local i = tonumber(action:sub(2))
	local t = i and Recipes.TRADER[i]
	if t then
		local price = math.max(1, t.price - (ps.class == "bunbit" and 1 or 0))
		if ps.inv:remove("paw", price) then
			State.notify(ps.player, "Куплено: " .. S.PlayerService.grant(ps, t.give), "good")
		end
	end
	openTrader(ps)
end

local function placeTrader()
	if trader.model then
		trader.model:Destroy()
	end
	local x, z = S.WorldBuilder.randomIn("forest")
	if not x then
		return
	end
	local m = Instance.new("Model")
	m.Name = "Тайный торговец"
	local body = part({ Size = Vector3.new(2.4, 4, 2), Position = Vector3.new(x, 2, z), Color = Color3.fromRGB(42, 58, 46) })
	body.Parent = m
	local lamp = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1, Position = Vector3.new(x + 1.8, 4.5, z), Material = Enum.Material.Neon, Color = Color3.fromRGB(125, 255, 154), CanCollide = false })
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(125, 255, 154)
	l.Range = 18
	l.Parent = lamp
	lamp.Parent = m
	prompt(body, "Торговать", "Тайный торговец", openTrader, 10)
	m.Parent = structFolder()
	trader.model = m
	trader.active = true
	trader.untilDay = State.run.day + 2
	trader.nextDay = State.run.day + 3
	State.notify(nil, "Тайный торговец пришёл в лес. Ищи зелёный фонарь", "good")
end

---------------------------------------------------------------- вулкан и плавильня
local function throwVolcano(ps)
	local c, b = ps.inv:count("carcass"), ps.inv:count("bcarcass")
	if c + b == 0 then
		State.notify(ps.player, "Нужны туши вампиров, оккультистов или пришельцев. Они падают после убийства", "warn")
		return
	end
	ps.inv:remove("carcass", c)
	ps.inv:remove("bcarcass", b)
	local from = State.run.volcano
	State.run.volcano += Rules.carcassValue(c, b)
	ps.tasks.volcano += c + b
	checkTickets(ps)
	for _, r in ipairs(Rules.volcanoRewards(Loot.VOLCANO, from, State.run.volcano)) do
		State.notify(ps.player, "Вулкан принял жертву и даёт: " .. grantEntry(ps, r.reward), "good")
	end
	for _ = 1, c + b do
		if State.rng() < Loot.VOLCANO_ALIEN.chance then
			local pool = Loot.VOLCANO_ALIEN.pool
			State.notify(ps.player, "Из жерла вылетело что-то инопланетное: " .. grantEntry(ps, { "weapon", pool[State.rint(1, #pool)] }), "good")
			break
		end
	end
	local nextR
	for _, r in ipairs(Loot.VOLCANO) do
		if State.run.volcano < r.at then
			nextR = r
			break
		end
	end
	State.notify(ps.player, "Вулкан: " .. State.run.volcano .. " туш" .. (nextR and (". До «" .. nextR.name .. "» ещё " .. (nextR.at - State.run.volcano)) or ". Все награды получены"))
	S.PlayerService.sync(ps)
end

local function useSmelter(ps)
	if not ps.inv:remove("fuel", 1) then
		State.notify(ps.player, "Плавильне нужна канистра с топливом", "warn")
		return
	end
	local r = Loot.SMELTER[State.rint(1, #Loot.SMELTER)]
	S.PlayerService.give(ps, r[1], r[2])
	State.notify(ps.player, "Плавильня выдала: " .. Items[r[1]].name .. " ×" .. r[2], "good")
end

---------------------------------------------------------------- лава (бутылка зимнего огня)
function Structures.makeLava(at: Vector3, duration: number)
	local p = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 18, 18), CFrame = CFrame.new(at.X, 0.2, at.Z) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 100, 30), CanCollide = false })
	p.Parent = structFolder()
	table.insert(lavaZones, { pos = Vector3.new(at.X, 0, at.Z), r = 9, untilT = os.clock() + duration, part = p })
	State.notify(nil, "Зимний огонь разлился лавой на 3 минуты")
end

---------------------------------------------------------------- боссы
local BOSS_MINIONS = { bat = "rabbit", spider = "wolf", occKing = "occ", caveKing = "occCave", alienKing = "alien", vampKing = "vampire", frogBoss = "frogGreen" }

local function spawnBoss(kind: string, at: Vector3)
	if S.Mobs.aliveWith("kind", kind) > 0 then
		return nil
	end
	local def = MobDefs.BOSSES[kind]
	local mob = S.Mobs.spawn(kind, at, { important = true, home = at, leash = 300, tag = "boss" })
	if not mob then
		return nil
	end
	mob.slamAt = os.clock() + 5
	mob.summonAt = os.clock() + 9
	mob.bossTick = function(m, target, d, now)
		if now > m.slamAt then
			m.slamAt = now + 6
			S.Combat.explode(m.root.Position, 14, m.dmg * 0.8, nil, true)
		end
		if now > m.summonAt then
			m.summonAt = now + 12
			local minion = BOSS_MINIONS[kind]
			if minion and MobDefs[minion] then
				spawnWave(m.root.Position, { minion }, 2, "bossMinion", 10)
			end
		end
	end
	State.notify(nil, "⚔ " .. def.name .. "!", "boss")
	return mob
end
Structures.spawnBoss = spawnBoss

local SEAL_BOSSES = { bat = true, spider = true, occKing = true, caveKing = true, alienKing = true, vampKing = true }

function Structures.onBossKilled(mob, ps)
	local kind = mob.kind
	State.run.bossesDone[kind] = true
	if SEAL_BOSSES[kind] then
		S.Camp.storage.shard = (S.Camp.storage.shard or 0) + 1
		State.notify(nil, MobDefs.BOSSES[kind].name .. " повержен! Осколок печати на складе лагеря: " .. S.Camp.storage.shard .. "/6", "good")
	end
	if not ps then
		return
	end
	if kind == "caveKing" then
		grantEntry(ps, { "weapon", "cdag" })
	elseif kind == "vampKing" then
		grantEntry(ps, { "weapon", "scythe" })
	elseif kind == "occKing" then
		grantEntry(ps, { "weapon", "hammer" })
		grantEntry(ps, { "weapon", "lcross", plus = { arrow = 15 } })
		S.PlayerService.give(ps, "coin", 20)
		S.PlayerService.give(ps, "fbottle", 2)
		State.notify(ps.player, "Король оккультистов: молот, лавовый арбалет, 20 монет и 2 бутылки зимнего огня", "good")
	elseif kind == "alienKing" then
		local e = Loot.UFO_CHEST[State.rint(1, #Loot.UFO_CHEST)]
		State.notify(ps.player, "Сундук корабля: " .. grantEntry(ps, e), "good")
		State.run.ufo.cleared = true
	elseif kind == "frogBoss" then
		-- после босса: 2 фиолетовые, 4 синие и 6 зелёных лягушек
		local at = pos("whirlpool") + Vector3.new(0, 0, 180)
		spawnWave(at, { "frogPurple", "frogPurple", "frogBlue", "frogBlue", "frogBlue", "frogBlue", "frogGreen", "frogGreen", "frogGreen", "frogGreen", "frogGreen", "frogGreen" }, 12, "frogFinal", 25)
		State.run.frogs.wave = 99
	end
end

---------------------------------------------------------------- слуги некроманта
function Structures.makeCorpse(at: Vector3, kind: string)
	local p = part({ Size = Vector3.new(3, 0.6, 2), Position = Vector3.new(at.X, 0.3, at.Z), Color = Color3.fromRGB(42, 26, 48), CanCollide = false })
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(181, 143, 209)
	l.Range = 8
	l.Parent = p
	p.Parent = structFolder()
	game:GetService("Debris"):AddItem(p, 30)
	prompt(p, "Поднять слугу", kind == "occKing" and "Король оккультистов" or "Тело оккультиста", function(ps, pr)
		if ps.class ~= "necro" then
			State.notify(ps.player, "Поднимать мёртвых умеет только некромант")
			return
		end
		local mine = 0
		for _, m in ipairs(S.Mobs.all()) do
			if m.alive and m.ally and m.owner == ps and m.servant then
				mine += 1
			end
		end
		if mine >= 3 then
			State.notify(ps.player, "Слишком много слуг", "warn")
			return
		end
		pr.Enabled = false
		local mob = S.Mobs.spawn(kind, at, { important = true, servant = true })
		if mob then
			S.Mobs.makeAlly(mob, ps, false)
			State.notify(ps.player, kind == "occKing" and "Король оккультистов служит тебе!" or "Оккультист поднялся и служит тебе", "good")
		end
		p:Destroy()
	end, 8)
end

---------------------------------------------------------------- приручение (флейтист)
local tames = {}
function Structures.startTame(ps)
	if not ps.flags.flute or ps.class ~= "flute" then
		State.notify(ps.player, "Приручать зверей умеет флейтист с дудочкой", "warn")
		return
	end
	local root = ps.player.Character and ps.player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local best, bd = nil, 18
	for _, m in ipairs(S.Mobs.all()) do
		if m.alive and not m.ally and (m.kind == "wolf" or m.kind == "alpha" or m.kind == "bear" or m.kind == "rabbit" or m.kind == "boar") then
			local d = (m.root.Position - root.Position).Magnitude
			if d < bd then
				best, bd = m, d
			end
		end
	end
	if not best then
		State.notify(ps.player, "Подойди ближе к зверю (волк, медведь, кабан, кролик)")
		return
	end
	tames[ps] = { mob = best, started = os.clock() }
	best.statuses.stun = os.clock() + 20
	Structures.openPanel(ps, "tame", "Приручение: " .. best.def.name, "Нажимай, когда стрелка в зелёной зоне. Заполни шкалу, потом накорми зверя.", { { id = "minigame", label = "", minigame = true } })
end
handlers.tame = function(ps, action)
	local t = tames[ps]
	if not t or not t.mob.alive then
		return
	end
	if action == "success" and os.clock() - t.started > 2 then
		local foods = { "cmeat", "cfish", "meat", "fish", "honey", "apple", "berry" }
		for _, f in ipairs(foods) do
			if ps.inv:remove(f, 1) then
				local pets = 0
				for _, m in ipairs(S.Mobs.all()) do
					if m.alive and m.ally and m.owner == ps and m.pet then
						pets += 1
					end
				end
				if pets >= 3 then
					State.notify(ps.player, "У тебя уже 3 питомца", "warn")
					return
				end
				t.mob.pet = true
				S.Mobs.makeAlly(t.mob, ps, true)
				t.mob.statuses.stun = nil
				State.notify(ps.player, t.mob.def.name .. " приручён и теперь твой питомец!", "good")
				tames[ps] = nil
				S.PlayerService.sync(ps)
				return
			end
		end
		State.notify(ps.player, "Нечем накормить зверя: нужна еда в мешке", "warn")
	elseif action == "fail" then
		t.mob.statuses.stun = nil
		tames[ps] = nil
	end
end

---------------------------------------------------------------- храмы джунглей
local function templePrompt(i: number)
	return function(ps)
		local st = State.run.temples[i]
		local at = pos("jungleTemple" .. i)
		if st == 0 then
			State.run.temples[i] = 1
			spawnWave(at, { "occJungle", "occJungle", "boar", "boar", "frog", "occJungleArcher" }, 6, "temple" .. i, 20)
			State.notify(nil, "Стража малого храма проснулась!", "boss")
		elseif st == 1 then
			if aliveTag("temple" .. i) > 0 then
				State.notify(ps.player, "Сначала расправься со стражей храма", "warn")
				return
			end
			State.run.temples[i] = 3
			S.PlayerService.give(ps, "skull", 1)
			S.WorldBuilder.makeChest(at.X + 8, at.Z + 8, "jungle", "common")
			State.notify(ps.player, "В подвале на стене нарисована пантера. Лёгкое испытание пройдено: ты забрал череп", "good")
		else
			State.notify(ps.player, "Подвал пуст")
		end
	end
end

local function jungleMain(ps)
	local run = State.run
	if not run.jungleMain then
		if ps.inv:count("skull") < 4 then
			State.notify(ps.player, "Нужно 4 черепа из малых храмов (" .. ps.inv:count("skull") .. "/4)", "warn")
			return
		end
		ps.inv:remove("skull", 4)
		run.jungleMain = true
		run.jungleOpens = #State.run.temples
		for id, n in pairs(Loot.JUNGLE_MAIN) do
			S.PlayerService.give(ps, id, n)
		end
		spawnWave(pos("jungleMain"), { "boar", "boar", "boar" }, 3, "jungleMain", 15)
		State.notify(nil, "Пол опустился, внизу лестница! Амулеты, зелёные фрагменты и сундук джунглей", "boss")
		return
	end
	if run.jungleOpens <= 0 then
		State.notify(ps.player, "Сундук джунглей пуст")
		return
	end
	run.jungleOpens -= 1
	local e = Loot.JUNGLE_CHEST[State.rint(1, #Loot.JUNGLE_CHEST)]
	State.notify(ps.player, "Сундук джунглей: " .. grantEntry(ps, e) .. " (осталось открытий: " .. run.jungleOpens .. ")", "good")
end

---------------------------------------------------------------- зимний замок
local function iceBlock(ps)
	local run = State.run
	local at = pos("winterCastle")
	if run.ice == 0 then
		run.ice = 1
		spawnWave(at, { "occ", "occ", "occWinterSword", "occWinterSword" }, 4, "ice", 12)
		State.notify(nil, "Глыба раскололась! Спавшие во льду оккультисты проснулись", "boss")
	elseif run.ice == 1 then
		if aliveTag("ice") > 0 then
			State.notify(ps.player, "Сначала победи проснувшихся оккультистов", "warn")
			return
		end
		run.ice = 3
		local e = Loot.ICE_CHEST[State.rint(1, #Loot.ICE_CHEST)]
		State.notify(ps.player, "Сундук во льду: " .. grantEntry(ps, e) .. ". Враги замерзают на 3 секунды", "good")
	else
		State.notify(ps.player, "Глыба разбита, сундук пуст")
	end
end

local function elfGift(ps)
	if not ps.inv:remove("gem", 1) then
		State.notify(ps.player, "Эльф: «Принеси мне зимний камень»")
		return
	end
	local r = State.rng()
	if r < 0.55 then
		local good = { { "battery", 4 }, { "bandage", 4 }, { "paw", 6 }, { "coin", 8 }, { "mshard", 1 }, { "bullet", 10 } }
		local g = good[State.rint(1, #good)]
		S.PlayerService.give(ps, g[1], g[2])
		State.notify(ps.player, "Эльф дарит: " .. Items[g[1]].name .. " ×" .. g[2], "good")
	elseif r < 0.85 then
		S.PlayerService.give(ps, "berry", 2)
		State.notify(ps.player, "Эльф дарит 2 ягоды. Скромно")
	else
		S.PlayerService.give(ps, "rope", 1)
		State.notify(ps.player, "Эльф дарит старую верёвку. Не повезло", "warn")
	end
end

---------------------------------------------------------------- замок оккультистов (3 этажа)
local function occCastle(ps)
	local run = State.run
	local at = pos("occCastle")
	if run.castleActive then
		if aliveTag("castle") > 0 then
			State.notify(ps.player, "На этаже ещё оккультисты", "warn")
			return
		end
		run.castleActive = false
		run.castleFloor += 1
		if run.castleFloor >= 3 then
			for id, n in pairs(Loot.OCC_CASTLE.items) do
				S.PlayerService.give(ps, id, n)
			end
			for _, p in ipairs(State.alivePlayers()) do
				if (State.flat(p.root.Position) - at).Magnitude < 120 then
					S.Data.addDiamonds(p.player, Loot.OCC_CASTLE.diamonds)
					State.notify(p.player, "Сундук замка: 5 алмазов 💎 (на них покупают классы)", "good")
				end
			end
			State.notify(ps.player, "Замок пройден: 5 металла, 3 амулета, зелёный фрагмент", "good")
			return
		end
		State.notify(nil, "Этаж " .. run.castleFloor .. " зачищен. Поднимайся выше", "good")
		return
	end
	if run.castleFloor >= 3 then
		State.notify(ps.player, "Замок пуст")
		return
	end
	local floor = run.castleFloor + 1
	local kinds = ({
		{ "occ", "occ", "occArcher", "occLava" },
		{ "occLava", "occLavaArcher", "occBrute", "occArcher" },
		{ "occBrute", "occLavaArcher", "occBrute", "occLava" },
	})[floor]
	spawnWave(at + Vector3.new(0, 0, 0), kinds, 4 + floor * 3, "castle", 20)
	run.castleActive = true
	State.notify(nil, "Замок оккультистов, этаж " .. floor .. " из 3!", "boss")
end

---------------------------------------------------------------- карнавал (3 этапа, вход за 3 билетика)
local function carnivalPanel(ps)
	local c = State.run.carnival
	local text, buttons = "", {}
	if c.stage == 0 then
		text = "Вход: 3 билетика. Задания за билетики:\n"
		for _, t in ipairs(TASKS) do
			text ..= (ps.ticketsGiven[t.id] and "✓ " or "· ") .. t.text .. " (" .. math.min(ps.tasks[t.id] or 0, t.need) .. "/" .. t.need .. ")\n"
		end
		table.insert(buttons, { id = "enter", label = "Войти (🎟️ " .. ps.inv:count("ticket") .. "/3)", enabled = ps.inv:count("ticket") >= 3 })
	elseif c.active then
		text = "Этап " .. c.stage .. ": победи всех вампиров (" .. aliveTag("carnival") .. " осталось)"
	elseif c.stage == 1 then
		text = "Этап 1 пройден, коса получена. Этап 2: пожертвуй " .. c.killed .. " туш вампиров."
		table.insert(buttons, { id = "sacrifice", label = "Пожертвовать ⚰️ " .. ps.inv:count("carcass") .. "/" .. c.killed, enabled = ps.inv:count("carcass") >= c.killed })
	elseif c.stage == 2 then
		text = "Этап 3: снова вампиры."
		table.insert(buttons, { id = "fight", label = "Начать этап 3", enabled = true })
	elseif c.stage == 3 then
		text = "Последний сундук: пожертвуй " .. c.killed .. " туш вампиров."
		table.insert(buttons, { id = "sacrifice", label = "Пожертвовать ⚰️ " .. ps.inv:count("carcass") .. "/" .. c.killed, enabled = ps.inv:count("carcass") >= c.killed })
	else
		text = "Карнавал пройден. Можно выходить."
	end
	Structures.openPanel(ps, "carnival", "Карнавал", text, buttons)
end
local function carnivalWave(n: number)
	local c = State.run.carnival
	c.active = true
	c.killed = n
	spawnWave(pos("carnival"), { "vampire" }, n, "carnival", 22)
end
handlers.carnival = function(ps, action)
	local c = State.run.carnival
	if action == "enter" and c.stage == 0 and ps.inv:remove("ticket", 3) then
		c.stage = 1
		carnivalWave(8 + math.floor(State.run.day / 10))
	elseif action == "sacrifice" and not c.active and (c.stage == 1 or c.stage == 3) then
		local need = Rules.carnivalSacrifice(2, c.killed)
		if ps.inv:remove("carcass", need) then
			local reward = c.stage == 1 and Loot.CARNIVAL[2] or Loot.CARNIVAL[3]
			State.notify(ps.player, "Сундук карнавала: " .. grantEntry(ps, reward), "good")
			c.stage += 1
		end
	elseif action == "fight" and c.stage == 2 and not c.active then
		c.stage = 3
		carnivalWave(10 + math.floor(State.run.day / 8))
	end
	carnivalPanel(ps)
end

---------------------------------------------------------------- озеро, рыбалка, водоворот
local fishing = {}
local function fish(ps)
	if not ps.flags.rod then
		State.notify(ps.player, "Нужна удочка: обменяй шкуру волка на Тотеме", "warn")
		return
	end
	if fishing[ps] then
		return
	end
	fishing[ps] = true
	State.notify(ps.player, "Закинул удочку…")
	task.delay(2, function()
		fishing[ps] = nil
		local r = State.rng()
		if r < 0.05 then
			S.PlayerService.give(ps, "frogkey", 1)
			State.notify(ps.player, "Выудил лягушачий ключ! 🗝️ " .. ps.inv:count("frogkey") .. "/" .. Rules.FROG_KEYS, "good")
		elseif r < 0.09 then
			S.PlayerService.give(ps, "gfish", 1)
			State.notify(ps.player, "Золотая рыба! Полностью лечит", "good")
		else
			S.PlayerService.give(ps, "fish", ps.class == "fisher" and 2 or 1)
		end
	end)
end

local FROG_WAVES = {
	{ "frog", "frog", "frog", "frog", "frog", "frog" },
	{ "frogGreen", "frogGreen", "frogGreen", "frogGreen", "frogGreen" },
	{ "frogBlue", "frogBlue", "frogBlue", "frogPurple", "frogPurple" },
}
local function whirlpool(ps)
	local f = State.run.frogs
	if f.active then
		State.notify(ps.player, "Битва с лягушками уже идёт", "warn")
		return
	end
	if f.wave >= 99 then
		State.notify(ps.player, "Водоворот затих")
		return
	end
	if ps.inv:count("frogkey") < Rules.FROG_KEYS then
		State.notify(ps.player, "Нужно " .. Rules.FROG_KEYS .. " лягушачьих ключей (" .. ps.inv:count("frogkey") .. "). Их роняют синие лягушки, их можно выловить удочкой", "warn")
		return
	end
	ps.inv:remove("frogkey", Rules.FROG_KEYS)
	f.active = true
	f.wave = 1
	f.ps = ps
	-- арена на берегу: страж водоворота — фиолетовая лягушка, потом волны
	local arena = pos("whirlpool") + Vector3.new(0, 0, 180)
	local root = ps.player.Character and ps.player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(arena + Vector3.new(0, 4, 0))
	end
	spawnWave(arena, FROG_WAVES[1], #FROG_WAVES[1], "frogs", 20)
	State.notify(nil, "Водоворот открылся! Лягушки идут волнами", "boss")
end

local function carnivalTick()
	local c = State.run.carnival
	if c.active and aliveTag("carnival") == 0 then
		c.active = false
		if c.stage == 1 then
			for _, p in ipairs(State.alivePlayers()) do
				if (State.flat(p.root.Position) - pos("carnival")).Magnitude < 120 then
					State.notify(p.player, "Первый сундук карнавала: " .. grantEntry(p.ps, Loot.CARNIVAL[1]), "good")
				end
			end
		else
			State.notify(nil, "Вампиры карнавала побеждены. Пожертвуй туши у входа", "good")
		end
	end
end

local function frogTick()
	local f = State.run.frogs
	if not f.active then
		return
	end
	local arena = pos("whirlpool") + Vector3.new(0, 0, 180)
	if f.wave < 90 and aliveTag("frogs") == 0 and S.Mobs.aliveWith("kind", "frogBoss") == 0 then
		f.wave += 1
		if f.wave <= #FROG_WAVES then
			spawnWave(arena, FROG_WAVES[f.wave], #FROG_WAVES[f.wave], "frogs", 20)
		elseif f.wave == #FROG_WAVES + 1 then
			spawnBoss("frogBoss", arena)
		end
	elseif f.wave >= 99 and aliveTag("frogFinal") == 0 then
		f.active = false
		local ps = f.ps
		if ps and ps.player.Parent then
			local e = Rules.rollChance(Loot.FROG_BOSS, State.rng)
			if e then
				State.notify(ps.player, "Доска лягушачьего царства: " .. grantEntry(ps, e), "good")
			else
				S.PlayerService.give(ps, "coin", 10)
				State.notify(ps.player, "В этот раз редкая награда не выпала (шанс 1–3%). Утешительный приз: 10 монет", "warn")
			end
		end
	end
end

---------------------------------------------------------------- корабль пришельцев
local ufoModel
local function ufoPrompt(ps)
	local u = State.run.ufo
	if not u.crashed then
		return
	end
	if u.cleared then
		State.notify(ps.player, "Корабль зачищен")
		return
	end
	if u.active then
		if aliveTag("ufo") > 0 then
			State.notify(ps.player, "Сначала победи пришельцев в комнате (" .. aliveTag("ufo") .. ")", "warn")
			return
		end
		u.active = false
		u.room += 1
		if u.room >= 6 then
			spawnBoss("alienKing", pos("whirlpool") + Vector3.new(-300, 0, -380))
			State.notify(nil, "Все 6 комнат зачищены! Король инопланетян вышел навстречу", "boss")
		else
			State.notify(nil, "Комната " .. u.room .. " зачищена", "good")
		end
		return
	end
	if u.room >= 6 then
		return
	end
	local basic, elite = Rules.ufoRoom(u.room + 1, Config.UFO_SCALE)
	local kinds = {}
	for _ = 1, elite do
		table.insert(kinds, "alienElite")
	end
	for _ = 1, basic do
		table.insert(kinds, "alien")
	end
	spawnWave(ufoModel:GetPivot().Position, kinds, #kinds, "ufo", 35)
	u.active = true
	State.notify(nil, "Комната " .. (u.room + 1) .. " из 6: " .. basic .. " пришельцев и " .. elite .. " в броне киборга", "boss")
end

function Structures.crashUfo()
	local u = State.run.ufo
	if u.crashed then
		return
	end
	u.crashed = true
	local at = pos("whirlpool") + Vector3.new(-300, 0, -380)
	ufoModel = Instance.new("Model")
	ufoModel.Name = "Летающая тарелка"
	local disc = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 40, 40), CFrame = CFrame.new(at + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Metal, Color = Color3.fromRGB(154, 163, 168) })
	disc.Parent = ufoModel
	local dome = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 16, Position = at + Vector3.new(0, 7, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(95, 230, 122), Transparency = 0.3 })
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(95, 230, 122)
	glow.Range = 40
	glow.Brightness = 3
	glow.Parent = dome
	dome.Parent = ufoModel
	prompt(dome, "Войти в комнату", "Тарелка светится зелёным: вход открыт", ufoPrompt, 25)
	ufoModel.PrimaryPart = disc
	ufoModel.Parent = structFolder()
	-- снаружи два слабых пришельца и сундуки
	spawnWave(at + Vector3.new(30, 0, 0), { "alien", "alien" }, 2, "ufoOutside", 8)
	for i = 1, 3 do
		S.WorldBuilder.makeChest(at.X + math.cos(i * 2) * 32, at.Z + math.sin(i * 2) * 32, "forest", "gold")
	end
	State.notify(nil, "👽 В лес упала летающая тарелка! Она светится зелёным — значит, внутрь можно войти", "boss")
end

---------------------------------------------------------------- постройка всего
function Structures.build()
	-- стенд и тотем в лагере
	local board = sign(pos("board"), "ПРОПАЛИ ДЕТИ")
	prompt(board, "Читать", "Стенд пропавших детей", openBoard, 10)
	local totem = tower(pos("totem"), Vector3.new(1.6, 7, 1.6), Color3.fromRGB(90, 58, 34), Enum.Material.Wood)
	prompt(totem, "Обменять шкуры", "Тотем Скорняка", openTotem, 9)

	-- вулкан
	local v = pos("volcano")
	local cone = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(40, 70, 70), CFrame = CFrame.new(v + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Basalt, Color = Color3.fromRGB(58, 42, 40) })
	cone.Parent = structFolder()
	local crater = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 30, 30), CFrame = CFrame.new(v + Vector3.new(0, 40.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 106, 42) })
	local fire = Instance.new("Fire")
	fire.Size = 20
	fire.Heat = 25
	fire.Parent = crater
	crater.Parent = structFolder()
	local ledge = part({ Size = Vector3.new(14, 1, 10), Position = v + Vector3.new(0, 0.5, 40), Material = Enum.Material.Basalt, Color = Color3.fromRGB(80, 60, 55) })
	ledge.Parent = structFolder()
	prompt(ledge, "Бросить туши", "Вулкан", throwVolcano, 14)

	local sm = tower(pos("smelter"), Vector3.new(8, 8, 8), Color3.fromRGB(90, 70, 60), Enum.Material.Brick)
	prompt(sm, "Бросить канистру", "Плавильня", useSmelter, 10)

	local hall = tower(pos("ritualHall"), Vector3.new(24, 10, 24), Color3.fromRGB(70, 30, 30), Enum.Material.Cobblestone)
	prompt(hall, "Призвать короля (4 амулета)", "Зал культа", function(ps)
		if State.run.bossesDone.occKing then
			State.notify(ps.player, "Король оккультистов уже повержен")
			return
		end
		if not ps.inv:remove("amulet", 4) then
			State.notify(ps.player, "Нужно 4 амулета оккультиста (" .. ps.inv:count("amulet") .. "/4)", "warn")
			return
		end
		spawnBoss("occKing", pos("ritualHall") + Vector3.new(0, 0, 30))
	end, 16)

	local castle = tower(pos("occCastle"), Vector3.new(40, 36, 40), Color3.fromRGB(60, 40, 45), Enum.Material.Cobblestone)
	prompt(castle, "Войти на этаж", "Замок оккультистов", occCastle, 26)

	-- алые земли
	local church = tower(pos("church"), Vector3.new(18, 14, 26), Color3.fromRGB(106, 74, 82), Enum.Material.Brick)
	prompt(church, "Взять бинты", "Церковь", function(ps)
		if State.run.day - State.run.churchDay < 2 then
			State.notify(ps.player, "Бинты ещё не пополнили, приходи через пару дней", "warn")
			return
		end
		State.run.churchDay = State.run.day
		S.PlayerService.give(ps, "bandage", 4)
		State.notify(ps.player, "В церкви ты взял 4 бинта", "good")
	end, 18)
	local crypt = tower(pos("crypt"), Vector3.new(16, 8, 16), Color3.fromRGB(40, 30, 36), Enum.Material.Slate)
	prompt(crypt, "Разбудить Короля вампиров", "Склеп", function(ps)
		if State.run.bossesDone.vampKing then
			State.notify(ps.player, "Склеп пуст")
			return
		end
		if State.run.day < 20 then
			State.notify(ps.player, "Из склепа веет холодом. Король вампиров проснётся после 20-го дня", "warn")
			return
		end
		spawnBoss("vampKing", pos("crypt") + Vector3.new(0, 0, 25))
	end, 14)
	local carnival = tower(pos("carnival"), Vector3.new(30, 12, 30), Color3.fromRGB(180, 60, 90), Enum.Material.Fabric)
	prompt(carnival, "Карнавал", "Карнавал", carnivalPanel, 20)

	-- зима
	local wc = pos("winterCastle")
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		tower(wc + Vector3.new(math.cos(a) * 45, 0, math.sin(a) * 45), Vector3.new(10, 22, 10), Color3.fromRGB(180, 205, 225), Enum.Material.Ice)
	end
	local ice = part({ Size = Vector3.new(10, 10, 10), Position = wc + Vector3.new(0, 5, 0), Material = Enum.Material.Ice, Color = Color3.fromRGB(160, 220, 245), Transparency = 0.25 })
	ice.Parent = structFolder()
	prompt(ice, "Разбить глыбу", "Ледяная глыба", iceBlock, 12)
	local elf = tower(pos("elf"), Vector3.new(6, 6, 6), Color3.fromRGB(232, 238, 242), Enum.Material.Snow)
	prompt(elf, "Отдать зимний камень", "Эльф", elfGift, 10)

	-- пещера: летучая мышь, затем король пещерных оккультистов
	local cave = tower(pos("caveEntrance"), Vector3.new(40, 26, 10), Color3.fromRGB(50, 46, 52), Enum.Material.Slate)
	prompt(cave, "Потревожить пещеру", "Пещера", function(ps)
		if not State.run.bossesDone.bat then
			spawnBoss("bat", pos("caveEntrance") + Vector3.new(0, 0, 30))
		elseif not State.run.bossesDone.caveKing then
			spawnBoss("caveKing", pos("caveEntrance") + Vector3.new(0, 0, 30))
		else
			State.notify(ps.player, "Пещера затихла")
		end
	end, 24)

	-- джунгли
	for i = 1, 4 do
		local t = tower(pos("jungleTemple" .. i), Vector3.new(16, 12, 16), Color3.fromRGB(70, 100, 62), Enum.Material.Cobblestone)
		prompt(t, "Войти в храм", "Малый храм", templePrompt(i), 14)
	end
	local main = tower(pos("jungleMain"), Vector3.new(30, 20, 30), Color3.fromRGB(60, 90, 52), Enum.Material.Cobblestone)
	prompt(main, "Главный храм", "4 черепа", jungleMain, 22)

	-- озеро: причал для рыбалки и водоворот
	local wp = pos("whirlpool")
	local pier = part({ Size = Vector3.new(6, 1, 30), Position = wp + Vector3.new(0, 0.5, 140), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(120, 90, 60) })
	pier.Parent = structFolder()
	prompt(pier, "Рыбачить", "Причал", fish, 16)
	local pool = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 24, 24), CFrame = CFrame.new(wp + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = Color3.fromRGB(80, 60, 200), Transparency = 0.4 })
	pool.Parent = structFolder()
	local guardFrog = part({ Size = Vector3.new(4, 3, 4), Position = wp + Vector3.new(0, 0, 125), Color = Color3.fromRGB(150, 70, 210) })
	guardFrog.Parent = structFolder()
	prompt(guardFrog, "Прыгнуть в водоворот (" .. Rules.FROG_KEYS .. " ключей)", "Страж — фиолетовая лягушка", whirlpool, 12)

	-- лава от бутылок и арена событий
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for i = #lavaZones, 1, -1 do
			local z = lavaZones[i]
			if now > z.untilT then
				z.part:Destroy()
				table.remove(lavaZones, i)
			else
				for _, m in ipairs(S.Mobs.inRadius(z.pos, z.r)) do
					m.statuses.burn = now + 1.5
				end
				for _, p in ipairs(State.alivePlayers()) do
					if p.ps.class ~= "pyro" and (State.flat(p.root.Position) - z.pos).Magnitude < z.r then
						p.ps.burnUntil = now + 1.5
					end
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(frogTick)
			pcall(carnivalTick)
		end
	end)
end

---------------------------------------------------------------- события суток
function Structures.dawn(day: number)
	if trader.active and day >= trader.untilDay then
		trader.active = false
		if trader.model then
			trader.model:Destroy()
			trader.model = nil
		end
	end
	if not trader.active and day >= trader.nextDay then
		placeTrader()
	end
	if day >= Config.UFO_DAY then
		Structures.crashUfo()
	end
	-- паук появляется в Мёртвой чаще с 16-го дня
	if day >= 16 and not State.run.bossesDone.spider and S.Mobs.aliveWith("kind", "spider") == 0 then
		local th
		for _, z in ipairs(World.ZONES) do
			if z.id == "thicket" then
				th = Vector3.new(z.x, 0, z.z)
			end
		end
		spawnBoss("spider", th)
	end
end

function Structures.init(services)
	S = services
	State = S.State
	part = S.WorldBuilder.part
	prompt = S.WorldBuilder.prompt
end

function Structures.start()
	Remotes.PanelAction.OnServerEvent:Connect(function(player, panelId, actionId)
		local ps = S.PlayerService.get(player)
		if not ps or type(panelId) ~= "string" or type(actionId) ~= "string" then
			return
		end
		if panelId == "fire" then
			if S.Camp.inCamp(player.Character and player.Character:GetPivot().Position or Vector3.new(1e5, 0, 0)) then
				S.Camp.action(ps, actionId)
			end
		elseif panelId == "tame" then
			handlers.tame(ps, actionId)
		elseif handlers[panelId] and ps.panel == panelId then
			handlers[panelId](ps, actionId)
		end
		S.PlayerService.sync(ps)
	end)
end

return Structures
