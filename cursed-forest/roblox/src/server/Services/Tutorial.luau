-- Обучение для новичков: цепочка заданий с подсказкой и стрелкой-указателем на цель.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)

local Tutorial = {}
local S, State

local function at(id: string): Vector3
	local s = World.STRUCTURES[id]
	return Vector3.new(s.x, 4, s.z)
end
local CAMP = Vector3.new(0, 4, 0)

local STEPS = {
	{
		text = "Прочитай стенд пропавших детей",
		hint = "Подойди к деревянному стенду рядом с костром и нажми E. Он скажет, кто за тобой охотится.",
		done = function(ps) return ps.knowsBiome end,
		target = function() return at("board") end,
	},
	{
		text = "Наруби 5 дерева",
		hint = "Нажми 1, чтобы взять топор. Подойди к дереву вплотную и жми левую кнопку мыши.",
		done = function(ps) return S.Camp.have(ps, "wood") >= 5 end,
		target = function(ps, pos) return S.WorldBuilder.nearest("tree", pos) end,
	},
	{
		text = "Отнеси дерево в лагерь",
		hint = "Вернись к костру. Всё из мешка само ляжет на склад лагеря.",
		done = function(ps) return ps.flags.deposited end,
		target = function() return CAMP end,
	},
	{
		text = "Подбрось дров в костёр",
		hint = "У костра нажми E и выбери «Подбросить 5 🪵». Без огня ночью опасно.",
		done = function(ps) return ps.flags.fueled end,
		target = function() return CAMP end,
	},
	{
		text = "Поймай кролика",
		hint = "Кролики бегают по лесу. Догони и ударь, потом подбери мясо: просто пройди по нему.",
		done = function(ps) return S.Camp.have(ps, "meat") + S.Camp.have(ps, "cmeat") >= 1 end,
		target = function(ps, pos) return S.Mobs.nearestKind("rabbit", pos) end,
	},
	{
		text = "Пожарь мясо",
		hint = "У костра нажми E и выбери «Пожарить мясо и рыбу». Сырое мясо вредно.",
		done = function(ps) return ps.flags.cooked end,
		target = function() return CAMP end,
	},
	{
		text = "Поешь",
		hint = "Нажми R. Когда сытость высокая, здоровье само восстанавливается.",
		done = function(ps) return ps.flags.ate end,
	},
	{
		text = "Открой сундук",
		hint = "Сундуки стоят в лесу. Подойди и нажми E. Внутри ткань, верёвки, батарейки.",
		done = function(ps) return ps.tasks.chests >= 1 end,
		target = function(ps, pos) return S.WorldBuilder.nearest("chest", pos) end,
	},
	{
		text = "Сделай факел",
		hint = "У костра нажми E, открой вкладку «Верстак» и выбери «Факел» (дерево + ткань).",
		done = function(ps) return ps.flags.crafted end,
		target = function() return CAMP end,
	},
	{
		text = "Переживи первую ночь",
		hint = "Ночью держись у костра. Олень боится света: зажги факел или фонарик клавишей F и свети на него.",
		done = function(ps) return State.run.day > (ps.joinDay or 1) end,
		target = function() return CAMP end,
	},
	{
		text = "Обменяй шкуру волка на Тотеме",
		hint = "Убей волка, подбери шкуру и подойди к резному столбу у костра (E). Там дают копьё, револьвер, удочку.",
		done = function(ps) return ps.flags.totem end,
		target = function() return at("totem") end,
	},
	{
		text = "Свободная игра",
		hint = "Перечитай стенд: там места для походов. Цель: победить королей, собрать 6 осколков печати и зажечь Великий Костёр к сотой ночи.",
		done = function() return false end,
	},
}

function Tutorial.update(ps, pos: Vector3)
	if not ps.tut then
		ps.tut = 1
	end
	local step = STEPS[ps.tut]
	while step and step.done(ps) do
		State.notify(ps.player, "✅ Задание выполнено: " .. step.text, "good")
		ps.tut += 1
		step = STEPS[ps.tut]
		if step then
			State.notify(ps.player, "📜 Новое задание: " .. step.text, "")
		end
	end
	if not step then
		return nil
	end
	local target = step.target and step.target(ps, pos) or nil
	return { i = ps.tut, n = #STEPS, text = step.text, hint = step.hint, target = target }
end

function Tutorial.init(services)
	S = services
	State = S.State
end

return Tutorial
