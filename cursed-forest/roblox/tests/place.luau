-- Проверка собранного файла места: все скрипты на своих местах
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local game = roblox.deserializePlace(fs.readFile("build/CursedForest.rbxl"))
local need = {
	{ "ServerScriptService", "Server", "Main", "Script" },
	{ "ReplicatedStorage", "Shared", "Rules", "ModuleScript" },
	{ "StarterPlayer", "StarterPlayerScripts", "Client", "Client" },
}
local bad = 0
for _, path in ipairs(need) do
	local node = game:GetService(path[1])
	for i = 2, #path - 1 do
		node = node and node:FindFirstChild(path[i])
	end
	local cls = path[#path]
	local okNode = node ~= nil and (cls == "Client" and node:IsA("LocalScript") or node:IsA(cls) or node.ClassName == cls)
	if not okNode then
		-- Client: папка с LocalScript внутри
		if cls == "Client" and node then
			okNode = node:FindFirstChild("Client") ~= nil
		end
	end
	print((okNode and "OK  " or "НЕТ ") .. table.concat(path, "."))
	if not okNode then
		bad += 1
	end
end
local services = game:GetService("ServerScriptService").Server:FindFirstChild("Services")
local n = 0
for _, ch in ipairs(services:GetChildren()) do
	n += 1
end
print("Серверных сервисов: " .. n)
if bad > 0 then
	process.exit(1)
end
