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

-- Функция для получения цвета игрока по имени
local function getPlayerColor(playerName)
	-- Простая хэш-функция для генерации цвета из имени
	local hash = 0
	for i = 1, #playerName do
		hash = (hash * 31 + string.byte(playerName, i)) % 360
	end

	-- Используем разные иконки в зависимости от хэша
	local colorIcons = { "🔴", "🔵", "🟢", "🟡", "🟣", "🟠", "⚫", "⚪" }
	local iconIndex = (hash % #colorIcons) + 1

	return colorIcons[iconIndex]
end

-- Функция обновления статуса
-- ReadyUI.lua - исправленная функция updateStatusDisplay
local function updateStatusDisplay(statusData)
	-- Перевіряємо тип даних - якщо це не таблиця, виходимо
	if type(statusData) ~= "table" then
		return
	end

	-- ДОДАЄМО ПЕРЕВІРКУ: якщо це дані про розміщення дослідників, ігноруємо
	if statusData.type then
		-- Це повідомлення про розміщення дослідника, а не статус готовності
		return
	end

	local readyCount = 0
	local totalCount = 0
	local statusText = ""

	for playerName, data in pairs(statusData) do
		-- Безпечна перевірка типів
		if type(data) == "table" and data.isReady ~= nil then
			totalCount += 1

			-- Використовуємо функцію для отримання кольору
			local colorIcon = getPlayerColor(playerName)

			if data.isReady then
				readyCount += 1
				statusText ..= colorIcon .. " " .. (data.displayName or playerName) .. " - ГОТОВ\n"
			else
				statusText ..= colorIcon .. " " .. (data.displayName or playerName) .. " - НЕ ГОТОВ\n"
			end
		end
	end

	if totalCount > 0 then
		statusLabel.Text = string.format("Готові: %d/%d\n\n%s", readyCount, totalCount, statusText)
	else
		statusLabel.Text = "Очікування гравців..."
	end
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
GameStartEvent.OnClientEvent:Connect(function(data)
	-- Извлекаем countdown из таблицы данных
	local countdownTime = data.countdown or data -- поддержка старого формата

	if type(countdownTime) == "table" then
		countdownTime = data.countdown or 3 -- значение по умолчанию
	end

	timerLabel.Visible = true

	-- Обратный отсчет
	for i = countdownTime, 1, -1 do
		timerLabel.Text = "Гра починається через: " .. i
		wait(1)
	end

	timerLabel.Text = "ГРА ПОЧИНАЄТЬСЯ!"

	-- Скрываем интерфейс
	screenGui.Enabled = false
end)

task.delay(0.001, function()
	-- Відправляємо запит на сервер для отримання поточного статусу
	PlayerReadyEvent:FireServer(false) -- Просто для ініціалізації

	print("📡 Запитуємо поточний статус гравців...")
end)

-- Додайте обробник для PlayerRemoving для оновлення списку
game:GetService("Players").PlayerRemoving:Connect(function(leftPlayer)
	-- Можна додати логіку для видалення гравця зі списку
	print("👤 Гравець вийшов:", leftPlayer.Name)
end)

print("✅ UI готовности загружен")
