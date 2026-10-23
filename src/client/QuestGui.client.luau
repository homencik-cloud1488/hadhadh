--[[
	QuestGui (LocalScript)
	Расположение: StarterPlayer > StarterPlayerScripts > Client > QuestGui

	GUI квестов целиком создаётся кодом, ничего рисовать в Studio не нужно.
	  • Кнопка "Квесты" слева, с красным значком (сколько наград можно забрать)
	  • Окно с вкладками: Ежедневные / Недельные / Достижения
	  • Карточки с прогресс-баром, наградой и кнопкой "Забрать"
	  • Таймер до обновления квестов
	  • Уведомление "Квест выполнен!" и анимация получения награды
	  • Клавиша J открывает и закрывает окно
	  • Масштабируется под телефон, планшет и ПК
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local QuestConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QuestConfig"))
local remotes = ReplicatedStorage:WaitForChild("QuestRemotes")
local stateEvent = remotes:WaitForChild("QuestState") :: RemoteEvent
local completedEvent = remotes:WaitForChild("QuestCompleted") :: RemoteEvent
local getQuests = remotes:WaitForChild("GetQuests") :: RemoteFunction
local claimQuest = remotes:WaitForChild("ClaimQuest") :: RemoteFunction

local TOGGLE_KEY = Enum.KeyCode.J

---------------------------------------------------------------------
-- Тема (меняй цвета здесь)
---------------------------------------------------------------------
local Theme = {
	Background = Color3.fromRGB(30, 32, 48),
	Panel = Color3.fromRGB(42, 45, 66),
	Card = Color3.fromRGB(54, 58, 84),
	CardDone = Color3.fromRGB(44, 47, 68),
	Stroke = Color3.fromRGB(20, 21, 32),
	Accent = Color3.fromRGB(255, 196, 61),
	Green = Color3.fromRGB(76, 209, 105),
	Gray = Color3.fromRGB(96, 100, 128),
	Red = Color3.fromRGB(235, 72, 72),
	BarBack = Color3.fromRGB(26, 28, 42),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(176, 182, 210),
	DarkText = Color3.fromRGB(40, 32, 10),
	Font = Enum.Font.GothamBold,
	FontMedium = Enum.Font.GothamMedium,
}

---------------------------------------------------------------------
-- Утилиты
---------------------------------------------------------------------
local function create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(radius: number)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function borderStroke(color: Color3, thickness: number?)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function textStroke(transparency: number?)
	return create("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Thickness = 1.5,
		Transparency = transparency or 0.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

local function tween(inst: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

-- Эффект наведения и нажатия для кнопок
local function addButtonFx(button: GuiButton)
	local scale = create("UIScale", { Parent = button })
	local hovering = false
	button.MouseEnter:Connect(function()
		hovering = true
		tween(scale, 0.12, { Scale = 1.05 })
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		tween(scale, 0.08, { Scale = 0.94 })
	end)
	button.MouseButton1Up:Connect(function()
		tween(scale, 0.12, { Scale = if hovering then 1.05 else 1 })
	end)
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local d = seconds // 86400
	local h = (seconds % 86400) // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if d > 0 then
		return string.format("%dд %02dч %02dм", d, h, m)
	end
	return string.format("%02d:%02d:%02d", h, m, s)
end

local function colorToHex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local function rewardRichText(reward: { [string]: number }, prefix: string?): string
	local parts = {}
	for _, currency in QuestConfig.CurrencyOrder do
		local amount = reward[currency]
		local info = QuestConfig.Currencies[currency]
		if amount and info then
			table.insert(parts, string.format('<font color="%s">%s %s%s</font>', colorToHex(info.Color), info.Icon, prefix or "", QuestConfig.ShortNumber(amount)))
		end
	end
	return table.concat(parts, "  ")
end

---------------------------------------------------------------------
-- Адаптивный масштаб (телефон / ПК)
---------------------------------------------------------------------
local responsiveScales: { UIScale } = {}

local function computeScale(): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 1
	end
	local viewport = camera.ViewportSize
	return math.clamp(math.min(viewport.X / 1100, viewport.Y / 620), 0.55, 1.2)
end

local function updateResponsive()
	local s = computeScale()
	for _, scale in responsiveScales do
		scale.Scale = s
	end
end

local function responsive(parent: GuiObject)
	local scale = create("UIScale", { Scale = computeScale(), Parent = parent })
	table.insert(responsiveScales, scale)
end

---------------------------------------------------------------------
-- Создание GUI
---------------------------------------------------------------------
local oldGui = playerGui:FindFirstChild("QuestGui")
if oldGui then
	oldGui:Destroy()
end

local screenGui = create("ScreenGui", {
	Name = "QuestGui",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 5,
	Parent = playerGui,
})

-- Кнопка открытия ------------------------------------------------
local openHolder = create("Frame", {
	Name = "OpenHolder",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 0),
	Size = UDim2.fromOffset(80, 80),
	BackgroundTransparency = 1,
	Parent = screenGui,
})
responsive(openHolder)

local openButton = create("TextButton", {
	Name = "OpenButton",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Theme.Panel,
	AutoButtonColor = false,
	Text = "",
	Parent = openHolder,
}, {
	corner(16),
	borderStroke(Theme.Accent, 3),
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
	}),
	create("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 42),
		Font = Theme.Font,
		Text = "📜",
		TextSize = 36,
		TextColor3 = Theme.Text,
	}),
	create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 1, -28),
		Size = UDim2.new(1, 0, 0, 22),
		Font = Theme.Font,
		Text = "Квесты",
		TextSize = 15,
		TextColor3 = Theme.Text,
	}, { textStroke(0.4) }),
})
addButtonFx(openButton)

local function createBadge(parent: GuiObject, size: number)
	return create("TextLabel", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.Red,
		Font = Theme.Font,
		Text = "0",
		TextSize = math.floor(size * 0.6),
		TextColor3 = Theme.Text,
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	}, {
		create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		borderStroke(Color3.new(1, 1, 1), 2),
	})
end

local openBadge = createBadge(openButton, 28)

-- Окно ------------------------------------------------------------
local windowHolder = create("Frame", {
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(660, 480),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = screenGui,
})
responsive(windowHolder)

local panel = create("Frame", {
	Name = "Panel",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Theme.Background,
	Parent = windowHolder,
}, {
	corner(18),
	borderStroke(Theme.Stroke, 4),
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 210)),
	}),
})
local popScale = create("UIScale", { Parent = panel })

create("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(22, 12),
	Size = UDim2.new(1, -90, 0, 42),
	Font = Theme.Font,
	Text = "📜 КВЕСТЫ",
	TextSize = 30,
	TextColor3 = Theme.Accent,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = panel,
}, { textStroke(0.2) })

local closeButton = create("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.fromOffset(42, 42),
	BackgroundColor3 = Theme.Red,
	AutoButtonColor = false,
	Font = Theme.Font,
	Text = "✕",
	TextSize = 22,
	TextColor3 = Theme.Text,
	Parent = panel,
}, { corner(12), borderStroke(Theme.Stroke, 2) })
addButtonFx(closeButton)

-- Вкладки
local tabsFrame = create("Frame", {
	Name = "Tabs",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 66),
	Size = UDim2.new(1, -32, 0, 44),
	Parent = panel,
}, {
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local infoLabel = create("TextLabel", {
	Name = "Info",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(22, 118),
	Size = UDim2.new(0.7, -22, 0, 22),
	Font = Theme.FontMedium,
	Text = "",
	TextSize = 15,
	TextColor3 = Theme.SubText,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = panel,
})

local infoRight = create("TextLabel", {
	Name = "InfoRight",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -22, 0, 118),
	Size = UDim2.new(0.3, 0, 0, 22),
	Font = Theme.Font,
	Text = "",
	TextSize = 15,
	TextColor3 = Theme.Accent,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = panel,
})

local content = create("Frame", {
	Name = "Content",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 146),
	Size = UDim2.new(1, -32, 1, -162),
	Parent = panel,
})

local loadingLabel = create("TextLabel", {
	Name = "Loading",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Font = Theme.Font,
	Text = "Загрузка квестов...",
	TextSize = 20,
	TextColor3 = Theme.SubText,
	Parent = content,
})

local tabButtons: { [string]: any } = {}
local tabBadges: { [string]: any } = {}
local scrollFrames: { [string]: ScrollingFrame } = {}

for i, category in QuestConfig.Categories do
	local info = QuestConfig.CategoryInfo[category]

	local button = create("TextButton", {
		Name = category,
		LayoutOrder = i,
		Size = UDim2.new(1 / #QuestConfig.Categories, -6, 1, 0),
		BackgroundColor3 = Theme.Card,
		AutoButtonColor = false,
		Font = Theme.Font,
		Text = info.Icon .. " " .. info.Name,
		TextSize = 18,
		TextColor3 = Theme.Text,
		Parent = tabsFrame,
	}, { corner(12), borderStroke(Theme.Stroke, 2) })
	addButtonFx(button)
	tabButtons[category] = button
	tabBadges[category] = createBadge(button, 24)

	scrollFrames[category] = create("ScrollingFrame", {
		Name = category,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Accent,
		Visible = false,
		Parent = content,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 3),
			PaddingBottom = UDim.new(0, 3),
			PaddingLeft = UDim.new(0, 3),
			PaddingRight = UDim.new(0, 12),
		}),
	})
end

-- Уведомления ----------------------------------------------------
local toastHolder = create("Frame", {
	Name = "Toasts",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(400, 76),
	BackgroundTransparency = 1,
	Parent = screenGui,
})
responsive(toastHolder)

---------------------------------------------------------------------
-- Состояние
---------------------------------------------------------------------
type Entry = { Id: string, Progress: number, Claimed: boolean }

local state: any = nil
local currentTab = "Daily"
local isOpen = false
local cards: { [string]: { [string]: any } } = {}
for _, category in QuestConfig.Categories do
	cards[category] = {}
end

local renderAll: () -> ()
local setOpen: (boolean) -> ()

local function getStatus(quest, entry: Entry): string
	if entry.Claimed then
		return "Claimed"
	elseif entry.Progress >= quest.Goal then
		return "Claimable"
	end
	return "InProgress"
end

local function countClaimable(category: string): number
	if not state or not state[category] then
		return 0
	end
	local n = 0
	for _, entry in state[category].List do
		local quest = QuestConfig.GetQuest(category, entry.Id)
		if quest and getStatus(quest, entry) == "Claimable" then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------------
-- Всплывающий текст награды
---------------------------------------------------------------------
local function showRewardPopup(fromButton: GuiObject, reward)
	if typeof(reward) ~= "table" then
		return
	end
	local pos = fromButton.AbsolutePosition + fromButton.AbsoluteSize / 2
	local label = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		Size = UDim2.fromOffset(300, 40),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		RichText = true,
		Text = rewardRichText(reward, "+"),
		TextSize = math.floor(26 * computeScale()),
		TextColor3 = Theme.Text,
		ZIndex = 50,
		Parent = screenGui,
	})
	local stroke = textStroke(0)
	stroke.Parent = label

	tween(label, 1.1, { Position = UDim2.fromOffset(pos.X, pos.Y - 90) })
	task.delay(0.5, function()
		tween(label, 0.6, { TextTransparency = 1 })
		tween(stroke, 0.6, { Transparency = 1 })
	end)
	task.delay(1.2, function()
		label:Destroy()
	end)
end

---------------------------------------------------------------------
-- Карточка квеста
---------------------------------------------------------------------
local function claim(card)
	if card.Status ~= "Claimable" or card.Pending then
		return
	end
	card.Pending = true
	card.Button.Text = "..."

	local ok, success, result = pcall(function()
		return claimQuest:InvokeServer(card.Category, card.Id)
	end)
	card.Pending = false

	if ok and success then
		if state and state[card.Category] then
			for _, entry in state[card.Category].List do
				if entry.Id == card.Id then
					entry.Claimed = true
				end
			end
		end
		showRewardPopup(card.Button, result)
		renderAll()
	else
		card.Button.Text = "ОШИБКА"
		card.Status = "" -- чтобы следующая отрисовка вернула нормальный вид кнопки
		warn("[QuestGui] Не удалось забрать награду:", if ok then result else success)
		task.delay(1, renderAll)
	end
end

local function createCard(category: string, quest)
	local frame = create("Frame", {
		Name = quest.Id,
		Size = UDim2.new(1, 0, 0, 92),
		BackgroundColor3 = Theme.Card,
		Parent = scrollFrames[category],
	}, { corner(12) })
	local stroke = borderStroke(Theme.Stroke, 2)
	stroke.Parent = frame

	create("Frame", {
		Name = "IconBox",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(66, 66),
		BackgroundColor3 = Theme.BarBack,
		Parent = frame,
	}, {
		corner(12),
		create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = Theme.Font,
			Text = QuestConfig.TypeIcons[quest.Type] or "⭐",
			TextSize = 34,
			TextColor3 = Theme.Text,
		}),
	})

	local title = create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(92, 10),
		Size = UDim2.new(1, -258, 0, 22),
		Font = Theme.Font,
		Text = quest.Title,
		TextSize = 19,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	create("TextLabel", {
		Name = "Description",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(92, 33),
		Size = UDim2.new(1, -258, 0, 18),
		Font = Theme.FontMedium,
		Text = QuestConfig.GetDescription(quest),
		TextSize = 14,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	local bar = create("Frame", {
		Name = "Bar",
		Position = UDim2.fromOffset(92, 60),
		Size = UDim2.new(1, -258, 0, 20),
		BackgroundColor3 = Theme.BarBack,
		Parent = frame,
	}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	local fill = create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Accent,
		Visible = false,
		Parent = bar,
	}, {
		create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 185)),
		}),
	})

	local barText = create("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.Font,
		Text = "",
		TextSize = 13,
		TextColor3 = Theme.Text,
		ZIndex = 2,
		Parent = bar,
	}, { textStroke(0.3) })

	create("TextLabel", {
		Name = "Reward",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 10),
		Size = UDim2.fromOffset(146, 24),
		Font = Theme.Font,
		RichText = true,
		Text = rewardRichText(quest.Reward),
		TextSize = 17,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	}, { textStroke(0.5) })

	local button = create("TextButton", {
		Name = "Claim",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -12),
		Size = UDim2.fromOffset(146, 40),
		BackgroundColor3 = Theme.Gray,
		AutoButtonColor = false,
		Font = Theme.Font,
		Text = "",
		TextSize = 16,
		TextColor3 = Theme.Text,
		Parent = frame,
	}, { corner(10) })
	local buttonStroke = borderStroke(Theme.Stroke, 2)
	buttonStroke.Parent = button
	addButtonFx(button)

	local card = {
		Category = category,
		Id = quest.Id,
		Frame = frame,
		Stroke = stroke,
		Title = title,
		Fill = fill,
		BarText = barText,
		Button = button,
		ButtonStroke = buttonStroke,
		Status = "",
		Pending = false,
		Pct = -1,
		Pulse = nil :: Tween?,
	}

	button.Activated:Connect(function()
		claim(card)
	end)

	cards[category][quest.Id] = card
	return card
end

local function updateCard(card, quest, entry: Entry, index: number)
	local pct = math.clamp(entry.Progress / quest.Goal, 0, 1)
	local status = getStatus(quest, entry)

	-- Прогресс-бар
	card.BarText.Text = QuestConfig.ShortNumber(math.min(entry.Progress, quest.Goal)) .. " / " .. QuestConfig.ShortNumber(quest.Goal)
	if pct ~= card.Pct then
		card.Fill.Visible = pct > 0
		if card.Pct < 0 then
			card.Fill.Size = UDim2.fromScale(pct, 1)
		else
			tween(card.Fill, 0.35, { Size = UDim2.fromScale(pct, 1) })
		end
		card.Pct = pct
	end

	-- Сортировка: сначала "Забрать", потом по проценту выполнения, полученные в конце
	if status == "Claimable" then
		card.Frame.LayoutOrder = index
	elseif status == "InProgress" then
		card.Frame.LayoutOrder = 1000 + math.floor((1 - pct) * 900) * 10 + index
	else
		card.Frame.LayoutOrder = 100000 + index
	end

	if card.Pending or status == card.Status then
		return
	end
	card.Status = status

	if card.Pulse then
		card.Pulse:Cancel()
		card.Pulse = nil
	end
	card.ButtonStroke.Thickness = 2

	if status == "Claimable" then
		card.Frame.BackgroundColor3 = Theme.Card
		card.Stroke.Color = Theme.Green
		card.Title.TextColor3 = Theme.Text
		card.Fill.BackgroundColor3 = Theme.Green
		card.Button.BackgroundColor3 = Theme.Green
		card.Button.TextColor3 = Theme.Text
		card.Button.Text = "ЗАБРАТЬ!"
		card.ButtonStroke.Color = Color3.new(1, 1, 1)
		card.Pulse = TweenService:Create(
			card.ButtonStroke,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Thickness = 4 }
		)
		card.Pulse:Play()
	elseif status == "InProgress" then
		card.Frame.BackgroundColor3 = Theme.Card
		card.Stroke.Color = Theme.Stroke
		card.Title.TextColor3 = Theme.Text
		card.Fill.BackgroundColor3 = Theme.Accent
		card.Button.BackgroundColor3 = Theme.Gray
		card.Button.TextColor3 = Theme.Text
		card.Button.Text = "В ПРОЦЕССЕ"
		card.ButtonStroke.Color = Theme.Stroke
	else
		card.Frame.BackgroundColor3 = Theme.CardDone
		card.Stroke.Color = Theme.Stroke
		card.Title.TextColor3 = Theme.SubText
		card.Fill.BackgroundColor3 = Theme.Green
		card.Button.BackgroundColor3 = Theme.BarBack
		card.Button.TextColor3 = Theme.Green
		card.Button.Text = "✓ ПОЛУЧЕНО"
		card.ButtonStroke.Color = Theme.Stroke
	end
end

---------------------------------------------------------------------
-- Отрисовка
---------------------------------------------------------------------
local function renderCategory(category: string)
	local data = state and state[category]
	local list = data and data.List or {}
	local seen = {}

	for index, entry in list do
		local quest = QuestConfig.GetQuest(category, entry.Id)
		if quest then
			seen[entry.Id] = true
			local card = cards[category][entry.Id] or createCard(category, quest)
			updateCard(card, quest, entry, index)
		end
	end

	-- Удаляем карточки квестов, которых больше нет (например, после сброса дня)
	for id, card in cards[category] do
		if not seen[id] then
			if card.Pulse then
				card.Pulse:Cancel()
			end
			card.Frame:Destroy()
			cards[category][id] = nil
		end
	end
end

local lastTotal = 0
local function updateBadges()
	local total = 0
	for _, category in QuestConfig.Categories do
		local n = countClaimable(category)
		total += n
		tabBadges[category].Visible = n > 0
		tabBadges[category].Text = tostring(n)
	end
	openBadge.Visible = total > 0
	openBadge.Text = if total > 9 then "9+" else tostring(total)

	-- Значок «подпрыгивает», когда появилась новая награда
	if total > lastTotal then
		openBadge.Size = UDim2.fromOffset(40, 40)
		tween(openBadge, 0.4, { Size = UDim2.fromOffset(28, 28) }, Enum.EasingStyle.Back)
	end
	lastTotal = total
end

local lastRefreshRequest = 0
local function requestRefresh()
	if os.clock() - lastRefreshRequest < 5 then
		return
	end
	lastRefreshRequest = os.clock()
	task.spawn(function()
		local ok, newState = pcall(function()
			return getQuests:InvokeServer()
		end)
		if ok and typeof(newState) == "table" then
			state = newState
			renderAll()
		end
	end)
end

local function updateInfo()
	if not state then
		infoLabel.Text = ""
		infoRight.Text = ""
		return
	end

	local data = state[currentTab]
	local list = data and data.List or {}
	local done = 0
	for _, entry in list do
		local quest = QuestConfig.GetQuest(currentTab, entry.Id)
		if quest and entry.Progress >= quest.Goal then
			done += 1
		end
	end
	infoRight.Text = string.format("Выполнено: %d/%d", done, #list)

	if currentTab == "Achievements" then
		infoLabel.Text = "🏆 Постоянные задания, награда выдаётся один раз"
		return
	end

	local nextReset = data and data.NextReset
	if not nextReset then
		infoLabel.Text = ""
		return
	end
	local remaining = nextReset - workspace:GetServerTimeNow()
	if remaining <= 0 then
		infoLabel.Text = "🔄 Обновляем квесты..."
		requestRefresh()
	else
		infoLabel.Text = "🔄 Новые квесты через " .. formatTime(remaining)
	end
end

local function selectTab(category: string)
	currentTab = category
	for name, button in tabButtons do
		local selected = name == category
		tween(button, 0.15, {
			BackgroundColor3 = if selected then Theme.Accent else Theme.Card,
			TextColor3 = if selected then Theme.DarkText else Theme.Text,
		})
		scrollFrames[name].Visible = selected and state ~= nil
	end
	scrollFrames[category].CanvasPosition = Vector2.zero
	updateInfo()
end

renderAll = function()
	if not state then
		return
	end
	loadingLabel.Visible = false
	for _, category in QuestConfig.Categories do
		renderCategory(category)
	end
	scrollFrames[currentTab].Visible = true
	updateBadges()
	updateInfo()
end

---------------------------------------------------------------------
-- Уведомление "Квест выполнен!"
---------------------------------------------------------------------
local toastQueue = {}
local toastRunning = false

local function playToast(category: string, quest)
	local toast = create("TextButton", {
		Name = "Toast",
		Position = UDim2.fromOffset(0, -110),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Panel,
		AutoButtonColor = false,
		Text = "",
		Parent = toastHolder,
	}, {
		corner(14),
		borderStroke(Theme.Green, 3),
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(0, 60, 1, 0),
			Font = Theme.Font,
			Text = "✅",
			TextSize = 36,
			TextColor3 = Theme.Text,
		}),
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(76, 10),
			Size = UDim2.new(1, -86, 0, 26),
			Font = Theme.Font,
			Text = "Квест выполнен!",
			TextSize = 20,
			TextColor3 = Theme.Green,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, { textStroke(0.4) }),
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(76, 38),
			Size = UDim2.new(1, -86, 0, 22),
			Font = Theme.FontMedium,
			RichText = true,
			Text = quest.Title .. "  " .. rewardRichText(quest.Reward),
			TextSize = 16,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
	})

	toast.Activated:Connect(function()
		selectTab(category)
		setOpen(true)
	end)

	tween(toast, 0.35, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
	task.wait(2.8)
	local out = tween(toast, 0.25, { Position = UDim2.fromOffset(0, -110) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	out.Completed:Wait()
	toast:Destroy()
end

local function queueToast(category: string, questId: string)
	local quest = QuestConfig.GetQuest(category, questId)
	if not quest then
		return
	end
	table.insert(toastQueue, { category, quest })
	if toastRunning then
		return
	end
	toastRunning = true
	task.spawn(function()
		while #toastQueue > 0 do
			local item = table.remove(toastQueue, 1)
			playToast(item[1], item[2])
		end
		toastRunning = false
	end)
end

---------------------------------------------------------------------
-- Открытие и закрытие
---------------------------------------------------------------------
setOpen = function(open: boolean)
	if open == isOpen then
		return
	end
	isOpen = open
	if open then
		windowHolder.Visible = true
		popScale.Scale = 0.85
		tween(popScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		updateInfo()
		if not state then
			requestRefresh()
		end
	else
		local t = tween(popScale, 0.15, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		t.Completed:Once(function()
			if not isOpen then
				windowHolder.Visible = false
			end
		end)
	end
end

openButton.Activated:Connect(function()
	setOpen(not isOpen)
end)

closeButton.Activated:Connect(function()
	setOpen(false)
end)

for category, button in tabButtons do
	button.Activated:Connect(function()
		selectTab(category)
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == TOGGLE_KEY then
		setOpen(not isOpen)
	end
end)

---------------------------------------------------------------------
-- Сеть
---------------------------------------------------------------------
stateEvent.OnClientEvent:Connect(function(newState)
	if typeof(newState) == "table" then
		state = newState
		renderAll()
	end
end)

completedEvent.OnClientEvent:Connect(queueToast)

-- Адаптивность
local function watchCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsive)
	end
	updateResponsive()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

-- Таймер
task.spawn(function()
	while true do
		if isOpen then
			updateInfo()
		end
		task.wait(1)
	end
end)

selectTab(currentTab)
requestRefresh()
