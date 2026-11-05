-- Строит карту при старте сервера: рельеф по зонам, озеро, деревья, камни, кусты, сундуки, точку появления.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local Rules = require(Shared.Rules)
local Config = require(Shared.Config)

local WorldBuilder = {}
local S, State
local resources = {} -- деревья и камни
local bushes = {}
local chests = {}
local rnd = Random.new(20261103)
local root

local MAT = {
	Ground = Enum.Material.Ground,
	Grass = Enum.Material.Grass,
	Basalt = Enum.Material.Basalt,
	Snow = Enum.Material.Snow,
	Slate = Enum.Material.Slate,
	LeafyGrass = Enum.Material.LeafyGrass,
	Mud = Enum.Material.Mud,
	Sand = Enum.Material.Sand,
}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end
WorldBuilder.part = part

local function prompt(parent: Instance, action: string, object: string, onTrigger, dist: number?)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = action
	pr.ObjectText = object
	pr.MaxActivationDistance = dist or 10
	pr.RequiresLineOfSight = false
	pr.Parent = parent
	pr.Triggered:Connect(function(player)
		local ps = S.PlayerService.get(player)
		if ps and ps.class then
			onTrigger(ps, pr)
		end
	end)
	return pr
end
WorldBuilder.prompt = prompt

local function randomIn(zoneId: string)
	for _ = 1, 40 do
		local x = rnd:NextNumber(-World.SIZE / 2 + 20, World.SIZE / 2 - 20)
		local z = rnd:NextNumber(-World.SIZE / 2 + 20, World.SIZE / 2 - 20)
		if World.zoneAt(x, z) == zoneId and Vector3.new(x, 0, z).Magnitude > Config.CAMP_RADIUS + 30 then
			return x, z
		end
	end
	return nil
end
WorldBuilder.randomIn = function(zoneId)
	return randomIn(zoneId)
end

local function buildTerrain()
	local t = workspace.Terrain
	t:Clear()
	t:FillBlock(CFrame.new(0, -6, 0), Vector3.new(World.SIZE, 12, World.SIZE), Enum.Material.Grass)
	for _, z in ipairs(World.ZONES) do
		if z.id ~= "forest" and z.id ~= "lake" then
			t:FillCylinder(CFrame.new(z.x, -4, z.z), 8, z.r, MAT[z.material] or Enum.Material.Grass) -- верх зоны вровень с землёй (y = 0)
		end
	end
	local lake
	for _, z in ipairs(World.ZONES) do
		if z.id == "lake" then
			lake = z
		end
	end
	t:FillCylinder(CFrame.new(lake.x, -4, lake.z), 8, lake.r + 10, Enum.Material.Sand)
	t:FillCylinder(CFrame.new(lake.x, -3.5, lake.z), 7, lake.r - 15, Enum.Material.Water) -- вода от y = −7 до 0
	t.WaterColor = Color3.fromRGB(28, 85, 116)
	-- граница карты: высокие скалы
	local half = World.SIZE / 2
	for _, cf in ipairs({ CFrame.new(0, 20, -half), CFrame.new(0, 20, half), CFrame.new(-half, 20, 0), CFrame.new(half, 20, 0) }) do
		local horizontal = math.abs(cf.Position.Z) > 1
		t:FillBlock(cf, horizontal and Vector3.new(World.SIZE, 60, 30) or Vector3.new(30, 60, World.SIZE), Enum.Material.Rock)
	end
end

local TREE_COLORS = {
	forest = { Color3.fromRGB(36, 72, 40), Color3.fromRGB(47, 90, 52) },
	jungle = { Color3.fromRGB(26, 96, 40), Color3.fromRGB(40, 120, 45) },
	winter = { Color3.fromRGB(40, 70, 60), Color3.fromRGB(230, 238, 242) },
	crimson = { Color3.fromRGB(110, 30, 35), Color3.fromRGB(150, 40, 45) },
	lava = { Color3.fromRGB(60, 50, 45), Color3.fromRGB(80, 60, 50) },
	thicket = { Color3.fromRGB(70, 66, 56), Color3.fromRGB(85, 80, 70) },
	meadow = { Color3.fromRGB(120, 140, 50), Color3.fromRGB(150, 160, 60) },
}

local function makeTree(x: number, z: number, zone: string, giant: boolean?)
	local scale = (giant and 2.6 or 1) * rnd:NextNumber(0.85, 1.3)
	local m = Instance.new("Model")
	m.Name = giant and "GiantTree" or "Tree"
	local trunk = part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(10 * scale, 1.6 * scale, 1.6 * scale),
		CFrame = CFrame.new(x, 5 * scale, z) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(80, 55, 35),
	})
	trunk.Parent = m
	local cols = TREE_COLORS[zone] or TREE_COLORS.forest
	local dead = zone == "thicket" or zone == "lava"
	if not dead then
		for i = 1, 2 do
			local leaf = part({
				Name = "Leaves",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * (7 - i * 1.5) * scale,
				Position = Vector3.new(x, (9 + i * 2.5) * scale, z),
				Material = zone == "winter" and i == 2 and Enum.Material.Snow or Enum.Material.Grass,
				Color = cols[i],
				CanCollide = false,
			})
			leaf.Parent = m
		end
	end
	m.PrimaryPart = trunk
	m.Parent = root.Trees
	table.insert(resources, { model = m, kind = "tree", pos = Vector3.new(x, 0, z), hp = giant and 80 or 3, max = giant and 80 or 3, giant = giant, zone = zone })
end

local function makeRock(x: number, z: number, zone: string)
	local ore = (zone == "winter" or zone == "cave" or zone == "lava") and rnd:NextNumber() < 0.4
	local coal = not ore and (zone == "winter" or zone == "lava") and rnd:NextNumber() < 0.45
	local p = part({
		Name = "Rock",
		Size = Vector3.new(rnd:NextNumber(3, 5), rnd:NextNumber(2, 3.5), rnd:NextNumber(3, 5)),
		Position = Vector3.new(x, 1.2, z),
		Orientation = Vector3.new(0, rnd:NextNumber(0, 360), 0),
		Material = Enum.Material.Slate,
		Color = ore and Color3.fromRGB(170, 110, 70) or coal and Color3.fromRGB(45, 45, 50) or Color3.fromRGB(115, 118, 122),
	})
	p.Parent = root.Rocks
	table.insert(resources, { model = p, kind = "rock", pos = Vector3.new(x, 0, z), hp = 4, max = 4, ore = ore, coal = coal, zone = zone })
end

local function makeBush(x: number, z: number)
	local p = part({
		Name = "Bush",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 4, 5),
		Position = Vector3.new(x, 1.5, z),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(45, 95, 42),
		CanCollide = false,
	})
	p.Parent = root.Bushes
	local b = { part = p, pos = Vector3.new(x, 0, z), berries = rnd:NextNumber() < 0.6 }
	local pr = prompt(p, "Собрать ягоды", "Куст", function(ps)
		if not b.berries then
			S.State.notify(ps.player, "Ягод нет, вырастут к утру")
			return
		end
		b.berries = false
		S.PlayerService.give(ps, "berry", 2)
		if S.State.rng() < 0.5 then
			S.PlayerService.give(ps, "rope", 1)
		end
	end, 8)
	b.prompt = pr
	table.insert(bushes, b)
end

local TIER_COLOR = {
	common = Color3.fromRGB(122, 82, 40),
	gold = Color3.fromRGB(212, 166, 58),
	ruby = Color3.fromRGB(180, 35, 45),
	infected = Color3.fromRGB(90, 42, 122),
}

function WorldBuilder.makeChest(x: number, z: number, zone: string, tier: string)
	local p = part({
		Name = "Chest",
		Size = Vector3.new(3, 2, 2),
		Position = Vector3.new(x, 1, z),
		Material = Enum.Material.WoodPlanks,
		Color = TIER_COLOR[tier] or TIER_COLOR.common,
	})
	local band = part({ Size = Vector3.new(3.05, 0.3, 2.05), Position = Vector3.new(x, 1.4, z), Material = Enum.Material.Metal, Color = Color3.fromRGB(230, 200, 110), CanCollide = false })
	band.Parent = p
	p.Parent = root.Chests
	local c = { part = p, zone = zone, tier = tier, open = false }
	local label = tier == "ruby" and "Рубиновый сундук" or tier == "gold" and "Золотой сундук" or tier == "infected" and "Заражённый сундук" or "Сундук"
	prompt(p, "Открыть", label, function(ps, pr)
		if c.open then
			return
		end
		c.open = true
		pr.Enabled = false
		p.Transparency = 0.6
		S.Structures.openChest(ps, c)
	end, 8)
	c.reset = function()
		c.open = false
		p.Transparency = 0
		local pr = p:FindFirstChildOfClass("ProximityPrompt")
		if pr then
			pr.Enabled = true
		end
	end
	table.insert(chests, c)
	return c
end

function WorldBuilder.build()
	S.State = S.State
	root = Instance.new("Folder")
	root.Name = "World"
	for _, n in ipairs({ "Trees", "Rocks", "Bushes", "Chests", "Structures" }) do
		local f = Instance.new("Folder")
		f.Name = n
		f.Parent = root
	end
	root.Parent = workspace
	WorldBuilder.root = root
	buildTerrain()

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 0.5, 16)
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = root

	local half = World.SIZE / 2 - 30
	for _ = 1, 900 do
		local x, z = rnd:NextNumber(-half, half), rnd:NextNumber(-half, half)
		local zone = World.zoneAt(x, z)
		local far = Vector3.new(x, 0, z).Magnitude > Config.CAMP_RADIUS + 25
		if far and zone ~= "lake" and zone ~= "cave" and (zone ~= "meadow" or rnd:NextNumber() < 0.08) then
			makeTree(x, z, zone)
		end
	end
	for _ = 1, 260 do
		local x, z = rnd:NextNumber(-half, half), rnd:NextNumber(-half, half)
		local zone = World.zoneAt(x, z)
		local rocky = zone == "winter" or zone == "cave" or zone == "lava"
		if Vector3.new(x, 0, z).Magnitude > Config.CAMP_RADIUS and zone ~= "lake" and (rocky or rnd:NextNumber() < 0.3) then
			makeRock(x, z, zone)
		end
	end
	for _ = 1, 260 do
		local x, z = rnd:NextNumber(-half, half), rnd:NextNumber(-half, half)
		local zone = World.zoneAt(x, z)
		if Vector3.new(x, 0, z).Magnitude > Config.CAMP_RADIUS and zone ~= "lake" and zone ~= "winter" and zone ~= "cave" then
			makeBush(x, z)
		end
	end
	for _ = 1, 60 do -- кусты на Золотой поляне, чтобы прятаться от Льва
		local a, r = rnd:NextNumber(0, math.pi * 2), math.sqrt(rnd:NextNumber()) * 230
		makeBush(math.cos(a) * r, 750 + math.sin(a) * r)
	end
	local CH = { forest = 18, lava = 6, winter = 6, cave = 5, jungle = 6, crimson = 6, thicket = 3, meadow = 3 }
	for zone, n in pairs(CH) do
		for _ = 1, n do
			local x, z = randomIn(zone)
			if x then
				local lootZone = (zone == "thicket" or zone == "meadow") and "forest" or zone
				WorldBuilder.makeChest(x, z, lootZone, Rules.chestTier(State.rng, false))
			end
		end
	end
	if State.run.hard then
		for _ = 1, 4 do
			local x, z = randomIn("forest")
			if x then
				makeTree(x, z, "forest", true)
			end
		end
		for _ = 1, 8 do
			local x, z = randomIn("forest")
			if x then
				WorldBuilder.makeChest(x, z, "forest", "infected")
			end
		end
	end
end

function WorldBuilder.inBush(pos: Vector3): boolean
	for _, b in ipairs(bushes) do
		local d = Vector3.new(pos.X - b.pos.X, 0, pos.Z - b.pos.Z).Magnitude
		if d < 3 then
			return true
		end
	end
	return false
end

-- Рубка и добыча камня: ищем ресурс перед игроком
function WorldBuilder.chop(ps, origin: Vector3, look: Vector3, range: number, chopPower: number): boolean
	local best, bd = nil, math.huge
	for _, r in ipairs(resources) do
		if r.hp > 0 then
			local to = Vector3.new(r.pos.X - origin.X, 0, r.pos.Z - origin.Z)
			local d = to.Magnitude - (r.giant and 3 or 1.5)
			if d < range and d < bd and (d < 2 or to.Unit:Dot(Vector3.new(look.X, 0, look.Z).Unit) > 0.4) then
				best, bd = r, d
			end
		end
	end
	if not best then
		return false
	end
	local PS = S.PlayerService
	if best.kind == "tree" then
		local mult = ps.class == "lumber" and 2 or 1
		best.hp -= chopPower * mult
		if best.hp <= 0 then
			best.model.Parent = nil
			best.cutDay = State.run.day
			ps.trees += 1
			if best.giant then
				PS.give(ps, "wood", 25)
				S.State.notify(ps.player, "Гигантское дерево повалено!", "good")
			else
				PS.give(ps, "wood", (ps.class == "lumber" and 2 or 1) * State.rint(2, 3))
				if State.rng() < 0.12 then
					PS.give(ps, "rope", 1)
				end
			end
		end
	else
		best.hp -= math.max(0.5, chopPower * 0.5)
		if best.hp <= 0 then
			best.model.Parent = nil
			best.cutDay = State.run.day
			PS.give(ps, "stone", State.rint(2, 3))
			if best.ore then
				PS.give(ps, "ore", State.rint(2, 3))
			end
			if best.coal then
				PS.give(ps, "coal", State.rint(2, 3))
			end
		end
	end
	return true
end

-- Утро: отрастают деревья и ягоды, часть сундуков снова закрыта
function WorldBuilder.dawn(day: number)
	for _, r in ipairs(resources) do
		if r.hp <= 0 and r.cutDay and day - r.cutDay >= (r.kind == "tree" and 3 or 4) then
			r.hp = r.max
			r.model.Parent = r.kind == "tree" and root.Trees or root.Rocks
		end
	end
	for _, b in ipairs(bushes) do
		if not b.berries and State.rng() < 0.6 then
			b.berries = true
		end
	end
	for _, c in ipairs(chests) do
		if c.open and c.tier ~= "infected" and State.rng() < 0.12 then
			c.tier = Rules.chestTier(State.rng, false)
			c.part.Color = TIER_COLOR[c.tier]
			c.reset()
		end
	end
end

function WorldBuilder.init(services)
	S = services
	State = S.State
end

return WorldBuilder
