--[[
	Main (Script)
	Расположение: ServerScriptService > Server > Main

	Запускает серверные сервисы.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Services = script.Parent:WaitForChild("Services")
local DataService = require(Services:WaitForChild("DataService"))
local QuestService = require(Services:WaitForChild("QuestService"))

QuestService.Init() -- создаёт RemoteEvents до загрузки игроков
DataService.Init()

---------------------------------------------------------------------
-- Тестовые команды в чат (работают ТОЛЬКО в Roblox Studio)
--   !q kill 50     +50 к убийствам врагов
--   !q boss 1      +1 босс
--   !q win 1       +1 победа
--   !q tower 10    +10 поставленных башен
--   !q upgrade 10  +10 улучшений
--   !q wave 10     +10 пройденных волн
--   !q cash 5000   +5000 заработанных денег
--   !q best 40     рекорд волны = 40
--   !q all         выполнить все квесты
--   !q reroll      выдать новые ежедневные и недельные квесты
--   !q resetach    сбросить достижения
---------------------------------------------------------------------
if RunService:IsStudio() then
	local aliases = {
		kill = "KillEnemies",
		boss = "KillBosses",
		win = "WinGames",
		play = "PlayGames",
		tower = "PlaceTowers",
		upgrade = "UpgradeTowers",
		wave = "CompleteWaves",
		cash = "EarnCash",
	}

	local function onChatted(player: Player, message: string)
		local args = string.split(string.lower(message), " ")
		if args[1] ~= "!q" then
			return
		end
		local cmd, amount = args[2], tonumber(args[3]) or 1

		if aliases[cmd] then
			QuestService.AddProgress(player, aliases[cmd], amount)
		elseif cmd == "best" then
			QuestService.ReportBest(player, "ReachWave", amount)
		elseif cmd == "all" then
			QuestService.DebugCompleteAll(player)
		elseif cmd == "reroll" then
			QuestService.DebugReroll(player)
		elseif cmd == "resetach" then
			QuestService.DebugResetAchievements(player)
		end
	end

	local function hook(player: Player)
		player.Chatted:Connect(function(message)
			onChatted(player, message)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end
