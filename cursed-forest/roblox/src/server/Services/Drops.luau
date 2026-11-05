-- Добыча на земле: светящийся кубик с иконкой. Подбирается сама, если подойти.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Config = require(Shared.Config)

local Drops = {}
local S
local list = {}
local folder

function Drops.init(services)
	S = services
	folder = Instance.new("Folder")
	folder.Name = "Drops"
	folder.Parent = workspace
end

function Drops.spawn(pos: Vector3, id: string, n: number, delay: number?)
	if n <= 0 or not Items[id] then
		return
	end
	local p = Instance.new("Part")
	p.Size = Vector3.new(1.2, 1.2, 1.2)
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.Neon
	p.Color = Items[id].free and Color3.fromRGB(255, 211, 107) or Color3.fromRGB(200, 170, 120)
	p.Position = Vector3.new(pos.X + math.random(-15, 15) / 10, 1, pos.Z + math.random(-15, 15) / 10)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(60, 24)
	gui.StudsOffset = Vector3.new(0, 1.6, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 60
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = Items[id].icon .. " " .. n
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.Parent = gui
	gui.Parent = p
	p.Parent = folder
	table.insert(list, { part = p, id = id, n = n, readyAt = os.clock() + (delay or 0.4), born = os.clock() })
	if #list > 250 then
		local old = table.remove(list, 1)
		old.part:Destroy()
	end
end

function Drops.pickup(ps, pos: Vector3)
	for i = #list, 1, -1 do
		local d = list[i]
		if os.clock() >= d.readyAt and (d.part.Position - pos).Magnitude < Config.PICKUP_RADIUS then
			local put = ps.inv:add(d.id, d.n)
			if put > 0 then
				d.n -= put
				S.PlayerService.sync(ps)
				S.State.popup(d.part.Position, "+" .. put .. " " .. Items[d.id].icon, Color3.fromRGB(255, 226, 168))
			end
			if d.n <= 0 then
				d.part:Destroy()
				table.remove(list, i)
			else
				d.readyAt = os.clock() + 2
			end
		end
	end
end

-- Раз в минуту удаляем очень старую добычу
task.spawn(function()
	while true do
		task.wait(60)
		for i = #list, 1, -1 do
			if os.clock() - list[i].born > 600 then
				list[i].part:Destroy()
				table.remove(list, i)
			end
		end
	end
end)

return Drops
