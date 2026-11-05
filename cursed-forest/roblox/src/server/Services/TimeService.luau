-- Сутки: время, освещение, закат (кто нападёт ночью), рассвет (новый день), сотая ночь и концовки.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)

local TimeService = {}
local S, State
local wasNight = false
local atmosphere, color

local function setupLighting()
	Lighting.Ambient = Color3.fromRGB(40, 40, 50)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 80)
	Lighting.FogColor = Color3.fromRGB(20, 26, 22)
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.35
	atmosphere.Color = Color3.fromRGB(170, 180, 170)
	atmosphere.Parent = Lighting
	color = Instance.new("ColorCorrectionEffect")
	color.Parent = Lighting
	local tint = ({ winter = Color3.fromRGB(225, 235, 255), jungle = Color3.fromRGB(225, 255, 225), savanna = Color3.fromRGB(255, 240, 210), crimson = Color3.fromRGB(255, 205, 205) })[State.run.biome.id]
	color.TintColor = tint or Color3.new(1, 1, 1)
end

local function onDusk()
	local run = State.run
	run.raid = Rules.raidKind(run.day, State.rng)
	State.notify(nil, Rules.raidText(run.raid), "boss")
	State.notify(nil, "Наступила ночь. Олень вышел на охоту", "warn")
	if run.day == Rules.DAYS_TO_WIN then
		if run.camp.level >= 5 then
			run.finale = true
			State.notify(nil, "СОТАЯ НОЧЬ! Держите Великий Костёр до рассвета!", "boss")
		else
			State.notify(nil, "Сотая ночь, а Великий Костёр не зажжён…", "boss")
		end
	end
end

local function newRun(text: string)
	State.notify(nil, text, "boss")
	task.wait(15)
	local run = State.run
	run.day, run.clock, run.finale = 1, Config.DAY_LENGTH * 0.05, false
	run.camp.level, run.camp.fuel = 1, 75
	S.Camp.storage = {}
	State.notify(nil, "Начинается новый забег. День 1", "good")
end

local function onDawn()
	local run = State.run
	if run.finale then
		for plr in pairs(State.players) do
			S.Data.addDiamonds(plr, Rules.diamondsForWin(run.hard))
			local prof = S.Data.get(plr)
			if prof then
				prof.wins += 1
			end
		end
		task.spawn(newRun, "Рассвет сотого дня! Великий Костёр горел до утра. Каждый выживший получает " .. Rules.diamondsForWin(run.hard) .. " 💎")
		return
	end
	if run.day >= Rules.DAYS_TO_WIN then
		task.spawn(newRun, "Великий Костёр так и не зажгли. Лес оставил вас себе")
		return
	end
	run.day += 1
	S.Mobs.dawn()
	S.WorldBuilder.dawn(run.day)
	S.Structures.dawn(run.day)
	for plr, ps in pairs(State.players) do
		if ps.class then
			S.Data.addClassDay(plr, ps.class)
		end
	end
	S.Data.saveAll()
	State.notify(nil, "☀ День " .. run.day .. " / " .. Rules.DAYS_TO_WIN, "good")
end

function TimeService.init(services)
	S = services
	State = S.State
end

function TimeService.start()
	setupLighting()
	RunService.Heartbeat:Connect(function(dt)
		local run = State.run
		run.clock += dt
		if run.clock >= Config.DAY_LENGTH then
			run.clock -= Config.DAY_LENGTH
			wasNight = false
			onDawn()
		end
		local night = Rules.isNight(run.clock, Config.DAY_LENGTH)
		if night and not wasNight then
			wasNight = true
			onDusk()
		end
		Lighting.ClockTime = Rules.clockTime(run.clock, Config.DAY_LENGTH)
		Lighting.Brightness = night and 0.3 or 2
		Lighting.FogEnd = night and 140 or 700
		atmosphere.Density = night and 0.55 or 0.3
		S.Camp.tick(dt)
	end)
end

return TimeService
