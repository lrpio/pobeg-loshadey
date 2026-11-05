-- Мобы. hp/dmg/speed в единицах Roblox (скорость в студах/с). weapon — что держит в руках (с моба не падает).
-- biome: где водится. ranged: стреляет. drops: таблица {item, шанс, мин, макс}.
local Mobs = {
	-- звери
	rabbit = { name = "Кролик", hp = 10, dmg = 0, speed = 18, passive = true, size = 1.2,
		drops = { { "meat", 1, 1, 1 }, { "rskin", 1, 1, 1 }, { "paw", 0.6, 1, 1 } } },
	wolf = { name = "Волк", hp = 40, dmg = 8, speed = 19, aggro = 40, size = 2,
		drops = { { "wpelt", 1, 1, 1 }, { "meat", 1, 1, 1 } } },
	alpha = { name = "Альфа-волк", hp = 140, dmg = 15, speed = 21, aggro = 50, size = 2.8,
		drops = { { "apelt", 1, 1, 1 }, { "meat", 1, 2, 2 } } },
	bear = { name = "Медведь", hp = 220, dmg = 24, speed = 15, aggro = 35, size = 3.5,
		drops = { { "bpelt", 1, 1, 1 }, { "meat", 1, 3, 3 }, { "bones", 1, 2, 2 }, { "honey", 0.5, 1, 1 } } },
	boar = { name = "Кабан", hp = 70, dmg = 12, speed = 19, aggro = 35, size = 2.2,
		drops = { { "meat", 1, 2, 2 }, { "bones", 0.3, 1, 1 } } },

	-- лягушки
	frog = { name = "Лягушка", hp = 28, dmg = 6, speed = 15, aggro = 30, size = 1.2, color = Color3.fromRGB(79, 170, 74) },
	frogGreen = { name = "Зелёная лягушка", hp = 50, dmg = 9, speed = 16, aggro = 50, size = 1.5, color = Color3.fromRGB(60, 200, 80) },
	frogBlue = { name = "Синяя лягушка", hp = 80, dmg = 12, speed = 16, aggro = 50, size = 1.7, color = Color3.fromRGB(60, 110, 230),
		drops = { { "frogkey", 0.25, 1, 1 } } },
	frogPurple = { name = "Фиолетовая лягушка", hp = 140, dmg = 16, speed = 17, aggro = 60, size = 2, color = Color3.fromRGB(150, 70, 210) },

	-- оккультисты (все виды из записей)
	occ = { name = "Оккультист", weapon = "Старый топор", hp = 45, dmg = 9, speed = 15, aggro = 40, biome = "any", occult = true },
	occArcher = { name = "Оккультист-лучник", weapon = "Арбалет", hp = 36, dmg = 8, speed = 14, aggro = 50, ranged = "bolt", rate = 2.1, biome = "any", occult = true },
	occBrute = { name = "Антоккультист", weapon = "Булава", hp = 120, dmg = 22, speed = 13, aggro = 40, biome = "any", occult = true, elite = true },
	occLava = { name = "Лавовый оккультист", weapon = "Старый топор", hp = 60, dmg = 12, speed = 15, aggro = 40, biome = "lava", occult = true },
	occLavaArcher = { name = "Лавовый лучник", weapon = "Огненный арбалет", hp = 50, dmg = 12, speed = 14, aggro = 55, ranged = "firebolt", rate = 2.2, biome = "lava", occult = true },
	occWinterSword = { name = "Зимний оккультист с мечом", weapon = "Меч", hp = 90, dmg = 10, speed = 15, aggro = 40, biome = "winter", occult = true },
	occWinterArcher = { name = "Зимний лучник", weapon = "Арбалет", hp = 70, dmg = 11, speed = 14, aggro = 55, ranged = "bolt", rate = 2, biome = "winter", occult = true },
	occWinterBomb = { name = "Зимний бомбист", weapon = "Бомбы", hp = 70, dmg = 18, speed = 13, aggro = 45, ranged = "bomb", rate = 3.5, biome = "winter", occult = true },
	occCave = { name = "Пещерный оккультист", weapon = "Пещерный кинжал", hp = 85, dmg = 14, speed = 16, aggro = 40, biome = "cave", occult = true },
	occCaveElite = { name = "Прокачанный пещерный оккультист", weapon = "Топор вудсмена", hp = 220, dmg = 22, speed = 15, aggro = 45, biome = "cave", occult = true, elite = true },
	occJungle = { name = "Джунглевый оккультист", weapon = "Копьё", hp = 60, dmg = 12, speed = 16, aggro = 40, biome = "jungle", occult = true },
	occJungleArcher = { name = "Джунглевый лучник", weapon = "Духовая трубка", hp = 45, dmg = 7, speed = 17, aggro = 55, ranged = "dart", rate = 1.4, poison = true, biome = "jungle", occult = true, shirtless = true },
	occJungleElite = { name = "Джунглевый воин", weapon = "Ядовитое копьё", hp = 160, dmg = 20, speed = 15, aggro = 45, poison = true, biome = "jungle", occult = true, elite = true },

	-- вампиры
	vampire = { name = "Вампир", hp = 55, dmg = 10, speed = 17, aggro = 90, night = true, vampire = true,
		drops = { { "bloodbottle", 0.3, 1, 1 }, { "paw", 0.3, 1, 1 }, { "cloth", 0.4, 1, 1 } } },

	-- пришельцы
	alien = { name = "Пришелец", weapon = "Райган", hp = 65, dmg = 11, speed = 15, aggro = 50, ranged = "laser", rate = 1.6, alien = true,
		drops = { { "battery", 0.5, 1, 1 } } },
	alienElite = { name = "Пришелец в броне киборга", weapon = "Лазерный меч", hp = 170, dmg = 20, speed = 16, aggro = 50, alien = true, elite = true,
		drops = { { "battery", 1, 2, 2 }, { "coin", 0.35, 2, 2 } } },
}

-- Общие трофеи с любого оккультиста (их оружие не выпадает)
Mobs.OCCULT_DROPS = { { "carcass", 1, 1, 1 }, { "cloth", 0.5, 1, 1 }, { "coin", 0.28, 1, 1 }, { "amulet", 0.07, 1, 1 }, { "battery", 0.12, 1, 1 } }

-- Мини-боссы и боссы
Mobs.BOSSES = {
	bat = { name = "Гигантская летучая мышь", hp = 420, dmg = 18, where = "cave",
		drops = { { "meat", 1, 2, 3 }, { "coin", 1, 5, 8 }, { "dynamite", 0.6, 1, 2 }, { "boomer", 1, 2, 4 } } },
	spider = { name = "Паук", hp = 650, dmg = 16, where = "thicket" },
	occKing = { name = "Король оккультистов", hp = 950, dmg = 18, where = "ritualHall", summon = "4 амулета", occult = true },
	caveKing = { name = "Король пещерных оккультистов", hp = 1150, dmg = 22, where = "cave", occult = true,
		drops = { { "meat", 1, 3, 4 }, { "coin", 1, 10, 14 }, { "dynamite", 1, 2, 3 }, { "boomer", 1, 4, 6 } }, weapon = "cdag" },
	alienKing = { name = "Король инопланетян", hp = 1500, dmg = 15, where = "ufo", alien = true },
	vampKing = { name = "Король вампиров", hp = 2400, dmg = 25, where = "crypt", weapon = "scythe", vampire = true },
	frogBoss = { name = "Борщис", hp = 900, dmg = 20, where = "whirlpool" },
}

return Mobs
