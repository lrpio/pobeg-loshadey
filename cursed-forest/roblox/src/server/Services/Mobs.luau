-- Мобы: построение моделей, ИИ, урон и статусы (огонь, яд, обморожение), трофеи, союзники, популяции, налёты, боссы.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MobDefs = require(Shared.Mobs)
local World = require(Shared.World)
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)

local Mobs = {}
local S, State
local list = {} -- активные мобы
local folder
local nextId = 0

local COLORS = {
	occ = Color3.fromRGB(62, 42, 82), occArcher = Color3.fromRGB(62, 42, 82), occBrute = Color3.fromRGB(90, 30, 40),
	occLava = Color3.fromRGB(120, 40, 20), occLavaArcher = Color3.fromRGB(140, 50, 20),
	occWinterSword = Color3.fromRGB(120, 150, 180), occWinterArcher = Color3.fromRGB(140, 170, 200), occWinterBomb = Color3.fromRGB(100, 130, 160),
	occCave = Color3.fromRGB(42, 42, 48), occCaveElite = Color3.fromRGB(30, 30, 36),
	occJungle = Color3.fromRGB(40, 90, 40), occJungleArcher = Color3.fromRGB(150, 110, 80), occJungleElite = Color3.fromRGB(30, 70, 30),
	vampire = Color3.fromRGB(120, 20, 34), alien = Color3.fromRGB(80, 200, 110), alienElite = Color3.fromRGB(120, 160, 190),
	rabbit = Color3.fromRGB(205, 185, 155), wolf = Color3.fromRGB(133, 138, 144), alpha = Color3.fromRGB(58, 61, 69),
	bear = Color3.fromRGB(107, 74, 47), boar = Color3.fromRGB(106, 74, 58),
}

local HUMANOID = { occ = true, vampire = true, alien = true }
local function isHumanoidShape(kind: string, def)
	return def.occult or def.vampire or def.alien or HUMANOID[kind]
end

-- Модель из деталей: корень + тело + голова; у гуманоидов капюшон, у зверей вытянутое тело
local function buildModel(kind: string, def, scale: number)
	local m = Instance.new("Model")
	m.Name = def.name
	local color = def.color or COLORS[kind] or Color3.fromRGB(120, 120, 120)
	local humanoidShape = isHumanoidShape(kind, def)
	local size = (def.size or 2) * scale
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Transparency = 1
	root.CanCollide = true
	if humanoidShape then
		root.Size = Vector3.new(2, 2, 1) * scale
	else
		root.Size = Vector3.new(size * 0.8, size * 0.6, size * 1.2)
	end
	root.Parent = m
	local body = Instance.new("Part")
	body.Name = "Body"
	body.CanCollide = false
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	local head = Instance.new("Part")
	head.Name = "Head"
	head.CanCollide = false
	head.Color = humanoidShape and Color3.fromRGB(20, 14, 26) or color
	if humanoidShape then
		body.Size = Vector3.new(2.2, 3.2, 1.4) * scale
		body.CFrame = root.CFrame
		head.Size = Vector3.new(1.4, 1.4, 1.4) * scale
		head.CFrame = root.CFrame * CFrame.new(0, 2.2 * scale, 0)
		-- капюшон
		local hood = Instance.new("WedgePart")
		hood.Name = "Hood"
		hood.CanCollide = false
		hood.Size = Vector3.new(1.8, 1.2, 1.8) * scale
		hood.Color = color:Lerp(Color3.new(0, 0, 0), 0.25)
		hood.CFrame = head.CFrame * CFrame.new(0, 0.9 * scale, 0)
		hood.Parent = m
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, hood
		weld.Parent = hood
		-- светящиеся глаза
		for sx = -1, 1, 2 do
			local eye = Instance.new("Part")
			eye.Name = "Eye"
			eye.Shape = Enum.PartType.Ball
			eye.Size = Vector3.one * 0.25 * scale
			eye.Material = Enum.Material.Neon
			eye.Color = def.vampire and Color3.fromRGB(255, 50, 50) or def.alien and Color3.fromRGB(10, 10, 10) or Color3.fromRGB(255, 211, 74)
			eye.CanCollide = false
			eye.CFrame = head.CFrame * CFrame.new(0.3 * sx * scale, 0.1, -0.71 * scale)
			eye.Parent = m
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = root, eye
			w.Parent = eye
		end
	else
		body.Size = Vector3.new(size * 0.8, size * 0.6, size * 1.3)
		body.CFrame = root.CFrame
		head.Size = Vector3.one * size * 0.5
		head.CFrame = root.CFrame * CFrame.new(0, size * 0.2, -size * 0.75)
	end
	body.Parent = m
	head.Parent = m
	for _, p in ipairs({ body, head }) do
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = root, p
		w.Parent = p
	end
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = humanoidShape and 1.6 * scale or size * 0.3
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.BreakJointsOnDeath = false
	hum.Parent = m
	m.PrimaryPart = root
	-- табличка с именем и полоской здоровья
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(120, 30)
	gui.StudsOffset = Vector3.new(0, (humanoidShape and 4 or size) * scale, 0)
	gui.MaxDistance = 80
	gui.Adornee = root
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.6, 0)
	name.Text = def.name
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.4
	name.Parent = gui
	local barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.Position = UDim2.new(0.1, 0, 0.68, 0)
	barBg.Size = UDim2.new(0.8, 0, 0.18, 0)
	barBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	barBg.BorderSizePixel = 0
	barBg.Parent = gui
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(214, 68, 76)
	bar.BorderSizePixel = 0
	bar.Parent = barBg
	gui.Parent = root
	return m, root, hum
end

function Mobs.spawn(kind: string, pos: Vector3, extra)
	local def = MobDefs[kind] or (MobDefs.BOSSES[kind] and MobDefs.BOSSES[kind])
	if not def then
		warn("Нет моба " .. kind)
		return nil
	end
	extra = extra or {}
	if #list >= Config.MAX_MOBS and not extra.important then
		return nil
	end
	local isBoss = MobDefs.BOSSES[kind] ~= nil
	local scale = isBoss and 2.6 or (def.elite and 1.25 or 1)
	local dayScale = 1 + State.run.day / 120
	local m, root, hum = buildModel(kind, def, scale)
	m:PivotTo(CFrame.new(pos.X, (isHumanoidShape(kind, def) and 3 or 2) * scale, pos.Z))
	m.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	nextId += 1
	local hp = (def.hp or 100) * (isBoss and 1 or dayScale)
	local mob = {
		id = nextId, kind = kind, def = def, model = m, root = root, hum = hum,
		hp = hp, max = hp, dmg = (def.dmg or 5) * (isBoss and 1 or (1 + State.run.day / 150)),
		speed = def.speed or 14, cd = 0, state = "wander", wanderAt = 0, home = extra.home or pos,
		leash = extra.leash or 120, statuses = {}, boss = isBoss, alive = true,
	}
	for k, v in pairs(extra) do
		mob[k] = v
	end
	hum.WalkSpeed = mob.speed
	m:SetAttribute("MobId", mob.id)
	table.insert(list, mob)
	return mob
end

function Mobs.nearestKind(kind: string, pos: Vector3): Vector3?
	local best, bd = nil, math.huge
	for _, m in ipairs(list) do
		if m.alive and not m.ally and m.kind == kind then
			local d = (m.root.Position - pos).Magnitude
			if d < bd then
				best, bd = m.root.Position, d
			end
		end
	end
	return best and (best + Vector3.new(0, 3, 0)) or nil
end

function Mobs.all()
	return list
end

local function updateBar(mob)
	local bar = mob.root:FindFirstChild("Tag") and mob.root.Tag.BarBg.Bar
	if bar then
		bar.Size = UDim2.fromScale(math.clamp(mob.hp / mob.max, 0, 1), 1)
		bar.BackgroundColor3 = mob.ally and Color3.fromRGB(143, 227, 155) or (mob.hp / mob.max < 0.3 and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(214, 68, 76))
	end
end

local function rollDrops(mob, pos)
	local function drop(tbl)
		for _, d in ipairs(tbl or {}) do
			local id, chance, mn, mx = d[1], d[2], d[3], d[4]
			if State.rng() < chance then
				if id == "meat" and mob.killer and mob.killer.class == "bandit" then
					id = "cmeat"
				end
				local n = State.rint(mn, mx)
				if id == "paw" and mob.killer and mob.killer.class == "bunbit" then
					n *= 2
				end
				if (id == "wpelt" or id == "apelt" or id == "bpelt") and mob.killer and mob.killer.class == "hunter" then
					n *= 2
				end
				S.Drops.spawn(pos, id, n)
			end
		end
	end
	drop(mob.def.drops)
	if mob.def.occult then
		drop(MobDefs.OCCULT_DROPS)
	end
	if mob.def.vampire or mob.def.alien then
		S.Drops.spawn(pos, "carcass", 1)
	end
	if mob.boss then
		S.Drops.spawn(pos, "bcarcass", 1)
	end
end

function Mobs.kill(mob, ps)
	if not mob.alive then
		return
	end
	mob.alive = false
	mob.killer = ps
	local pos = mob.root.Position
	if not mob.ally and not mob.noLoot then
		rollDrops(mob, pos)
	end
	-- некромант может поднять оккультиста (даже короля)
	if (mob.def.occult or mob.kind == "occKing") and not mob.ally then
		for _, other in pairs(State.players) do
			if other.class == "necro" then
				S.Structures.makeCorpse(pos, mob.kind)
				break
			end
		end
	end
	if ps and mob.def.vampire then
		ps.tasks.vampKills += 1
		S.Structures.onVampireKilled(ps)
	end
	if mob.onDeath then
		task.spawn(mob.onDeath, mob, ps)
	end
	if mob.boss then
		S.Structures.onBossKilled(mob, ps)
	end
	mob.hum.Health = 0
	for _, p in ipairs(mob.model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Color = p.Color:Lerp(Color3.new(0, 0, 0), 0.5)
		end
	end
	game:GetService("Debris"):AddItem(mob.model, 2)
end

-- Урон по мобу. opts: {player, fire, frost, poison, dot, melee, bomb}
function Mobs.damage(mob, dmg: number, opts)
	if not mob or not mob.alive then
		return
	end
	opts = opts or {}
	local ps = opts.player
	if mob.shield and mob.shield() then
		S.State.popup(mob.root.Position + Vector3.new(0, 5, 0), "ЩИТ", Color3.fromRGB(166, 220, 239))
		return
	end
	if ps and not opts.dot then
		if ps.class == "assassin" and mob.state ~= "chase" and not mob.boss then
			dmg *= 3
			S.State.popup(mob.root.Position + Vector3.new(0, 6, 0), "КРИТ!", Color3.fromRGB(255, 211, 107))
		end
		if (ps.class == "cyborg" or ps.class == "alien" or ps.class == "scientist") and mob.def.alien then
			dmg *= 1.5
		end
		if ps.class == "vampire" then
			S.PlayerService.heal(ps, dmg * 0.12)
		end
		if ps.class == "ice" then
			opts.frost = true
		end
		if ps.class == "poison" then
			opts.poison = true
		end
		if ps.class == "brawler" and opts.melee then
			ps.combo += 1
			if ps.combo % 3 == 0 and not mob.boss then
				mob.statuses.stun = os.clock() + 1.2
			end
		end
	end
	mob.hp -= dmg
	if opts.fire then
		mob.statuses.burn = os.clock() + 3
	end
	if opts.poison then
		mob.statuses.poison = os.clock() + 4
	end
	if opts.frost then
		mob.statuses.frost = os.clock() + 3 -- обморожение на 3 секунды
		mob.hum.WalkSpeed = mob.speed * 0.45
	end
	if not opts.dot then
		mob.state = "chase"
		mob.target = ps
		S.State.popup(mob.root.Position + Vector3.new(0, 4, 0), tostring(math.floor(dmg)), Color3.new(1, 1, 1))
	end
	updateBar(mob)
	if mob.hp <= 0 then
		Mobs.kill(mob, ps)
	end
end

function Mobs.inRadius(pos: Vector3, r: number, includeAllies: boolean?)
	local out = {}
	for _, m in ipairs(list) do
		if m.alive and (includeAllies or not m.ally) and (m.root.Position - pos).Magnitude < r + (m.boss and 4 or 1.5) then
			table.insert(out, m)
		end
	end
	return out
end

function Mobs.fromPart(part: Instance)
	local model = part:FindFirstAncestorOfClass("Model")
	while model and not model:GetAttribute("MobId") do
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	if not model then
		return nil
	end
	local id = model:GetAttribute("MobId")
	for _, m in ipairs(list) do
		if m.id == id then
			return m
		end
	end
	return nil
end

-- Сделать моба союзником (питомец флейтиста или слуга некроманта)
function Mobs.makeAlly(mob, owner, weaker: boolean?)
	mob.ally = true
	mob.owner = owner
	mob.state = "follow"
	if weaker then
		mob.max *= 0.6
		mob.hp = math.min(mob.hp, mob.max)
		mob.dmg *= 0.7
	end
	local tag = mob.root:FindFirstChild("Tag")
	if tag then
		tag.TextLabel.Text = mob.def.name .. " (союзник)"
	end
	updateBar(mob)
end

-- Снаряд моба: мгновенная проверка с небольшим разбросом
local function mobShoot(mob, target)
	local from = mob.root.Position + Vector3.new(0, 1.5, 0)
	local to = target.root.Position
	local miss = (to - from).Magnitude / 120
	if State.rng() < 0.25 + miss then
		S.Combat.tracer(from, to + Vector3.new(State.rng() * 4 - 2, 0, State.rng() * 4 - 2), Color3.fromRGB(255, 120, 80))
		return
	end
	local color = mob.def.ranged == "laser" and Color3.fromRGB(255, 74, 106) or mob.def.ranged == "dart" and Color3.fromRGB(155, 227, 123) or Color3.fromRGB(200, 170, 120)
	S.Combat.tracer(from, to, color)
	if mob.def.ranged == "bomb" then
		S.Combat.explode(to, 8, mob.dmg, nil, true)
		return
	end
	S.PlayerService.damage(target.ps, mob.dmg, mob)
	if mob.def.ranged == "firebolt" then
		target.ps.burnUntil = os.clock() + 3
	end
	if mob.def.poison then
		target.ps.poisonUntil = os.clock() + 3
	end
end

local function nearestHostile(pos: Vector3, r: number)
	local best, bd = nil, r
	for _, m in ipairs(list) do
		if m.alive and not m.ally and not m.def.passive then
			local d = (m.root.Position - pos).Magnitude
			if d < bd then
				best, bd = m, d
			end
		end
	end
	return best, bd
end

local function think(mob, now: number)
	local pos = mob.root.Position
	local def = mob.def
	-- статусы
	if mob.statuses.burn and now < mob.statuses.burn then
		Mobs.damage(mob, 6 * 0.2, { dot = true })
	end
	if mob.statuses.poison and now < mob.statuses.poison then
		Mobs.damage(mob, 4 * 0.2, { dot = true })
	end
	if mob.statuses.frost and now >= mob.statuses.frost then
		mob.statuses.frost = nil
		mob.hum.WalkSpeed = mob.speed
	end
	if not mob.alive then
		return
	end
	if mob.statuses.stun and now < mob.statuses.stun then
		mob.hum:MoveTo(pos)
		return
	end
	-- союзники
	if mob.ally then
		local owner = mob.owner and mob.owner.player.Character and mob.owner.player.Character:FindFirstChild("HumanoidRootPart")
		local enemy, ed = nearestHostile(pos, 60)
		if enemy then
			mob.hum:MoveTo(enemy.root.Position)
			if ed < 6 + (enemy.boss and 4 or 0) and now > mob.cd then
				mob.cd = now + 0.8
				Mobs.damage(enemy, mob.dmg, { player = mob.owner, dot = false })
			end
		elseif owner then
			if (owner.Position - pos).Magnitude > 120 then
				mob.model:PivotTo(owner.CFrame * CFrame.new(3, 0, 3))
			elseif (owner.Position - pos).Magnitude > 10 then
				mob.hum:MoveTo(owner.Position)
			end
		end
		return
	end
	local targetInfo, td = State.nearestPlayer(pos, (mob.raid or mob.wave) and 600 or (def.aggro or 40) * (mob.state == "chase" and 2.2 or 1))
	-- ассасин в кустах невидим; вампиры не трогают класс «Вампир»
	if targetInfo and ((targetInfo.ps.class == "assassin" and targetInfo.ps.inBush) or (def.vampire and targetInfo.ps.class == "vampire" and mob.state ~= "chase")) then
		targetInfo = nil
	end
	if def.passive then
		if targetInfo and td < 22 then
			local away = (pos - targetInfo.root.Position)
			mob.hum:MoveTo(pos + away.Unit * 20)
		elseif now > mob.wanderAt then
			mob.wanderAt = now + State.rng() * 3 + 2
			mob.hum:MoveTo(pos + Vector3.new(State.rng() * 30 - 15, 0, State.rng() * 30 - 15))
		end
		return
	end
	-- вампиры боятся света костра и фонарика
	if def.vampire then
		if S.Camp.inLight(pos) then
			mob.hum:MoveTo(pos + Vector3.new(pos.X, 0, pos.Z).Unit * 20)
			return
		end
		if targetInfo and S.Guardians.isLit(targetInfo.ps, pos, 0.5) then
			Mobs.damage(mob, 2, { dot = true })
			mob.hum:MoveTo(pos + (pos - targetInfo.root.Position).Unit * 15)
			return
		end
	end
	-- поводок к дому
	if not mob.raid and not mob.wave and not mob.boss and (pos - mob.home).Magnitude > mob.leash then
		mob.state = "return"
	end
	if mob.state == "return" then
		mob.hum:MoveTo(mob.home)
		if (pos - mob.home).Magnitude < mob.leash * 0.5 then
			mob.state = "wander"
		end
		return
	end
	-- стены лагеря не пускают зверей и оккультистов
	if State.run.camp.walls and not mob.boss and Vector3.new(pos.X, 0, pos.Z).Magnitude < Config.CAMP_RADIUS - 5 then
		mob.hum:MoveTo(Vector3.new(pos.X, 0, pos.Z).Unit * (Config.CAMP_RADIUS + 10))
		return
	end
	if targetInfo then
		mob.state = "chase"
		local tpos = targetInfo.root.Position
		if mob.bossTick then
			mob.bossTick(mob, targetInfo, td, now)
		end
		if def.ranged then
			if td > 45 then
				mob.hum:MoveTo(tpos)
			elseif td < 25 then
				mob.hum:MoveTo(pos + (pos - tpos).Unit * 10)
			else
				mob.hum:MoveTo(pos)
			end
			if now > mob.cd then
				mob.cd = now + (def.rate or 2)
				mobShoot(mob, targetInfo)
			end
		else
			mob.hum:MoveTo(tpos)
			local reach = mob.boss and 9 or 5
			if td < reach and now > mob.cd then
				mob.cd = now + (mob.boss and 1.4 or 1)
				S.PlayerService.damage(targetInfo.ps, mob.dmg, mob)
			end
		end
	else
		if mob.state == "chase" then
			mob.state = "wander"
		end
		if now > mob.wanderAt then
			mob.wanderAt = now + State.rng() * 4 + 2
			local h = mob.home
			mob.hum:MoveTo(h + Vector3.new(State.rng() * 60 - 30, 0, State.rng() * 60 - 30))
		end
	end
end

-- Популяции по зонам: {группа, лимит, зоны, виды}
local POP = {
	{ "rabbit", 28, { "forest", "meadow", "thicket" }, { "rabbit" } },
	{ "wolf", 8, { "forest", "thicket" }, { "wolf" } },
	{ "alpha", 2, { "thicket" }, { "alpha" } },
	{ "bear", 4, { "forest", "winter" }, { "bear" } },
	{ "boar", 6, { "jungle" }, { "boar" } },
	{ "lakeFrog", 5, { "lake" }, { "frog", "frog", "frogBlue" } },
	{ "occLava", 7, { "lava" }, { "occLava", "occLava", "occLavaArcher", "occBrute" } },
	{ "occWinter", 7, { "winter" }, { "occWinterSword", "occWinterArcher", "occWinterBomb" } },
	{ "occCave", 6, { "cave" }, { "occCave", "occCave", "occCave", "occCaveElite" } },
	{ "occJungle", 7, { "jungle" }, { "occJungle", "occJungle", "occJungleArcher", "occJungleElite" } },
	{ "occForest", 4, { "forest" }, { "occ", "occ", "occArcher" }, minDay = 4 },
	{ "crypt", 5, { "crimson" }, { "vampire" } },
}

local function popCount(grp: string)
	local c = 0
	for _, m in ipairs(list) do
		if m.alive and m.grp == grp then
			c += 1
		end
	end
	return c
end
Mobs.popCount = popCount

local function farFromPlayers(x: number, z: number, minD: number): boolean
	for _, p in ipairs(State.alivePlayers()) do
		if (Vector3.new(x, 0, z) - State.flat(p.root.Position)).Magnitude < minD then
			return false
		end
	end
	return true
end

local function populate()
	for _, row in ipairs(POP) do
		local grp, cap, zones, kinds = row[1], row[2], row[3], row[4]
		if (row.minDay or 0) <= State.run.day and popCount(grp) < cap then
			local zone = zones[State.rint(1, #zones)]
			local x, z = S.WorldBuilder.randomIn(zone)
			if x and farFromPlayers(x, z, 80) then
				Mobs.spawn(kinds[State.rint(1, #kinds)], Vector3.new(x, 0, z), { grp = grp, home = Vector3.new(x, 0, z), leash = 140 })
			end
		end
	end
	-- ночной налёт: вампиры или оккультисты идут к игрокам
	if Rules.isNight(State.run.clock, Config.DAY_LENGTH) then
		local cap = math.min(3 + math.floor(State.run.day / 5), State.run.finale and 24 or 14)
		if popCount("raid") < cap then
			local players = State.alivePlayers()
			if #players > 0 then
				local p = players[State.rint(1, #players)]
				local a = State.rng() * math.pi * 2
				local pos = p.root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * 120
				if Vector3.new(pos.X, 0, pos.Z).Magnitude > Config.CAMP_RADIUS + 20 then
					local kind = State.run.raid == "occult" and ({ "occ", "occ", "occArcher", "occBrute" })[State.rint(1, 4)] or "vampire"
					Mobs.spawn(kind, pos, { grp = "raid", raid = true })
				end
			end
		end
	end
end

-- Утро: вампиры и ночные налётчики сгорают
function Mobs.dawn()
	for _, m in ipairs(list) do
		if m.alive and (m.grp == "raid" or (m.def.vampire and m.grp ~= "crypt" and m.grp ~= "carnival")) then
			m.noLoot = true
			Mobs.kill(m, nil)
		end
	end
end

function Mobs.aliveWith(field: string, value)
	local n = 0
	for _, m in ipairs(list) do
		if m.alive and m[field] == value then
			n += 1
		end
	end
	return n
end

function Mobs.init(services)
	S = services
	State = S.State
	folder = Instance.new("Folder")
	folder.Name = "Mobs"
	folder.Parent = workspace
end

function Mobs.start()
	local acc, popAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		popAcc += dt
		if acc >= 0.2 then
			acc = 0
			local now = os.clock()
			for i = #list, 1, -1 do
				local m = list[i]
				if not m.alive or not m.model.Parent then
					table.remove(list, i)
				else
					local ok, err = pcall(think, m, now)
					if not ok then
						warn("[Mobs] " .. tostring(err))
					end
				end
			end
		end
		if popAcc >= 2 then
			popAcc = 0
			populate()
		end
	end)
end

return Mobs
