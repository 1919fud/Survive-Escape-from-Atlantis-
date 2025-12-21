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

-- ДОДАНО: Стан для підсвічування човна
local currentHoveredBoat = nil
local boatHighlight = nil

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
infoLabel.Size = UDim2.new(1, -29, 0, 115)
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
	local isOnWater = explorer:GetAttribute("IsOnWater") or false

	-- Додаємо інформацію про правила руху
	local rulesText = ""
	if isOnWater then
		rulesText = "\n🌊 Зараз на воді:\n"
			.. "• Можна зробити 1 крок\n"
			.. "• Можна вийти на сушу\n"
			.. "• Не можна залишатися на воді\n"
			.. "❗ Потрібно вийти на сушу цього ходу!"
	else
		rulesText = "\n📜 Правила руху:\n"
			.. "• ⛰️ По суші: без обмежень\n"
			.. "• 🌊 У воду: можна лише 1 раз за хід\n"
			.. "• ⚠️ Після води: рух завершено\n"
			.. "• 🎯 Плануйте маршрут обережно!"
	end

	infoLabel.Text = string.format(
		"📍 Дослідник #%d\n"
			.. "💰 Скарби: %d\n"
			.. "🗺️ Координати: Q%d R%d\n"
			.. "💧 Стан: %s\n"
			.. "%s\n\n"
			.. "🖱️ Натисніть на доступний тайл для переміщення",
		explorerId,
		treasureValue,
		q,
		r,
		isOnWater and "На воді 🌊" or "На суші ⛰️",
		rulesText
	)

	selectionFrame.Visible = true
	selectionFrame.Size = UDim2.new(0, 350, 0, 180) -- Збільшуємо розмір для нового тексту

	-- Оновлюємо позицію кнопки
	closeButton.Position = UDim2.new(0.5, -40, 1, -30)
end

-- Функція для отримання моделі дослідника (якщо клікнули на частину)
local function getExplorerModel(clickedObject)
	local current = clickedObject
	while current and current ~= workspace do
		-- Спочатку перевіряємо, чи це човен
		if current:IsA("Model") and current:GetAttribute("IsBoat") == true then
			return nil -- Ігноруємо кліки на човни
		end

		-- Потім шукаємо модель з атрибутом IsExplorer
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

	-- Перевіряємо, чи це човен
	local current = target
	while current and current ~= workspace do
		if current:IsA("Model") and current:GetAttribute("IsBoat") == true then
			return nil -- Ігноруємо кліки на човни
		end
		current = current.Parent
	end

	-- Тепер шукаємо дослідника
	current = target
	while current and current ~= workspace do
		if current:IsA("Model") and current:GetAttribute("IsExplorer") == true then
			local explorerId = current:GetAttribute("ExplorerId")
			local explorerPlayer = current:GetAttribute("Player")

			if explorerId and explorerPlayer then
				explorerId = tonumber(explorerId) or explorerId
				print("🔍 Знайдено дослідника ID:", explorerId, "гравця:", explorerPlayer)
				return current
			end
		end
		current = current.Parent
	end

	return nil
end

-- ДОДАНО: Функція для отримання човна під курсором
local function getBoatUnderCursor()
	local target = mouse.Target
	if not target then
		return nil
	end

	local current = target
	while current and current ~= workspace do
		if current:IsA("Model") and current:GetAttribute("IsBoat") == true then
			local boatId = current:GetAttribute("BoatId")
			local boatPlayer = current:GetAttribute("Player")
			local q = current:GetAttribute("Q")
			local r = current:GetAttribute("R")

			-- ДОДАТКОВА ПЕРЕВІРКА
			print("🔍 ДЕТАЛЬНІ АТРИБУТИ ЧОВНА:")
			print("  ID:", boatId, "тип:", typeof(boatId))
			print("  Q:", q, "тип:", typeof(q))
			print("  R:", r, "тип:", typeof(r))
			print("  Player:", boatPlayer)

			return current
		end
		current = current.Parent
	end
	return nil
end

-- ДОДАНО: Функція для підсвічування човна
local function highlightBoatOnHover(boatModel, highlight)
	if not boatModel or not boatModel:IsA("Model") then
		return
	end
	local boatId = boatModel:GetAttribute("BoatId")
	local boatPlayer = boatModel:GetAttribute("Player")

	if not boatId or not boatPlayer then
		print(
			"⚠️ Човен не має всіх атрибутів, пропускаємо підсвічування"
		)
		return
	end

	-- Не підсвічуємо якщо вже є виділений дослідник
	if selectedExplorer then
		if boatHighlight and boatHighlight.Parent == boatModel then
			boatHighlight:Destroy()
			boatHighlight = nil
			currentHoveredBoat = nil
		end
		return
	end

	if not highlight then
		if boatHighlight and boatHighlight.Parent == boatModel then
			boatHighlight:Destroy()
			boatHighlight = nil
		end
		currentHoveredBoat = nil
		return
	end

	-- Створюємо нове підсвічування для човна
	local highlightObj = Instance.new("Highlight")
	highlightObj.Name = "BoatHoverHighlight"

	-- Вибираємо колір залежно від гравця
	local boatPlayerName = boatModel:GetAttribute("Player") or "Unknown"
	local isMyBoat = (boatPlayerName == player.Name)

	if isMyBoat then
		-- Синій для наших човнів
		highlightObj.FillColor = Color3.fromRGB(0, 150, 255)
		highlightObj.OutlineColor = Color3.fromRGB(0, 100, 200)
	else
		-- Золотий для чужих човнів
		highlightObj.FillColor = Color3.fromRGB(255, 215, 0)
		highlightObj.OutlineColor = Color3.fromRGB(218, 165, 32)
	end

	highlightObj.FillTransparency = 0.6
	highlightObj.OutlineTransparency = 0.3
	highlightObj.Parent = boatModel

	boatHighlight = highlightObj
	currentHoveredBoat = boatModel

	-- Додаємо ефект пульсації
	coroutine.wrap(function()
		while boatHighlight and boatHighlight.Parent == boatModel do
			local tweenInfo1 = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween1 = TweenService:Create(highlightObj, tweenInfo1, { FillTransparency = 0.4 })
			tween1:Play()
			tween1.Completed:Wait()

			if not boatHighlight or boatHighlight.Parent ~= boatModel then
				break
			end

			local tweenInfo2 = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween2 = TweenService:Create(highlightObj, tweenInfo2, { FillTransparency = 0.8 })
			tween2:Play()
			tween2.Completed:Wait()
		end
	end)()
end

-- ДОДАНО: Функція для отримання інформації про човен для UI
local function getBoatInfo(boat)
	if not boat then
		return "Немає інформації"
	end

	-- ДОДАНО: Перетворюємо атрибути на числа
	local boatId = boat:GetAttribute("BoatId")
	local boatIdNum = tonumber(boatId) or 0 -- Перетворюємо на число або 0 за замовчуванням

	local playerName = boat:GetAttribute("Player") or "Невідомо"

	local q = boat:GetAttribute("Q")
	local qNum = tonumber(q) or 0 -- Перетворюємо на число

	local r = boat:GetAttribute("R")
	local rNum = tonumber(r) or 0 -- Перетворюємо на число

	-- Рахуємо дослідників на човні
	local explorersOnBoat = 0
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") then
			local expQ = obj:GetAttribute("Q")
			local expR = obj:GetAttribute("R")

			-- Перетворюємо координати дослідника на числа
			local expQNum = tonumber(expQ) or 0
			local expRNum = tonumber(expR) or 0

			if expQNum == qNum and expRNum == rNum then
				explorersOnBoat = explorersOnBoat + 1
			end
		end
	end

	local capacityText = string.format("%d/3", explorersOnBoat)
	local capacityColor = explorersOnBoat >= 3 and "❌" or "✅"

	-- ВИПРАВЛЕННЯ: Використовуємо числа для форматування
	return string.format(
		"🚤 Човен #%d\n"
			.. "👤 Власник: %s\n"
			.. "📍 Координати: Q%d R%d\n"
			.. "👥 Місткість: %s %s\n"
			.. "\nℹ️ Натисніть на дослідника, щоб посадити на човен",
		boatIdNum, -- число
		playerName, -- рядок
		qNum, -- число
		rNum, -- число
		capacityText, -- рядок
		capacityColor -- рядок
	)
end

-- Функція для відображення інформації про човен
local function showBoatInfo(boat)
	if not boat then
		return
	end

	selectionFrame.Visible = true
	selectionFrame.Size = UDim2.new(0, 320, 0, 140)
	selectionFrame.Position = UDim2.new(0.5, -160, 0.05, 0)

	titleLabel.Text = "🚤 ІНФОРМАЦІЯ ПРО ЧОВЕН"
	infoLabel.Text = getBoatInfo(boat)
	closeButton.Visible = true
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

	-- Не підсвічуємо якщо він вже обраний
	if explorerModel == selectedExplorer then
		if highlight then
			-- Якщо це обраний дослідник, не показуємо зелене підсвічування
			if currentHighlight and currentHighlight.Parent == explorerModel then
				currentHighlight:Destroy()
				currentHighlight = nil
			end
			return
		end
	end

	if not highlight then
		if currentHighlight and currentHighlight.Parent == explorerModel then
			currentHighlight:Destroy()
			currentHighlight = nil
		end
		currentHoveredExplorer = nil
		return
	end

	-- Не показуємо підсвічування, якщо вже є вибраний інший дослідник
	if selectedExplorer and explorerModel ~= selectedExplorer then
		if currentHighlight and currentHighlight.Parent == explorerModel then
			currentHighlight:Destroy()
			currentHighlight = nil
		end
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
		-- Вимикаємо підсвічування
		if selectionHighlight then
			selectionHighlight:Destroy()
			selectionHighlight = nil
		end

		-- ВАЖЛИВО: також прибираємо підсвічування наведення з цього дослідника
		if currentHighlight and currentHighlight.Parent == explorerModel then
			currentHighlight:Destroy()
			currentHighlight = nil
		end

		selectedExplorer = nil
		currentHoveredExplorer = nil -- ДОДАНО: скидаємо і наведення
		updateSelectionUI(nil)
		print("🔴 Підсвічування вибраного дослідника вимкнено")
		return
	end

	-- Спочатку очищаємо старе підсвічування
	if selectionHighlight then
		selectionHighlight:Destroy()
		selectionHighlight = nil
	end

	-- Створюємо нове підсвічування для обраного
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
	print("🔵 Підсвічування вибраного дослідника увімкнено")
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

local function createWaterEffect(tile)
	if not tile:FindFirstChild("WaterEffect") then
		local particleEmitter = Instance.new("ParticleEmitter")
		particleEmitter.Name = "WaterEffect"
		particleEmitter.Color = ColorSequence.new(Color3.fromRGB(100, 150, 255))
		particleEmitter.Size = NumberSequence.new(0.3)
		particleEmitter.Transparency = NumberSequence.new(0.5)
		particleEmitter.Lifetime = NumberRange.new(0.5, 1)
		particleEmitter.Rate = 20
		particleEmitter.Speed = NumberRange.new(1, 2)
		particleEmitter.VelocitySpread = 180
		particleEmitter.Parent = tile

		-- Видаляємо через 5 секунд після зникнення highlight
		game:GetService("Debris"):AddItem(particleEmitter, 5)
	end
end

local function highlightAvailableTiles(data)
	clearTileHighlights()

	if not data or not data.availableTiles then
		return
	end

	-- Створюємо різні кольори для різних вартостей і типів
	local colorByCost = {
		[1] = Color3.fromRGB(0, 255, 0), -- Зелений для 1 кроку (сушя)
		[2] = Color3.fromRGB(255, 255, 0), -- Жовтий для 2 кроків
		[3] = Color3.fromRGB(255, 165, 0), -- Помаранчевий для 3 кроків
	}

	-- Для воды специальные цвета
	local waterColor = Color3.fromRGB(0, 150, 255) -- Синий для воды

	for _, tileData in ipairs(data.availableTiles) do
		local tile = tileData.tile and tileData.tile.meshPart
		if tile then
			local highlight = Instance.new("Highlight")
			highlight.Name = "AvailableTileHighlight"

			local cost = tileData.cost or 1
			local isWater = tileData.isWater or false

			if isWater then
				-- Водні тайли сині з спеціальним ефектом
				highlight.FillColor = waterColor
				highlight.OutlineColor = Color3.fromRGB(0, 100, 200)
				highlight.FillTransparency = 0.3 -- Менша прозорість для води
				highlight.OutlineTransparency = 0

				-- Додаємо ефект хвиль для води
				coroutine.wrap(function()
					while highlight and highlight.Parent == tile do
						local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
						local tween = TweenService:Create(highlight, tweenInfo, { FillTransparency = 0.6 })
						tween:Play()
						task.wait(1)
					end
				end)()
			else
				-- Сухопутні тайли по вартості
				highlight.FillColor = colorByCost[cost] or Color3.fromRGB(0, 255, 0)
				highlight.OutlineColor = Color3.fromRGB(0, 200, 0)
				highlight.FillTransparency = 0.7
				highlight.OutlineTransparency = 0
			end

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

			if isWater then
				costLabel.Text = cost .. " 💧" -- Іконка воды
				costLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
				costLabel.Font = Enum.Font.GothamBlack
			else
				costLabel.Font = Enum.Font.GothamBold
			end

			costLabel.TextScaled = true
			costLabel.TextStrokeTransparency = 0
			costLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			costLabel.Parent = billboard

			-- Зберігаємо інформацію про вартість
			highlight:SetAttribute("Cost", cost)
			highlight:SetAttribute("Q", tileData.q)
			highlight:SetAttribute("R", tileData.r)
			highlight:SetAttribute("IsWater", isWater)

			highlight.Parent = tile
			table.insert(tileHighlights, highlight)
		end
	end

	isMovementMode = true
	print("📍 Показано доступні тайли для переміщення")

	-- Оновлюємо UI з інформацією про правила
	if data.remainingActions then
		closeButton.Visible = true
		-- Перевіряємо чи є водні тайли
		local hasWaterTiles = false
		for _, tileData in ipairs(data.availableTiles) do
			if tileData.isWater then
				hasWaterTiles = true
				break
			end
		end

		local waterWarning = ""
		if hasWaterTiles then
			waterWarning =
				"\n⚠️ УВАГА: Крок у воду завершить хід цього дослідника!"
		end
		infoLabel.Position = UDim2.new(0, 10, 0, 15)
		infoLabel.Size = UDim2.new(0, 335, 0, 140)
		infoLabel.Text = string.format(
			"📍 Дослідник #%d\n"
				.. "💰 Залишилось монет: %d/3\n"
				.. "📜 Правила руху:\n"
				.. "  ⛰️ По суші: без обмежень\n"
				.. "  🌊 У воду: МАКСИМУМ 1 раз за хід\n"
				.. "  ⛔ Після води: рух завершено"
				.. "%s",
			selectedExplorer:GetAttribute("ExplorerId"),
			data.remainingActions,
			waterWarning
		)
	end
end

local function isBoat(object)
	local current = object
	while current and current ~= workspace do
		if current:IsA("Model") and current:GetAttribute("IsBoat") == true then
			return true
		end
		current = current.Parent
	end
	return false
end

local function getBoatOnTile(q, r)
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("IsBoat") then
			local boatQ = obj:GetAttribute("Q")
			local boatR = obj:GetAttribute("R")
			if boatQ == q and boatR == r then
				return obj
			end
		end
	end
	return nil
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

local function clearSelectionState()
	-- Очищаємо підсвічування тайлів
	clearTileHighlights()

	-- ДОДАНО: Очищаємо підсвічування човна
	if boatHighlight then
		boatHighlight:Destroy()
		boatHighlight = nil
	end
	currentHoveredBoat = nil

	-- Скидаємо вибір дослідника
	if selectedExplorer then
		highlightSelectedExplorer(selectedExplorer, false)
		-- ДОДАНО: також скидаємо підсвічування наведення
		if currentHighlight and currentHighlight.Parent == selectedExplorer then
			currentHighlight:Destroy()
			currentHighlight = nil
		end
	end

	-- Скидаємо стан
	isMovementMode = false
	currentHoveredExplorer = nil
	selectedExplorer = nil

	-- Ховаємо UI
	selectionFrame.Visible = false

	-- Повертаємо стандартний текст
	if infoLabel then
		infoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		infoLabel.Text = "Оберіть дослідника для переміщення"
	end

	print("🧹 Стан вибору очищено")
end

local function getExplorersOnBoatCount(boatId)
	if not boatId then
		return 0
	end

	local count = 0
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") and obj:GetAttribute("BoatId") == boatId then
			count = count + 1
		end
	end
	return count
end

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
	explorerId = tonumber(explorerId) or explorerId

	print("🖱️ Клік по досліднику:")
	print("  ID:", explorerId)
	print("  Власник:", explorerPlayer)
	print("  Ваше ім'я:", player.Name)

	-- Перевіряємо чи це наш дослідник
	if explorerPlayer ~= player.Name then
		print("❌ Це не ваш дослідник!")

		infoLabel.Text =
			"❌ Це дослідник іншого гравця!\nОберіть свого дослідника"
		infoLabel.TextColor3 = Color3.fromRGB(255, 100, 100)

		task.delay(2, function()
			if infoLabel then
				infoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
				infoLabel.Text = "Оберіть дослідника для переміщення"
			end
		end)
		return
	end

	-- Перевіряємо чи це вже обраний дослідник
	local selectedId = selectedExplorer and selectedExplorer:GetAttribute("ExplorerId")
	local selectedPlayer = selectedExplorer and selectedExplorer:GetAttribute("Player")
	selectedId = selectedId and (tonumber(selectedId) or selectedId)

	if selectedExplorer and explorer ~= selectedExplorer then
		print(
			"⚠️ Вже обрано іншого дослідника. Скасуйте поточний вибір."
		)

		infoLabel.Text =
			"⚠️ Вже обрано іншого дослідника!\nСкасуйте вибір, щоб обрати цього"
		infoLabel.TextColor3 = Color3.fromRGB(255, 165, 0)

		task.delay(2, function()
			if infoLabel then
				infoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
				infoLabel.Text = "Оберіть дослідника для переміщення"
			end
		end)
		return
	end

	if explorerId == selectedId and explorerPlayer == selectedPlayer then
		-- Вже обраний - скасовуємо вибір
		print("✖️ Вибір дослідника скасовано")
		clearSelectionState()
		SelectExplorerEvent:FireServer(nil)
	else
		-- Обираємо нового дослідника
		print("🎯 Обрано дослідника ID:", explorerId, "гравця:", explorerPlayer)
		clearSelectionState()
		highlightSelectedExplorer(explorer, true)
		SelectExplorerEvent:FireServer(explorerId)
	end
end

local function moveExplorerToTile(tileData)
	if not selectedExplorer or not isMovementMode or not isMyTurn then
		print("❌ Немає обраного дослідника або не режим переміщення")
		return
	end

	local explorerId = selectedExplorer:GetAttribute("ExplorerId")

	-- ДОДАНО: Перевіряємо чи є човен на цьому тайлі
	local boat = getBoatOnTile(tileData.q, tileData.r)
	local isBoatTile = boat ~= nil

	print(
		"🚶 Спроба перемістити дослідника",
		explorerId,
		"на Q=",
		tileData.q,
		"R=",
		tileData.r,
		isBoatTile and "(човен)" or ""
	)

	-- Відправляємо запит на сервер
	MoveExplorerEvent:FireServer(explorerId, tileData.q, tileData.r)

	-- Очищаємо підсвічування
	clearTileHighlights()
	highlightSelectedExplorer(selectedExplorer, false)
end

-- Обробник кліку по кнопці "Скасувати"
closeButton.MouseButton1Click:Connect(function()
	clearSelectionState()
	SelectExplorerEvent:FireServer(nil)
	print("✖️ Вибір скасовано через UI")
end)

-- Додайте цю функцію після інших функцій
local function updateExplorerStatusInfo()
	-- Ця функція може бути використана для відображення
	-- інформації про те, чи може дослідник рухатися
	print("🔄 Оновлення інформації про стан дослідників")

	-- Можна додати візуальні індикатори на дослідниках,
	-- які вже входили у воду
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") and obj:GetAttribute("Player") == player.Name then
			local isOnWater = obj:GetAttribute("IsOnWater")
			local hasEnteredWater = obj:GetAttribute("HasEnteredWaterThisTurn")

			-- Можна додати світлові ефекти або індикатори
			if hasEnteredWater or isOnWater then
				-- Додайте візуальний ефект для дослідника,
				-- який вже входив у воду або знаходиться на воді
				-- Наприклад, блакитну ауру
				local effect = obj:FindFirstChild("WaterLockEffect")
				if not effect then
					effect = Instance.new("Highlight")
					effect.Name = "WaterLockEffect"
					effect.FillColor = Color3.fromRGB(0, 100, 255)
					effect.OutlineColor = Color3.fromRGB(0, 200, 255)
					effect.FillTransparency = 0.8
					effect.OutlineTransparency = 0.5
					effect.Parent = obj
				end
			else
				-- Видаляємо ефект, якщо дослідник може рухатися
				local effect = obj:FindFirstChild("WaterLockEffect")
				if effect then
					effect:Destroy()
				end
			end
		end
	end
end

UpdateReadyStatusEvent.OnClientEvent:Connect(function(data)
	if data.type == "ExplorerMoved" then
		-- Оновлюємо стан дослідника, якщо він обраний
		if selectedExplorer and selectedExplorer:GetAttribute("ExplorerId") == data.explorerId then
			-- Оновлюємо атрибут IsOnWater
			selectedExplorer:SetAttribute("IsOnWater", data.isWaterTile or false)

			-- Оновлюємо UI
			updateSelectionUI(selectedExplorer)

			-- Додаткове повідомлення якщо крок на воду
			if data.isWaterTile then
				infoLabel.Text = infoLabel.Text
					.. "\n\n💧 КРОК НА ВОДУ! Рух завершено для цього дослідника."

				-- Автоматично закриваємо вибір через 3 секунди
				task.delay(3, function()
					if selectionFrame.Visible then
						clearTileHighlights()
						highlightSelectedExplorer(selectedExplorer, false)
						SelectExplorerEvent:FireServer(nil)
					end
				end)
			end
		end
	elseif data.type == "MainGameTurn" then
		-- Обновляем информацию о ходе
		local currentPlayerName = data.currentPlayer or ""
		isMyTurn = (currentPlayerName == player.Name)

		if isMyTurn then
			closeButton.Visible = false
			print("🎮 Ваш хід! Залишилось дій:", data.remainingActions or 0)
			selectionFrame.Visible = true
			infoLabel.Size = UDim2.new(1, -29, 0, 150)
			-- Додаємо загальні правила гри
			local generalRules = "\n🎯 Загальні правила гри:\n"
				.. "• Кожен гравець має 3 монети за хід\n"
				.. "• 1 крок = 1 монета\n"
				.. "• Кожен дослідник може ввійти у воду 1 раз за хід\n"
				.. "• Після води рух завершено для цього дослідника\n"
				.. "• Наступного ходу можна знову ввійти у воду"

			infoLabel.Text = string.format(
				"🎯 Ваш хід!\n"
					.. "⏱️ Залишилось дій: %d/3\n"
					.. "%s\n"
					.. "🖱️ Оберіть дослідника для переміщення",
				data.remainingActions or 0,
				generalRules
			)

			-- Збільшуємо розмір фрейму
			selectionFrame.Size = UDim2.new(0, 400, 0, 220)
		else
			print("⏳ Зараз ходить:", currentPlayerName)
			selectionFrame.Visible = false
		end
		updateExplorerStatusInfo()
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
	elseif data and data.type == "explorer_water_blocked" then
		-- Випадок, коли дослідник вже входив у воду
		print("💧 Дослідник заблокований для руху - вже входив у воду!")
		clearTileHighlights()

		if selectedExplorer then
			infoLabel.Text = string.format(
				"📍 Дослідник #%d\n"
					.. "❌ Заблоковано для руху!\n"
					.. "💧 Цей дослідник вже входив у воду цього ходу\n"
					.. "⏳ Почекайте наступного ходу, щоб рухатися знову\n\n"
					.. "🎯 Оберіть іншого дослідника",
				selectedExplorer:GetAttribute("ExplorerId")
			)
			infoLabel.TextColor3 = Color3.fromRGB(255, 100, 100)

			task.delay(3, function()
				if selectionFrame.Visible then
					clearSelectionState()
				end
			end)
		end
	elseif data and data.type == "boat_full" then
		-- НОВО: Обробка заповненого човна
		print("🚤 Човен #" .. (data.boatId or "?") .. " заповнений!")
		clearTileHighlights()

		if selectedExplorer then
			infoLabel.Text = string.format(
				"📍 Дослідник #%d\n"
					.. "❌ Човен #%d заповнений!\n"
					.. "🚤 Максимум 3 дослідника на човні\n"
					.. "🎯 Оберіть інший тайл або іншого дослідника",
				data.explorerId or selectedExplorer:GetAttribute("ExplorerId"),
				data.boatId or "?"
			)
			infoLabel.TextColor3 = Color3.fromRGB(255, 100, 100)

			task.delay(3, function()
				if selectionFrame.Visible then
					infoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
					infoLabel.Text = "Оберіть дослідника для переміщення"
				end
			end)
		end
	end
end)

-- Додайте цю функцію після інших функцій

-- ДОДАНО: Основний цикл для відстеження наведення на човни та дослідників
RunService.Heartbeat:Connect(function()
	-- Перевіряємо чи активна фаза гри
	if not isGamePhaseActive then
		if currentHoveredExplorer then
			highlightExplorerOnHover(currentHoveredExplorer, false)
		end
		if currentHoveredBoat then
			highlightBoatOnHover(currentHoveredBoat, false)
		end
		return
	end

	-- ДОДАНО: Спочатку перевіряємо човен
	local hoveredBoat = getBoatUnderCursor()

	if hoveredBoat and hoveredBoat ~= currentHoveredBoat then
		-- Навели на новий човен
		highlightBoatOnHover(currentHoveredBoat, false)
		highlightBoatOnHover(hoveredBoat, true)
		showBoatInfo(hoveredBoat)
	elseif not hoveredBoat and currentHoveredBoat then
		-- Зійшли з човна
		highlightBoatOnHover(currentHoveredBoat, false)
		currentHoveredBoat = nil
		selectionFrame.Visible = false
	end

	-- Потім перевіряємо дослідників (тільки якщо не на човні)
	if not hoveredBoat and isMyTurn then
		local hoveredExplorer = getExplorerUnderCursor()

		if hoveredExplorer and hoveredExplorer ~= currentHoveredExplorer then
			-- Навели на нового дослідника
			highlightExplorerOnHover(currentHoveredExplorer, false)
			highlightExplorerOnHover(hoveredExplorer, true)
		elseif not hoveredExplorer and currentHoveredExplorer then
			-- Зійшли з дослідника
			highlightExplorerOnHover(currentHoveredExplorer, false)
		end
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
			-- ДОДАНО: Спочатку перевіряємо чи це човен
			local boat = getBoatUnderCursor()
			if boat then
				-- Показуємо інформацію про човен
				showBoatInfo(boat)
				return
			end

			-- Потім перевіряємо чи це дослідник
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
		if boatHighlight then
			boatHighlight:Destroy()
			boatHighlight = nil
		end
		clearTileHighlights()
		currentHoveredExplorer = nil
		currentHoveredBoat = nil
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

	-- Знаходимо тайл за координатами
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

		-- ВИПРАВЛЕННЯ: Рахуємо, скільки вже дослідників на цьому тайлі
		local explorersOnTile = {}
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:GetAttribute("IsExplorer") then
				local expQ = obj:GetAttribute("Q")
				local expR = obj:GetAttribute("R")
				if expQ == q and expR == r and obj ~= explorer then
					table.insert(explorersOnTile, obj)
				end
			end
		end

		local explorerIndex = #explorersOnTile + 1 -- Наш дослідник буде наступним
		local maxExplorersPerTile = 6
		local spacing = 2 -- Відстань між дослідниками

		if isWaterTile then
			-- Позиціонування на воді зі зміщенням
			local baseHeight = 4.38 -- Базова висота над водою

			-- Розраховуємо зміщення по колу
			local angle = (explorerIndex - 1) * (360 / maxExplorersPerTile)
			local radius = 1.5 -- Радіус кола

			local offsetX = math.cos(math.rad(angle)) * radius
			local offsetZ = math.sin(math.rad(angle)) * radius

			local explorerPosition = Vector3.new(tilePosition.X + offsetX, baseHeight, tilePosition.Z + offsetZ)

			local rotatedCFrame = CFrame.new(explorerPosition) * CFrame.Angles(0, math.rad(90 + angle), 0)
			explorer:SetPrimaryPartCFrame(rotatedCFrame)

			print(
				"📍 Дослідник переміщений на ВОДУ Q=",
				q,
				"R=",
				r,
				"позиція:",
				explorerIndex,
				"з",
				maxExplorersPerTile
			)

			-- Додаємо ефект для води
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
			local radius = 2.0 -- Більший радіус для суші

			local offsetX = math.cos(math.rad(angle)) * radius
			local offsetZ = math.sin(math.rad(angle)) * radius

			local explorerPosition = Vector3.new(tilePosition.X + offsetX, baseHeight, tilePosition.Z + offsetZ)

			local rotatedCFrame = CFrame.new(explorerPosition) * CFrame.Angles(0, math.rad(90 + angle), 0)
			explorer:SetPrimaryPartCFrame(rotatedCFrame)

			print(
				"📍 Дослідник переміщений на ОСТРІВ Q=",
				q,
				"R=",
				r,
				"тип:",
				targetTileType,
				"позиція:",
				explorerIndex,
				"з",
				maxExplorersPerTile
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

		-- Додаємо атрибут з позицією на тайлі
		explorer:SetAttribute("TilePositionIndex", explorerIndex)
	else
		print(
			"❌ Не знайдено тайл для позиціонування дослідника Q=",
			q,
			"R=",
			r
		)
	end
end

local function updateExplorerPositionOnBoat(explorer, q, r, boatId)
	if not explorer or not explorer:IsA("Model") then
		return
	end

	-- Знаходимо човен за ID
	local boat = nil
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("IsBoat") and obj:GetAttribute("BoatId") == boatId then
			boat = obj
			break
		end
	end

	if not boat then
		-- Якщо човен не знайдений за ID, шукаємо за координатами
		boat = getBoatOnTile(q, r)
	end

	if boat then
		print("🚤 Дослідник сів на човен #" .. tostring(boatId))

		-- Рахуємо скільки дослідників вже на цьому човні
		local explorersOnBoat = 0
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:GetAttribute("IsExplorer") then
				local expQ = obj:GetAttribute("Q")
				local expR = obj:GetAttribute("R")
				if expQ == q and expR == r then
					explorersOnBoat = explorersOnBoat + 1
				end
			end
		end

		local explorerIndex = explorersOnBoat
		local maxExplorersPerBoat = 3

		if explorerIndex <= maxExplorersPerBoat then
			-- Позиціонуємо на човні зі зміщенням
			local boatPosition = boat.PrimaryPart.Position
			local baseHeight = 2 -- Базова висота над човном

			-- Розраховуємо зміщення по колу
			local angle = (explorerIndex - 1) * (360 / maxExplorersPerBoat)
			local radius = 1.2 -- Радіус на човні

			local offsetX = math.cos(math.rad(angle)) * radius
			local offsetZ = math.sin(math.rad(angle)) * radius

			local explorerPosition =
				Vector3.new(boatPosition.X + offsetX, boatPosition.Y + baseHeight, boatPosition.Z + offsetZ)

			local rotatedCFrame = CFrame.new(explorerPosition) * CFrame.Angles(0, math.rad(90 + angle), 0)
			explorer:SetPrimaryPartCFrame(rotatedCFrame)

			-- Додаємо спеціальний ефект для дослідників на човні
			local boatEffect = explorer:FindFirstChild("BoatEffect")
			if not boatEffect then
				boatEffect = Instance.new("ParticleEmitter")
				boatEffect.Name = "BoatEffect"
				boatEffect.Color = ColorSequence.new(Color3.fromRGB(0, 150, 255))
				boatEffect.Size = NumberSequence.new(0.3)
				boatEffect.Transparency = NumberSequence.new(0.7)
				boatEffect.Lifetime = NumberRange.new(1, 2)
				boatEffect.Rate = 15
				boatEffect.Speed = NumberRange.new(1)
				boatEffect.Parent = explorer.PrimaryPart
			end

			-- Оновлюємо атрибути
			explorer:SetAttribute("Q", q)
			explorer:SetAttribute("R", r)
			explorer:SetAttribute("IsOnWater", true)
			explorer:SetAttribute("OnBoat", true)
			explorer:SetAttribute("BoatId", boatId)

			print(
				"📍 Дослідник розміщений на човні #"
					.. boatId
					.. ", позиція: "
					.. explorerIndex
					.. "/"
					.. maxExplorersPerBoat
			)
		else
			print("❌ Забагато дослідників на човні!")
		end
	else
		print("❌ Човен не знайдений для позиціонування дослідника")
	end
end

-- Додайте після інших обробників подій
UpdateReadyStatusEvent.OnClientEvent:Connect(function(data)
	if data.type == "ExplorerMoved" then
		-- Знаходимо дослідника
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:GetAttribute("IsExplorer") and obj:GetAttribute("ExplorerId") == data.explorerId then
				if data.isBoatTile and data.boatId then
					-- Дослідник сів на човен
					updateExplorerPositionOnBoat(obj, data.q, data.r, data.boatId)
				else
					-- Звичайне переміщення
					updateExplorerPosition(obj, data.q, data.r)
				end

				break
			end
		end
	end
end)
