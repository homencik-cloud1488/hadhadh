--[[
	OpenShopButton_Toggle (LocalScript)
	Вариант с переключением: нажал — открыл, нажал ещё раз — закрыл.
	Плюс кнопка закрытия внутри самого окна (если она есть).

	Куда положить: внутрь кнопки-открывашки в PlayerGui/StarterGui.
]]

local plr = game.Players.LocalPlayer

local playerGui = plr:WaitForChild("PlayerGui")
local shopGui = playerGui:WaitForChild("ShopGui")
local frame = shopGui:WaitForChild("Frame")

-- Открыть / закрыть по нажатию на кнопку
script.Parent.MouseButton1Click:Connect(function()
	frame.Visible = not frame.Visible
end)

-- Закрыть по кнопке внутри окна (имя поправь под свою кнопку)
local closeButton = frame:FindFirstChild("CloseButton")
if closeButton then
	closeButton.MouseButton1Click:Connect(function()
		frame.Visible = false
	end)
end
