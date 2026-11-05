-- Правила игры: чистые функции без Roblox API (проверяются тестами в Lune).
local Rules = {}

Rules.NIGHT_START = 0.6 -- доля суток, с которой начинается ночь
Rules.DAYS_TO_WIN = 100
Rules.FROG_KEYS = 8 -- столько ключей нужно для водоворота
Rules.DIAMONDS_WIN = 5
Rules.DIAMONDS_WIN_HARD = 10

function Rules.phase(clock: number, dayLen: number): number
	return (clock % dayLen) / dayLen
end

function Rules.isNight(clock: number, dayLen: number): boolean
	return Rules.phase(clock, dayLen) >= Rules.NIGHT_START
end

-- Время суток для Lighting.ClockTime (0..24): день 6:00–18:00, ночь 18:00–6:00
function Rules.clockTime(clock: number, dayLen: number): number
	local p = Rules.phase(clock, dayLen)
	if p < Rules.NIGHT_START then
		return 6 + (p / Rules.NIGHT_START) * 12
	end
	return (18 + ((p - Rules.NIGHT_START) / (1 - Rules.NIGHT_START)) * 12) % 24
end

-- Кто нападёт этой ночью. rng() возвращает число 0..1.
function Rules.raidKind(day: number, rng): string
	if day >= 3 and rng() < 0.55 then
		return "occult"
	end
	return "vampire"
end

function Rules.raidText(kind: string): string
	if kind == "occult" then
		return "Сегодня ночью на тебя нападут оккультисты!"
	end
	return "Сегодня ночью на тебя нападут вампиры!"
end

-- Урон с учётом брони и модификаторов. mods: {mult, armorReduce, debuff, tough}
function Rules.damageTaken(dmg: number, mods): number
	local reduce = mods.armorReduce or 0
	local out = dmg * (1 - reduce) * (1 + 0.08 * (mods.debuff or 0))
	if mods.tough then
		out *= 0.7
	end
	return math.max(1, out)
end

function Rules.damageDealt(base: number, mods): number
	local m = mods.mult or 1
	if mods.gold then
		m *= 1.5
	end
	if mods.strength then
		m *= 1.25
	end
	return base * m
end

-- Уровень топора вудсмена
function Rules.woodsmanLevel(levels, trees: number)
	local best = levels[1]
	local lvl = 1
	for i, l in ipairs(levels) do
		if trees >= l.trees then
			best = l
			lvl = i
		end
	end
	return lvl, best
end

-- Новые награды вулкана при переходе счётчика туш from → to
function Rules.volcanoRewards(table_, from: number, to: number)
	local got = {}
	for _, r in ipairs(table_) do
		if from < r.at and to >= r.at then
			table.insert(got, r)
		end
	end
	return got
end

function Rules.carcassValue(carcass: number, bossCarcass: number): number
	return carcass + bossCarcass * 10
end

-- Качество сундука. rubyWisp утраивает шанс рубинового.
function Rules.chestTier(rng, rubyWisp: boolean?): string
	local r = rng()
	if r < 0.03 * (rubyWisp and 3 or 1) then
		return "ruby"
	elseif r < 0.14 then
		return "gold"
	end
	return "common"
end

-- Азарт-щит: качество сундука сдвигается на ступень вверх или вниз
local TIERS = { "common", "gold", "ruby" }
function Rules.gambleTier(tier: string, rng): string
	local idx = 1
	for i, t in ipairs(TIERS) do
		if t == tier then
			idx = i
		end
	end
	if rng() < 0.5 then
		idx += 1
	else
		idx -= 1
	end
	return TIERS[math.clamp(idx, 1, #TIERS)]
end

-- Корабль пришельцев: 6 комнат. Возвращает (обычных, прокачанных) в комнате room (1..6).
Rules.UFO_BASIC = { 15, 20, 25, 30, 35, 35 }
Rules.UFO_ELITE = { 1, 1, 2, 3, 4, 4 }
function Rules.ufoRoom(room: number, scale: number?): (number, number)
	scale = scale or 1
	local b = Rules.UFO_BASIC[room] or 0
	local e = Rules.UFO_ELITE[room] or 0
	return math.max(1, math.floor(b * scale + 0.5)), e
end

-- Карнавал: на этапах 2 и 3 нужно пожертвовать столько вампиров, сколько убито на этапе
function Rules.carnivalSacrifice(stage: number, killedThisStage: number): number
	if stage == 1 then
		return 0
	end
	return killedThisStage
end

-- Заряд крови (коса или плащ): при ударе с шансом +1 деление; полный заряд (5) лечит
Rules.BLOOD_MAX = 5
function Rules.bloodHit(charge: number, rng, chance: number?): (number, boolean)
	if rng() < (chance or 0.2) then
		charge += 1
	end
	if charge >= Rules.BLOOD_MAX then
		return 0, true
	end
	return charge, false
end

-- Выбор награды с шансами (каждая запись chance); nil, если ничего не выпало
function Rules.rollChance(list, rng)
	for _, e in ipairs(list) do
		if rng() < (e.chance or 0) then
			return e
		end
	end
	return nil
end

-- Случайная запись из списка с весами (weight по умолчанию 1)
function Rules.pickWeighted(list, rng)
	local total = 0
	for _, e in ipairs(list) do
		total += e.weight or 1
	end
	local r = rng() * total
	for _, e in ipairs(list) do
		r -= e.weight or 1
		if r <= 0 then
			return e
		end
	end
	return list[#list]
end

-- Алмазы за прохождение 100 дней
function Rules.diamondsForWin(hard: boolean): number
	return hard and Rules.DIAMONDS_WIN_HARD or Rules.DIAMONDS_WIN
end

return Rules
