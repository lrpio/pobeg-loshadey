-- Биомы, зоны карты, хозяева биомов и структуры. Координаты в студах (X, Z), центр лагеря в (0, 0).
local World = {}

World.SIZE = 2400 -- карта 2400×2400 студов

-- Биом игры выбирается случайно; стенд пропавших детей в лагере сообщает его игроку.
World.BIOMES = {
	{ id = "winter", name = "Зимний лес", hunter = "leopard", hunterName = "Снежный барс",
		hint = "Снежный барс идёт по следу, в снегу его не видно. Спугни его шумом: выстрелом или дудочкой." },
	{ id = "jungle", name = "Джунгли", hunter = "panther", hunterName = "Пантера",
		hint = "Пантера подкрадывается со спины, видны только глаза. Повернись к ней лицом, и она отступит." },
	{ id = "savanna", name = "Саванна", hunter = "lion", hunterName = "Лев",
		hint = "Днём тебя ищет Лев. Услышишь рык — прыгай в кусты, иначе он бросится." },
	{ id = "crimson", name = "Алый лес", hunter = "deer", hunterName = "Олень-Хранитель",
		hint = "Другого хищника нет, но Олень выходит чаще и злее. Держи фонарик наготове." },
}

-- Зоны карты: центр, радиус, цвет земли (для Terrain), материал.
World.ZONES = {
	{ id = "camp", name = "Лагерь выживших", x = 0, z = 0, r = 110, material = "Ground" },
	{ id = "forest", name = "Тихий лес", x = 0, z = 0, r = 1200, material = "Grass" },
	{ id = "lava", name = "Лавовый биом", x = -650, z = -750, r = 330, material = "Basalt" },
	{ id = "winter", name = "Зимние горы", x = 650, z = -800, r = 360, material = "Snow" },
	{ id = "cave", name = "Пещеры", x = 0, z = -950, r = 220, material = "Slate" },
	{ id = "jungle", name = "Джунгли", x = 800, z = 650, r = 340, material = "LeafyGrass" },
	{ id = "crimson", name = "Алые земли", x = -800, z = 600, r = 320, material = "Mud" },
	{ id = "lake", name = "Озеро", x = 450, z = 100, r = 160, material = "Sand" },
	{ id = "meadow", name = "Золотая поляна", x = 0, z = 750, r = 250, material = "Grass" },
	{ id = "thicket", name = "Мёртвая чаща", x = -600, z = 0, r = 230, material = "Ground" },
}

-- Структуры (место, зона). Сервер строит их из деталей и вешает ProximityPrompt.
World.STRUCTURES = {
	board = { name = "Стенд пропавших детей", x = 0, z = -40 },
	totem = { name = "Тотем Скорняка", x = 45, z = -10 },
	volcano = { name = "Вулкан", x = -650, z = -800, zone = "lava" },
	smelter = { name = "Плавильня", x = -560, z = -650, zone = "lava" },
	occCastle = { name = "Замок оккультистов", x = -780, z = -620, zone = "lava", floors = 3 },
	ritualHall = { name = "Зал культа", x = -500, z = -760, zone = "lava" },
	church = { name = "Церковь", x = -800, z = 470, zone = "crimson" },
	crypt = { name = "Склеп вампиров", x = -900, z = 700, zone = "crimson" },
	carnival = { name = "Карнавал", x = -650, z = 760, zone = "crimson" },
	winterCastle = { name = "Зимний замок", x = 700, z = -850, zone = "winter" },
	elf = { name = "Эльф", x = 540, z = -700, zone = "winter" },
	caveEntrance = { name = "Пещера", x = 0, z = -900, zone = "cave" },
	jungleTemple1 = { name = "Малый храм", x = 680, z = 540, zone = "jungle" },
	jungleTemple2 = { name = "Малый храм", x = 940, z = 560, zone = "jungle" },
	jungleTemple3 = { name = "Малый храм", x = 680, z = 790, zone = "jungle" },
	jungleTemple4 = { name = "Малый храм", x = 950, z = 780, zone = "jungle" },
	jungleMain = { name = "Главный храм", x = 810, z = 660, zone = "jungle" },
	whirlpool = { name = "Водоворот", x = 450, z = 100, zone = "lake" },
}

-- Хозяева биомов (их нельзя убить)
World.GUARDIANS = {
	deer = { name = "Олень", speed = 14, dmg = 45, nightOnly = true },
	leopard = { name = "Снежный барс", speed = 26, dmg = 32, scaredByNoise = true },
	lion = { name = "Лев", speed = 18, charge = 55, dmg = 50, dayOnly = true, hideInBush = true },
	panther = { name = "Пантера", speed = 18, dmg = 38, fearsGaze = true },
}

function World.zoneAt(x: number, z: number): string
	for _, zone in ipairs(World.ZONES) do
		if zone.id ~= "forest" then
			local dx, dz = x - zone.x, z - zone.z
			if dx * dx + dz * dz < zone.r * zone.r then
				return zone.id
			end
		end
	end
	return "forest"
end

return World
