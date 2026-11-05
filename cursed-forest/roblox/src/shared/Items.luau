-- Предметы. free=true: не занимает место в мешке (лёгкие/особые вещи).
local Items = {
	-- ресурсы (занимают место в мешке)
	wood = { name = "Дерево", icon = "🪵" },
	stone = { name = "Камень", icon = "🪨" },
	ore = { name = "Руда", icon = "⛓️" },
	coal = { name = "Уголь", icon = "⚫" },
	metal = { name = "Металл", icon = "🔩" },
	rope = { name = "Верёвка", icon = "🧵" },
	cloth = { name = "Ткань", icon = "🧶" },
	bones = { name = "Кости", icon = "🦴" },
	rskin = { name = "Шкура кролика", icon = "🐇" },
	wpelt = { name = "Шкура волка", icon = "🐺" },
	apelt = { name = "Шкура альфа-волка", icon = "👑" },
	bpelt = { name = "Шкура медведя", icon = "🐻" },
	carcass = { name = "Туша", icon = "⚰️" },
	bcarcass = { name = "Туша босса", icon = "💀" },
	-- еда
	berry = { name = "Ягоды", icon = "🫐", food = 8 },
	apple = { name = "Яблоко", icon = "🍎", food = 12 },
	meat = { name = "Сырое мясо", icon = "🥩", food = 10, raw = true },
	fish = { name = "Сырая рыба", icon = "🐟", food = 8, raw = true },
	cmeat = { name = "Жареное мясо", icon = "🍖", food = 25 },
	cfish = { name = "Жареная рыба", icon = "🍤", food = 22 },
	honey = { name = "Мёд", icon = "🍯", food = 15 },
	soup = { name = "Суп", icon = "🍲", food = 50, heal = 20 },
	feast = { name = "Пир", icon = "🍱", food = 80, heal = 50 },
	gfish = { name = "Золотая рыба", icon = "🐠", food = 60, heal = 999 },
	-- лёгкие и особые
	paw = { name = "Лапка кролика", icon = "🐾", free = true },
	battery = { name = "Батарейка", icon = "🔋", free = true },
	bullet = { name = "Патроны", icon = "🟡", free = true },
	shell = { name = "Патроны дробовика", icon = "🟥", free = true },
	arrow = { name = "Болты", icon = "➶", free = true },
	kunai = { name = "Кунаи", icon = "🗡️", free = true },
	fuel = { name = "Канистра", icon = "🛢️", free = true },
	bomb = { name = "Огненная бомба", icon = "💣", free = true },
	boomer = { name = "Бабахалка", icon = "🧨", free = true },
	dynamite = { name = "Динамит", icon = "🧨", free = true },
	bandage = { name = "Бинт", icon = "🩹", free = true },
	torch = { name = "Факел", icon = "🔥", free = true },
	spice = { name = "Приправы", icon = "🧂", free = true },
	spike = { name = "Острые шипы", icon = "📍", free = true },
	bloodbottle = { name = "Бутылка с кровью", icon = "🩸", free = true },
	fbottle = { name = "Бутылка зимнего огня", icon = "🧪", free = true },
	amulet = { name = "Амулет оккультиста", icon = "🔮", free = true },
	coin = { name = "Монета оккультистов", icon = "🪙", free = true },
	skull = { name = "Череп", icon = "☠️", free = true },
	jfrag = { name = "Зелёный фрагмент", icon = "🟢", free = true },
	gem = { name = "Зимний камень", icon = "💠", free = true },
	mshard = { name = "Осколок метеорита", icon = "☄️", free = true },
	ticket = { name = "Билетик карнавала", icon = "🎟️", free = true },
	frogkey = { name = "Лягушачий ключ", icon = "🗝️", free = true },
	seed = { name = "Семена цветов", icon = "🌱", free = true },
	flower = { name = "Цветок", icon = "🌸", free = true },
	shard = { name = "Осколок печати", icon = "💎", free = true },
}

Items.STACK = 10 -- предметов в одной ячейке мешка

-- Мешки: 1 плохой (5 мест), 2 хороший (15, торговец), 3 адский (находка в адском биоме), 4 гигантский (покупка или находка)
Items.BAGS = {
	{ name = "Плохой мешок", slots = 5 },
	{ name = "Хороший мешок", slots = 15 },
	{ name = "Адский мешок", slots = 20 },
	{ name = "Гигантский мешок", slots = 30 },
}

return Items
