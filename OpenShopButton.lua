--[[
	OpenShopButton (LocalScript)

	Куда положить:
		StarterGui -> ShopGui -> ... -> Кнопка (TextButton/ImageButton)
		и этот код вставить ВНУТРЬ этой кнопки как LocalScript.

	Важно: должен быть именно LocalScript (Script на клиенте не сработает).
]]

local plr = game.Players.LocalPlayer

-- Ждём, пока у игрока точно появится PlayerGui и ShopGui
local playerGui = plr:WaitForChild("PlayerGui")
local shopGui = playerGui:WaitForChild("ShopGui")
local frame = shopGui:WaitForChild("Frame")

-- ИСПРАВЛЕНО: было MouseButton1Click;connect(function)  ->  :Connect(function()
script.Parent.MouseButton1Click:Connect(function()
	frame.Visible = true
end)
