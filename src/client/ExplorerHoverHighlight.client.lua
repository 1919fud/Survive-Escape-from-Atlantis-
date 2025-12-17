-- ExplorerHoverHighlight.lua (LocalScript в StarterPlayerScripts)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local PlayerGui = player:WaitForChild("PlayerGui")
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local GameStartEvent = GameEvents:WaitForChild("GameStartEvent")
local MoveExplorerEvent = GameEvents:WaitForChild("MoveExplorerEvent")
local HighlightTilesEvent = GameEvents:WaitForChild("HighlightTilesEvent")
local SelectExplorerEvent = GameEvents:WaitForChild("SelectExplorerEvent")
local UpdateReadyStatusEvent = GameEvents:WaitForChild("UpdateReadyStatusEvent")

-- Стан
local currentHoveredExplorer = nil
local currentHighlight = nil
local selectedExplorer = nil
local selectionHighlight = nil
local isGamePhaseActive = false
local isMyTurn = false
local availableTiles = {} -- Таблиця доступних для переміщення тайлів
local tileHighlights = {} -- Підсвічування тайлів
local isMovementMode = false

-- Створення UI для відображення вибору
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ExplorerSelectionUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = PlayerGui

local selectionFrame = Instance.new("Frame")
selectionFrame.Name = "SelectionFrame"
selectionFrame.Size = UDim2.new(0, 300, 0, 120)
selectionFrame.Position = UDim2.new(0.5, -150, 0.05, 0)
selectionFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
selectionFrame.BackgroundTransparency = 0.3
selectionFrame.BorderSizePixel = 0
selectionFrame.Visible = false
selectionFrame.Parent = screenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = selectionFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Text = "🕵️ ОБРАНО ДОСЛІДНИКА"
titleLabel.TextSize = 18
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = selectionFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Name = "InfoLabel"
infoLabel.Size = UDim2.new(1, -20, 0, 60)
infoLabel.Position = UDim2.new(0, 10, 0, 35)
infoLabel.BackgroundTransparency = 1
infoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
infoLabel.TextSize = 14
infoLabel.TextWrapped = true
infoLabel.Font = Enum.Font.Gotham
infoLabel.Text = "Оберіть дослідника для переміщення"
infoLabel.Parent = selectionFrame

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 80, 0, 25)
closeButton.Position = UDim2.new(0.5, -40, 1, -30)
closeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Text = "СКАСУВАТИ"
closeButton.TextSize = 12
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = selectionFrame

local UICorner2 = Instance.new("UICorner")
UICorner2.CornerRadius = UDim.new(0, 4)
UICorner2.Parent = closeButton

-- Функція для відображення інформації про обраного дослідника
local function updateSelectionUI(explorer)
	if not explorer then
		selectionFrame.Visible = false
		return
	end

	local explorerId = explorer:GetAttribute("ExplorerId") or "немає"
	local treasureValue = explorer:GetAttribute("TreasureValue") or 0
	local q = explorer:GetAttribute("Q") or 0
	local r = explorer:GetAttribute("R") or 0

	infoLabel.Text = string.format(
		"📍 Дослідник #%d\n"
			.. "💰 Скарби: %d\n"
			.. "🗺️ Координати: Q%d R%d\n"
			.. "🖱️ Натисніть на доступний тайл для переміщення\n"
			.. "❗ Інші дослідники зараз недоступні для вибору",
		explorerId,
		treasureValue,
		q,
		r
	)

	selectionFrame.Visible = true
end

-- Функція для отримання моделі дослідника (якщо клікнули на частину)
local function getExplorerModel(clickedObject)
	local current = clickedObject
	while current and current ~= workspace do
		-- Шукаємо модель з атрибутом IsExplorer
		if current:IsA("Model") and current:GetAttribute("IsExplorer") == true then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- Функція для отримання дослідника під курсором
local function getExplorerUnderCursor()
	local target = mouse.Target
	if not target then
		return nil
	end

	-- Шукаємо модель дослідника
	local explorerModel = getExplorerModel(target)

	if explorerModel then
		local explorerId = explorerModel:GetAttribute("ExplorerId")
		local explorerPlayer = explorerModel:GetAttribute("Player")

		-- Перевіряємо обидва атрибути
		if explorerId and explorerPlayer then
			-- Преобразуем ID в число для согласованности с сервером
			explorerId = tonumber(explorerId) or explorerId
			print(
				"🔍 Знайдено дослідника ID:",
				explorerId,
				"гравця:",
				explorerPlayer,
				"тип ID:",
				type(explorerId)
			)
			return explorerModel
		else
			-- Логируем если атрибуты не полные
			print("⚠️ Модель має IsExplorer=true, але відсутні атрибути:")
			print("  ExplorerId:", explorerId)
			print("  Player:", explorerPlayer)
			return nil
		end
	end

	return nil
end

local function getTileUnderCursor()
	local target = mouse.Target
	if target and target:GetAttribute("IsLand") == true then
		return target
	end
	return nil
end

-- Підсвічування дослідника при наведенні
local function highlightExplorerOnHover(explorerModel, highlight)
	if not explorerModel then
		return
	end

	-- Не підсвічуємо інших дослідників, якщо вже є обраний
	if selectedExplorer then
		-- Дозволяємо підсвічувати тільки обраного дослідника
		if explorerModel ~= selectedExplorer then
			return
		end
	end

	-- Не підсвічуємо якщо вже обраний
	if explorerModel == selectedExplorer then
		return
	end

	if not highlight then
		if currentHighlight and currentHighlight.Parent == explorerModel then
			currentHighlight:Destroy()
			currentHighlight = nil
		end
		currentHoveredExplorer = nil
		return
	end

	-- Створюємо нове підсвічування
	local highlightObj = Instance.new("Highlight")
	highlightObj.Name = "ExplorerHoverHighlight"

	-- Визначаємо чи це наш дослідник
	local explorerPlayer = explorerModel:GetAttribute("Player")
	local isMyExplorer = (explorerPlayer == player.Name)

	if isMyExplorer then
		-- Зелений для своїх дослідників
		highlightObj.FillColor = Color3.fromRGB(0, 255, 0)
		highlightObj.OutlineColor = Color3.fromRGB(0, 200, 0)
	else
		-- Червоний для чужих дослідників
		highlightObj.FillColor = Color3.fromRGB(255, 50, 50)
		highlightObj.OutlineColor = Color3.fromRGB(200, 0, 0)
	end

	highlightObj.FillTransparency = 0.7
	highlightObj.OutlineTransparency = 0
	highlightObj.Parent = explorerModel

	currentHighlight = highlightObj
	currentHoveredExplorer = explorerModel
end

-- Підсвічування обраного дослідника
local function highlightSelectedExplorer(explorerModel, highlight)
	if not explorerModel then
		return
	end

	if not highlight then
		if selectionHighlight then
			selectionHighlight:Destroy()
			selectionHighlight = nil
		end
		selectedExplorer = nil
		updateSelectionUI(nil)
		return
	end

	-- Створюємо підсвічування для обраного
	local highlightObj = Instance.new("Highlight")
	highlightObj.Name = "ExplorerSelectedHighlight"
	highlightObj.FillColor = Color3.fromRGB(0, 150, 255) -- Синій для обраного
	highlightObj.OutlineColor = Color3.fromRGB(0, 100, 200)
	highlightObj.FillTransparency = 0.5
	highlightObj.OutlineTransparency = 0
	highlightObj.Parent = explorerModel

	selectionHighlight = highlightObj
	selectedExplorer = explorerModel

	-- Ефект пульсації
	coroutine.wrap(function()
		while selectionHighlight and selectionHighlight.Parent == explorerModel do
			local tweenInfo1 = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween1 = TweenService:Create(highlightObj, tweenInfo1, { FillTransparency = 0.3 })
			tween1:Play()
			tween1.Completed:Wait()

			if not selectionHighlight or selectionHighlight.Parent ~= explorerModel then
				break
			end

			local tweenInfo2 = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween2 = TweenService:Create(highlightObj, tweenInfo2, { FillTransparency = 0.7 })
			tween2:Play()
			tween2.Completed:Wait()
		end
	end)()

	-- Оновлюємо UI
	updateSelectionUI(explorerModel)
end

local function clearTileHighlights()
	for _, highlight in ipairs(tileHighlights) do
		if highlight and highlight.Parent then
			-- Видаляємо BillboardGui з вартістю
			local tile = highlight.Parent
			local billboard = tile:FindFirstChild("CostDisplay")
			if billboard then
				billboard:Destroy()
			end

			highlight:Destroy()
		end
	end
	tileHighlights = {}
	isMovementMode = false
end

local function highlightAvailableTiles(data)
	clearTileHighlights()

	if not data or not data.availableTiles then
		return
	end

	-- Створюємо різні кольори для різних вартостей
	local colorByCost = {
		[1] = Color3.fromRGB(0, 255, 0), -- Зелений для 1 кроку
		[2] = Color3.fromRGB(255, 255, 0), -- Жовтий для 2 кроків
		[3] = Color3.fromRGB(255, 165, 0), -- Помаранчевий для 3 кроків
	}

	local outlineColorByCost = {
		[1] = Color3.fromRGB(0, 200, 0),
		[2] = Color3.fromRGB(200, 200, 0),
		[3] = Color3.fromRGB(200, 100, 0),
	}

	for _, tileData in ipairs(data.availableTiles) do
		local tile = tileData.tile and tileData.tile.meshPart
		if tile then
			local highlight = Instance.new("Highlight")
			highlight.Name = "AvailableTileHighlight"

			local cost = tileData.cost or 1
			highlight.FillColor = colorByCost[cost] or Color3.fromRGB(0, 255, 0)
			highlight.OutlineColor = outlineColorByCost[cost] or Color3.fromRGB(0, 200, 0)
			highlight.FillTransparency = 0.7
			highlight.OutlineTransparency = 0

			-- Додаємо BillboardGui з інформацією про вартість
			local billboard = Instance.new("BillboardGui")
			billboard.Name = "CostDisplay"
			billboard.Size = UDim2.new(2, 0, 2, 0)
			billboard.StudsOffset = Vector3.new(0, 3, 0)
			billboard.AlwaysOnTop = true
			billboard.Adornee = tile
			billboard.Parent = tile

			local costLabel = Instance.new("TextLabel")
			costLabel.Name = "CostLabel"
			costLabel.Size = UDim2.new(1, 0, 1, 0)
			costLabel.BackgroundTransparency = 1
			costLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			costLabel.Text = tostring(cost)
			costLabel.TextScaled = true
			costLabel.Font = Enum.Font.GothamBold
			costLabel.TextStrokeTransparency = 0
			costLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			costLabel.Parent = billboard

			-- Зберігаємо інформацію про вартість
			highlight:SetAttribute("Cost", cost)
			highlight:SetAttribute("Q", tileData.q)
			highlight:SetAttribute("R", tileData.r)

			highlight.Parent = tile
			table.insert(tileHighlights, highlight)
		end
	end

	isMovementMode = true
	print("📍 Показано доступні тайли для переміщення")

	-- Оновлюємо UI з інформацією
	if data.remainingActions then
		infoLabel.Text = string.format(
			"📍 Дослідник #%d обраний\n"
				.. "💰 Залишилось монет: %d\n"
				.. "🟢 1 крок = 1 монета\n"
				.. "🟡 2 кроки = 2 монети\n"
				.. "🟠 3 кроки = 3 монети\n"
				.. "🖱️ Клікніть на тайл для переміщення",
			selectedExplorer:GetAttribute("ExplorerId"),
			data.remainingActions
		)
	end
end

local function getHighlightedTileUnderCursor()
	local target = mouse.Target
	if target then
		-- Перевіряємо чи це підсвічений тайл
		local highlight = target:FindFirstChild("AvailableTileHighlight")
		if highlight then
			return {
				tile = target,
				cost = highlight:GetAttribute("Cost") or 1,
				q = highlight:GetAttribute("Q"),
				r = highlight:GetAttribute("R"),
			}
		end
	end
	return nil
end

-- Функція для очищення підсвічування тайлів

-- Обробник кліку по досліднику
local function onExplorerClick(explorer)
	if not isGamePhaseActive or not isMyTurn then
		print("❌ Не ваш хід або фаза не активна!")
		print("  isGamePhaseActive:", isGamePhaseActive)
		print("  isMyTurn:", isMyTurn)
		return
	end

	local explorerPlayer = explorer:GetAttribute("Player")
	local explorerId = explorer:GetAttribute("ExplorerId")

	-- Преобразуем ID в число
	explorerId = tonumber(explorerId) or explorerId

	print("🖱️ Клік по досліднику:")
	print("  ID:", explorerId)
	print("  Власник:", explorerPlayer)
	print("  Ваше ім'я:", player.Name)

	-- Перевіряємо чи це наш дослідник
	if explorerPlayer ~= player.Name then
		print("❌ Це не ваш дослідник!")
		print("  Очікуваний власник:", player.Name)
		print("  Фактичний власник:", explorerPlayer)
		return
	end

	-- Перевіряємо чи це вже обраний дослідник
	local selectedId = selectedExplorer and selectedExplorer:GetAttribute("ExplorerId")
	local selectedPlayer = selectedExplorer and selectedExplorer:GetAttribute("Player")

	selectedId = selectedId and (tonumber(selectedId) or selectedId)

	if selectedExplorer and (explorerId ~= selectedId or explorerPlayer ~= selectedPlayer) then
		print(
			"⚠️ Вже обрано дослідника. Скасуйте поточний вибір, щоб обрати іншого."
		)
		print("  Обраний дослідник ID:", selectedId, "власник:", selectedPlayer)
		return
	end

	if explorerId == selectedId and explorerPlayer == selectedPlayer then
		-- Вже обраний - скасовуємо вибір
		clearTileHighlights()
		highlightSelectedExplorer(selectedExplorer, false)
		print("✖️ Вибір дослідника скасовано")

		-- Повідомляємо сервер про скасування вибору
		SelectExplorerEvent:FireServer(nil)
	else
		-- Обираємо нового дослідника
		clearTileHighlights()
		highlightSelectedExplorer(explorer, true)
		print("🎯 Обрано дослідника ID:", explorerId, "гравця:", explorerPlayer)

		-- Повідомляємо сервер про вибір дослідника
		SelectExplorerEvent:FireServer(explorerId)
	end
end

local function moveExplorerToTile(tileData)
	if not selectedExplorer or not isMovementMode or not isMyTurn then
		print("❌ Немає обраного дослідника або не режим переміщення")
		return
	end

	local explorerId = selectedExplorer:GetAttribute("ExplorerId")

	print(
		"🚶 Спроба перемістити дослідника",
		explorerId,
		"на Q=",
		tileData.q,
		"R=",
		tileData.r,
		"вартістю",
		tileData.cost,
		"монет"
	)

	-- Відправляємо запит на сервер
	MoveExplorerEvent:FireServer(explorerId, tileData.q, tileData.r)

	-- Очищаємо підсвічування
	clearTileHighlights()
	highlightSelectedExplorer(selectedExplorer, false)
end

-- Обробник кліку по кнопці "Скасувати"
-- Обробник кліку по кнопці "Скасувати"
closeButton.MouseButton1Click:Connect(function()
	if selectedExplorer then
		clearTileHighlights()
		highlightSelectedExplorer(selectedExplorer, false)
		SelectExplorerEvent:FireServer(nil)
		print("✖️ Вибір скасовано через UI")

		-- Додайте додаткове повідомлення для наочності
		infoLabel.Text = "Вибір скасовано. Можете обрати іншого дослідника."
		task.delay(2, function()
			if infoLabel then
				infoLabel.Text = "Оберіть дослідника для переміщення"
			end
		end)
	end
end)

UpdateReadyStatusEvent.OnClientEvent:Connect(function(data)
	if data.type == "MainGameTurn" then
		-- Обновляем информацию о ходе
		local currentPlayerName = data.currentPlayer or ""
		isMyTurn = (currentPlayerName == player.Name)

		if isMyTurn then
			print("🎮 Ваш хід! Залишилось дій:", data.remainingActions or 0)
			selectionFrame.Visible = true
			infoLabel.Text = string.format(
				"🎯 Ваш хід!\n"
					.. "⏱️ Залишилось дій: %d/%d\n"
					.. "🖱️ Оберіть дослідника для переміщення",
				data.remainingActions or 0,
				data.maxActions or 3
			)
		else
			print("⏳ Зараз ходить:", currentPlayerName)
			selectionFrame.Visible = false
		end
	end
end)

-- Обробник подій гри
GameStartEvent.OnClientEvent:Connect(function(data)
	print("📡 Отримано подію гри:", data.phase)

	if data.phase == "main_game_active" then
		-- Основная игра началась
		isGamePhaseActive = true
		isMyTurn = false -- Пока не наш хід
		print("🎮 Основна гра активна. Чекаємо на хід...")
	elseif data.phase == "main_game_turn" and data.isYourTurn then
		-- Наш хід в основной игре
		isGamePhaseActive = true
		isMyTurn = true
		print("🎮 Ваш хід! Можете обирати дослідників")
		print("  Залишилось дій:", data.remainingActions or 3)

		-- Показываем UI выбора
		selectionFrame.Visible = true
		titleLabel.Text = "🕵️ ВАШ ХІД"
		infoLabel.Text = string.format(
			"Ваш хід!\nЗалишилось дій: %d/%d\nОберіть дослідника для переміщення",
			data.remainingActions or 3,
			data.maxActions or 3
		)
	elseif data.phase == "main_game_waiting" then
		-- Ждем своего хода
		isGamePhaseActive = true
		isMyTurn = false
		print("⏳ Чекайте свій хід... Зараз ходить інший гравець")
		selectionFrame.Visible = false

		-- Очищаем подсветку
		if currentHighlight then
			currentHighlight:Destroy()
			currentHighlight = nil
		end
		if selectionHighlight then
			selectionHighlight:Destroy()
			selectionHighlight = nil
		end
		clearTileHighlights()
		currentHoveredExplorer = nil
		selectedExplorer = nil
	elseif data.phase == "placement" or data.phase == "placement_complete" or data.phase == "boats_placement" then
		-- Фазы размещения - отключаем подсветку
		isGamePhaseActive = false
		isMyTurn = false
		print("⏸️ Фаза розміщення - підсвічування вимкнено")

		-- Очищаем подсветку и UI
		if currentHighlight then
			currentHighlight:Destroy()
			currentHighlight = nil
		end
		if selectionHighlight then
			selectionHighlight:Destroy()
			selectionHighlight = nil
		end
		clearTileHighlights()
		currentHoveredExplorer = nil
		selectedExplorer = nil
		selectionFrame.Visible = false
	elseif data.phase == "main_game_ended" or data.phase == "game_over" then
		-- Игра завершена
		isGamePhaseActive = false
		isMyTurn = false
		print("⏹️ Гра завершена - підсвічування вимкнено")

		-- Очищаем подсветку и UI
		if currentHighlight then
			currentHighlight:Destroy()
			currentHighlight = nil
		end
		if selectionHighlight then
			selectionHighlight:Destroy()
			selectionHighlight = nil
		end
		clearTileHighlights()
		currentHoveredExplorer = nil
		selectedExplorer = nil
		selectionFrame.Visible = false
	end
end)

HighlightTilesEvent.OnClientEvent:Connect(function(data)
	if data and data.type == "movement" then
		print("📍 Отримано доступні тайли для переміщення")
		highlightAvailableTiles(data)
	elseif data and data.type == "clear" then
		clearTileHighlights()
	end
end)

-- Основний цикл для відстеження наведення
RunService.Heartbeat:Connect(function()
	-- Перевіряємо чи активна фаза гри
	if not isGamePhaseActive or not isMyTurn then
		if currentHoveredExplorer then
			highlightExplorerOnHover(currentHoveredExplorer, false)
		end
		return
	end

	local hoveredExplorer = getExplorerUnderCursor()

	if hoveredExplorer and hoveredExplorer ~= currentHoveredExplorer then
		-- Навели на нового дослідника
		highlightExplorerOnHover(currentHoveredExplorer, false)
		highlightExplorerOnHover(hoveredExplorer, true)
	elseif not hoveredExplorer and currentHoveredExplorer then
		-- Зійшли з дослідника
		highlightExplorerOnHover(currentHoveredExplorer, false)
	end
end)

-- Обробник кліків миші
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local target = mouse.Target
		if target then
			local explorer = getExplorerUnderCursor()
			if explorer then
				onExplorerClick(explorer)
			else
				-- Перевіряємо, чи це підсвічений тайл
				local highlightedTile = getHighlightedTileUnderCursor()
				if highlightedTile and selectedExplorer and isMovementMode then
					-- Спроба перемістити дослідника на цей тайл
					moveExplorerToTile(highlightedTile)
				elseif selectedExplorer then
					print(
						"⚠️ Є обраний дослідник. Скасуйте через UI або клікніть на того ж дослідника"
					)
				end
			end
		end
	end
end)

-- Очищення при виході з гри
Players.PlayerRemoving:Connect(function(leftPlayer)
	if leftPlayer == player then
		if currentHighlight then
			currentHighlight:Destroy()
			currentHighlight = nil
		end
		if selectionHighlight then
			selectionHighlight:Destroy()
			selectionHighlight = nil
		end
		clearTileHighlights()
		currentHoveredExplorer = nil
		selectedExplorer = nil
		selectionFrame.Visible = false
	end
end)

print("✅ Система підсвічування та вибору дослідників завантажена")

-- Ініціалізація: перевіряємо початковий стан
task.delay(1, function()
	print(
		"🔍 Початковий стан: Фаза гри активна =",
		isGamePhaseActive,
		"Ваш хід =",
		isMyTurn
	)
end)

-- Додайте в кінець скрипту
local function updateExplorerPosition(explorer, q, r)
	if not explorer or not explorer:IsA("Model") then
		return
	end

	-- Знаходимо тайл за координатами (як острів, так і воду)
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
				print("📍 Знайдено тайл острова для дослідника")
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
					print("🌊 Знайдено водний тайл для дослідника")
					break
				end
			end
		end
	end

	if targetTile and explorer.PrimaryPart then
		local tilePosition = targetTile.Position

		if isWaterTile then
			-- Позиціонування на воді
			local heightOffset = 4.38 -- Висота над водою
			local explorerPosition = Vector3.new(tilePosition.X, heightOffset, tilePosition.Z)
			local rotatedCFrame = CFrame.new(explorerPosition) * CFrame.Angles(0, math.rad(90), 0)

			explorer:SetPrimaryPartCFrame(rotatedCFrame)
			print("📍 Дослідник переміщений на ВОДУ Q=", q, "R=", r)

			-- Додаємо ефект для води (необов'язково)
			local waterEffect = explorer:FindFirstChild("WaterEffect")
			if not waterEffect then
				waterEffect = Instance.new("ParticleEmitter")
				waterEffect.Name = "WaterEffect"
				waterEffect.Color = ColorSequence.new(Color3.fromRGB(100, 150, 255))
				waterEffect.Size = NumberSequence.new(0.2)
				waterEffect.Transparency = NumberSequence.new(0.7)
				waterEffect.Lifetime = NumberRange.new(1, 2)
				waterEffect.Rate = 10
				waterEffect.Speed = NumberRange.new(1)
				waterEffect.Parent = explorer.PrimaryPart
			end
		else
			-- Позиціонування на суші
			local heightOffset = 0
			local targetTileType = targetTile:GetAttribute("TileType")

			if targetTileType == "Beach" then
				heightOffset = 6.062
			elseif targetTileType == "Forest" then
				heightOffset = 7.037
			elseif targetTileType == "Mountain" then
				heightOffset = 8.007
			else
				heightOffset = 6 -- За замовчуванням
			end

			local explorerPosition = Vector3.new(tilePosition.X, heightOffset, tilePosition.Z)
			local rotatedCFrame = CFrame.new(explorerPosition) * CFrame.Angles(0, math.rad(90), 0)

			explorer:SetPrimaryPartCFrame(rotatedCFrame)
			print(
				"📍 Дослідник переміщений на ОСТРІВ Q=",
				q,
				"R=",
				r,
				"тип:",
				targetTileType
			)

			-- Видаляємо ефект води, якщо він є
			local waterEffect = explorer:FindFirstChild("WaterEffect")
			if waterEffect then
				waterEffect:Destroy()
			end
		end

		-- Оновлюємо атрибути
		explorer:SetAttribute("Q", q)
		explorer:SetAttribute("R", r)
		explorer:SetAttribute("IsOnWater", isWaterTile)
	else
		print(
			"❌ Не знайдено тайл для позиціонування дослідника Q=",
			q,
			"R=",
			r
		)
	end
end

-- Додайте після інших обробників подій
UpdateReadyStatusEvent.OnClientEvent:Connect(function(data)
	if data.type == "ExplorerMoved" then
		-- Знаходимо дослідника в робочому просторі
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:GetAttribute("IsExplorer") and obj:GetAttribute("ExplorerId") == data.explorerId then
				updateExplorerPosition(obj, data.q, data.r)
				break
			end
		end
	end
end)

UpdateReadyStatusEvent.OnClientEvent:Connect(function(data)
	if data.type == "MainGameTurn" then
		-- Обновляем информацию о ходе
		local currentPlayerName = data.currentPlayer or ""
		isMyTurn = (currentPlayerName == player.Name)

		if isMyTurn then
			print("🎮 Ваш хід! Залишилось дій:", data.remainingActions or 0)
			selectionFrame.Visible = true
			infoLabel.Text = string.format(
				"🎯 Ваш хід!\n⏱️ Залишилось дій: %d/%d\n🖱️ Оберіть дослідника для переміщення",
				data.remainingActions or 0,
				data.maxActions or 3
			)
		else
			print("⏳ Зараз ходить:", currentPlayerName)
			print("  Ваше ім'я:", player.Name)
			selectionFrame.Visible = false
		end
	end
end)
