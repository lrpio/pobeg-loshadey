-- Броня: reduce — доля поглощаемого урона.
local Armor = {
	none = { name = "Без брони", reduce = 0 },
	brown = { name = "Коричневая броня", reduce = 0.05 },
	jungle = { name = "Броня джунглей", reduce = 0.08, thorns = true, poisonAura = true },
	leather = { name = "Кожаная броня", reduce = 0.15 },
	fur = { name = "Меховая броня", reduce = 0.25, coldOutside = true },
	winter = { name = "Зимняя броня", reduce = 0.3, coldOutside = true, coldCastle = true },
	iron = { name = "Железная броня", reduce = 0.4, heavy = true },
	vampire = { name = "Вампирская броня", reduce = 0.4, blood = true },
	vcape = { name = "Плащ вампира", reduce = 0.4, blood = true },
	cyborg = { name = "Броня киборга", reduce = 0.55 },
	best = { name = "Лучшая броня", reduce = 0.6, aura = 6 },
	meteor = { name = "Метеоритная броня", reduce = 0.6 },
}

-- Предметы-надеваемые без защиты
Armor.EXTRA = {
	jhat = { name = "Шапка джунглей", poisonResist = 0.6 },
	frogBoots = { name = "Лягушачьи сапоги", jump = 1.6 },
}

return Armor
