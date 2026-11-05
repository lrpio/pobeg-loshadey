-- Оружие. melee: ближний бой (range — дальность удара в студах).
-- ammo: какой предмет тратит выстрел. mag/reload: магазин с бесконечными патронами (пришельское оружие, духовая трубка).
-- fire/frost/poison: статус при попадании. Значения урона общие для сервера.
local Weapons = {
	-- топоры
	axe1 = { name = "Старый топор", melee = true, dmg = 12, range = 7, cd = 0.5, chop = 1 },
	axeWood = { name = "Топор вудсмена", melee = true, dmg = 14, range = 7, cd = 0.48, chop = 1.2, levels = true },
	axe2 = { name = "Хороший топор", melee = true, dmg = 18, range = 7, cd = 0.46, chop = 2 },
	axe3 = { name = "Отличный топор", melee = true, dmg = 28, range = 7.5, cd = 0.44, chop = 3 },
	axeRed = { name = "Красный топор", melee = true, dmg = 46, range = 8, cd = 0.4, chop = 4.5 },
	-- ближний бой
	spear = { name = "Копьё", melee = true, dmg = 22, range = 10, cd = 0.55 },
	poisonSpear = { name = "Ядовитое копьё", melee = true, dmg = 30, range = 10, cd = 0.5, poison = true },
	mace = { name = "Булава", melee = true, dmg = 42, range = 7, cd = 0.85, knock = 40 },
	hammer = { name = "Молот", melee = true, dmg = 52, range = 7.5, cd = 0.9, knock = 45, fire = true },
	katana = { name = "Катана", melee = true, dmg = 36, range = 8.5, cd = 0.28, unique = true },
	scythe = { name = "Вампирская коса", melee = true, dmg = 30, range = 9, cd = 0.5, blood = true },
	vhoe = { name = "Вампирская мотыга", melee = true, dmg = 26, range = 8.5, cd = 0.5, blood = true },
	jclaws = { name = "Когти джунглей", melee = true, dmg = 30, range = 6, cd = 0.32, poison = true },
	cdag = { name = "Пещерный кинжал", melee = true, dmg = 20, range = 5.5, cd = 0.14 },
	fsword = { name = "Огненный меч", melee = true, dmg = 38, range = 7.5, cd = 0.45, fire = true },
	isword = { name = "Ледяной меч", melee = true, dmg = 34, range = 7.5, cd = 0.42, frost = true },
	ihammer = { name = "Ледяной молот", melee = true, dmg = 56, range = 8, cd = 0.9, frost = true, knock = 45 },
	lsword = { name = "Лазерный меч", melee = true, dmg = 40, range = 8, cd = 0.35 },
	dissolver = { name = "Растворитель", melee = true, dmg = 6, range = 6.5, cd = 0.4, dissolve = true },
	policeShield = { name = "Полицейский щит", melee = true, dmg = 1, range = 4, cd = 1, joke = true },
	flamer = { name = "Огнемёт", melee = true, dmg = 7, range = 16, cd = 0.09, ammo = "fuel", fire = true, cone = true },
	dynamiteHand = { name = "Динамит", melee = true, dmg = 70, range = 6, cd = 1, ammo = "dynamite", explode = 14 },
	-- дальний бой
	crossbow = { name = "Арбалет", dmg = 18, cd = 0.7, ammo = "arrow", speed = 140 },
	fcross = { name = "Огненный арбалет", dmg = 26, cd = 0.75, ammo = "arrow", speed = 150, fire = true },
	lcross = { name = "Лавовый арбалет", dmg = 38, cd = 0.7, ammo = "arrow", speed = 160, fire = true },
	icross = { name = "Ледяной арбалет", dmg = 30, cd = 0.7, ammo = "arrow", speed = 150, frost = true },
	blowgun = { name = "Духовая трубка", dmg = 6, cd = 0.35, mag = 3, reload = 1.6, speed = 140, poison = true },
	jblowgun = { name = "Духовая трубка джунглей", dmg = 12, cd = 0.3, mag = 4, reload = 1.4, speed = 150, poison = true },
	revolver = { name = "Револьвер", dmg = 32, cd = 0.42, ammo = "bullet", speed = 300, loud = true },
	rifle = { name = "Винтовка", dmg = 72, cd = 1.05, ammo = "bullet", speed = 400, loud = true },
	shotgun = { name = "Тактический дробовик", dmg = 14, cd = 0.8, ammo = "shell", pellets = 6, spread = 0.3, speed = 260, loud = true },
	cshotgun = { name = "Проклятый дробовик", dmg = 19, cd = 0.55, ammo = "shell", pellets = 7, spread = 0.3, speed = 280, loud = true },
	kunai = { name = "Кунаи", dmg = 17, cd = 0.22, ammo = "kunai", speed = 220 },
	vknives = { name = "Вампирские ножи", dmg = 20, cd = 0.25, mag = 6, reload = 2, speed = 220, blood = true },
	shuriken = { name = "Ледяные сюрикены", dmg = 16, cd = 0.25, mag = 8, reload = 2, speed = 220, frost = true },
	wand = { name = "Жезл некроманта", dmg = 9, cd = 0.55, speed = 120 },
	-- пришельцы: бесконечные патроны, долгая перезарядка
	raygun = { name = "Райган", dmg = 19, cd = 0.3, mag = 8, reload = 3, speed = 320, alien = true },
	lcannon = { name = "Лазерная пушка киборга", dmg = 10, cd = 0.9, mag = 4, reload = 3.6, beam = 90, alien = true },
	plasma = { name = "Плазменный дробовик", dmg = 17, cd = 0.7, mag = 3, reload = 3.6, pellets = 5, spread = 0.3, speed = 220, alien = true },
}

-- Порядок в хотбаре
Weapons.ORDER = {
	"axe1", "axeWood", "axe2", "axe3", "axeRed", "spear", "poisonSpear", "mace", "hammer", "katana", "scythe", "vhoe",
	"jclaws", "cdag", "fsword", "isword", "ihammer", "lsword", "dissolver", "policeShield", "flamer", "dynamiteHand",
	"crossbow", "fcross", "lcross", "icross", "blowgun", "jblowgun", "revolver", "rifle", "shotgun", "cshotgun",
	"kunai", "vknives", "shuriken", "wand", "raygun", "lcannon", "plasma",
}

-- Уровни топора вудсмена по числу срубленных деревьев
Weapons.WOODSMAN_LEVELS = {
	{ trees = 0, dmg = 14, chop = 1.2 },
	{ trees = 25, dmg = 20, chop = 1.8 },
	{ trees = 80, dmg = 28, chop = 2.6 },
	{ trees = 180, dmg = 38, chop = 3.5 },
}

return Weapons
