--[[
	QuestService (ModuleScript)
	Расположение: ServerScriptService > Server > Services > QuestService

	Серверная логика квестов: выдача, прогресс, сбросы, награды.

	Как засчитывать прогресс из других серверных скриптов:

		local QuestService = require(game.ServerScriptService.Server.Services.QuestService)

		QuestService.AddProgress(player, "KillEnemies", 1)    -- убил врага
		QuestService.AddProgress(player, "KillBosses", 1)     -- убил босса
		QuestService.AddProgress(player, "PlaceTowers", 1)    -- поставил башню
		QuestService.AddProgress(player, "UpgradeTowers", 1)  -- улучшил башню
		QuestService.AddProgress(player, "CompleteWaves", 1)  -- прошёл волну
		QuestService.AddProgress(player, "WinGames", 1)       -- выиграл матч
		QuestService.AddProgress(player, "PlayGames", 1)      -- сыграл матч
		QuestService.AddProgress(player, "EarnCash", 250)     -- заработал 250 денег
		QuestService.ReportBest(player, "ReachWave", 37)      -- дошёл до 37-й волны (рекорд)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QuestConfig"))
local DataService = require(script.Parent.DataService)

local QuestService = {}

local ROTATING = { "Daily", "Weekly" } -- категории, которые сбрасываются по времени

local stateEvent: RemoteEvent
local completedEvent: RemoteEvent
local dirty: { [Player]: boolean } = {}
local lastClaim: { [Player]: number } = {}

---------------------------------------------------------------------
-- Время и сбросы
---------------------------------------------------------------------

local function getPeriodIndex(category: string, now: number): number
	local info = QuestConfig.CategoryInfo[category]
	return math.floor((now - info.Offset) / info.Period)
end

local function getNextReset(category: string, now: number): number
	local info = QuestConfig.CategoryInfo[category]
	return (getPeriodIndex(category, now) + 1) * info.Period + info.Offset
end

local function rollQuests(category: string)
	local pool = QuestConfig.Quests[category]
	local count = math.min(QuestConfig.CategoryInfo[category].Count, #pool)

	local order = {}
	for i = 1, #pool do
		order[i] = i
	end
	local rng = Random.new()
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end

	local list = {}
	for i = 1, count do
		list[i] = { Id = pool[order[i]].Id, Progress = 0, Claimed = false }
	end
	return list
end

-- Проверяет данные квестов игрока и при необходимости выдаёт новые.
-- Возвращает true, если что-то изменилось.
local function ensureQuestData(profile): boolean
	profile.Quests = profile.Quests or {}
	local quests = profile.Quests
	local now = os.time()
	local changed = false

	for _, category in ROTATING do
		local period = getPeriodIndex(category, now)
		local data = quests[category]

		if data and data.List then
			-- Убираем квесты, которые удалили из конфига
			local valid = {}
			for _, entry in data.List do
				if QuestConfig.GetQuest(category, entry.Id) then
					table.insert(valid, entry)
				end
			end
			if #valid ~= #data.List then
				data.List = valid
				changed = true
			end
		end

		if not data or not data.List or data.Period ~= period or #data.List == 0 then
			quests[category] = { Period = period, List = rollQuests(category) }
			changed = true
		end
	end

	quests.Achievements = quests.Achievements or {}
	return changed
end

---------------------------------------------------------------------
-- Отправка состояния клиенту
---------------------------------------------------------------------

local function buildState(profile)
	local now = os.time()
	local quests = profile.Quests

	local achievements = {}
	for _, quest in QuestConfig.Quests.Achievements do
		local entry = quests.Achievements[quest.Id]
		table.insert(achievements, {
			Id = quest.Id,
			Progress = entry and entry.Progress or 0,
			Claimed = entry and entry.Claimed or false,
		})
	end

	return {
		Daily = { List = quests.Daily.List, NextReset = getNextReset("Daily", now) },
		Weekly = { List = quests.Weekly.List, NextReset = getNextReset("Weekly", now) },
		Achievements = { List = achievements },
	}
end

local function pushState(player: Player)
	dirty[player] = nil
	local profile = DataService.GetProfile(player)
	if profile then
		ensureQuestData(profile)
		stateEvent:FireClient(player, buildState(profile))
	end
end

---------------------------------------------------------------------
-- Прогресс
---------------------------------------------------------------------

-- Обходит все активные квесты игрока нужного типа и применяет к ним updater
local function updateQuests(player: Player, questType: string, updater: (current: number) -> number)
	local profile = DataService.GetProfile(player)
	if not profile or not profile.Quests or not profile.Quests.Daily then
		return
	end
	local quests = profile.Quests

	local function apply(category: string, quest, entry)
		if quest.Type ~= questType or entry.Claimed or entry.Progress >= quest.Goal then
			return
		end
		local newProgress = math.clamp(updater(entry.Progress), 0, quest.Goal)
		if newProgress == entry.Progress then
			return
		end
		entry.Progress = newProgress
		dirty[player] = true
		if newProgress >= quest.Goal then
			completedEvent:FireClient(player, category, quest.Id)
		end
	end

	for _, category in ROTATING do
		for _, entry in quests[category].List do
			local quest = QuestConfig.GetQuest(category, entry.Id)
			if quest then
				apply(category, quest, entry)
			end
		end
	end

	for _, quest in QuestConfig.Quests.Achievements do
		if quest.Type == questType then
			local entry = quests.Achievements[quest.Id]
			if not entry then
				entry = { Progress = 0, Claimed = false }
				quests.Achievements[quest.Id] = entry
			end
			apply("Achievements", quest, entry)
		end
	end
end

-- Добавить прогресс (+amount)
function QuestService.AddProgress(player: Player, questType: string, amount: number?)
	local add = amount or 1
	if add <= 0 then
		return
	end
	updateQuests(player, questType, function(current)
		return current + add
	end)
end

-- Для рекордов: прогресс = максимум(текущий, value). Например, "дойди до 40-й волны".
function QuestService.ReportBest(player: Player, questType: string, value: number)
	updateQuests(player, questType, function(current)
		return math.max(current, value)
	end)
end

---------------------------------------------------------------------
-- Получение награды
---------------------------------------------------------------------

local function findEntry(profile, category: string, questId: string)
	if category == "Achievements" then
		return profile.Quests.Achievements[questId]
	end
	local data = profile.Quests[category]
	if data and data.List then
		for _, entry in data.List do
			if entry.Id == questId then
				return entry
			end
		end
	end
	return nil
end

local function onClaim(player: Player, category: any, questId: any)
	if typeof(category) ~= "string" or typeof(questId) ~= "string" then
		return false, "Неверный запрос"
	end

	local now = os.clock()
	if lastClaim[player] and now - lastClaim[player] < 0.25 then
		return false, "Слишком быстро"
	end
	lastClaim[player] = now

	local profile = DataService.GetProfile(player)
	if not profile or not profile.Quests or not profile.Quests.Daily then
		return false, "Данные ещё загружаются"
	end
	ensureQuestData(profile)

	local quest = QuestConfig.GetQuest(category, questId)
	local entry = quest and findEntry(profile, category, questId)
	if not quest or not entry then
		return false, "Квест не найден"
	end
	if entry.Claimed then
		return false, "Награда уже получена"
	end
	if entry.Progress < quest.Goal then
		return false, "Квест ещё не выполнен"
	end

	entry.Claimed = true
	for currency, amount in quest.Reward do
		DataService.AddCurrency(player, currency, amount)
	end

	pushState(player)
	return true, quest.Reward
end

---------------------------------------------------------------------
-- Отладка (используется командами в Studio, см. Main.server.luau)
---------------------------------------------------------------------

function QuestService.DebugCompleteAll(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	for _, category in QuestConfig.Categories do
		for _, quest in QuestConfig.Quests[category] do
			QuestService.ReportBest(player, quest.Type, quest.Goal)
		end
	end
end

function QuestService.DebugReroll(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	for _, category in ROTATING do
		profile.Quests[category] = nil
	end
	pushState(player)
end

function QuestService.DebugResetAchievements(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	profile.Quests.Achievements = {}
	pushState(player)
end

---------------------------------------------------------------------
-- Инициализация
---------------------------------------------------------------------

function QuestService.Init()
	local remotes = Instance.new("Folder")
	remotes.Name = "QuestRemotes"

	stateEvent = Instance.new("RemoteEvent")
	stateEvent.Name = "QuestState"
	stateEvent.Parent = remotes

	completedEvent = Instance.new("RemoteEvent")
	completedEvent.Name = "QuestCompleted"
	completedEvent.Parent = remotes

	local getQuests = Instance.new("RemoteFunction")
	getQuests.Name = "GetQuests"
	getQuests.Parent = remotes

	local claimQuest = Instance.new("RemoteFunction")
	claimQuest.Name = "ClaimQuest"
	claimQuest.Parent = remotes

	remotes.Parent = ReplicatedStorage

	getQuests.OnServerInvoke = function(player)
		local profile = DataService.WaitForProfile(player, 20)
		if not profile then
			return nil
		end
		ensureQuestData(profile)
		return buildState(profile)
	end

	claimQuest.OnServerInvoke = onClaim

	DataService.ProfileLoaded:Connect(function(player, profile)
		ensureQuestData(profile)
		pushState(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
		lastClaim[player] = nil
	end)

	-- Отправляем изменения пачками, а не на каждое убийство (экономит трафик)
	task.spawn(function()
		while true do
			task.wait(0.3)
			for player in dirty do
				pushState(player)
			end
		end
	end)

	-- Проверяем, не наступил ли новый день или неделя
	task.spawn(function()
		while true do
			task.wait(15)
			for _, player in Players:GetPlayers() do
				local profile = DataService.GetProfile(player)
				if profile and ensureQuestData(profile) then
					pushState(player)
				end
			end
		end
	end)
end

return QuestService
