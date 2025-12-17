-- MainGameTurnUI.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local UpdateReadyStatusEvent = GameEvents:WaitForChild("UpdateReadyStatusEvent")
local GameStartEvent = GameEvents:WaitForChild("GameStartEvent")

-- Створюємо UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainGameTurnUI"
screenGui.Parent = PlayerGui
screenGui.Enabled = false

-- Основний фрейм
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 100)
mainFrame.Position = UDim2.new(1, -310, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Інформація про хід
local turnLabel = Instance.new("TextLabel")
turnLabel.Size = UDim2.new(1, -10, 0, 30)
turnLabel.Position = UDim2.new(0, 5, 0, 5)
turnLabel.BackgroundTransparency = 1
turnLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
turnLabel.Text = "Хід: "
turnLabel.TextSize = 16
turnLabel.Font = Enum.Font.GothamBold
turnLabel.Parent = mainFrame

-- Лічильник дій
local actionsLabel = Instance.new("TextLabel")
actionsLabel.Size = UDim2.new(1, -10, 0, 30)
actionsLabel.Position = UDim2.new(0, 5, 0, 35)
actionsLabel.BackgroundTransparency = 1
actionsLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
actionsLabel.Text = "Дій залишилось: 3/3"
actionsLabel.TextSize = 14
actionsLabel.Font = Enum.Font.Gotham
actionsLabel.Parent = mainFrame

-- Номер раунду
local roundLabel = Instance.new("TextLabel")
roundLabel.Size = UDim2.new(1, -10, 0, 30)
roundLabel.Position = UDim2.new(0, 5, 0, 65)
roundLabel.BackgroundTransparency = 1
roundLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
roundLabel.Text = "Раунд: 1"
roundLabel.TextSize = 12
roundLabel.Font = Enum.Font.Gotham
roundLabel.Parent = mainFrame

-- Обробники подій
UpdateReadyStatusEvent.OnClientEvent:Connect(function(data)
	if data.type == "MainGameTurn" then
		screenGui.Enabled = true

		if data.currentPlayer == player.Name then
			turnLabel.Text = "🎮 ВАШ ХІД!"
			turnLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
			actionsLabel.Text = string.format(
				"💰 Монет залишилось: %d/%d",
				data.remainingActions or 3,
				data.maxActions or 3
			)
		else
			turnLabel.Text = "Ходить: " .. data.currentPlayer
			turnLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			actionsLabel.Text = "⏳ Чекайте свій хід..."
		end

		if data.turnInfo and data.turnInfo.currentRound then
			roundLabel.Text = "Раунд: " .. data.turnInfo.currentRound
		end
	elseif data.type == "ExplorerMoved" then
		if player.Name == data.playerName then
			actionsLabel.Text =
				string.format("Переміщено! Витрачено: %d монет", data.moveCost or 1)

			-- Оновлюємо через 2 секунди
			task.delay(2, function()
				if actionsLabel then
					local remaining = data.remainingActions or 0
					if remaining > 0 then
						actionsLabel.Text = string.format("💰 Монет залишилось: %d/3", remaining)
						--[[else
						actionsLabel.Text = "⏳ Очікування наступного ходу..."]]
						--
					end
				end
			end)
		end
	end
end)

GameStartEvent.OnClientEvent:Connect(function(data)
	if data.phase == "main_game_active" then
		screenGui.Enabled = true
	elseif data.phase == "placement" or data.phase == "boats_placement" then
		screenGui.Enabled = false
	end
end)

print("✅ UI черги ходів для основної гри завантажено")
