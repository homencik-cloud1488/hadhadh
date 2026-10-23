--[[
	DataService (ModuleScript)
	Расположение: ServerScriptService > Server > Services > DataService

	Простое сохранение данных игрока через DataStore + leaderstats (Coins, Gems).
	Чтобы сохранения работали в Studio: Game Settings > Security >
	"Enable Studio Access to API Services" = ON.

	Для большой игры лучше перейти на ProfileStore (защита от дюпа и session locking),
	интерфейс модуля (GetProfile / AddCurrency) можно оставить прежним.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_INTERVAL = 120 -- секунд

local DataService = {}

local profiles: { [Player]: any } = {}
local canSave: { [Player]: boolean } = {}

local loadedEvent = Instance.new("BindableEvent")
DataService.ProfileLoaded = loadedEvent.Event -- (player, profile)

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore недоступен, прогресс не будет сохраняться:", result)
	end
end

local function defaultProfile()
	return {
		Coins = 0,
		Gems = 0,
		Quests = {},
	}
end

local function deepCopy(t)
	local copy = {}
	for k, v in t do
		copy[k] = if type(v) == "table" then deepCopy(v) else v
	end
	return copy
end

-- Добавляет недостающие поля (если ты добавишь новые поля в defaultProfile)
local function reconcile(data, template)
	for k, v in template do
		if data[k] == nil then
			data[k] = if type(v) == "table" then deepCopy(v) else v
		end
	end
end

local function getKey(player: Player): string
	return "Player_" .. player.UserId
end

local function setupLeaderstats(player: Player, profile)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	for _, currency in { "Coins", "Gems" } do
		local value = leaderstats:FindFirstChild(currency)
		if not value then
			value = Instance.new("IntValue")
			value.Name = currency
			value.Parent = leaderstats
		end
		value.Value = profile[currency] or 0
	end
end

local function loadPlayer(player: Player)
	local data = nil
	local loaded = false

	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(getKey(player))
			end)
			if ok then
				data = result
				loaded = true
				break
			end
			warn(("[DataService] Ошибка загрузки %s (попытка %d): %s"):format(player.Name, attempt, tostring(result)))
			-- Нет доступа к API в Studio: повторять бессмысленно
			if string.find(tostring(result), "StudioAccessToApisNotAllowed") or string.find(tostring(result), "403") then
				warn("[DataService] Включи Game Settings > Security > Enable Studio Access to API Services")
				break
			end
			task.wait(attempt)
		end
	end

	if not player.Parent then
		return -- игрок вышел, пока грузились данные
	end

	if type(data) ~= "table" then
		data = defaultProfile()
	end
	reconcile(data, defaultProfile())

	profiles[player] = data
	-- Если загрузка не удалась, НЕ сохраняем, чтобы не затереть настоящие данные пустыми
	canSave[player] = loaded

	setupLeaderstats(player, data)
	loadedEvent:Fire(player, data)
end

function DataService.Save(player: Player)
	local data = profiles[player]
	if not data or not canSave[player] or not store then
		return
	end
	local ok, err = pcall(function()
		store:UpdateAsync(getKey(player), function()
			return data
		end)
	end)
	if not ok then
		warn("[DataService] Ошибка сохранения", player.Name, err)
	end
end

function DataService.GetProfile(player: Player)
	return profiles[player]
end

function DataService.WaitForProfile(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 20)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.AddCurrency(player: Player, currency: string, amount: number)
	local profile = profiles[player]
	if not profile then
		return false
	end
	profile[currency] = (profile[currency] or 0) + amount

	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(currency)
	if value then
		value.Value = profile[currency]
	end
	return true
end

function DataService.Init()
	Players.PlayerAdded:Connect(loadPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player)
		profiles[player] = nil
		canSave[player] = nil
	end)

	-- Автосохранение
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(DataService.Save, player)
			end
		end
	end)

	-- Сохранение при выключении сервера
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.Save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
