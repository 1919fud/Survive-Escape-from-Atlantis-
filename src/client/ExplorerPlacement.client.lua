-- ExplorerPlacement.lua (LocalScript в StarterPlayerScripts/Client/)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- Сеть
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local PlaceExplorerEvent = GameEvents:WaitForChild("PlaceExplorerEvent")
local UpdateReadyStatusEvent = GameEvents:WaitForChild("UpdateReadyStatusEvent")
local GameStartEvent = GameEvents:WaitForChild("GameStartEvent")

local treasureLimits = {
	[1] = { current = 0, max = 2, available = true },
	[2] = { current = 0, max = 2, available = true },
	[3] = { current = 0, max = 2, available = true },
	[4] = { current = 0, max = 2, available = true },
	[5] = { current = 0, max = 2, available = true },
}

-- Функция для получения визуального цвета игрока
local function getPlayerVisualColor(playerName)
	local hash = 0
	for i = 1, #playerName do
		hash = (hash * 31 + string.byte(playerName, i)) % 360
	end

	local colors = {
		BrickColor.new("Bright red"),
		BrickColor.new("Bright blue"),
		BrickColor.new("Bright green"),
		BrickColor.new("Bright yellow"),
		BrickColor.new("Bright violet"),
		BrickColor.new("Bright orange"),
		BrickColor.new("Medium stone grey"),
		BrickColor.new("White"),
	}

	local colorIndex = (hash % #colors) + 1
	return colors[colorIndex]
end

-- Поиск существующего исследователя на тайле
local function findExistingExplorer(q, r)
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") then
			local explorerQ = obj:GetAttribute("Q")
			local explorerR = obj:GetAttribute("R")

			if explorerQ == q and explorerR == r then
				return obj
			end
		end
	end
	return nil
end

-- Эффект появления исследователя
local function spawnExplorerAppearanceEffect(explorer)
	if not explorer:IsA("Model") then
		return
	end

	local primaryPart = explorer.PrimaryPart
	if not primaryPart then
		return
	end

	-- Сохраняем оригинальный размер
	local originalSize = primaryPart.Size

	-- Эффект появления (увеличиваем из точки)
	primaryPart.Size = Vector3.new(0.1, 0.1, 0.1)

	local tweenInfo = TweenInfo.new(
		0.5, -- длительность
		Enum.EasingStyle.Back, -- тип анимации
		Enum.EasingDirection.Out -- направление
	)

	local tween = TweenService:Create(primaryPart, tweenInfo, { Size = originalSize })
	tween:Play()

	-- Добавляем свечение
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 255, 0)
	highlight.OutlineColor = Color3.fromRGB(255, 165, 0)
	highlight.FillTransparency = 0.8
	highlight.OutlineTransparency = 0
	highlight.Parent = explorer

	-- Удаляем свечение через 1 секунду
	game:GetService("Debris"):AddItem(highlight, 1)
end

-- Создание визуала исследователя
local function createExplorerVisual(playerName, treasureValue, q, r)
	-- Ищем шаблон исследователя
	local explorerTemplate = ReplicatedStorage:FindFirstChild("Explorer")
	if not explorerTemplate then
		warn("❌ Не найден шаблон Explorer в ReplicatedStorage")
		return
	end

	-- Ищем тайл по координатам
	local map = workspace:WaitForChild("Map")
	local targetTile = nil

	-- Ищем тайл с нужными координатами
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")

			if tileQ == q and tileR == r then
				targetTile = obj
				break
			end
		end
	end

	if not targetTile then
		warn("❌ Не найден тайл для отображения исследователя: Q=", q, "R=", r)
		return
	end

	-- Проверяем, не существует ли уже исследователь на этом тайле
	local existingExplorer = findExistingExplorer(q, r)
	if existingExplorer then
		existingExplorer:Destroy()
	end

	-- Создаем исследователя
	local explorer = explorerTemplate:Clone()
	explorer.Name = "Explorer_" .. playerName .. "_" .. treasureValue

	-- Убеждаемся, что у модели есть PrimaryPart
	if not explorer.PrimaryPart then
		-- Если нет PrimaryPart, ищем первую часть
		for _, part in ipairs(explorer:GetDescendants()) do
			if part:IsA("BasePart") then
				explorer.PrimaryPart = part
				break
			end
		end
	end

	if not explorer.PrimaryPart then
		warn("❌ У модели исследователя нет PrimaryPart и не найдены части")
		explorer:Destroy()
		return
	end

	-- Позиционируем над тайлом
	local yOffset = explorer.PrimaryPart.Size.Y / 2 + targetTile.Size.Y / 2 + 0.5
	explorer:SetPrimaryPartCFrame(targetTile.CFrame + Vector3.new(0, yOffset, 0))

	-- Устанавливаем цвет в зависимости от игрока
	local playerColor = getPlayerVisualColor(playerName)

	-- Применяем цвет ко всем частям модели
	for _, part in ipairs(explorer:GetDescendants()) do
		if part:IsA("BasePart") then
			part.BrickColor = playerColor
		end
	end

	-- Добавляем атрибуты
	explorer:SetAttribute("Player", playerName)
	explorer:SetAttribute("TreasureValue", treasureValue)
	explorer:SetAttribute("Q", q)
	explorer:SetAttribute("R", r)
	explorer:SetAttribute("IsExplorer", true)

	-- Помещаем в workspace
	explorer.Parent = workspace

	-- Добавляем эффект появления
	spawnExplorerAppearanceEffect(explorer)

	print("👤 Создан визуал исследователя для", playerName, "на Q=", q, "R=", r)
end

-- Создаем UI для выбора исследователей
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ExplorerPlacementUI"
screenGui.Enabled = false
screenGui.Parent = PlayerGui

-- Основной фрейм
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 400, 0, 250)
mainFrame.Position = UDim2.new(0.5, -200, 0.1, 0)
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

-- Информация о текущем ходе
local turnInfoLabel = Instance.new("TextLabel")
turnInfoLabel.Size = UDim2.new(1, -20, 0, 30)
turnInfoLabel.Position = UDim2.new(0, 10, 0, 45)
turnInfoLabel.BackgroundTransparency = 1
turnInfoLabel.Text = "Зараз ходить: ..."
turnInfoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
turnInfoLabel.TextScaled = true
turnInfoLabel.Font = Enum.Font.Gotham
turnInfoLabel.Parent = mainFrame

-- Кнопки сокровищ
local treasuresFrame = Instance.new("Frame")
treasuresFrame.Size = UDim2.new(1, -20, 0, 60)
treasuresFrame.Position = UDim2.new(0, 10, 0, 80)
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
statusLabel.Position = UDim2.new(0, 10, 0, 150)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Оберіть значення скарбів (1-5)"
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = mainFrame

-- Прогресс
local progressLabel = Instance.new("TextLabel")
progressLabel.Size = UDim2.new(1, -20, 0, 30)
progressLabel.Position = UDim2.new(0, 10, 0, 190)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "Розміщено: 0/10"
progressLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
progressLabel.TextScaled = true
progressLabel.Font = Enum.Font.Gotham
progressLabel.Parent = mainFrame

-- Панель очереди игроков
local queueFrame = Instance.new("Frame")
queueFrame.Size = UDim2.new(0, 250, 0, 150)
queueFrame.Position = UDim2.new(1, 10, 0, 0)
queueFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
queueFrame.BorderSizePixel = 0
queueFrame.Visible = false
queueFrame.Parent = screenGui

local queueTitle = Instance.new("TextLabel")
queueTitle.Size = UDim2.new(1, 0, 0, 30)
queueTitle.Position = UDim2.new(0, 0, 0, 0)
queueTitle.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
queueTitle.Text = "ЧЕРГА ГРАВЦІВ"
queueTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
queueTitle.TextScaled = true
queueTitle.Font = Enum.Font.GothamBold
queueTitle.Parent = queueFrame

local queueList = Instance.new("TextLabel")
queueList.Size = UDim2.new(1, -10, 1, -40)
queueList.Position = UDim2.new(0, 5, 0, 35)
queueList.BackgroundTransparency = 1
queueList.Text = "Завантаження..."
queueList.TextColor3 = Color3.fromRGB(255, 255, 255)
queueList.TextXAlignment = Enum.TextXAlignment.Left
queueList.TextYAlignment = Enum.TextYAlignment.Top
queueList.TextWrapped = true
queueList.Parent = queueFrame

-- Переменные
local selectedTreasureValue = nil
local isPlacementMode = false
local isMyTurn = false
local explorersPlaced = 0
local maxExplorers = 10
local currentPlayersData = {}

-- Функция для получения цвета игрока по имени (для UI)
local function getPlayerColor(playerName)
	local hash = 0
	for i = 1, #playerName do
		hash = (hash * 31 + string.byte(playerName, i)) % 360
	end

	local colorIcons = { "🔴", "🔵", "🟢", "🟡", "🟣", "🟠", "⚫", "⚪" }
	local iconIndex = (hash % #colorIcons) + 1

	return colorIcons[iconIndex]
end

-- Обновление информации об очереди
local function updateQueueDisplay(turnInfo, playersData)
	if not turnInfo then
		return
	end

	currentPlayersData = playersData or currentPlayersData

	local queueText = ""
	local currentIndex = turnInfo.currentPlayerIndex or 1

	for i, playerObj in ipairs(turnInfo.playersOrder or {}) do
		local playerName = playerObj.Name
		local playerData = currentPlayersData[playerName] or {}
		local explorersCount = playerData.explorersPlaced or 0
		local playerMaxExplorers = playerData.maxExplorers or 10

		local colorIcon = getPlayerColor(playerName)
		local status = ""

		if i == currentIndex then
			status = "🎯 ЗАРАЗ ХОДИТЬ"
		elseif explorersCount >= playerMaxExplorers then
			status = "✅ ЗАВЕРШЕНО"
		else
			status = "⏳ ЧЕКАЄ"
		end

		queueText ..= string.format(
			"%s %s: %d/%d - %s\n",
			colorIcon,
			playerName,
			explorersCount,
			playerMaxExplorers,
			status
		) -- ИСПОЛЬЗОВАТЬ НОВОЕ ИМЯ
	end

	queueList.Text = queueText
	queueFrame.Visible = true
end

-- Подсветка кнопок
local function updateButtonsHighlight()
	for value, button in pairs(treasureButtons) do
		local limitInfo = treasureLimits[value]

		if value == selectedTreasureValue then
			button.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
		elseif not limitInfo.available then
			-- Недоступно (лимит достигнут)
			button.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
			button.Text = value .. " ✗"
		else
			-- Доступно
			button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
			button.Text = value .. " (" .. limitInfo.current .. "/" .. limitInfo.max .. ")"
		end
	end
end

-- Обновление статуса UI
local function updateUIStatus()
	if isMyTurn then
		titleLabel.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
		turnInfoLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
		statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

		-- Включаем кнопки только если они доступны
		for value, button in pairs(treasureButtons) do
			local limitInfo = treasureLimits[value]
			button.Visible = true
			button.Active = limitInfo.available
		end
	else
		titleLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		turnInfoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)

		-- Выключаем все кнопки
		for _, button in pairs(treasureButtons) do
			button.Visible = false
			button.Active = false
		end
	end
end

-- Обработчики кнопок сокровищ
for value, button in pairs(treasureButtons) do
	button.MouseButton1Click:Connect(function()
		if not isMyTurn then
			return
		end

		-- Проверяем доступность значения сокровищ
		local limitInfo = treasureLimits[value]
		if not limitInfo.available then
			statusLabel.Text = "❌ Ліміт для цього значення скарбів досягнуто!"
			return
		end

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
local currentHighlightedTile = nil
local function highlightTile(tile, highlight)
	if currentHighlightedTile and currentHighlightedTile ~= tile then
		-- Сбрасываем предыдущую подсветку
		local prevTileType = currentHighlightedTile:GetAttribute("TileType")
		if prevTileType == "Beach" then
			currentHighlightedTile.BrickColor = BrickColor.new("Bright yellow")
		elseif prevTileType == "Forest" then
			currentHighlightedTile.BrickColor = BrickColor.new("Dark green")
		elseif prevTileType == "Mountain" then
			currentHighlightedTile.BrickColor = BrickColor.new("Medium stone grey")
		end
	end

	if tile and highlight then
		tile.BrickColor = BrickColor.new("Bright green")
		currentHighlightedTile = tile
	end
end

-- Обработчик клика по тайлу
local function onTileClick(tile)
	if not isPlacementMode or not isMyTurn or not selectedTreasureValue then
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

	-- Отправляем на сервер через FireServer
	PlaceExplorerEvent:FireServer(selectedTreasureValue, q, r)

	-- Сбрасываем выбор для следующего размещения
	selectedTreasureValue = nil
	updateButtonsHighlight()
	statusLabel.Text = "Оберіть значення скарбів (1-5)"
end

-- Основной цикл для отслеживания мыши
RunService.Heartbeat:Connect(function()
	if not isPlacementMode or not isMyTurn then
		if currentHighlightedTile then
			highlightTile(currentHighlightedTile, false)
			currentHighlightedTile = nil
		end
		return
	end

	local tile = getTileUnderCursor()
	highlightTile(tile, tile ~= nil)
end)

-- Обработчик клика мыши
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local tile = getTileUnderCursor()
		if tile and isPlacementMode and isMyTurn then
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

		-- Показываем очередь
		queueFrame.Visible = true
	elseif data.phase == "player_turn" and data.isYourTurn then
		-- Наш ход!
		isMyTurn = true
		turnInfoLabel.Text = "🎯 ВАШ ХІД! Оберіть дослідника"
		updateUIStatus()
		print("🎮 Ваш ход! Размещайте исследователя")
	elseif data.phase == "waiting_turn" then
		-- Ждем своего хода
		isMyTurn = false
		turnInfoLabel.Text = "⏳ Чекайте свій хід..."
		updateUIStatus()
	elseif data.phase == "placement_complete" then
		-- Фаза размещения завершена
		isPlacementMode = false
		isMyTurn = false
		screenGui.Enabled = false
		print("✅ Фаза размещения завершена!")
	end
end)

UpdateReadyStatusEvent.OnClientEvent:Connect(function(data)
	if data.type == "ExplorerPlaced" then
		-- ОБНОВЛЯЕМ ТОЛЬКО СВОЙ ПРОГРЕСС, если это наш исследователь
		if data.playerName == player.Name then
			explorersPlaced = data.explorerCount or explorersPlaced
			progressLabel.Text = "Розміщено: " .. explorersPlaced .. "/" .. maxExplorers

			if explorersPlaced >= maxExplorers then
				statusLabel.Text = "Всі дослідники розміщені!"
				isMyTurn = false
				updateUIStatus()
			end
		end

		-- Создаем визуал исследователя (для всех игроков)
		createExplorerVisual(data.playerName, data.treasureValue, data.q, data.r)

		-- Обновляем информацию о лимитах если она пришла
		if data.treasureLimits then
			treasureLimits = data.treasureLimits
			updateButtonsHighlight()
		end
	elseif data.type == "PlayerTurn" then
		-- Обновляем информацию об очереди
		local currentPlayerName = data.currentPlayer or ""
		local turnInfo = data.turnInfo or {}
		local playersData = data.playersData or {}

		-- Определяем, наш ли это ход
		isMyTurn = (currentPlayerName == player.Name)

		if isMyTurn then
			turnInfoLabel.Text = "🎯 ВАШ ХІД! Оберіть дослідника"
			-- ОБНОВЛЯЕМ СВОЙ ПРОГРЕСС ТОЛЬКО КОГДА НАШ ХОД
			local myData = playersData[player.Name] or {}
			explorersPlaced = myData.explorersPlaced or 0
			progressLabel.Text = "Розміщено: " .. explorersPlaced .. "/" .. maxExplorers
		else
			turnInfoLabel.Text = "Зараз ходить: " .. currentPlayerName
			-- СБРАСЫВАЕМ СЧЕТЧИК ЕСЛИ НЕ НАШ ХОД
			explorersPlaced = 0
			progressLabel.Text = "Розміщено: 0/" .. maxExplorers
		end

		updateUIStatus()
		updateQueueDisplay(turnInfo, playersData)

		-- Обновляем информацию о лимитах если она пришла
		if data.treasureLimits then
			treasureLimits = data.treasureLimits
			updateButtonsHighlight()
		end
	end
end)

-- Обработчик выхода игрока (чистка)
Players.PlayerRemoving:Connect(function(leftPlayer)
	-- Удаляем всех исследователей этого игрока
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") and obj:GetAttribute("Player") == leftPlayer.Name then
			obj:Destroy()
		end
	end
end)
