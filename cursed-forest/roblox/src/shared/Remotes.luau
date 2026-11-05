-- Сетевые события. Сервер создаёт их, клиент ждёт.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"State", -- сервер → клиент: состояние игрока и мира
	"Notify", -- сервер → клиент: сообщение (text, kind)
	"Popup", -- сервер → клиент: всплывающий урон (pos, text, color)
	"Panel", -- сервер → клиент: открыть окно {id, title, text, buttons}
	"ClassList", -- сервер → клиент: список классов с ценами и замками
	"ChooseClass", -- клиент → сервер: (classId, buy)
	"Attack", -- клиент → сервер: (weaponIndex, aimPosition)
	"Action", -- клиент → сервер: ("flashlight"|"eat"|"bandage"|"throw"|"torch", arg)
	"PanelAction", -- клиент → сервер: (panelId, actionId)
}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, n in ipairs(NAMES) do
		if not folder:FindFirstChild(n) then
			local r = Instance.new("RemoteEvent")
			r.Name = n
			r.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, n in ipairs(NAMES) do
	Remotes[n] = folder:WaitForChild(n)
end
return Remotes
