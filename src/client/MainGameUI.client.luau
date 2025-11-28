-- MainGameUI.client.lua (LocalScript в StarterPlayerScripts/Client/)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local GameStartEvent = GameEvents:WaitForChild("GameStartEvent")

-- Создаем простой UI для основной игры
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainGameUI"
screenGui.Parent = PlayerGui
screenGui.Enabled = false

-- Основной фрейм
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 400, 0, 120)
mainFrame.Position = UDim2.new(0.5, -200, 0, 50)
mainFrame.AnchorPoint = Vector2.new(0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Заголовок
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, 0, 0, 40)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Text = "🎮 ОСНОВНА ГРА"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 18
titleLabel.Parent = mainFrame

-- Сообщение
local messageLabel = Instance.new("TextLabel")
messageLabel.Name = "MessageLabel"
messageLabel.Size = UDim2.new(1, 0, 0, 40)
messageLabel.Position = UDim2.new(0, 0, 0, 40)
messageLabel.BackgroundTransparency = 1
messageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
messageLabel.Text = "Гра триває..."
messageLabel.Font = Enum.Font.Gotham
messageLabel.TextSize = 14
messageLabel.Parent = mainFrame

-- Инструкция
local instructionLabel = Instance.new("TextLabel")
instructionLabel.Name = "InstructionLabel"
instructionLabel.Size = UDim2.new(1, 0, 0, 40)
instructionLabel.Position = UDim2.new(0, 0, 0, 80)
instructionLabel.BackgroundTransparency = 1
instructionLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
instructionLabel.Text = "Скоро з'явиться можливість переміщати шукачів"
instructionLabel.Font = Enum.Font.Gotham
instructionLabel.TextSize = 12
instructionLabel.TextWrapped = true
instructionLabel.Parent = mainFrame

-- Обработчик начала игры
GameStartEvent.OnClientEvent:Connect(function(data)
	if data.phase == "main_game" then
		screenGui.Enabled = true
		messageLabel.Text = data.message or "Підготовка до гри..."

		-- Показываем обратный отсчет
		if data.countdown then
			for i = data.countdown, 1, -1 do
				messageLabel.Text = "Гра починається через: " .. i
				wait(1)
			end
		end
	elseif data.phase == "main_game_active" then
		messageLabel.Text = data.message or "Гра триває!"
		instructionLabel.Text = "Система переміщення шукачів готується..."
	else
		screenGui.Enabled = false
	end
end)

print("✅ UI основной игры загружен")
