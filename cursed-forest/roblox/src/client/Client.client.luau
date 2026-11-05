-- Клиент: выбор класса, интерфейс (здоровье, сытость, день, мешок), хотбар оружия, сообщения, окна построек,
-- мини-игра приручения, управление с клавиатуры и телефона.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Items = require(Shared.Items)
local Weapons = require(Shared.Weapons)
local Armor = require(Shared.Armor)

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local gui = Instance.new("ScreenGui")
gui.Name = "ForestUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local C = {
	bg = Color3.fromRGB(14, 20, 16),
	panel = Color3.fromRGB(24, 33, 26),
	line = Color3.fromRGB(47, 59, 47),
	ink = Color3.fromRGB(236, 228, 207),
	muted = Color3.fromRGB(160, 168, 148),
	ember = Color3.fromRGB(255, 143, 63),
	ember2 = Color3.fromRGB(255, 196, 107),
	blood = Color3.fromRGB(214, 68, 76),
	moss = Color3.fromRGB(134, 180, 106),
}
local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function new(class: string, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function corner(o, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o)
	return o
end
local function stroke(o, color)
	new("UIStroke", { Color = color or C.line, Thickness = 1 }, o)
	return o
end
local function label(parent, text, size, props)
	local t = new("TextLabel", {
		BackgroundTransparency = 1, Text = text, Font = FONT, TextSize = size or 14, TextColor3 = C.ink,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Size = UDim2.new(1, 0, 0, (size or 14) + 6),
	}, parent)
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	return t
end
local function button(parent, text, onClick, props)
	local b = new("TextButton", {
		Text = text, Font = FONT_BOLD, TextSize = 14, TextColor3 = C.ember2, BackgroundColor3 = Color3.fromRGB(42, 30, 20),
		AutoButtonColor = true, Size = UDim2.new(1, 0, 0, 34), TextWrapped = true,
	}, parent)
	corner(b, 6)
	stroke(b, C.ember)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	b.Activated:Connect(onClick)
	return b
end
local function bar(parent, y, color)
	local bg = new("Frame", { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = Color3.fromRGB(10, 10, 10), BackgroundTransparency = 0.3 }, parent)
	corner(bg, 4)
	local fill = new("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, bg)
	corner(fill, 4)
	local text = label(bg, "", 12, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(6, 0), Font = FONT_BOLD })
	return fill, text
end

----------------------------------------------------------------- HUD
local hud = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)
local left = new("Frame", { Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(220, 150), BackgroundTransparency = 1 }, hud)
local hpFill, hpText = bar(left, 0, C.blood)
local fdFill, fdText = bar(left, 24, Color3.fromRGB(215, 154, 62))
local wmFill, wmText = bar(left, 48, Color3.fromRGB(166, 220, 239))
local fireText = label(left, "", 13, { Position = UDim2.fromOffset(0, 72) })
local bagText = label(left, "", 13, { Position = UDim2.fromOffset(0, 92) })
local bloodText = label(left, "", 13, { Position = UDim2.fromOffset(0, 112), TextColor3 = C.blood })

local top = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(340, 70), BackgroundColor3 = C.bg, BackgroundTransparency = 0.25 }, hud)
corner(top, 6)
stroke(top)
local dayText = label(top, "День 1 / 100", 22, { Position = UDim2.fromOffset(0, 4), TextXAlignment = Enum.TextXAlignment.Center, Font = FONT_BOLD })
local dayBarBg = new("Frame", { Position = UDim2.new(0, 14, 0, 36), Size = UDim2.new(1, -28, 0, 6), BackgroundColor3 = Color3.fromRGB(34, 43, 35) }, top)
local dayBar = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.ember, BorderSizePixel = 0 }, dayBarBg)
local raidText = label(top, "", 13, { Position = UDim2.fromOffset(0, 46), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.muted })

-- сообщения
local feed = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 92), Size = UDim2.fromOffset(520, 200), BackgroundTransparency = 1 }, hud)
new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, feed)
local feedOrder = 0
local function toast(text: string, kind: string?)
	feedOrder -= 1
	local col = kind == "boss" and C.blood or kind == "warn" and C.ember or kind == "good" and C.ember2 or C.moss
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.bg, BackgroundTransparency = 0.15, LayoutOrder = feedOrder }, feed)
	corner(f, 4)
	new("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = col, BorderSizePixel = 0 }, f)
	local t = label(f, text, 14, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -16, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = kind == "boss" and FONT_BOLD or FONT })
	new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, f)
	local kids = {}
	for _, ch in ipairs(feed:GetChildren()) do
		if ch:IsA("Frame") then
			table.insert(kids, ch)
		end
	end
	if #kids > 5 then
		table.sort(kids, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		kids[1]:Destroy()
	end
	task.delay(kind == "boss" and 7 or 5, function()
		if f.Parent then
			f:Destroy()
		end
	end)
	return t
end

-- хотбар
local hotbar = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(600, 58), BackgroundTransparency = 1 }, hud)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center }, hotbar)

local state = nil
local selected = 1

local function weaponShort(id)
	local n = Weapons[id].name
	return n:match("(%S+)$") or n
end

local function redrawHotbar()
	for _, c in ipairs(hotbar:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	if not state then
		return
	end
	for i, w in ipairs(state.inv.weapons) do
		local def = Weapons[w]
		local ammo = ""
		if def.mag then
			ammo = (state.mag[w] or def.mag) .. "/" .. def.mag
		elseif def.ammo then
			ammo = tostring(state.inv.items[def.ammo] or 0)
		end
		local b = new("TextButton", {
			Size = UDim2.fromOffset(64, 56), BackgroundColor3 = C.bg, BackgroundTransparency = 0.2, AutoButtonColor = true,
			Text = (i <= 9 and (i .. " ") or "") .. weaponShort(w) .. (ammo ~= "" and ("\n" .. ammo) or ""),
			Font = FONT_BOLD, TextSize = 11, TextColor3 = C.ink, TextWrapped = true,
		}, hotbar)
		corner(b, 5)
		stroke(b, i == selected and C.ember or C.line)
		b.Activated:Connect(function()
			selected = i
			redrawHotbar()
		end)
	end
end

----------------------------------------------------------------- всплывающий текст в мире
Remotes.Popup.OnClientEvent:Connect(function(pos: Vector3, text: string, color: Color3)
	local cam = workspace.CurrentCamera
	if (cam.CFrame.Position - pos).Magnitude > 120 then
		return
	end
	local anchor = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.one * 0.2, Position = pos }, workspace)
	local bb = new("BillboardGui", { Size = UDim2.fromOffset(120, 30), AlwaysOnTop = true, Adornee = anchor }, anchor)
	local t = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = text, TextColor3 = color, TextStrokeTransparency = 0.3, Font = FONT_BOLD, TextScaled = true }, bb)
	TweenService:Create(anchor, TweenInfo.new(0.9), { Position = pos + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	game:GetService("Debris"):AddItem(anchor, 1)
end)

Remotes.Notify.OnClientEvent:Connect(toast)

----------------------------------------------------------------- окна (панели)
local modal = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Visible = false, ZIndex = 20 }, gui)
local board = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 560, 0.8, 0), BackgroundColor3 = C.panel, ZIndex = 21 }, modal)
corner(board, 8)
stroke(board)
new("UISizeConstraint", { MaxSize = Vector2.new(560, 700) }, board)
local mTitle = label(board, "", 22, { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -70, 0, 30), Font = FONT_BOLD, TextColor3 = C.ember2, ZIndex = 22 })
local closeBtn = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(32, 32), Text = "✕", Font = FONT_BOLD, TextSize = 16, TextColor3 = C.ink, BackgroundColor3 = C.bg, ZIndex = 22 }, board)
corner(closeBtn, 6)
local scroll = new("ScrollingFrame", { Position = UDim2.fromOffset(16, 52), Size = UDim2.new(1, -32, 1, -64), BackgroundTransparency = 1, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ZIndex = 22 }, board)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
local currentPanel = nil
local minigameConn = nil

local function closePanel()
	modal.Visible = false
	if minigameConn then
		minigameConn:Disconnect()
		minigameConn = nil
		if currentPanel == "tame" then
			Remotes.PanelAction:FireServer("tame", "fail")
		end
	end
	currentPanel = nil
end
closeBtn.Activated:Connect(closePanel)

local function runMinigame(container)
	-- стрелка бегает по шкале; попади в зелёную зону 4 раза
	local track = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(16, 24, 16), ZIndex = 23 }, container)
	corner(track, 4)
	local zone = new("Frame", { Size = UDim2.fromScale(0.2, 1), Position = UDim2.fromScale(0.4, 0), BackgroundColor3 = C.moss, BackgroundTransparency = 0.4, ZIndex = 24 }, track)
	local needle = new("Frame", { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = C.ember2, ZIndex = 25 }, track)
	local progBg = new("Frame", { Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = Color3.fromRGB(10, 10, 10), ZIndex = 23 }, container)
	local prog = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.moss, ZIndex = 24 }, progBg)
	local t, progress, zc = 0, 0, 0.5
	local function hit()
		local p = (math.sin(t * 2.6) + 1) / 2
		if math.abs(p - zc) < 0.1 then
			progress += 25
			zc = 0.2 + math.random() * 0.6
		else
			progress = math.max(0, progress - 15)
		end
		prog.Size = UDim2.fromScale(progress / 100, 1)
		if progress >= 100 then
			if minigameConn then
				minigameConn:Disconnect()
				minigameConn = nil
			end
			Remotes.PanelAction:FireServer("tame", "success")
			modal.Visible = false
			currentPanel = nil
		end
	end
	button(container, "Ритм! (Пробел)", hit, { ZIndex = 23 })
	minigameConn = RunService.RenderStepped:Connect(function(dt)
		t += dt
		local p = (math.sin(t * 2.6) + 1) / 2
		needle.Position = UDim2.fromScale(p, 0)
		zone.Position = UDim2.fromScale(zc - 0.1, 0)
	end)
	return hit
end
local minigameHit = nil

Remotes.Panel.OnClientEvent:Connect(function(data)
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	if minigameConn then
		minigameConn:Disconnect()
		minigameConn = nil
	end
	currentPanel = data.id
	mTitle.Text = data.title
	local txt = label(scroll, data.text, 14, { AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextColor3 = C.muted, ZIndex = 23, LayoutOrder = 1 })
	txt.RichText = false
	local tabs
	for i, b in ipairs(data.buttons) do
		if b.minigame then
			local box = new("Frame", { Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 23 }, scroll)
			new("UIListLayout", { Padding = UDim.new(0, 8) }, box)
			minigameHit = runMinigame(box)
		elseif b.tab then
			if not tabs then
				tabs = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 0, ZIndex = 23 }, scroll)
				new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, tabs)
			end
			local tb = button(tabs, b.label, function()
				Remotes.PanelAction:FireServer(data.id, b.id)
			end, { Size = UDim2.fromOffset(150, 32), ZIndex = 23, BackgroundColor3 = b.on and Color3.fromRGB(58, 40, 24) or C.bg })
		else
			local btn = button(scroll, b.label, function()
				Remotes.PanelAction:FireServer(data.id, b.id)
			end, { LayoutOrder = 2 + i, ZIndex = 23 })
			if b.enabled == false then
				btn.AutoButtonColor = false
				btn.TextColor3 = C.muted
				btn.BackgroundTransparency = 0.6
				btn.Active = false
			end
		end
	end
	modal.Visible = true
end)

----------------------------------------------------------------- выбор класса
local classScreen = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, ZIndex = 30 }, gui)
local title = label(classScreen, "100 дней в Проклятом лесу", 40, { Position = UDim2.fromOffset(24, 20), Size = UDim2.new(1, -48, 0, 48), Font = FONT_BOLD, ZIndex = 31 })
local subtitle = label(classScreen, "Выбери класс. Новые классы покупаются за алмазы, их дают за прохождение 100 дней и в замке оккультистов.", 15, { Position = UDim2.fromOffset(24, 72), Size = UDim2.new(1, -48, 0, 40), TextColor3 = C.muted, ZIndex = 31 })
local diamondText = label(classScreen, "", 16, { Position = UDim2.fromOffset(24, 112), Size = UDim2.new(1, -48, 0, 22), TextColor3 = C.ember2, Font = FONT_BOLD, ZIndex = 31 })
local grid = new("ScrollingFrame", { Position = UDim2.fromOffset(24, 142), Size = UDim2.new(1, -48, 1, -160), BackgroundTransparency = 1, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ZIndex = 31 }, classScreen)
new("UIGridLayout", { CellSize = UDim2.fromOffset(260, 120), CellPadding = UDim2.fromOffset(8, 8) }, grid)

Remotes.ClassList.OnClientEvent:Connect(function(list, diamonds)
	diamondText.Text = "💎 Алмазы: " .. diamonds
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for _, c in ipairs(list) do
		local card = new("Frame", { BackgroundColor3 = C.panel, ZIndex = 31 }, grid)
		corner(card, 6)
		stroke(card, c.unlocked and C.line or Color3.fromRGB(70, 50, 40))
		new("Frame", { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = c.color, BorderSizePixel = 0, ZIndex = 32 }, card)
		label(card, c.name .. (c.unlocked and "" or ("  🔒 " .. c.cost .. " 💎")), 16, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -20, 0, 20), Font = FONT_BOLD, ZIndex = 32 })
		label(card, c.desc, 12, { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -20, 0, 50), TextColor3 = C.muted, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 32 })
		button(card, c.unlocked and "Играть" or ("Купить за " .. c.cost .. " 💎"), function()
			Remotes.ChooseClass:FireServer(c.id, not c.unlocked)
		end, { Position = UDim2.new(0, 12, 1, -38), Size = UDim2.new(1, -24, 0, 30), ZIndex = 32 })
	end
end)

----------------------------------------------------------------- состояние от сервера
Remotes.State.OnClientEvent:Connect(function(s)
	local wasNil = state == nil or state.class == nil
	state = s
	if s.class then
		classScreen.Visible = false
		hud.Visible = true
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hpFill.Size = UDim2.fromScale(math.clamp(hum.Health / hum.MaxHealth, 0, 1), 1)
		hpText.Text = string.format("Здоровье %d/%d", math.floor(hum.Health), math.floor(hum.MaxHealth))
	end
	fdFill.Size = UDim2.fromScale(s.hunger / 100, 1)
	fdText.Text = (s.class == "cyborg" and "Энергия " or "Сытость ") .. math.floor(s.hunger)
	wmFill.Parent.Visible = s.warmth < 99.5
	wmFill.Size = UDim2.fromScale(s.warmth / 100, 1)
	wmText.Text = "Тепло " .. math.floor(s.warmth)
	fireText.Text = string.format("🔥 Костёр ур.%d: %d%%", s.fire.level, math.floor(s.fire.fuel))
	bagText.Text = string.format("🎒 %s: %d/%d мест · %s", "Мешок", s.inv.used, s.inv.capacity, (Armor[s.inv.armor] or Armor.none).name)
	bloodText.Text = s.blood > 0 and ("🩸 Заряд крови " .. s.blood .. "/" .. s.bloodMax) or ""
	dayText.Text = (s.night and "☾ " or "☀ ") .. "День " .. s.day .. " / 100"
	dayBar.Size = UDim2.fromScale(s.phase, 1)
	dayBar.BackgroundColor3 = s.night and Color3.fromRGB(70, 90, 160) or C.ember
	raidText.Text = (s.night and (s.raid == "occult" and "Ночь оккультистов" or "Ночь вампиров") or "")
		.. (s.biome and ("  · биом: " .. s.biome) or "  · загляни на стенд у костра")
	if selected > #s.inv.weapons then
		selected = 1
	end
	redrawHotbar()
end)

----------------------------------------------------------------- управление
local function aimPoint(): Vector3
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if isTouch and root then
		return root.Position + root.CFrame.LookVector * 30
	end
	return mouse.Hit.Position
end

local attacking = false
local function attack()
	if not state or modal.Visible then
		return
	end
	Remotes.Attack:FireServer(selected, aimPoint())
end

UserInputService.InputBegan:Connect(function(input, processed)
	if modal.Visible and input.KeyCode == Enum.KeyCode.Space and minigameHit and currentPanel == "tame" then
		minigameHit()
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and modal.Visible then
		closePanel()
		return
	end
	if processed or not state then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		attacking = true
		attack()
	end
	local k = input.KeyCode
	local n = ({ [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6, [Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8, [Enum.KeyCode.Nine] = 9 })[k]
	if n and n <= #state.inv.weapons then
		selected = n
		redrawHotbar()
	elseif k == Enum.KeyCode.F then
		Remotes.Action:FireServer("flashlight")
	elseif k == Enum.KeyCode.R then
		Remotes.Action:FireServer("eat")
	elseif k == Enum.KeyCode.H then
		Remotes.Action:FireServer("bandage")
	elseif k == Enum.KeyCode.G then
		Remotes.Action:FireServer("throw", aimPoint())
	elseif k == Enum.KeyCode.Q then
		Remotes.Action:FireServer("tame")
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		attacking = false
	end
end)
-- зажатая кнопка: атака повторяется (сервер сам следит за перезарядкой)
task.spawn(function()
	while true do
		task.wait(0.12)
		if attacking then
			attack()
		end
	end
end)

-- кнопки для телефона
if isTouch then
	local pad = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -80), Size = UDim2.fromOffset(190, 130), BackgroundTransparency = 1 }, hud)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(58, 58), CellPadding = UDim2.fromOffset(6, 6) }, pad)
	local function tbtn(text, fn, hold)
		local b = new("TextButton", { Text = text, Font = FONT_BOLD, TextSize = 12, TextColor3 = C.ink, BackgroundColor3 = C.bg, BackgroundTransparency = 0.25, TextWrapped = true }, pad)
		corner(b, 29)
		stroke(b)
		if hold then
			b.MouseButton1Down:Connect(function()
				attacking = true
				attack()
			end)
			b.MouseButton1Up:Connect(function()
				attacking = false
			end)
		else
			b.Activated:Connect(fn)
		end
	end
	tbtn("🔦\nСвет", function() Remotes.Action:FireServer("flashlight") end)
	tbtn("🍖\nЕда", function() Remotes.Action:FireServer("eat") end)
	tbtn("💣\nБросок", function() Remotes.Action:FireServer("throw", aimPoint()) end)
	tbtn("🩹\nБинт", function() Remotes.Action:FireServer("bandage") end)
	tbtn("🎵\nПриручить", function() Remotes.Action:FireServer("tame") end)
	tbtn("⚔️\nУдар", nil, true)
end

-- здоровье обновляется плавно между пакетами состояния
RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hud.Visible then
		hpFill.Size = UDim2.fromScale(math.clamp(hum.Health / hum.MaxHealth, 0, 1), 1)
		hpText.Text = string.format("Здоровье %d/%d", math.floor(hum.Health), math.floor(hum.MaxHealth))
	end
end)

-- запросить список классов (на случай, если сервер отправил его раньше, чем клиент подписался)
task.delay(1, function()
	if classScreen.Visible then
		Remotes.Action:FireServer("class")
	end
end)
