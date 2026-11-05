-- Сохранение между играми (DataStore): алмазы, купленные классы, прожитые дни по классам.
-- Забег (100 дней) живёт на сервере; между играми сохраняется только прогресс игрока.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Data = {}
local store
local ok = pcall(function()
	store = DataStoreService:GetDataStore("CursedForest_v1")
end)
if not ok then
	store = nil
	warn("[Data] DataStore недоступен: в Studio включите Game Settings → Security → Enable Studio Access to API Services")
end

local profiles = {}

local function default()
	return { diamonds = 0, unlocked = { hunter = true }, classDays = {}, wins = 0 }
end

function Data.load(player: Player)
	local prof = default()
	if store then
		local success, saved = pcall(function()
			return store:GetAsync("p_" .. player.UserId)
		end)
		if success and type(saved) == "table" then
			prof.diamonds = saved.diamonds or 0
			prof.unlocked = saved.unlocked or prof.unlocked
			prof.classDays = saved.classDays or {}
			prof.wins = saved.wins or 0
		end
	end
	prof.unlocked.hunter = true
	profiles[player] = prof
	return prof
end

function Data.get(player: Player)
	return profiles[player]
end

function Data.save(player: Player)
	local prof = profiles[player]
	if not prof or not store then
		return
	end
	pcall(function()
		store:SetAsync("p_" .. player.UserId, prof)
	end)
end

function Data.release(player: Player)
	Data.save(player)
	profiles[player] = nil
end

function Data.addDiamonds(player: Player, n: number)
	local prof = profiles[player]
	if prof then
		prof.diamonds += n
		Data.save(player)
	end
end

function Data.isUnlocked(player: Player, classId: string, cost: number): boolean
	if RunService:IsStudio() and require(game:GetService("ReplicatedStorage").Shared.Config).STUDIO_UNLOCK_ALL then
		return true
	end
	local prof = profiles[player]
	return cost == 0 or (prof ~= nil and prof.unlocked[classId] == true)
end

function Data.buy(player: Player, classId: string, cost: number): boolean
	local prof = profiles[player]
	if not prof or prof.unlocked[classId] then
		return prof ~= nil
	end
	if prof.diamonds < cost then
		return false
	end
	prof.diamonds -= cost
	prof.unlocked[classId] = true
	Data.save(player)
	return true
end

function Data.addClassDay(player: Player, classId: string)
	local prof = profiles[player]
	if prof then
		prof.classDays[classId] = (prof.classDays[classId] or 0) + 1
	end
end

function Data.saveAll()
	for plr in pairs(profiles) do
		Data.save(plr)
	end
end

game:BindToClose(function()
	Data.saveAll()
end)

return Data
