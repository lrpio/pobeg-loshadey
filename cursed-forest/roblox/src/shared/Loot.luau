-- Таблицы добычи. Формат записи: { kind = "item"|"weapon"|"armor"|"extra", id, min, max, weight } или шанс (chance) для особых наград.
local Loot = {}

-- Обычные сундуки по зонам
Loot.CHEST = {
	forest = { { "item", "cloth", 1, 2 }, { "item", "rope", 1, 2 }, { "item", "berry", 2, 3 }, { "item", "battery", 1, 1 }, { "item", "paw", 1, 2 }, { "item", "bandage", 1, 1 } },
	lava = { { "item", "coal", 2, 3 }, { "item", "fuel", 1, 1 }, { "item", "coin", 2, 4 }, { "item", "amulet", 1, 1 } },
	winter = { { "item", "coal", 2, 3 }, { "item", "ore", 2, 3 }, { "item", "gem", 1, 1 } },
	cave = { { "item", "ore", 2, 4 }, { "item", "dynamite", 1, 1 }, { "item", "boomer", 2, 3 }, { "item", "coin", 2, 4 }, { "weapon", "cdag", 1, 1, weight = 0.15 } },
	jungle = { { "item", "berry", 3, 4 }, { "item", "rope", 2, 3 }, { "item", "paw", 1, 2 } },
	crimson = { { "item", "bandage", 1, 2 }, { "item", "bloodbottle", 1, 2 }, { "item", "paw", 1, 2 } },
}

-- Сундук по качеству. Худший сундук иногда даёт тактический дробовик (6 патронов).
Loot.TIER_EXTRA = {
	common = { { "weapon", "shotgun", chance = 0.04, plus = { shell = 6 } } },
	gold = { { "armor", "iron" }, { "weapon", "mace" }, { "item", "battery", 3, 3 }, { "item", "bandage", 3, 3 } },
	-- Рубиновый (лучший): лучшая броня, тактический дробовик, кунаи и «шуточный» полицейский щит
	ruby = { { "armor", "best" }, { "weapon", "shotgun", plus = { shell = 8 } }, { "weapon", "kunai", plus = { kunai = 40 } }, { "weapon", "policeShield" } },
	-- Заражённый (хард-мод)
	infected = { { "weapon", "axeRed" }, { "weapon", "cshotgun", plus = { shell = 8 } } },
}

-- Сундук джунглей (главный храм): открывается столько раз, сколько малых храмов на карте
Loot.JUNGLE_CHEST = { { "weapon", "jclaws" }, { "extra", "jhat" }, { "armor", "jungle" } }

-- Сундук во льду (зимний замок): всё оружие с обморожением на 3 с
Loot.ICE_CHEST = { { "weapon", "icross", plus = { arrow = 15 } }, { "weapon", "isword" }, { "weapon", "shuriken" }, { "weapon", "ihammer" } }

-- Награда за лягушачьего босса. Шансы: по 1%, ядовитое копьё 3%.
Loot.FROG_BOSS = {
	{ "armor", "jungle", chance = 0.01 },
	{ "weapon", "jblowgun", chance = 0.01 },
	{ "extra", "frogBoots", chance = 0.01 },
	{ "weapon", "poisonSpear", chance = 0.03 },
}

-- Сундук после короля инопланетян
Loot.UFO_CHEST = { { "weapon", "lcannon" }, { "armor", "cyborg" }, { "weapon", "lsword" }, { "weapon", "raygun" } }

-- Вулкан: туши → награды по порогам. Туша босса считается за 10.
Loot.VOLCANO = {
	{ at = 10, reward = { "item", "amulet", 1, 1 }, name = "Амулет оккультиста" },
	{ at = 25, reward = { "weapon", "fsword" }, name = "Огненный меч" },
	{ at = 45, reward = { "weapon", "fcross" }, name = "Огненный арбалет" },
	{ at = 70, reward = { "bag", 3 }, name = "Адский мешок" },
}
-- Малый шанс, что из вулкана вылетит что-то инопланетное (чаще всего райган)
Loot.VOLCANO_ALIEN = { chance = 0.04, pool = { "raygun", "raygun", "raygun", "lsword", "plasma" } }

-- Плавильня: 1 канистра → случайные патроны
Loot.SMELTER = { { "bullet", 6 }, { "bullet", 6 }, { "shell", 3 } }

-- Замок оккультистов, награда после 3-го этажа
Loot.OCC_CASTLE = { items = { metal = 5, amulet = 3, jfrag = 1 }, diamonds = 5 }

-- Карнавал: 3 этапа. Этап 1 — коса 100%. Этапы 2 и 3 требуют пожертвовать столько вампиров, сколько убито на этапе.
Loot.CARNIVAL = { { "weapon", "scythe" }, { "weapon", "vknives" }, { "armor", "vampire" } }

-- Главный храм после установки 4 черепов
Loot.JUNGLE_MAIN = { amulet = 3, jfrag = 3 }

return Loot
