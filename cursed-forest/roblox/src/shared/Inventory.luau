-- Мешок игрока: ячейки по STACK предметов. Лёгкие предметы (free) места не занимают.
-- Модуль без зависимостей от Roblox, чтобы его можно было тестировать в Lune.
local Inventory = {}
Inventory.__index = Inventory

function Inventory.new(itemsDef, bagTier: number?)
	local self = setmetatable({}, Inventory)
	self.def = itemsDef
	self.items = {} -- id -> количество
	self.bag = bagTier or 1
	self.weapons = {} -- список id оружия
	self.armor = "none"
	self.extras = {} -- id -> true (шапка джунглей, лягушачьи сапоги)
	return self
end

function Inventory:capacity(): number
	return self.def.BAGS[self.bag].slots
end

function Inventory:count(id: string): number
	return self.items[id] or 0
end

local function slotsFor(n: number, stack: number): number
	if n <= 0 then
		return 0
	end
	return math.ceil(n / stack)
end

function Inventory:slotsUsed(except: string?): number
	local used = 0
	for id, n in pairs(self.items) do
		local d = self.def[id]
		if id ~= except and d and not d.free then
			used += slotsFor(n, self.def.STACK)
		end
	end
	return used
end

-- Сколько штук предмета ещё влезет
function Inventory:roomFor(id: string): number
	local d = self.def[id]
	if not d then
		return 0
	end
	if d.free then
		return math.huge
	end
	local freeSlots = self:capacity() - self:slotsUsed(id)
	return math.max(0, freeSlots * self.def.STACK - self:count(id))
end

-- Добавить предметы. Возвращает (сколько положили, сколько не влезло).
function Inventory:add(id: string, n: number): (number, number)
	if n <= 0 then
		return 0, 0
	end
	local put = math.min(n, self:roomFor(id))
	if put > 0 then
		self.items[id] = self:count(id) + put
	end
	return put, n - put
end

function Inventory:has(id: string, n: number?): boolean
	return self:count(id) >= (n or 1)
end

function Inventory:remove(id: string, n: number?): boolean
	n = n or 1
	if self:count(id) < n then
		return false
	end
	self.items[id] -= n
	if self.items[id] <= 0 then
		self.items[id] = nil
	end
	return true
end

-- Цена вида {wood = 3, stone = 2}
function Inventory:canPay(cost): boolean
	for id, n in pairs(cost) do
		if self:count(id) < n then
			return false
		end
	end
	return true
end

function Inventory:pay(cost): boolean
	if not self:canPay(cost) then
		return false
	end
	for id, n in pairs(cost) do
		self:remove(id, n)
	end
	return true
end

function Inventory:addWeapon(id: string, order)
	for _, w in ipairs(self.weapons) do
		if w == id then
			return false
		end
	end
	table.insert(self.weapons, id)
	if order then
		local pos = {}
		for i, w in ipairs(order) do
			pos[w] = i
		end
		table.sort(self.weapons, function(a, b)
			return (pos[a] or 999) < (pos[b] or 999)
		end)
	end
	return true
end

function Inventory:hasWeapon(id: string): boolean
	for _, w in ipairs(self.weapons) do
		if w == id then
			return true
		end
	end
	return false
end

-- Надеть броню, только если она лучше текущей
function Inventory:equipArmor(id: string, armorDef): boolean
	local cur = armorDef[self.armor]
	local new = armorDef[id]
	if not new then
		return false
	end
	if cur and cur.reduce >= new.reduce and self.armor ~= "none" then
		return false
	end
	self.armor = id
	return true
end

function Inventory:setBag(tier: number): boolean
	if tier > self.bag then
		self.bag = tier
		return true
	end
	return false
end

-- Снимок для отправки клиенту
function Inventory:snapshot()
	local items = {}
	for k, v in pairs(self.items) do
		items[k] = v
	end
	local extras = {}
	for k in pairs(self.extras) do
		table.insert(extras, k)
	end
	return {
		items = items,
		weapons = table.clone(self.weapons),
		armor = self.armor,
		extras = extras,
		bag = self.bag,
		capacity = self:capacity(),
		used = self:slotsUsed(),
	}
end

return Inventory
