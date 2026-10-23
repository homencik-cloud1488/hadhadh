# hadhadh: Tower Defense (Roblox)

## 📜 Система квестов

Готовая система квестов: GUI, серверная логика, сохранение и награды.

**Что умеет:**
- 3 вкладки: **Ежедневные** (сброс каждый день), **Недельные** (сброс по понедельникам), **Достижения** (навсегда)
- Каждый день и каждую неделю игроку выпадают случайные квесты из пула
- Карточки с иконкой, анимированным прогресс-баром, наградой и кнопкой «ЗАБРАТЬ!»
- Таймер до обновления квестов
- Красный значок с количеством наград, которые можно забрать
- Уведомление «Квест выполнен!» сверху экрана (по клику открывает квесты)
- Всплывающий текст `+150 💰` при получении награды
- Клавиша **J** открывает и закрывает окно
- Работает на телефонах (GUI масштабируется)
- Защита: прогресс и награды считаются только на сервере
- Сохранение через DataStore, монеты и гемы видны в `leaderstats`

### Структура

```
src/
├── shared/
│   └── QuestConfig.luau          → ReplicatedStorage/Shared/QuestConfig      (ModuleScript)
├── server/
│   ├── Main.server.luau          → ServerScriptService/Server/Main           (Script)
│   └── Services/
│       ├── DataService.luau      → ServerScriptService/Server/Services/DataService  (ModuleScript)
│       └── QuestService.luau     → ServerScriptService/Server/Services/QuestService (ModuleScript)
└── client/
    └── QuestGui.client.luau      → StarterPlayer/StarterPlayerScripts/Client/QuestGui (LocalScript)
```

### Установка

**Вариант 1: через Rojo (рекомендуется)**
1. Установи [Rojo](https://rojo.space/) и плагин для Studio.
2. В папке проекта выполни `rojo serve`.
3. В Studio открой плагин Rojo и нажми **Connect**.

**Вариант 2: вручную, без Rojo**
1. В **ReplicatedStorage** создай папку `Shared`, внутри **ModuleScript** `QuestConfig` и вставь код из `src/shared/QuestConfig.luau`.
2. В **ServerScriptService** создай папку `Server`:
   - внутри **Script** `Main` с кодом из `src/server/Main.server.luau`;
   - внутри папку `Services`, а в ней два **ModuleScript**: `DataService` и `QuestService`.
3. В **StarterPlayer → StarterPlayerScripts** создай папку `Client`, внутри **LocalScript** `QuestGui` с кодом из `src/client/QuestGui.client.luau`.

> Чтобы сохранения работали в Studio, включи
> **Game Settings → Security → Enable Studio Access to API Services**.

### Как засчитывать прогресс в игре

В любом **серверном** скрипте:

```lua
local QuestService = require(game.ServerScriptService.Server.Services.QuestService)

-- враг умер (нужно знать, кто его убил)
QuestService.AddProgress(player, "KillEnemies", 1)
if enemy:GetAttribute("IsBoss") then
	QuestService.AddProgress(player, "KillBosses", 1)
end

-- башня поставлена / улучшена
QuestService.AddProgress(player, "PlaceTowers", 1)
QuestService.AddProgress(player, "UpgradeTowers", 1)

-- волна пройдена (всем игрокам в матче)
for _, p in game.Players:GetPlayers() do
	QuestService.AddProgress(p, "CompleteWaves", 1)
	QuestService.ReportBest(p, "ReachWave", currentWave) -- рекорд волны
end

-- конец матча
QuestService.AddProgress(player, "PlayGames", 1)
if won then
	QuestService.AddProgress(player, "WinGames", 1)
end

-- игрок заработал деньги в матче
QuestService.AddProgress(player, "EarnCash", amount)
```

Можно вызывать хоть сотни раз в секунду: обновления отправляются клиенту пачками раз в 0.3 сек.

### Как добавить или изменить квесты

Всё настраивается в `src/shared/QuestConfig.luau`:

```lua
{ Id = "D_Kill200", Type = "KillEnemies", Goal = 200, Title = "Истребитель",
  Description = "Победи {goal} врагов", Reward = { Coins = 100, Gems = 5 } },
```

- `Id`: уникальный, после релиза лучше не менять (он хранится в сохранениях).
- `CategoryInfo.Daily.Count`: сколько ежедневных квестов выдаётся игроку.
- Новый тип действия: добавь его в `QuestConfig.Types` и `QuestConfig.TypeIcons`, потом вызывай `AddProgress` с этим типом.
- Цвета GUI меняются в таблице `Theme` в начале `QuestGui.client.luau`.

### Тестовые команды (только в Studio)

Пиши в чат:

| Команда | Что делает |
|---|---|
| `!q kill 50` | +50 убийств |
| `!q boss 1` | +1 босс |
| `!q win 1` | +1 победа |
| `!q tower 10` | +10 поставленных башен |
| `!q upgrade 10` | +10 улучшений |
| `!q wave 10` | +10 волн |
| `!q cash 5000` | +5000 заработанных денег |
| `!q best 40` | рекорд волны 40 |
| `!q all` | выполнить все квесты |
| `!q reroll` | новые ежедневные и недельные квесты |
| `!q resetach` | сбросить достижения |
