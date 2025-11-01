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
local screenGui = PlayerGui:WaitForChild("ReadyUI")
-- Основной фрейм
local mainFrame = screenGui:WaitForChild("Frame")
-- Кнопка готовности
local readyButton = mainFrame:WaitForChild("ReadyButton")
-- Статус игроков
local statusLabel = mainFrame:WaitForChild("StatusLabel")

-- Таймер начала игры
local timerLabel = mainFrame:WaitForChild("TimerLabel")

-- Переменные
screenGui.Enabled = true
local isPlayerReady = false

-- В ReadyUI.lua обновить функцию updateStatusDisplay:
local function updateStatusDisplay(statusData)
	local readyCount = 0
	local totalCount = 0
	local statusText = ""

	for playerName, data in pairs(statusData) do
		totalCount += 1
		local colorIcon = "⚪" -- Белый по умолчанию

		-- Добавляем цветные иконки в зависимости от цвета игрока
		if data.color then
			if data.color.R > 0.8 and data.color.G < 0.3 and data.color.B < 0.3 then
				colorIcon = "🔴" -- Красный
			elseif data.color.R < 0.3 and data.color.G < 0.3 and data.color.B > 0.8 then
				colorIcon = "🔵" -- Синий
			elseif data.color.R < 0.3 and data.color.G > 0.8 and data.color.B < 0.3 then
				colorIcon = "🟢" -- Зеленый
			elseif data.color.R > 0.8 and data.color.G > 0.8 and data.color.B < 0.3 then
				colorIcon = "🟡" -- Желтый
			elseif data.color.R > 0.7 and data.color.G < 0.5 and data.color.B > 0.7 then
				colorIcon = "🟣" -- Фиолетовый
			end
		end

		if data.isReady then
			readyCount += 1
			statusText ..= colorIcon .. " " .. (data.displayName or playerName) .. " - ГОТОВ\n"
		else
			statusText ..= colorIcon .. " " .. (data.displayName or playerName) .. " - НЕ ГОТОВ\n"
		end
	end

	statusLabel.Text = string.format("Готові: %d/%d\n\n%s", readyCount, totalCount, statusText)
end
--[[-- Функция обновления статуса
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
]]
--
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
