-- Бой: удары и выстрелы игроков (проверка на сервере), взрывы, броски, визуальные трассеры.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Weapons)
local Rules = require(Shared.Rules)

local Combat = {}
local S, State
local fxFolder

function Combat.tracer(from: Vector3, to: Vector3, color: Color3?, width: number?)
	local len = (to - from).Magnitude
	if len < 0.1 then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.Neon
	p.Color = color or Color3.fromRGB(255, 224, 138)
	p.Size = Vector3.new(width or 0.2, width or 0.2, len)
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2)
	p.Parent = fxFolder
	Debris:AddItem(p, 0.08)
end

function Combat.explode(pos: Vector3, radius: number, dmg: number, ps, hurtsPlayers: boolean?)
	local e = Instance.new("Explosion")
	e.Position = pos
	e.BlastRadius = radius
	e.BlastPressure = 0
	e.DestroyJointRadiusPercent = 0
	e.Parent = workspace
	for _, m in ipairs(S.Mobs.inRadius(pos, radius)) do
		local mult = (ps and ps.class == "bandit") and 1.5 or 1
		S.Mobs.damage(m, dmg * mult, { player = ps, fire = true, bomb = true })
	end
	for _, p in ipairs(State.alivePlayers()) do
		if (p.root.Position - pos).Magnitude < radius then
			if hurtsPlayers or (p.ps == ps and ps.class ~= "pyro") then
				S.PlayerService.damage(p.ps, hurtsPlayers and dmg or 12)
			end
		end
	end
	S.Guardians.noise(pos)
end

local function weaponStats(ps, wid: string)
	local w = Weapons[wid]
	if w.levels then
		local _, lvl = Rules.woodsmanLevel(Weapons.WOODSMAN_LEVELS, ps.trees)
		local copy = table.clone(w)
		copy.dmg = lvl.dmg
		copy.chop = lvl.chop
		return copy
	end
	return w
end

local function outMult(ps, w)
	local m = 1
	if ps.class == "vampire" and not Rules.isNight(State.run.clock, require(Shared.Config).DAY_LENGTH) then
		m *= 0.85
	end
	if ps.class == "brawler" and w.melee then
		m *= 1.35
	end
	if ps.class == "hunter" then
		if not w.melee then
			m *= 1.2
		end
		m *= 1 + 0.04 * (ps.flags.grow or 0)
	end
	if ps.buffs.str and ps.buffs.str > os.clock() then
		m *= 1.25
	end
	return m
end

local function bloodTick(ps, w)
	local armorHasBlood = require(Shared.Armor)[ps.inv.armor].blood
	if not (w.blood or armorHasBlood) then
		return
	end
	local charge, full = Rules.bloodHit(ps.blood, State.rng, 0.2)
	ps.blood = charge
	if full then
		S.PlayerService.heal(ps, 25)
		State.notify(ps.player, "Заряд крови полон: +25 здоровья", "good")
	end
	S.PlayerService.sync(ps)
end

local function melee(ps, root: BasePart, look: Vector3, w, wid)
	local dmg = w.dmg * outMult(ps, w)
	local hitAny = false
	local arc = w.cone and 0.85 or 0.55
	for _, m in ipairs(S.Mobs.inRadius(root.Position, w.range + 2)) do
		local to = m.root.Position - root.Position
		local flat = Vector3.new(to.X, 0, to.Z)
		if flat.Magnitude < 3 or flat.Unit:Dot(look) > arc then
			hitAny = true
			if w.dissolve and not m.boss and m.hp < m.max * 0.3 then
				m.noLoot = true
				S.Mobs.kill(m, ps)
				State.popup(m.root.Position + Vector3.new(0, 4, 0), "РАСТВОРЁН", Color3.fromRGB(125, 255, 176))
				S.Drops.spawn(m.root.Position, "bullet", State.rint(2, 4))
				if State.rng() < 0.6 then
					S.Drops.spawn(m.root.Position, "shell", State.rint(1, 2))
				end
			else
				S.Mobs.damage(m, w.joke and 1 or dmg, { player = ps, melee = true, fire = w.fire, frost = w.frost, poison = w.poison })
				if w.knock and m.alive and not m.boss then
					m.root.AssemblyLinearVelocity = flat.Unit * w.knock + Vector3.new(0, 10, 0)
				end
			end
			bloodTick(ps, w)
		end
	end
	if S.Guardians.hitTest(root.Position, look, w.range + 2) then
		hitAny = true
	end
	if not hitAny and w.chop then
		S.WorldBuilder.chop(ps, root.Position, look, w.range + 2, w.chop)
	end
	if w.explode then
		Combat.explode(root.Position + look * 6, w.explode, w.dmg, ps)
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function ranged(ps, char: Model, root: BasePart, aim: Vector3, w)
	local head = char:FindFirstChild("Head") or root
	local origin = head.Position
	local dir = (aim - origin)
	if dir.Magnitude < 1 then
		dir = root.CFrame.LookVector
	end
	dir = dir.Unit
	local dmg = w.dmg * outMult(ps, w)
	rayParams.FilterDescendantsInstances = { char, fxFolder, workspace:FindFirstChild("Drops") }
	if w.beam then
		-- луч киборга пробивает всех на линии
		local hits = 0
		for _, m in ipairs(S.Mobs.inRadius(origin, w.beam)) do
			local rel = m.root.Position - origin
			local t = rel:Dot(dir)
			if t > 0 and t < w.beam and (rel - dir * t).Magnitude < 4 + (m.boss and 3 or 0) then
				S.Mobs.damage(m, dmg, { player = ps })
				hits += 1
			end
		end
		Combat.tracer(origin, origin + dir * w.beam, Color3.fromRGB(125, 255, 154), 0.6)
		if hits > 2 then
			State.popup(origin + Vector3.new(0, 3, 0), "×" .. hits, Color3.fromRGB(125, 255, 154))
		end
		return
	end
	local pellets = w.pellets or 1
	for _ = 1, pellets do
		local d = dir
		if pellets > 1 then
			local spread = w.spread or 0.2
			d = (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles((State.rng() - 0.5) * spread, (State.rng() - 0.5) * spread, 0)).LookVector
		end
		local range = math.min(250, (w.speed or 200) * 1.2)
		local result = workspace:Raycast(origin, d * range, rayParams)
		local hitPos = result and result.Position or origin + d * range
		local color = w.alien and Color3.fromRGB(125, 255, 154) or w.fire and Color3.fromRGB(255, 138, 61) or w.frost and Color3.fromRGB(191, 239, 255) or Color3.fromRGB(255, 224, 138)
		Combat.tracer(origin, hitPos, color)
		if result then
			local mob = S.Mobs.fromPart(result.Instance)
			if mob and not mob.ally then
				S.Mobs.damage(mob, dmg, { player = ps, fire = w.fire, frost = w.frost, poison = w.poison })
				bloodTick(ps, w)
			elseif S.Guardians.fromPart(result.Instance) then
				State.popup(hitPos + Vector3.new(0, 2, 0), "НЕУЯЗВИМ", Color3.fromRGB(166, 220, 239))
			end
		end
	end
	if w.loud then
		S.Guardians.noise(origin)
	end
end

local function onAttack(player: Player, idx, aim)
	local ps = S.PlayerService.get(player)
	if not ps or not ps.class or typeof(idx) ~= "number" or typeof(aim) ~= "Vector3" then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return
	end
	local wid = ps.inv.weapons[idx]
	if not wid then
		return
	end
	local w = weaponStats(ps, wid)
	local now = os.clock()
	if now < (ps.cd[wid] or 0) then
		return
	end
	ps.cd[wid] = now + w.cd
	-- патроны
	if w.mag then
		if ps.reloadUntil[wid] then
			return
		end
		ps.mag[wid] = ps.mag[wid] or w.mag
		if ps.mag[wid] <= 0 then
			ps.reloadUntil[wid] = now + w.reload
			return
		end
		ps.mag[wid] -= 1
		if ps.mag[wid] <= 0 then
			ps.reloadUntil[wid] = now + w.reload
			State.notify(player, "Перезарядка…")
		end
	elseif w.ammo then
		if w.ammo == "fuel" then
			ps.fuelShots = ps.fuelShots or 0
			if ps.fuelShots <= 0 then
				if not ps.inv:remove("fuel", 1) then
					State.notify(player, "Нет канистр с топливом", "warn")
					return
				end
				ps.fuelShots = 60
			end
			ps.fuelShots -= 1
		elseif not ps.inv:remove(w.ammo, 1) then
			State.notify(player, "Нет патронов: " .. require(Shared.Items)[w.ammo].name, "warn")
			return
		end
	end
	local look = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
	if w.melee then
		melee(ps, root, look, w, wid)
	else
		ranged(ps, char, root, aim, w)
	end
	S.PlayerService.sync(ps)
end

-- Бросок: бомба → бабахалка → бутылка зимнего огня → бутылка с кровью
function Combat.throw(ps, aim: Vector3)
	local char = ps.player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local kinds = { "bomb", "boomer", "fbottle", "bloodbottle" }
	local kind
	for _, k in ipairs(kinds) do
		if ps.inv:has(k) then
			kind = k
			break
		end
	end
	if not kind then
		State.notify(ps.player, "Нечего бросить", "warn")
		return
	end
	ps.inv:remove(kind, 1)
	local target = aim
	local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
	if flat.Magnitude > 40 then
		target = root.Position + flat.Unit * 40
	end
	Combat.tracer(root.Position + Vector3.new(0, 2, 0), target, Color3.fromRGB(255, 160, 60), 0.4)
	task.delay(0.5, function()
		if kind == "bomb" then
			Combat.explode(target, 12, 45, ps)
		elseif kind == "boomer" then
			Combat.explode(target, 9, 28, ps)
		elseif kind == "fbottle" then
			S.Structures.makeLava(target, 180)
		elseif kind == "bloodbottle" then
			ps.blood = math.min(Rules.BLOOD_MAX, ps.blood + 2)
			if ps.blood >= Rules.BLOOD_MAX then
				ps.blood = 0
				S.PlayerService.heal(ps, 25)
			end
			State.notify(ps.player, "Кровь пополнила заряд")
			S.PlayerService.sync(ps)
		end
	end)
end

function Combat.attachTorch(ps)
	local char = ps.player.Character
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	if not hand then
		return
	end
	local old = hand:FindFirstChild("Torch")
	if old then
		old:Destroy()
	end
	local t = Instance.new("Part")
	t.Name = "Torch"
	t.Size = Vector3.new(0.3, 2, 0.3)
	t.Color = Color3.fromRGB(107, 74, 43)
	t.CanCollide = false
	t.Massless = true
	t.CFrame = hand.CFrame * CFrame.new(0, 0.5, -0.5)
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Parent = t
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Parent = t
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = hand, t
	w.Parent = t
	t.Parent = hand
	Debris:AddItem(t, math.max(1, ps.torchUntil - os.clock()))
end

function Combat.init(services)
	S = services
	State = S.State
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "Fx"
	fxFolder.Parent = workspace
end

function Combat.start()
	Remotes.Attack.OnServerEvent:Connect(onAttack)
end

return Combat
