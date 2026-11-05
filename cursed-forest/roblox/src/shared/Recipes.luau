-- Крафт у верстака и улучшения костра
local Recipes = {}

Recipes.CRAFT = {
	{ id = "torch", name = "Факел", cost = { wood = 1, cloth = 1 }, give = { item = "torch", n = 1 } },
	{ id = "crossbow", name = "Арбалет + 10 болтов", cost = { wood = 3, rope = 2 }, give = { weapon = "crossbow", item = "arrow", n = 10 } },
	{ id = "arrow", name = "Болты ×5", cost = { wood = 1, stone = 1 }, give = { item = "arrow", n = 5 } },
	{ id = "bullet", name = "Патроны ×6", cost = { ore = 1, coal = 1 }, give = { item = "bullet", n = 6 } },
	{ id = "fuel", name = "Канистра", cost = { coal = 2, ore = 1 }, give = { item = "fuel", n = 1 } },
	{ id = "bomb", name = "Огненная бомба", cost = { coal = 1, cloth = 1, ore = 1 }, give = { item = "bomb", n = 1 } },
	{ id = "bandage", name = "Бинт", cost = { cloth = 2 }, give = { item = "bandage", n = 1 } },
	{ id = "leather", name = "Кожаная броня", cost = { rskin = 3, rope = 2 }, give = { armor = "leather" } },
	{ id = "fur", name = "Меховая броня", cost = { wpelt = 2, cloth = 1 }, give = { armor = "fur" } },
	{ id = "winter", name = "Зимняя броня", cost = { wpelt = 3, cloth = 3 }, give = { armor = "winter" } },
	{ id = "soup", name = "Суп", cost = { meat = 2, berry = 1, fish = 1 }, give = { item = "soup", n = 1 } },
}

Recipes.FIRE = {
	{ level = 2, cost = { wood = 20 }, radius = 70 },
	{ level = 3, cost = { wood = 20, coal = 10 }, radius = 85 },
	{ level = 4, cost = { coal = 15, ore = 10 }, radius = 100 },
	{ level = 5, cost = { shard = 6 }, radius = 120, great = true },
}
Recipes.FIRE_BASE_RADIUS = 55

-- Тотем: одна шкура — один предмет
Recipes.TOTEM = {
	{ pelt = "wpelt", name = "Копьё", give = { weapon = "spear" } },
	{ pelt = "wpelt", name = "Револьвер + 12 патронов", give = { weapon = "revolver", item = "bullet", n = 12 } },
	{ pelt = "wpelt", name = "Удочка", give = { flag = "rod" } },
	{ pelt = "wpelt", name = "Дудочка", give = { flag = "flute" } },
	{ pelt = "apelt", name = "Гигантский мешок", give = { bag = 4 } },
	{ pelt = "apelt", name = "Сильный фонарик", give = { flashlight = 2 } },
	{ pelt = "apelt", name = "Винтовка + 6 патронов", give = { weapon = "rifle", item = "bullet", n = 6 } },
	{ pelt = "bpelt", name = "Отличный топор", give = { weapon = "axe3" } },
	{ pelt = "bpelt", name = "Железная броня", give = { armor = "iron" } },
}

-- Тайный торговец: за лапки кролика
Recipes.TRADER = {
	{ name = "Хороший топор", price = 5, give = { weapon = "axe2" } },
	{ name = "Хороший мешок (15 мест)", price = 5, give = { bag = 2 } },
	{ name = "Гигантский мешок (30 мест)", price = 14, give = { bag = 4 } },
	{ name = "Старый фонарик", price = 3, give = { flashlight = 1 } },
	{ name = "Батарейка", price = 1, give = { item = "battery", n = 1 } },
}

return Recipes
