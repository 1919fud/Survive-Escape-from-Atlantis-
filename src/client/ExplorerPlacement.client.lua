-- 1. Тут
-- ExplorerPlacement.lua (LocalScript в StarterPlayerScripts/Client/)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- Сеть
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local PlaceExplorerEvent = GameEvents:WaitForChild("PlaceExplorerEvent")
local UpdateReadyStatusEvent = GameEvents:WaitForChild("UpdateReadyStatusEvent")
local GameStartEvent = GameEvents:WaitForChild("GameStartEvent")

-- Создаем UI для выбора исследователей
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ExplorerPlacementUI"
screenGui.Enabled = false
screenGui.Parent = PlayerGui

-- Основной фрейм
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 350, 0, 200)
mainFrame.Position = UDim2.new(0.5, -175, 0.1, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Заголовок
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 40)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
titleLabel.Text = "ВИБІР ДОСЛІДНИКА"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = mainFrame

-- Кнопки сокровищ
local treasuresFrame = Instance.new("Frame")
treasuresFrame.Size = UDim2.new(1, -20, 0, 60)
treasuresFrame.Position = UDim2.new(0, 10, 0, 50)
treasuresFrame.BackgroundTransparency = 1
treasuresFrame.Parent = mainFrame

local treasureButtons = {}
local treasureValues = { 1, 2, 3, 4, 5 }

for i, value in ipairs(treasureValues) do
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 50, 0, 50)
	button.Position = UDim2.new(0, (i - 1) * 60, 0, 0)
	button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	button.Text = tostring(value)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Parent = treasuresFrame

	treasureButtons[value] = button
end

-- Статус
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 40)
statusLabel.Position = UDim2.new(0, 10, 0, 120)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Оберіть значення скарбів (1-5)"
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = mainFrame

-- Прогресс
local progressLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 30)
statusLabel.Position = UDim2.new(0, 10, 0, 160)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Розміщено: 0/10"
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = mainFrame

-- 1. Тут

-- Переменные
local selectedTreasureValue = nil
local isPlacementMode = false
local explorersPlaced = 0
local maxExplorers = 10

-- Подсветка кнопок
local function updateButtonsHighlight()
	for value, button in pairs(treasureButtons) do
		if value == selectedTreasureValue then
			button.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
		else
			button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		end
	end
end

-- Обработчики кнопок сокровищ
for value, button in pairs(treasureButtons) do
	button.MouseButton1Click:Connect(function()
		selectedTreasureValue = value
		updateButtonsHighlight()
		statusLabel.Text = "Обрано скарбів: " .. value .. " → Клікніть на тайл землі"
		print("🎒 Выбрано исследователя с сокровищами:", value)
	end)
end

-- Функция для определения тайла под курсором
local function getTileUnderCursor()
	local mouse = player:GetMouse()
	local target = mouse.Target

	if target and target:GetAttribute("IsLand") then
		return target
	end

	return nil
end

-- Подсветка тайла
local function highlightTile(tile, highlight)
	if tile then
		if highlight then
			tile.BrickColor = BrickColor.new("Bright green")
		else
			-- Возвращаем оригинальный цвет
			local tileType = tile:GetAttribute("TileType")
			if tileType == "Beach" then
				tile.BrickColor = BrickColor.new("Bright yellow")
			elseif tileType == "Forest" then
				tile.BrickColor = BrickColor.new("Dark green")
			elseif tileType == "Mountain" then
				tile.BrickColor = BrickColor.new("Medium stone grey")
			end
		end
	end
end

-- Обработчик клика по тайлу
local function onTileClick(tile)
	if not isPlacementMode or not selectedTreasureValue then
		return
	end

	local q = tile:GetAttribute("Q") or tile:GetAttribute("q")
	local r = tile:GetAttribute("R") or tile:GetAttribute("r")

	if not q or not r then
		warn("❌ У тайла нет координат Q R")
		return
	end

	print(
		"📍 Размещение исследователя на Q=",
		q,
		"R=",
		r,
		"с сокровищами:",
		selectedTreasureValue
	)

	-- Отправляем на сервер
	local success = PlaceExplorerEvent:InvokeServer(selectedTreasureValue, q, r)

	if success then
		-- Сбрасываем выбор для следующего размещения
		selectedTreasureValue = nil
		updateButtonsHighlight()
		statusLabel.Text = "Оберіть значення скарбів (1-5)"
	end
end

-- Основной цикл для отслеживания мыши
RunService.Heartbeat:Connect(function()
	if not isPlacementMode then
		return
	end

	local tile = getTileUnderCursor()

	-- Обновляем подсветку
	if tile then
		highlightTile(tile, true)
	else
		-- Сбрасываем подсветку всех тайлов (упрощенная версия)
	end
end)

-- Обработчик клика мыши
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local tile = getTileUnderCursor()
		if tile and isPlacementMode then
			onTileClick(tile)
		end
	end
end)

-- Обработчики сетевых событий
GameStartEvent.OnClientEvent:Connect(function(data)
	if data.phase == "placement" then
		-- Начинаем фазу размещения
		isPlacementMode = true
		screenGui.Enabled = true
		statusLabel.Text = "Оберіть значення скарбів (1-5)"
		print("🎯 Фаза размещения исследователей начата!")
	end
end)

UpdateReadyStatusEvent.OnClientEvent:Connect(function(data)
	if data.type == "ExplorerPlaced" then
		-- Обновляем прогресс
		explorersPlaced = data.explorerCount
		progressLabel.Text = "Розміщено: " .. explorersPlaced .. "/" .. maxExplorers

		if explorersPlaced >= maxExplorers then
			statusLabel.Text = "Всі дослідники розміщені!"
			isPlacementMode = false
		end
	end
end)

print("✅ Система размещения исследователей загружена")
