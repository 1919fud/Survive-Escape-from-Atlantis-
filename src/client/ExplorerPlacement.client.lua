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
local PlaceBoatEvent = GameEvents:WaitForChild("PlaceBoatEvent")

local playerTreasureLimits = {
	[1] = { current = 0, max = 2, available = true },
	[2] = { current = 0, max = 2, available = true },
	[3] = { current = 0, max = 2, available = true },
	[4] = { current = 0, max = 2, available = true },
	[5] = { current = 0, max = 2, available = true },
}
local playerBoatsPlaced = 0
local playerMaxBoats = 2
local currentPhase = "explorers"
local selectedTreasureValue = nil
local isPlacementMode = false
local isMyTurn = false
local explorersPlaced = 0
local maxExplorers = 10
local currentPlayersData = {}
local currentHighlightedTile = nil

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
-- Створення визуала дослідника
local function createExplorerVisual(playerName, treasureValue, q, r, explorerId)
	-- Знаходимо шаблон дослідника
	local explorerTemplate = ReplicatedStorage:FindFirstChild("Explorer")
	if not explorerTemplate then
		warn("❌ Не знайдений шаблон Explorer в ReplicatedStorage")
		return
	end

	-- Шукаємо тайл за координатами
	local map = workspace:WaitForChild("Map")
	local targetTile = nil
	local isWaterTile = false

	-- Спочатку шукаємо тайл острова
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
			local isLand = obj:GetAttribute("IsLand")

			if tileQ == q and tileR == r and isLand == true then
				targetTile = obj
				isWaterTile = false
				break
			end
		end
	end

	-- Якщо не знайшли острів, шукаємо воду
	if not targetTile then
		for _, obj in ipairs(map:GetDescendants()) do
			if obj:IsA("MeshPart") then
				local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
				local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
				local isWater = obj:GetAttribute("IsWater") or obj:GetAttribute("Placeboat")

				if tileQ == q and tileR == r and isWater then
					targetTile = obj
					isWaterTile = true
					break
				end
			end
		end
	end

	if not targetTile then
		warn(
			"❌ Не знайдений тайл для відображення дослідника: Q=",
			q,
			"R=",
			r
		)
		return
	end

	-- ВИПРАВЛЕННЯ: Рахуємо вже існуючих дослідників на цьому тайлі
	local existingExplorersOnTile = {}
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") then
			local expQ = obj:GetAttribute("Q")
			local expR = obj:GetAttribute("R")
			if expQ == q and expR == r then
				table.insert(existingExplorersOnTile, obj)
			end
		end
	end

	local explorerIndex = #existingExplorersOnTile + 1
	local maxExplorersPerTile = 6

	-- Створюємо дослідника
	local explorer = explorerTemplate:Clone()
	explorer.Name = "Explorer_" .. playerName .. "_" .. treasureValue .. "_" .. explorerId

	-- Переконуємося, що у моделі є PrimaryPart
	if not explorer.PrimaryPart then
		for _, part in ipairs(explorer:GetDescendants()) do
			if part:IsA("BasePart") then
				explorer.PrimaryPart = part
				break
			end
		end
	end

	if not explorer.PrimaryPart then
		warn("❌ У моделі дослідника немає PrimaryPart і не знайдені частини")
		explorer:Destroy()
		return
	end

	-- Позиціонуємо на тайлі зі зміщенням
	local tilePosition = targetTile.Position

	if isWaterTile then
		-- Позиціонування на воді зі зміщенням
		local baseHeight = 4.38

		-- Розраховуємо зміщення по колу
		local angle = (explorerIndex - 1) * (360 / maxExplorersPerTile)
		local radius = 1.5

		local offsetX = math.cos(math.rad(angle)) * radius
		local offsetZ = math.sin(math.rad(angle)) * radius

		local explorerPosition = Vector3.new(tilePosition.X + offsetX, baseHeight, tilePosition.Z + offsetZ)

		local rotatedCFrame = CFrame.new(explorerPosition) * CFrame.Angles(0, math.rad(90 + angle), 0)
		explorer:SetPrimaryPartCFrame(rotatedCFrame)
	else
		-- Позиціонування на суші зі зміщенням
		local baseHeight = 0
		local targetTileType = targetTile:GetAttribute("TileType")

		if targetTileType == "Beach" then
			baseHeight = 6.062
		elseif targetTileType == "Forest" then
			baseHeight = 7.037
		elseif targetTileType == "Mountain" then
			baseHeight = 8.007
		else
			baseHeight = 6
		end

		-- Розраховуємо зміщення по колу
		local angle = (explorerIndex - 1) * (360 / maxExplorersPerTile)
		local radius = 2.0

		local offsetX = math.cos(math.rad(angle)) * radius
		local offsetZ = math.sin(math.rad(angle)) * radius

		local explorerPosition = Vector3.new(tilePosition.X + offsetX, baseHeight, tilePosition.Z + offsetZ)

		local rotatedCFrame = CFrame.new(explorerPosition) * CFrame.Angles(0, math.rad(90 + angle), 0)
		explorer:SetPrimaryPartCFrame(rotatedCFrame)
	end

	-- Встановлюємо колір залежно від гравця
	local playerColor = getPlayerVisualColor(playerName)

	-- Застосовуємо колір до всіх частин моделі
	for _, part in ipairs(explorer:GetDescendants()) do
		if part:IsA("BasePart") then
			part.BrickColor = playerColor
		end
	end

	-- Додаємо атрибути
	explorer:SetAttribute("Player", playerName)
	explorer:SetAttribute("TreasureValue", treasureValue)
	explorer:SetAttribute("ExplorerId", explorerId)
	explorer:SetAttribute("Q", q)
	explorer:SetAttribute("R", r)
	explorer:SetAttribute("IsExplorer", true)
	explorer:SetAttribute("IsOnWater", isWaterTile)
	explorer:SetAttribute("TilePositionIndex", explorerIndex)

	-- Поміщаємо в workspace
	explorer.Parent = workspace

	-- Додаємо ефект появи
	spawnExplorerAppearanceEffect(explorer)

	print(
		"👤 Створений візуал дослідника для",
		playerName,
		"на Q=",
		q,
		"R=",
		r,
		"позиція:",
		explorerIndex,
		"/",
		maxExplorersPerTile,
		isWaterTile and "(вода)" or "(суша)"
	)
end

-- Создаем UI для выбора исследователей
local screenGui = PlayerGui:WaitForChild("ExplorerPlacementUI")
screenGui.Enabled = false
-- Основной фрейм
local mainFrame = screenGui:WaitForChild("MainFrame")

-- Заголовок
local titleLabel = mainFrame:WaitForChild("TitleLabel")

-- Информация о текущем ходе
local turnInfoLabel = mainFrame:WaitForChild("TurnInfoLabel")

-- Кнопки сокровищ
local treasuresFrame = screenGui:WaitForChild("TreasuresFrame")

local treasureButtons = {}
local treasureValues = { 1, 2, 3, 4, 5 }

for i, value in ipairs(treasureValues) do
	local buttonName = "TreasureButton" .. value
	local button = treasuresFrame:WaitForChild(buttonName)
	button.Position = UDim2.new(0, 0, 0, (i - 1) * 60)
	treasureButtons[value] = button
end

-- Статус
local statusLabel = mainFrame:WaitForChild("StatusLabel")

-- Прогресс
local progressLabel = mainFrame:WaitForChild("ProgressLabel")

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
	if not playersData then
		return
	end

	currentPlayersData = playersData or currentPlayersData

	local queueText = ""
	local currentPlayerName = turnInfo and turnInfo.currentPlayer and turnInfo.currentPlayer.Name or ""

	for playerName, playerData in pairs(playersData) do
		local boatsCount = playerData.boatsPlaced or 0
		local maxBoats = playerData.maxBoats or 2

		local colorIcon = getPlayerColor(playerName)
		local status = ""

		if playerName == currentPlayerName then
			status = "🚤 ЗАРАЗ ХОДИТЬ"
		elseif boatsCount >= maxBoats then
			status = "✅ ЗАВЕРШЕНО"
		else
			status = "⏳ ЧЕКАЄ"
		end

		queueText ..= string.format("%s %s: %d/%d чов. - %s\n", colorIcon, playerName, boatsCount, maxBoats, status)
	end
end

-- Подсветка кнопок
local function updateButtonsHighlight()
	for value, button in pairs(treasureButtons) do
		local limitInfo = playerTreasureLimits[value]

		if value == selectedTreasureValue then
			button.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
		elseif not limitInfo or not limitInfo.available then
			-- Недоступно (ліміт гравця досягнутий)
			button.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
			button.Text = value .. " X (" .. (limitInfo and limitInfo.current or 0) .. "/2)"
		else
			-- Доступно
			button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
			button.Text = value .. " (" .. (limitInfo and limitInfo.current or 0) .. "/2)"
		end
	end
end

-- Обновление статуса UI
local function updateUIStatus()
	if isMyTurn then
		statusLabel.Text = "Оберіть значення скарбів (1-5)"
		titleLabel.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
		turnInfoLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
		statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

		-- ВКЛЮЧАЄМО кнопки тільки якщо вони доступні
		for value, button in pairs(treasureButtons) do
			local limitInfo = playerTreasureLimits[value]
			button.Visible = true
			button.Active = limitInfo and limitInfo.available or false
		end
	else
		titleLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		turnInfoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)

		-- ВИМИКАЄМО всі кнопки
		for _, button in pairs(treasureButtons) do
			button.Visible = false
			button.Active = false
		end
	end
end

-- Обработчики кнопок сокровищ
for value, button in pairs(treasureButtons) do
	button.MouseButton1Click:Connect(function()
		if not isMyTurn or currentPhase ~= "explorers" then
			return
		end

		-- Проверяем доступность значения сокровищ
		local limitInfo = playerTreasureLimits[value]
		if not limitInfo or not limitInfo.available then
			statusLabel.Text = "❌ Ліміт для цього значення скарбів досягнуто!"
			return
		end

		selectedTreasureValue = value
		updateButtonsHighlight()
		statusLabel.Text = "Обрано скарбів: "
			.. value
			.. " → Клікніть на тайл острова"
		print("🎒 Выбрано исследователя с сокровищами:", value)
	end)
end

-- Функция для определения тайла под курсором
local function getTileUnderCursor()
	local mouse = player:GetMouse()
	local target = mouse.Target

	if target then
		-- Перевіряємо всі можливі типи тайлів
		local isLand = target:GetAttribute("IsLand") == true
		local isWater = target:GetAttribute("IsWater") == true or target:GetAttribute("Placeboat") == true
		local hasCoords = (target:GetAttribute("Q") ~= nil or target:GetAttribute("q") ~= nil)
			and (target:GetAttribute("R") ~= nil or target:GetAttribute("r") ~= nil)

		if hasCoords and (isLand or isWater) then
			return target
		end
	end

	return nil
end

-- Обработчик клика по тайлу
local function onTileClick(tile)
	if not isPlacementMode or not isMyTurn then
		return
	end

	local q = tile:GetAttribute("Q") or tile:GetAttribute("q")
	local r = tile:GetAttribute("R") or tile:GetAttribute("r")

	if not q or not r then
		warn("❌ У тайла нет координат Q R")
		return
	end

	if currentPhase == "explorers" then
		-- Фаза дослідників
		if not selectedTreasureValue then
			statusLabel.Text = "❌ Спочатку оберіть значення скарбів!"
			updateButtonsHighlight()
			return
		end

		if tile:GetAttribute("IsLand") == true then
			local existingExplorer = findExistingExplorer(q, r)
			if existingExplorer then
				statusLabel.Text =
					"❌ На цьому тайлі вже є дослідник! Фаза розміщення - лиміт 1 на тайлі"
				updateButtonsHighlight()
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
			PlaceExplorerEvent:FireServer(selectedTreasureValue, q, r)
			updateButtonsHighlight()
			selectedTreasureValue = nil
		else
			statusLabel.Text = "❌ Тут не можна ставити дослідника (не земля)"
			warn("❌ Тайл не є землею для розміщення дослідника")
			updateButtonsHighlight()
		end
		statusLabel.Text = "Оберіть значення скарбів (1-5)"
	elseif currentPhase == "boats" then
		-- Фаза човнів
		if tile:GetAttribute("Placeboat") == true then
			print("🚤 Размещение човна на Q=", q, "R=", r)
			PlaceBoatEvent:FireServer(q, r)
		else
			statusLabel.Text = "❌ На цей тайл не можна ставити човен"
			warn("❌ Тайл не є водою для розміщення човна")
		end
	end
end

-- Основной цикл для отслеживания мыши
RunService.Heartbeat:Connect(function()
	if not isPlacementMode or not isMyTurn then
		if currentHighlightedTile then
			-- Сбрасываем подсветку
			local existingHighlight = currentHighlightedTile:FindFirstChild("TileHighlight")
			if existingHighlight then
				existingHighlight:Destroy()
			end
			currentHighlightedTile = nil
		end
		return
	end

	local tile = getTileUnderCursor()

	if currentPhase == "explorers" then
		-- Подсветка для исследователей (зеленая)
		if currentHighlightedTile and currentHighlightedTile ~= tile then
			-- Сбрасываем предыдущую подсветку
			local existingHighlight = currentHighlightedTile:FindFirstChild("TileHighlight")
			if existingHighlight then
				existingHighlight:Destroy()
			end
		end
		-- example tile = Title_3_4 нам нада от название только Title как написать в условии
		if tile then
			-- Удаляем старый highlight если есть
			local existingHighlight = tile:FindFirstChild("TileHighlight")
			if existingHighlight then
				existingHighlight:Destroy()
			end

			-- Создаем новый highlight
			local highlight = Instance.new("Highlight")
			highlight.Name = "TileHighlight"

			if tile:GetAttribute("IsLand") == true then
				-- Зеленая подсветка для земли
				highlight.FillColor = Color3.fromRGB(38, 135, 57)
				highlight.OutlineColor = Color3.fromRGB(0, 255, 38)
				highlight.FillTransparency = 0.8
				highlight.OutlineTransparency = 0
			else
				-- Красная подсветка для воды/недоступных тайлов
				highlight.FillColor = Color3.fromRGB(167, 33, 33)
				highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
				highlight.FillTransparency = 0.8
				highlight.OutlineTransparency = 0
			end

			highlight.Parent = tile
			currentHighlightedTile = tile
		end
	elseif currentPhase == "boats" then
		-- Специальная подсветка для лодок
		if currentHighlightedTile and currentHighlightedTile ~= tile then
			-- Сбрасываем предыдущую подсветку
			local existingHighlight = currentHighlightedTile:FindFirstChild("TileHighlight")
			if existingHighlight then
				existingHighlight:Destroy()
			end
		end

		if tile then
			-- Удаляем старый highlight если есть
			local existingHighlight = tile:FindFirstChild("TileHighlight")
			if existingHighlight then
				existingHighlight:Destroy()
			end

			-- Создаем новый highlight
			local highlight = Instance.new("Highlight")
			highlight.Name = "TileHighlight"

			if tile:GetAttribute("Placeboat") == true then
				-- Синяя подсветка для доступных лодочных тайлов
				highlight.FillColor = Color3.fromRGB(0, 100, 255)
				highlight.OutlineColor = Color3.fromRGB(0, 200, 255)
				highlight.FillTransparency = 0.8
				highlight.OutlineTransparency = 0
			else
				-- Красная подсветка для недоступных тайлов
				highlight.FillColor = Color3.fromRGB(167, 33, 33)
				highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
				highlight.FillTransparency = 0.8
				highlight.OutlineTransparency = 0
			end

			highlight.Parent = tile
			currentHighlightedTile = tile
		end
	end
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
		currentPhase = "explorers"
		isPlacementMode = true
		screenGui.Enabled = true
		statusLabel.Text = "Оберіть значення скарбів (1-5)"
		print("🎯 Фаза размещения исследователей начата!")

		-- Показываем очередь
	elseif data.phase == "player_turn" and data.isYourTurn then
		-- Наш ход!
		isMyTurn = true
		turnInfoLabel.Text = "🎯 ВАШ ХІД! Оберіть дослідника"
		updateUIStatus()
		print("🎮 Ваш ход! Размещайте исследователя")
	elseif data.phase == "placement_complete" then
		-- Фаза размещения завершена
		isPlacementMode = false
		isMyTurn = false
		screenGui.Enabled = false
		print("✅ Фаза размещения завершена!")
	elseif data.phase == "boats_placement" then
		currentPhase = "boats"
		isPlacementMode = true
		screenGui.Enabled = true
		playerMaxBoats = data.boatsPerPlayer or 2
		playerBoatsPlaced = 0

		-- Ховаємо кнопки скарбів
		for _, button in pairs(treasureButtons) do
			button.Visible = false
		end

		statusLabel.Text = "🚤 Оберіть тайл з помаранчевий обводкою"
		turnInfoLabel.Text = "Фаза розміщення човнів"
		progressLabel.Text = "Ваші човни: 0/" .. playerMaxBoats

		print(
			"🚤 Фаза размещения лодок начата! Шукайте тайли з помаранчевий обводкою"
		)
	elseif data.phase == "boat_turn" and data.isYourTurn then
		-- Наш хід у фазі човнів
		isMyTurn = true
		turnInfoLabel.Text = "🚤 ВАШ ХІД! Оберіть тайл для човна"
		updateUIStatus()
		statusLabel.Text = "Шукайте тайли з помаранчевий обводкою"
		progressLabel.Text = "Ваші човни: " .. playerBoatsPlaced .. "/" .. playerMaxBoats
	elseif data.phase == "boat_waiting" then
		-- Чекаємо ходу іншого гравця
		isMyTurn = false
		turnInfoLabel.Text = "⏳ Чекайте свій хід для човна"
		updateUIStatus()
		statusLabel.Text = data.message or "Чекайте..."
	elseif data.phase == "waiting_turn" then
		-- Ждем своего хода
		isMyTurn = false
		turnInfoLabel.Text = "⏳ Чекайте свій хід..."
		updateUIStatus()
	elseif data.phase == "all_placement_complete" then
		-- ВСЕ розміщення завершено
		isPlacementMode = false
		isMyTurn = false
		screenGui.Enabled = false

		if data.message then
			print("📢 " .. data.message)
		end

		print("🎯 ВСЕ фази розміщення завершені! Чекаємо основну гру...")
	elseif data.phase == "main_game_turn" and data.isYourTurn then
		-- Основна фаза гри почалась
		currentPhase = "main_game"
		isPlacementMode = false
		isMyTurn = true
		-- Приховуємо UI розміщення, показуємо UI основної гри
		screenGui.Enabled = false
	elseif data.phase == "main_game_waiting" then
		isMyTurn = false
		screenGui.Enabled = false
	end
end)

local function findExistingBoat(q, r)
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsBoat") then
			local boatQ = obj:GetAttribute("Q")
			local boatR = obj:GetAttribute("R")
			if boatQ == q and boatR == r then
				return obj
			end
		end
	end
	return nil
end

local function spawnBoatAppearanceEffect(boat)
	if not boat:IsA("Model") then
		return
	end

	local primaryPart = boat.PrimaryPart
	if not primaryPart then
		return
	end

	-- Сохраняем оригинальный размер
	local originalSize = primaryPart.Size

	-- Эффект появления
	primaryPart.Size = Vector3.new(0.1, 0.1, 0.1)
	local tweenInfo = TweenInfo.new(0.7, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
	local tween = TweenService:Create(primaryPart, tweenInfo, { Size = originalSize })
	tween:Play()

	-- Подсветка
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(0, 100, 255)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0
	highlight.Parent = boat

	game:GetService("Debris"):AddItem(highlight, 2)
end

local function createBoatVisual(playerName, q, r)
	-- Ищем шаблон лодки
	local boatTemplate = ReplicatedStorage:FindFirstChild("Boat")
	if not boatTemplate then
		warn("❌ Не найден шаблон Boat в ReplicatedStorage")
		return
	end

	-- Ищем тайл
	local map = workspace:WaitForChild("Map")
	local targetTile = nil

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
		warn("❌ Тайл для отображения човна не найден: Q=", q, "R=", r)
		return
	end

	local existingBoat = findExistingBoat(q, r)
	if existingBoat then
		existingBoat:Destroy()
	end
	-- Создаем лодку
	local boat = boatTemplate:Clone()
	boat.Name = "Boat_" .. playerName .. "_" .. q .. "_" .. r

	local primaryPart = boat.PrimaryPart

	-- Убеждаемся, что у модели есть PrimaryPart
	if not primaryPart then
		for _, part in ipairs(boat:GetDescendants()) do
			if part:IsA("BasePart") then
				primaryPart = part
				boat.PrimaryPart = primaryPart
				break
			end
		end
	end

	if not boat.PrimaryPart then
		warn("❌ У модели човна нет PrimaryPart")
		boat:Destroy()
		return
	end

	-- Позиционируем на тайле
	local tileTopY = targetTile.Position.Y + targetTile.Size.Y / 2
	local boatBottomY = primaryPart.Position.Y - primaryPart.Size.Y / 2
	local yOffset = tileTopY - boatBottomY + 0.3

	-- Додаємо обертання на 180 градусів навколо осі X або Z
	local rotatedCFrame = (targetTile.CFrame + Vector3.new(0, yOffset, 0)) * CFrame.Angles(math.rad(180), 0, 0)

	boat:PivotTo(rotatedCFrame)

	-- Добавляем атрибуты
	boat:SetAttribute("IsBoat", true)
	boat:SetAttribute("Player", playerName)
	boat:SetAttribute("Q", q)
	boat:SetAttribute("R", r)

	-- Помещаем в workspace
	boat.Parent = workspace

	-- Эффект появления
	spawnBoatAppearanceEffect(boat)

	print("🚤 Создан визуал човна для", playerName, "на Q=", q, "R=", r)
end

UpdateReadyStatusEvent.OnClientEvent:Connect(function(data)
	if data.type == "ExplorerPlaced" then
		if data.playerName == player.Name then
			explorersPlaced = data.explorerCount or explorersPlaced
			progressLabel.Text = "Розміщено: " .. explorersPlaced .. "/" .. maxExplorers

			if explorersPlaced >= maxExplorers then
				statusLabel.Text = "Всі дослідники розміщені!"
				isMyTurn = false
				updateUIStatus()
			end
		end
		local explorerId = data.explorerId or data.explorerCount
		if not explorerId then
			explorerId = data.explorerCount
		end
		-- Створюємо візуал дослідника (для всіх гравців)
		createExplorerVisual(data.playerName, data.treasureValue, data.q, data.r, explorerId)

		-- Оновлюємо інформацію про ліміти якщо вона прийшла
		if data.playerTreasureLimits then
			playerTreasureLimits = data.playerTreasureLimits
			updateButtonsHighlight()
		end
	elseif data.type == "BoatPlaced" then
		-- Оновлюємо прогрес човнів
		if data.playerName == player.Name then
			playerBoatsPlaced = data.boatsPlaced or 0
			progressLabel.Text = "Ваші човни: " .. playerBoatsPlaced .. "/" .. playerMaxBoats
		end
		createBoatVisual(data.playerName, data.q, data.r)
		-- Оновлюємо загальну інформацію
		if data.playersData then
			updateQueueDisplay(nil, data.playersData) -- Оновлюємо відображення черги
		end
	elseif data.type == "BoatTurn" then
		-- Оновлення черги гравців для човнів
		local currentPlayerName = data.currentPlayer or ""
		isMyTurn = (currentPlayerName == player.Name)

		local boatsPlaced = data.boatsPlaced or 0
		local maxBoats = data.maxBoats or 2
		local boatsLeft = math.max(0, maxBoats - boatsPlaced)

		if isMyTurn then
			turnInfoLabel.Text = "🚤 ВАШ ХІД! Оберіть тайл для човна"
			statusLabel.Text = "Залишилось човнів: " .. boatsLeft
		else
			turnInfoLabel.Text = "Зараз ходить: " .. currentPlayerName
			statusLabel.Text = "⏳ Чекайте свій хід"
		end

		if data.playersData then
			updateQueueDisplay(nil, data.playersData)
		end
	elseif data.type == "PlayerTurn" then
		-- Оновлюємо інформацію про чергу
		local currentPlayerName = data.currentPlayer or ""
		local turnInfo = data.turnInfo or {}
		local playersData = data.playersData or {}

		-- Визначаємо, чи наш це хід
		isMyTurn = (currentPlayerName == player.Name)

		if isMyTurn then
			turnInfoLabel.Text = "🎯 ВАШ ХІД! Оберіть дослідника"
			-- ОНОВЛЮЄМО СВІЙ ПРОГРЕС ТІЛЬКИ КОЛИ НАШ ХІД
			local myData = playersData[player.Name] or {}
			explorersPlaced = myData.explorersPlaced or 0
			progressLabel.Text = "Розміщено: " .. explorersPlaced .. "/" .. maxExplorers

			-- АКТИВУЄМО КНОПКИ
			for _, button in pairs(treasureButtons) do
				button.Active = true
				button.Visible = true
			end
		else
			turnInfoLabel.Text = "Зараз ходить: " .. currentPlayerName
			-- СКИДАЄМО ЛІЧИЛЬНИК І ВИМИКАЄМО КНОПКИ
			local myData = playersData[player.Name] or {}
			explorersPlaced = myData.explorersPlaced or 0
			progressLabel.Text = "Розміщено: " .. explorersPlaced .. "/" .. maxExplorers

			-- ВИМИКАЄМО КНОПКИ ДЛЯ ІНШИХ ГРАВЦІВ
			for _, button in pairs(treasureButtons) do
				button.Active = false
				button.Visible = false
			end

			statusLabel.Text = "⏳ Чекайте своєї черги..."
		end

		updateUIStatus()
		updateQueueDisplay(turnInfo, playersData)

		-- Оновлюємо інформацію про ліміти якщо вона прийшла
		if data.playerTreasureLimits then
			playerTreasureLimits = data.playerTreasureLimits
			updateButtonsHighlight()
		end
	elseif data.type == "error" then
		statusLabel.Text = data.message or "Помилка розміщення!"
		statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)

		if statusLabel then
			statusLabel.Text = "Оберіть значення скарбів (1-5)"
			statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
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
