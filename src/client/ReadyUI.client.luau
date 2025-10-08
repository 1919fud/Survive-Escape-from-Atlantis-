-- ReadyUI.lua (LocalScript в StarterPlayerScripts/Client/)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Ждем пока загрузится PlayerGui
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- Ждем события игры
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local PlayerReadyEvent = GameEvents:WaitForChild("PlayerReadyEvent")
local UpdateReadyStatusEvent = GameEvents:WaitForChild("UpdateReadyStatusEvent")
local GameStartEvent = GameEvents:WaitForChild("GameStartEvent")

-- Создаем интерфейс
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ReadyUI"
screenGui.Parent = PlayerGui

-- Основной фрейм
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 400, 0, 300)
mainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Заголовок
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 60)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
titleLabel.Text = "ВИЖАТИ: ВТЕЧА З ОСТРОВА"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = mainFrame

-- Кнопка готовности
local readyButton = Instance.new("TextButton")
readyButton.Size = UDim2.new(0, 200, 0, 50)
readyButton.Position = UDim2.new(0.5, -100, 0.7, -25)
readyButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
readyButton.Text = "ГОТОВО"
readyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
readyButton.TextScaled = true
readyButton.Font = Enum.Font.GothamBold
readyButton.Parent = mainFrame

-- Статус игроков
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -40, 0, 100)
statusLabel.Position = UDim2.new(0, 20, 0, 70)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Очікування гравців..."
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextScaled = true
statusLabel.TextWrapped = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = mainFrame

-- Таймер начала игры
local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, 0, 0, 40)
timerLabel.Position = UDim2.new(0, 0, 0, 180)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = ""
timerLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
timerLabel.TextScaled = true
timerLabel.Font = Enum.Font.GothamBold
timerLabel.Visible = false
timerLabel.Parent = mainFrame

-- Переменные
local isPlayerReady = false

-- Функция обновления статуса
local function updateStatusDisplay(statusData)
	local readyCount = 0
	local totalCount = 0
	local statusText = ""

	for playerName, data in pairs(statusData) do
		totalCount += 1
		if data.isReady then
			readyCount += 1
			statusText ..= "🟢 " .. (data.displayName or playerName) .. " - ГОТОВ\n"
		else
			statusText ..= "🔴 " .. (data.displayName or playerName) .. " - НЕ ГОТОВ\n"
		end
	end

	statusLabel.Text = string.format("Готові: %d/%d\n\n%s", readyCount, totalCount, statusText)
end

-- Обработчик нажатия кнопки
readyButton.MouseButton1Click:Connect(function()
	isPlayerReady = not isPlayerReady

	if isPlayerReady then
		readyButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
		readyButton.Text = "НЕ ГОТОВ"
		readyButton.Interactable = false
	else
		readyButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
		readyButton.Text = "ГОТОВО"
	end

	-- Отправляем статус на сервер
	PlayerReadyEvent:FireServer(isPlayerReady)
end)

-- Получение обновлений статуса от сервера
UpdateReadyStatusEvent.OnClientEvent:Connect(function(statusData)
	updateStatusDisplay(statusData)
end)

-- Обработчик начала игры
GameStartEvent.OnClientEvent:Connect(function(countdownTime)
	timerLabel.Visible = true

	-- Обратный отсчет
	for i = countdownTime, 1, -1 do
		timerLabel.Text = "Гра починається через: " .. i
		wait(1)
	end

	timerLabel.Text = "ГРА ПОЧИНАЄТЬСЯ!"
	wait(1)

	-- Скрываем интерфейс
	screenGui.Enabled = false
end)

print("✅ UI готовности загружен")
