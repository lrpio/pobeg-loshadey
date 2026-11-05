-- Точка входа сервера: собирает сервисы, связывает их и запускает.
local Services = script.Parent:WaitForChild("Services")

local S = {}
for _, name in ipairs({ "State", "Data", "WorldBuilder", "Drops", "Camp", "Mobs", "Combat", "Guardians", "Structures", "PlayerService", "TimeService" }) do
	S[name] = require(Services:WaitForChild(name))
end

-- init: передаём ссылки друг на друга
for name, svc in pairs(S) do
	if type(svc) == "table" and svc.init then
		svc.init(S)
	end
end

-- мир строится до появления игроков
S.WorldBuilder.build()
S.Camp.build(S.WorldBuilder.root.Structures)
S.Structures.build()

for _, name in ipairs({ "Mobs", "Combat", "Guardians", "Structures", "PlayerService", "TimeService" }) do
	if S[name].start then
		S[name].start()
	end
end

print("[CursedForest] сервер запущен. Биом: " .. S.State.run.biome.name)
