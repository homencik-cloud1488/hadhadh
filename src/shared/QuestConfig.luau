--[[
	QuestConfig (ModuleScript)
	Расположение: ReplicatedStorage > Shared > QuestConfig

	Здесь настраиваются ВСЕ квесты. Этот модуль используют и сервер, и клиент.

	Как добавить квест:
	  1. Скопируй любую строку в нужном разделе (Daily / Weekly / Achievements).
	  2. Дай квесту УНИКАЛЬНЫЙ Id (потом его лучше не менять, он хранится в сохранениях).
	  3. Type: тип действия (см. QuestConfig.Types ниже).
	  4. Goal: сколько нужно сделать. {goal} в описании заменится на это число.
	  5. Reward: награда, например { Coins = 100, Gems = 5 }.
]]

local QuestConfig = {}

-- Типы действий. Сервер вызывает QuestService.AddProgress(player, "<Type>", amount)
QuestConfig.Types = {
	KillEnemies = "KillEnemies", -- убить врага
	KillBosses = "KillBosses", -- убить босса
	PlaceTowers = "PlaceTowers", -- поставить башню
	UpgradeTowers = "UpgradeTowers", -- улучшить башню
	CompleteWaves = "CompleteWaves", -- пройти волну
	WinGames = "WinGames", -- выиграть матч
	PlayGames = "PlayGames", -- сыграть матч (любой результат)
	EarnCash = "EarnCash", -- заработать внутриматчевые деньги
	ReachWave = "ReachWave", -- рекорд: дойти до волны N (через QuestService.ReportBest)
}

-- Иконка для каждого типа (показывается в карточке квеста)
QuestConfig.TypeIcons = {
	KillEnemies = "⚔️",
	KillBosses = "👹",
	PlaceTowers = "🏰",
	UpgradeTowers = "⬆️",
	CompleteWaves = "🌊",
	WinGames = "🏆",
	PlayGames = "🎮",
	EarnCash = "💵",
	ReachWave = "🚩",
}

-- Валюты наград
QuestConfig.Currencies = {
	Coins = { Icon = "💰", Name = "Монеты", Color = Color3.fromRGB(255, 205, 70) },
	Gems = { Icon = "💎", Name = "Гемы", Color = Color3.fromRGB(110, 200, 255) },
}
QuestConfig.CurrencyOrder = { "Coins", "Gems" }

-- Порядок вкладок
QuestConfig.Categories = { "Daily", "Weekly", "Achievements" }

-- Настройки категорий.
-- Count: сколько случайных квестов выдаётся игроку из пула.
-- Period / Offset: период сброса в секундах (по UTC).
--   Daily: каждый день в 00:00 UTC (03:00 по Москве).
--   Weekly: каждый понедельник в 00:00 UTC (смещение 4 дня, потому что 01.01.1970 был четвергом).
QuestConfig.CategoryInfo = {
	Daily = { Name = "Ежедневные", Icon = "☀️", Count = 3, Period = 86400, Offset = 0 },
	Weekly = { Name = "Недельные", Icon = "📅", Count = 3, Period = 7 * 86400, Offset = 4 * 86400 },
	Achievements = { Name = "Достижения", Icon = "🏆" },
}

QuestConfig.Quests = {
	-- Ежедневные: игроку выпадает Count штук из этого пула
	Daily = {
		{ Id = "D_Kill200", Type = "KillEnemies", Goal = 200, Title = "Истребитель", Description = "Победи {goal} врагов", Reward = { Coins = 100 } },
		{ Id = "D_Kill500", Type = "KillEnemies", Goal = 500, Title = "Мясорубка", Description = "Победи {goal} врагов", Reward = { Coins = 200 } },
		{ Id = "D_Boss3", Type = "KillBosses", Goal = 3, Title = "Охотник на боссов", Description = "Победи {goal} босса", Reward = { Coins = 150, Gems = 5 } },
		{ Id = "D_Place25", Type = "PlaceTowers", Goal = 25, Title = "Строитель", Description = "Поставь {goal} башен", Reward = { Coins = 100 } },
		{ Id = "D_Upgrade20", Type = "UpgradeTowers", Goal = 20, Title = "Инженер", Description = "Улучши башни {goal} раз", Reward = { Coins = 120 } },
		{ Id = "D_Waves30", Type = "CompleteWaves", Goal = 30, Title = "Стойкая оборона", Description = "Пройди {goal} волн", Reward = { Coins = 150 } },
		{ Id = "D_Win2", Type = "WinGames", Goal = 2, Title = "Победитель", Description = "Выиграй {goal} матча", Reward = { Coins = 200, Gems = 5 } },
		{ Id = "D_Cash10k", Type = "EarnCash", Goal = 10000, Title = "Казначей", Description = "Заработай {goal} денег в матчах", Reward = { Coins = 120 } },
		{ Id = "D_Play3", Type = "PlayGames", Goal = 3, Title = "Разминка", Description = "Сыграй {goal} матча", Reward = { Coins = 80 } },
	},

	-- Недельные
	Weekly = {
		{ Id = "W_Kill5000", Type = "KillEnemies", Goal = 5000, Title = "Легенда поля боя", Description = "Победи {goal} врагов", Reward = { Coins = 1000, Gems = 20 } },
		{ Id = "W_Boss25", Type = "KillBosses", Goal = 25, Title = "Гроза боссов", Description = "Победи {goal} боссов", Reward = { Coins = 800, Gems = 25 } },
		{ Id = "W_Win15", Type = "WinGames", Goal = 15, Title = "Непобедимый", Description = "Выиграй {goal} матчей", Reward = { Coins = 1200, Gems = 30 } },
		{ Id = "W_Upgrade200", Type = "UpgradeTowers", Goal = 200, Title = "Главный инженер", Description = "Улучши башни {goal} раз", Reward = { Coins = 800, Gems = 15 } },
		{ Id = "W_Waves300", Type = "CompleteWaves", Goal = 300, Title = "Марафонец", Description = "Пройди {goal} волн", Reward = { Coins = 1000, Gems = 20 } },
		{ Id = "W_Wave40", Type = "ReachWave", Goal = 40, Title = "Несокрушимый", Description = "Дойди до {goal}-й волны за один матч", Reward = { Coins = 1500, Gems = 40 } },
	},

	-- Достижения: постоянные, выполняются один раз и не сбрасываются
	Achievements = {
		{ Id = "A_FirstWin", Type = "WinGames", Goal = 1, Title = "Первая победа", Description = "Выиграй свой первый матч", Reward = { Coins = 250 } },
		{ Id = "A_Kill1000", Type = "KillEnemies", Goal = 1000, Title = "Ветеран", Description = "Победи {goal} врагов", Reward = { Coins = 500, Gems = 10 } },
		{ Id = "A_Kill10000", Type = "KillEnemies", Goal = 10000, Title = "Генерал", Description = "Победи {goal} врагов", Reward = { Coins = 2000, Gems = 50 } },
		{ Id = "A_Kill100000", Type = "KillEnemies", Goal = 100000, Title = "Повелитель обороны", Description = "Победи {goal} врагов", Reward = { Coins = 10000, Gems = 200 } },
		{ Id = "A_Boss100", Type = "KillBosses", Goal = 100, Title = "Убийца боссов", Description = "Победи {goal} боссов", Reward = { Gems = 100 } },
		{ Id = "A_Win100", Type = "WinGames", Goal = 100, Title = "Чемпион", Description = "Выиграй {goal} матчей", Reward = { Gems = 150 } },
		{ Id = "A_Place1000", Type = "PlaceTowers", Goal = 1000, Title = "Архитектор", Description = "Поставь {goal} башен", Reward = { Coins = 3000 } },
		{ Id = "A_Wave50", Type = "ReachWave", Goal = 50, Title = "За гранью", Description = "Дойди до {goal}-й волны за один матч", Reward = { Gems = 75 } },
	},
}

---------------------------------------------------------------------
-- Вспомогательные функции (менять не нужно)
---------------------------------------------------------------------

local index = {}
for category, list in QuestConfig.Quests do
	index[category] = {}
	for _, quest in list do
		assert(index[category][quest.Id] == nil, "Повторяющийся Id квеста: " .. quest.Id)
		index[category][quest.Id] = quest
	end
end

function QuestConfig.GetQuest(category: string, questId: string)
	local byId = index[category]
	return byId and byId[questId]
end

-- 1234567 -> "1 234 567"
function QuestConfig.FormatNumber(n: number): string
	local s = tostring(math.floor(n))
	local sign = ""
	if string.sub(s, 1, 1) == "-" then
		sign = "-"
		s = string.sub(s, 2)
	end
	local result = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1 ")))
	if string.sub(result, 1, 1) == " " then
		result = string.sub(result, 2)
	end
	return sign .. result
end

-- 15000 -> "15K", 2500000 -> "2.5M"
function QuestConfig.ShortNumber(n: number): string
	if n >= 1e6 then
		return (string.gsub(string.format("%.1fM", n / 1e6), "%.0M", "M"))
	elseif n >= 1e4 then
		return (string.gsub(string.format("%.1fK", n / 1e3), "%.0K", "K"))
	end
	return QuestConfig.FormatNumber(n)
end

function QuestConfig.GetDescription(quest): string
	return (string.gsub(quest.Description, "{goal}", QuestConfig.FormatNumber(quest.Goal)))
end

return QuestConfig
