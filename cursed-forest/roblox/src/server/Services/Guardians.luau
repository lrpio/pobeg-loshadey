-- Хранители, которых нельзя убить: Олень (каждую ночь) и хозяин биома (Барс / Лев / Пантера).
-- Модели закреплены (Anchored) и двигаются через PivotTo на сервере.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)

local Guardians = {}
local S, State
local folder
local G = {} -- kind -> запись

local function block(parent, size, cf, color, material, name)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Name = name or "Part"
	p.Parent = parent
	return p
end

local function buildModel(kind: string)
	local m = Instance.new("Model")
	m.Name = World.GUARDIANS[kind].name
	local base = CFrame.new(0, 0, 0)
	local body, eyeColor
	if kind == "deer" then
		body = block(m, Vector3.new(3, 3, 6), base * CFrame.new(0, 5, 0), Color3.fromRGB(42, 29, 20), nil, "Body")
		block(m, Vector3.new(2, 2.4, 2.4), base * CFrame.new(0, 7.4, -3.6), Color3.fromRGB(42, 29, 20), nil, "Head")
		for sx = -1, 1, 2 do
			block(m, Vector3.new(0.3, 4, 0.3), base * CFrame.new(0.8 * sx, 10, -3.6) * CFrame.Angles(0, 0, math.rad(25 * sx)), Color3.fromRGB(58, 42, 26), Enum.Material.Wood, "Antler")
			block(m, Vector3.new(0.4, 3.5, 0.4), base * CFrame.new(1 * sx, 1.8, -2), Color3.fromRGB(42, 29, 20))
			block(m, Vector3.new(0.4, 3.5, 0.4), base * CFrame.new(1 * sx, 1.8, 2), Color3.fromRGB(42, 29, 20))
		end
		eyeColor = Color3.fromRGB(255, 42, 42)
	elseif kind == "leopard" then
		body = block(m, Vector3.new(2.2, 2, 5), base * CFrame.new(0, 2.2, 0), Color3.fromRGB(216, 221, 224), nil, "Body")
		block(m, Vector3.new(1.6, 1.6, 1.6), base * CFrame.new(0, 2.8, -3), Color3.fromRGB(216, 221, 224), nil, "Head")
		eyeColor = Color3.fromRGB(191, 239, 255)
	elseif kind == "lion" then
		body = block(m, Vector3.new(2.8, 2.6, 6), base * CFrame.new(0, 2.8, 0), Color3.fromRGB(199, 154, 62), nil, "Body")
		block(m, Vector3.new(3.2, 3.2, 2), base * CFrame.new(0, 3.6, -3.4), Color3.fromRGB(122, 74, 26), nil, "Mane")
		block(m, Vector3.new(1.8, 1.8, 1.4), base * CFrame.new(0, 3.4, -4.4), Color3.fromRGB(216, 170, 78), nil, "Head")
		eyeColor = Color3.fromRGB(255, 190, 60)
	else -- panther
		body = block(m, Vector3.new(2.2, 2, 5.4), base * CFrame.new(0, 2.2, 0), Color3.fromRGB(11, 11, 15), nil, "Body")
		block(m, Vector3.new(1.6, 1.6, 1.6), base * CFrame.new(0, 2.8, -3.2), Color3.fromRGB(11, 11, 15), nil, "Head")
		eyeColor = Color3.fromRGB(232, 240, 74)
	end
	local head = m:FindFirstChild("Head")
	for sx = -1, 1, 2 do
		local e = block(m, Vector3.one * 0.35, head.CFrame * CFrame.new(0.45 * sx, 0.2, -head.Size.Z / 2 - 0.05), eyeColor, Enum.Material.Neon, "Eye")
		local glow = Instance.new("PointLight")
		glow.Color = eyeColor
		glow.Range = 6
		glow.Brightness = 2
		glow.Parent = e
	end
	m.PrimaryPart = body
	m:SetAttribute("Guardian", kind)
	m:SetAttribute("H", body.Position.Y)
	return m
end

local function setVisible(g, on: boolean)
	g.visible = on
	g.model.Parent = on and folder or nil
end

local function moveToward(g, target: Vector3, speed: number, dt: number)
	local pos = g.pos
	local to = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
	if to.Magnitude < 0.1 then
		return
	end
	local step = math.min(to.Magnitude, speed * dt)
	g.pos = pos + to.Unit * step
	g.look = to.Unit
end

local function render(g)
	if g.visible then
		local p = g.pos + Vector3.new(0, g.model:GetAttribute("H") or 2, 0)
		g.model:PivotTo(CFrame.lookAt(p, p + g.look))
	end
end

-- Освещён ли point фонариком игрока ps (конус) или факелом (круг)
function Guardians.isLit(ps, point: Vector3, cosLimit: number?)
	local char = ps.player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return false
	end
	local to = point - head.Position
	local d = to.Magnitude
	if ps.torchUntil > os.clock() and d < 22 then
		return "torch"
	end
	if not ps.lightOn then
		return false
	end
	local range = ps.flashlight == 2 and 70 or 50
	local look = head.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z).Unit
	local flatTo = Vector3.new(to.X, 0, to.Z)
	if d < range and flatTo.Magnitude > 0 and flatTo.Unit:Dot(flatLook) > (cosLimit or (ps.flashlight == 2 and 0.85 or 0.9)) then
		return ps.flashlight == 2 and "strong" or "flash"
	end
	return false
end

-- Выстрел или взрыв рядом спугивает барса
function Guardians.noise(pos: Vector3)
	local g = G.leopard
	if g and g.visible and (g.pos - pos).Magnitude < 120 then
		if g.scared <= 0 then
			State.notify(nil, "Шум спугнул снежного барса!")
		end
		g.scared = 5
	end
end

function Guardians.hitTest(origin: Vector3, look: Vector3, range: number): boolean
	for _, g in pairs(G) do
		if g.visible then
			local to = Vector3.new(g.pos.X - origin.X, 0, g.pos.Z - origin.Z)
			if to.Magnitude < range + 3 and (to.Magnitude < 3 or to.Unit:Dot(look) > 0.5) then
				State.popup(g.pos + Vector3.new(0, 8, 0), "НЕУЯЗВИМ", Color3.fromRGB(166, 220, 239))
				return true
			end
		end
	end
	return false
end

function Guardians.fromPart(part: Instance)
	local m = part:FindFirstAncestorOfClass("Model")
	return m and m:GetAttribute("Guardian")
end

local function spawnNear(g, target, dist: number, behind: boolean)
	local look = target.root.CFrame.LookVector
	local a
	if behind then
		a = math.atan2(-look.Z, -look.X) + (State.rng() - 0.5)
	else
		a = State.rng() * math.pi * 2
	end
	g.pos = target.root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * dist
	g.pos = Vector3.new(g.pos.X, 0, g.pos.Z)
	g.look = Vector3.new(1, 0, 0)
	setVisible(g, true)
end

local function attack(g, target, dmg: number, label: string)
	S.PlayerService.damage(target.ps, dmg, nil)
	State.notify(target.player, label .. " напал!", "boss")
end

local function campPush(g)
	local r = S.Camp.radius() + 8
	local flat = Vector3.new(g.pos.X, 0, g.pos.Z)
	if flat.Magnitude < r then
		g.pos = flat.Unit * r
		return true
	end
	return false
end

-- Олень: ночью подкрадывается; фонарик в глаза — замирает и уходит
local function updDeer(g, dt: number, now: number)
	local night = Rules.isNight(State.run.clock, Config.DAY_LENGTH) or g.forced
	local crimson = State.run.biome.id == "crimson"
	if not night then
		if g.visible then
			setVisible(g, false)
		end
		g.state = "gone"
		g.t = 3
		return
	end
	if g.state == "gone" then
		g.t -= dt
		if g.t <= 0 then
			local players = State.alivePlayers()
			local target
			for _, p in ipairs(players) do
				if not S.Camp.inLight(p.root.Position) then
					target = p
					break
				end
			end
			if target then
				spawnNear(g, target, 110, false)
				g.state = "stalk"
				g.lit = 0
			else
				g.t = 3
			end
		end
		return
	end
	local target, d = State.nearestPlayer(g.pos, 400)
	if not target then
		g.state = "gone"
		setVisible(g, false)
		return
	end
	if g.state == "flee" then
		moveToward(g, g.pos + (g.pos - target.root.Position), 40, dt)
		g.t -= dt
		if g.t <= 0 then
			g.state = "gone"
			g.t = (State.rng() * 7 + 9) * (crimson and 0.5 or 1) * (State.run.finale and 0.4 or 1)
			setVisible(g, false)
		end
		render(g)
		return
	end
	local lit = Guardians.isLit(target.ps, g.pos + Vector3.new(0, 6, 0))
	if lit == "flash" or lit == "strong" then
		g.lit += dt
		if g.lit > (lit == "strong" and 0.25 or 1) then
			g.state = "flee"
			g.t = 3
			g.lit = 0
			State.notify(target.player, "Олень ослеплён и ушёл в темноту")
		end
		render(g)
		return
	end
	g.lit = math.max(0, g.lit - dt * 0.5)
	local speed = math.min(26, 9 + State.run.day * 0.15) * (crimson and 1.35 or 1) * (State.run.finale and 1.3 or 1)
	if lit == "torch" then
		moveToward(g, g.pos + (g.pos - target.root.Position), speed * 0.6, dt)
	else
		moveToward(g, target.root.Position, speed, dt)
	end
	campPush(g)
	if d < 5 then
		attack(g, target, 45, "Олень")
		g.state = "flee"
		g.t = 2.5
	end
	render(g)
end

-- Общая логика «появиться — охотиться — уйти» для хозяина биома
local function updHunter(g, dt: number, now: number)
	local kind = g.kind
	local night = Rules.isNight(State.run.clock, Config.DAY_LENGTH)
	local active = (kind == "lion" and not night) or (kind == "panther" and night) or kind == "leopard"
	if State.run.day < 2 or not active then
		if g.visible then
			setVisible(g, false)
		end
		g.state = "away"
		return
	end
	if g.state == "away" then
		g.off -= dt
		if g.off > 0 then
			return
		end
		local players = State.alivePlayers()
		local target
		for _, p in ipairs(players) do
			if not S.Camp.inCamp(p.root.Position) then
				target = p
				break
			end
		end
		if not target then
			g.off = 5
			return
		end
		spawnNear(g, target, kind == "lion" and 140 or 90, kind ~= "lion")
		g.state = kind == "lion" and "stalk" or "hunt"
		g.scared, g.cd, g.rounds = 0, 1.5, 0
		State.notify(target.player, ({
			leopard = "❄ Снежный барс вышел на твой след. Шум его спугнёт",
			lion = "🦁 Лев охотится на тебя. Услышишь рык — прячься в кусты",
			panther = "🐈‍⬛ Из темноты смотрят жёлтые глаза… Не поворачивайся к пантере спиной",
		})[kind], "warn")
	end
	local target, d = State.nearestPlayer(g.pos, 500)
	if not target then
		g.state = "away"
		g.off = 10
		setVisible(g, false)
		return
	end
	g.cd -= dt
	g.scared -= dt
	if campPush(g) then
		g.scared = math.max(g.scared, 1.5)
	end
	local def = World.GUARDIANS[kind]
	if g.scared > 0 then
		moveToward(g, g.pos + (g.pos - target.root.Position), 30, dt)
		if d > 110 then
			g.state = "away"
			g.off = State.rng() * 25 + 25
			setVisible(g, false)
		end
		render(g)
		return
	end
	if kind == "leopard" then
		local detect = target.ps.class == "ice" and 50 or 9999
		if d < detect then
			moveToward(g, target.root.Position, target.ps.inBush and 14 or def.speed, dt)
		end
		if d < 5 and g.cd <= 0 then
			attack(g, target, def.dmg, "Снежный барс")
			g.cd, g.scared = 2, 3
		end
	elseif kind == "panther" then
		local look = target.root.CFrame.LookVector
		local toP = g.pos - target.root.Position
		local watched = Vector3.new(look.X, 0, look.Z).Unit:Dot(Vector3.new(toP.X, 0, toP.Z).Unit) > 0.65 and d < 90
		if watched then
			moveToward(g, g.pos + toP, 9, dt)
			g.look = -Vector3.new(toP.X, 0, toP.Z).Unit
		else
			moveToward(g, target.root.Position, def.speed, dt)
		end
		if d < 5 and g.cd <= 0 then
			attack(g, target, def.dmg, "Пантера")
			g.cd, g.scared = 2.5, 3
		end
	else -- lion
		local hidden = target.ps.inBush
		g.t = (g.t or 0) - dt
		if g.state == "stalk" then
			moveToward(g, target.root.Position, hidden and 7 or 14, dt)
			if d < 75 and not hidden then
				g.state = "roar"
				g.t = 1.4
				State.notify(target.player, "РРРР! Лев заметил тебя. Прячься в кусты!", "boss")
			end
		elseif g.state == "roar" then
			local to = target.root.Position - g.pos
			g.look = Vector3.new(to.X, 0, to.Z).Unit
			if hidden then
				g.state = "stalk"
			elseif g.t <= 0 then
				g.state = "charge"
				g.t = 1
				g.dir = g.look
			end
		elseif g.state == "charge" then
			g.pos += g.dir * def.charge * dt
			if d < 6 then
				attack(g, target, def.dmg, "Лев")
				g.state, g.t = "rest", 2.4
			elseif g.t <= 0 then
				g.state, g.t = "rest", 1.2
			end
		elseif g.state == "rest" and g.t <= 0 then
			g.rounds += 1
			if g.rounds >= 3 then
				g.state, g.off = "away", State.rng() * 25 + 35
				setVisible(g, false)
			else
				g.state = "stalk"
			end
		end
	end
	render(g)
end

function Guardians.init(services)
	S = services
	State = S.State
	folder = Instance.new("Folder")
	folder.Name = "Guardians"
	folder.Parent = workspace
end

function Guardians.start()
	G.deer = { kind = "deer", model = buildModel("deer"), pos = Vector3.zero, look = Vector3.new(1, 0, 0), state = "gone", t = 5, lit = 0, visible = false }
	local hk = State.run.biome.hunter
	if hk ~= "deer" then
		G[hk] = { kind = hk, model = buildModel(hk), pos = Vector3.zero, look = Vector3.new(1, 0, 0), state = "away", off = 20, scared = 0, cd = 0, visible = false }
	end
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for kind, g in pairs(G) do
			local ok, err = pcall(kind == "deer" and updDeer or updHunter, g, dt, now)
			if not ok then
				warn("[Guardians] " .. tostring(err))
			end
		end
	end)
end

function Guardians.forceDeer(on: boolean)
	if G.deer then
		G.deer.forced = on
	end
end

return Guardians
