-- Общее состояние забега и игроков на сервере + мелкие помощники (сообщения, всплывающий текст).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)
local World = require(Shared.World)

local State = {}

local rng = Random.new()
State.rng = function()
	return rng:NextNumber()
end
State.rint = function(a: number, b: number)
	return rng:NextInteger(a, b)
end

local biome = World.BIOMES[rng:NextInteger(1, #World.BIOMES)]

State.run = {
	day = 1,
	clock = Config.DAY_LENGTH * 0.05,
	biome = biome,
	raid = "vampire",
	hard = Config.HARD_MODE,
	camp = { level = 1, fuel = 75, walls = false },
	volcano = 0, -- сколько туш сброшено в вулкан
	ufo = { crashed = false, room = 0, active = false, cleared = false },
	temples = { 0, 0, 0, 0 }, -- 0 не тронут, 1 стража, 2 можно спуститься, 3 череп взят
	jungleMain = false,
	jungleOpens = 0,
	ice = 0, -- 0 цела, 1 проснулись оккультисты, 2 сундук, 3 пусто
	castleFloor = 0, -- замок оккультистов: пройдено этажей
	castleActive = false,
	carnival = { stage = 0, killed = 0, active = false },
	frogs = { keysNeeded = 8, active = false, wave = 0 },
	bossesDone = {},
	churchDay = -9,
	finale = false,
}

State.players = {} -- [Player] = ps (заполняет PlayerService)

function State.notify(player: Player?, text: string, kind: string?)
	if player then
		Remotes.Notify:FireClient(player, text, kind or "")
	else
		Remotes.Notify:FireAllClients(text, kind or "")
	end
end

function State.popup(pos: Vector3, text: string, color: Color3?)
	Remotes.Popup:FireAllClients(pos, text, color or Color3.new(1, 1, 1))
end

function State.alivePlayers()
	local out = {}
	for plr, ps in pairs(State.players) do
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if ps.class and hum and root and hum.Health > 0 then
			table.insert(out, { player = plr, ps = ps, root = root, hum = hum })
		end
	end
	return out
end

function State.nearestPlayer(pos: Vector3, maxDist: number?)
	local best, bd = nil, maxDist or math.huge
	for _, p in ipairs(State.alivePlayers()) do
		local d = (p.root.Position - pos).Magnitude
		if d < bd then
			best, bd = p, d
		end
	end
	return best, bd
end

function State.flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

return State
