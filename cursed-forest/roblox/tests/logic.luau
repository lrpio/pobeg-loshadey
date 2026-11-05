-- Тесты чистой логики (мешок и правила). Запуск: lune run tests/logic.luau
local process = require("@lune/process")
local Items = require("../src/shared/Items")
local Inventory = require("../src/shared/Inventory")
local Rules = require("../src/shared/Rules")
local Loot = require("../src/shared/Loot")
local Weapons = require("../src/shared/Weapons")

local passed, failed = 0, 0
local function check(name, cond)
	if cond then
		passed += 1
	else
		failed += 1
		print("ПРОВАЛ: " .. name)
	end
end
local function seq(values)
	local i = 0
	return function()
		i += 1
		return values[(i - 1) % #values + 1]
	end
end

-- мешок: 5 мест по 10 предметов
local inv = Inventory.new(Items, 1)
check("плохой мешок на 5 мест", inv:capacity() == 5)
local put, left = inv:add("wood", 37)
check("37 дерева: влезло всё (4 ячейки)", put == 37 and left == 0 and inv:slotsUsed() == 4)
put, left = inv:add("stone", 25)
check("камень: влезло 10 (1 ячейка), 15 не влезло", put == 10 and left == 15)
put, left = inv:add("wood", 5)
check("дерево добивает 4-ю ячейку до 40", put == 3 and left == 2 and inv:count("wood") == 40)
check("лёгкие предметы не занимают место", (inv:add("paw", 50)) == 50 and inv:slotsUsed() == 5)
check("оплата", inv:pay({ wood = 10, stone = 5 }) and inv:count("wood") == 30 and inv:count("stone") == 5)
check("нельзя оплатить без ресурсов", not inv:pay({ ore = 1 }))
check("мешок улучшается, но не ухудшается", inv:setBag(2) and inv:capacity() == 15 and not inv:setBag(1))
check("оружие без дублей", inv:addWeapon("rifle", Weapons.ORDER) and not inv:addWeapon("rifle", Weapons.ORDER))
inv:addWeapon("axe1", Weapons.ORDER)
check("оружие сортируется по порядку", inv.weapons[1] == "axe1" and inv.weapons[2] == "rifle")
local Armor = { none = { reduce = 0 }, brown = { reduce = 0.05 }, iron = { reduce = 0.4 } }
check("броня надевается, если лучше", inv:equipArmor("iron", Armor) and not inv:equipArmor("brown", Armor) and inv.armor == "iron")
check("снимок для клиента", inv:snapshot().capacity == 15)

-- сутки
check("утро не ночь", not Rules.isNight(10, 180))
check("ночь с 60% суток", Rules.isNight(110, 180))
check("часы: начало дня 6:00", math.abs(Rules.clockTime(0, 180) - 6) < 0.01)
check("часы: закат 18:00", math.abs(Rules.clockTime(108, 180) - 18) < 0.01)
check("часы: конец ночи около 6:00", math.abs(Rules.clockTime(179.99, 180) - 6) < 0.05)

-- налёты
check("до 3-го дня только вампиры", Rules.raidKind(2, seq({ 0 })) == "vampire")
check("с 3-го дня бывают оккультисты", Rules.raidKind(5, seq({ 0.1 })) == "occult")
check("текст налёта оккультистов", Rules.raidText("occult"):find("оккультисты") ~= nil)

-- урон
check("броня 40% режет урон", math.abs(Rules.damageTaken(100, { armorReduce = 0.4 }) - 60) < 0.001)
check("минимум 1 урона", Rules.damageTaken(0.1, { armorReduce = 0.9 }) == 1)
check("разломы усиливают урон", math.abs(Rules.damageTaken(100, { debuff = 2 }) - 116) < 0.001)
check("золото +50%", Rules.damageDealt(10, { gold = true }) == 15)

-- вудсмен
local lvl = Rules.woodsmanLevel(Weapons.WOODSMAN_LEVELS, 90)
check("90 деревьев = 3 уровень", lvl == 3)
check("0 деревьев = 1 уровень", (Rules.woodsmanLevel(Weapons.WOODSMAN_LEVELS, 0)) == 1)

-- вулкан
local got = Rules.volcanoRewards(Loot.VOLCANO, 8, 30)
check("8→30 туш: две награды", #got == 2 and got[1].at == 10 and got[2].at == 25)
check("туша босса = 10", Rules.carcassValue(3, 2) == 23)
check("повтор порога не даёт награду", #Rules.volcanoRewards(Loot.VOLCANO, 30, 40) == 0)

-- сундуки
check("рубиновый при низком броске", Rules.chestTier(seq({ 0.01 })) == "ruby")
check("рубиновый огонёк утраивает шанс", Rules.chestTier(seq({ 0.08 }), true) == "ruby" and Rules.chestTier(seq({ 0.08 }), false) == "gold")
check("азарт: вверх", Rules.gambleTier("common", seq({ 0.1 })) == "gold")
check("азарт: не ниже обычного", Rules.gambleTier("common", seq({ 0.9 })) == "common")

-- корабль
local b1, e1 = Rules.ufoRoom(1)
local b6, e6 = Rules.ufoRoom(6)
check("комната 1: 15 и 1 прокачанный", b1 == 15 and e1 == 1)
check("комната 6: 35 и 4 прокачанных", b6 == 35 and e6 == 4)

-- карнавал, кровь, лягушки
check("этап 1 карнавала без жертвы", Rules.carnivalSacrifice(1, 9) == 0)
check("этап 2: жертва = убитые", Rules.carnivalSacrifice(2, 9) == 9)
local charge, healed = Rules.bloodHit(4, seq({ 0.1 }))
check("полный заряд крови лечит и обнуляется", charge == 0 and healed)
check("ключей для водоворота 8", Rules.FROG_KEYS == 8)
local frog = Rules.rollChance(Loot.FROG_BOSS, seq({ 0.5, 0.5, 0.5, 0.02 }))
check("ядовитое копьё 3%", frog ~= nil and frog[2] == "poisonSpear")
check("награды лягушачьего босса редкие", Rules.rollChance(Loot.FROG_BOSS, seq({ 0.5 })) == nil)
check("алмазы за победу 5 / хард 10", Rules.diamondsForWin(false) == 5 and Rules.diamondsForWin(true) == 10)

print(("Тесты: прошло %d, провалено %d"):format(passed, failed))
if failed > 0 then
	process.exit(1)
end
