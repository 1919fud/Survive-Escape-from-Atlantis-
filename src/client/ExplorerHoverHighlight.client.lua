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
local SelectBoatEvent = GameEvents:WaitForChild("SelectBoatEvent")
local MoveBoatEvent = GameEvents:WaitForChild("MoveBoatEvent")

-- Стан
local currentHoveredExplorer = nil
local currentHighlight = nil
local selectedExplorer = nil
local selectionHighlight = nil
local selectedBoat = nil
local availableBoatTiles = {}
local boatTileHighlights = {}
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
infoLabel.Text = "Оберіть дослідника для переміщення або човен"
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

	-- Додаємо інформацію про можливість сісти на човен
	local boatHint =
		"\n🚤 Порада: Можна натиснути на човен, щоб посадити цього дослідника"

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
			.. "%s\n"
			.. "%s\n\n"
			.. "🖱️ Натисніть на доступний тайл або човен для переміщення",
		explorerId,
		treasureValue,
		q,
		r,
		isOnWater and "На воді 🌊" or "На суші ⛰️",
		rulesText,
		boatHint
	)

	selectionFrame.Visible = true
	selectionFrame.Size = UDim2.new(0, 350, 0, 200)
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

			-- Перевіряємо, чи є всі атрибути
			if boatId and q and r then
				print("🔍 Знайдено човен: ", current.Name, "ID:", boatId, "Q:", q, "R:", r)
				return current
			else
				print("⚠️ Човен має неповні атрибути:", current.Name)
				-- Спробуємо отримати координати з назви
				local nameParts = current.Name:split("_")
				if #nameParts >= 4 then
					local lastQ = tonumber(nameParts[#nameParts - 1])
					local lastR = tonumber(nameParts[#nameParts])
					if lastQ and lastR then
						print("🔍 Отримано координати з назви: Q=", lastQ, "R=", lastR)
						current:SetAttribute("Q", lastQ)
						current:SetAttribute("R", lastR)
						return current
					end
				end
			end
		end
		current = current.Parent
	end

	return nil
end

local function getBoatControllerClient(boat)
	local boatId = boat:GetAttribute("BoatId")
	local playerCounts = {}
	local maxCount = 0

	-- Рахуємо дослідників кожного гравця на човні
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") then
			if obj:GetAttribute("BoatId") == boatId then
				local playerName = obj:GetAttribute("Player")
				playerCounts[playerName] = (playerCounts[playerName] or 0) + 1
				if playerCounts[playerName] > maxCount then
					maxCount = playerCounts[playerName]
				end
			end
		end
	end

	-- Якщо човен пустий - повертаємо nil (всі можуть контролювати)
	if maxCount == 0 then
		print("🚤 Човен #" .. boatId .. " пустий - можуть контролювати всі")
		return nil
	end

	-- Знаходимо гравців з максимальною кількістю
	local controllers = {}
	for playerName, count in pairs(playerCounts) do
		if count == maxCount then
			table.insert(controllers, playerName)
		end
	end

	-- Якщо лише один гравець - він контролює
	if #controllers == 1 then
		return controllers[1]
	end

	-- Якщо декілька гравців - нічия
	if #controllers > 1 then
		print("🚤 Човен #" .. boatId .. " - нічия між " .. #controllers .. " гравцями")
		return nil -- nil означає "обидва можуть контролювати"
	end

	return nil
end

-- Функція для підсвічування човна
local function highlightBoatOnHover(boatModel, highlight)
	if not boatModel or not boatModel:IsA("Model") then
		return
	end

	-- ВИПРАВЛЕНО: Дозволяємо підсвічування човна навіть якщо є обраний дослідник
	-- Але змінюємо колір, щоб показати, що це не для переміщення

	local boatId = boatModel:GetAttribute("BoatId")
	local boatPlayer = boatModel:GetAttribute("Player")

	if not boatId or not boatPlayer then
		print(
			"⚠️ Човен не має всіх атрибутів, пропускаємо підсвічування"
		)
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

	-- Вибираємо колір залежно від гравця та стану
	local boatPlayerName = boatModel:GetAttribute("Player") or "Unknown"
	local isMyBoat = (boatPlayerName == player.Name)

	-- Якщо є обраний дослідник - показуємо спеціальний колір
	if selectedExplorer then
		-- Жовтий для можливості посадити дослідника на човен
		highlightObj.FillColor = Color3.fromRGB(255, 255, 0)
		highlightObj.OutlineColor = Color3.fromRGB(255, 200, 0)
	elseif isMyBoat then
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
local function clearBoatAttributes(explorer)
	if not explorer or not explorer:IsA("Model") then
		return
	end

	explorer:SetAttribute("OnBoat", false)
	explorer:SetAttribute("BoatId", nil)
	explorer:SetAttribute("BoatPlaceIndex", nil)

	-- Видаляємо всі ефекти човна
	local boatEffect = explorer:FindFirstChild("BoatEffect")
	if boatEffect then
		boatEffect:Destroy()
	end

	local waterEffect = explorer:FindFirstChild("WaterEffect")
	if waterEffect then
		waterEffect:Destroy()
	end

	print("🧹 Очищено атрибути човна для дослідника")
end
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

local function clearBoatTileHighlights()
	for _, highlight in ipairs(boatTileHighlights) do
		if highlight and highlight.Parent then
			local tile = highlight.Parent
			local billboard = tile:FindFirstChild("BoatCostDisplay")
			if billboard then
				billboard:Destroy()
			end
			highlight:Destroy()
		end
	end
	boatTileHighlights = {}
end
local function clearSelectionState()
	print("🧹 Очищення стану вибору...")

	-- Очищаємо підсвічування тайлів
	clearTileHighlights()

	-- Очищаємо підсвічування човна
	if boatHighlight then
		boatHighlight:Destroy()
		boatHighlight = nil
	end
	clearBoatTileHighlights()

	-- ВИПРАВЛЕНО: видаляємо ТІЛЬКИ виділення обраного дослідника
	if selectionHighlight then
		selectionHighlight:Destroy()
		selectionHighlight = nil
	end

	-- ВИПРАВЛЕНО: Залишаємо підсвічування наведення
	-- воно автоматично оновлюється в циклі Heartbeat

	-- Скидаємо стан
	isMovementMode = false
	selectedExplorer = nil
	selectedBoat = nil

	-- Ховаємо UI
	selectionFrame.Visible = false

	-- Повертаємо стандартний текст
	if infoLabel then
		infoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		infoLabel.Text = "Оберіть дослідника для переміщення або човен"
	end

	print("✅ Стан вибору очищено (збережено підсвічування наведення)")
end
local function clearBoatSelection()
	clearBoatTileHighlights()
	selectedBoat = nil

	-- Сховати UI якщо потрібно
	if selectionFrame then
		if not selectedExplorer then
			selectionFrame.Visible = false
		end
	end
end

local function getExplorersOnBoatCount(boatId)
	if not boatId then
		return 0
	end

	local count = 0
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") then
			local objBoatId = obj:GetAttribute("BoatId")
			-- Перевіряємо як стрінгу і як число
			if objBoatId and tostring(objBoatId) == tostring(boatId) then
				count = count + 1
			end
		end
	end

	print("🔍 На човні #" .. boatId .. " знайдено " .. count .. " дослідників")
	return count
end

local function hasSpaceOnBoat(boatId)
	if not boatId then
		return false
	end

	local count = getExplorersOnBoatCount(boatId)
	return count < 3
end

local function onBoatClick(boat)
	if not isGamePhaseActive or not isMyTurn then
		print("❌ Не ваш хід або фаза не активна!")
		return
	end

	local boatId = boat:GetAttribute("BoatId")
	local controllerName = getBoatControllerClient(boat)

	-- Якщо є обраний дослідник - спробувати посадити його на човен
	if selectedExplorer then
		print("🚤 Спроба посадити обраного дослідника на човен")

		-- Перевіряємо, чи це наш дослідник
		local explorerPlayer = selectedExplorer:GetAttribute("Player")
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

		-- Перевіряємо, чи можна контролювати човен
		if controllerName and controllerName ~= player.Name then
			print("❌ Ви не контролюєте цей човен!")
			infoLabel.Text = "❌ Ви не контролюєте цей човен!\n🚤 Контролює: "
				.. controllerName
			infoLabel.TextColor3 = Color3.fromRGB(255, 100, 100)

			task.delay(2, function()
				if infoLabel then
					infoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
					infoLabel.Text = "Оберіть човен або дослідника"
				end
			end)
			return
		end

		-- Перевіряємо, чи не заповнений човен
		local explorersOnBoatCount = getExplorersOnBoatCount(boatId)
		if explorersOnBoatCount >= 3 then
			print("❌ Човен заповнений!")
			infoLabel.Text = "❌ Човен заповнений!\n🚤 Максимум 3 дослідника"
			infoLabel.TextColor3 = Color3.fromRGB(255, 100, 100)

			task.delay(2, function()
				if infoLabel then
					infoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
					infoLabel.Text = "Оберіть інший човен або тайл"
				end
			end)
			return
		end

		-- Отримуємо координати човна
		local boatQ = boat:GetAttribute("Q")
		local boatR = boat:GetAttribute("R")
		local explorerId = selectedExplorer:GetAttribute("ExplorerId")

		print(
			"🚤 Посадка дослідника #",
			explorerId,
			"на човен #",
			boatId,
			"Q=",
			boatQ,
			"R=",
			boatR
		)

		-- Відправляємо запит на сервер
		MoveExplorerEvent:FireServer(explorerId, boatQ, boatR)

		-- Очищаємо вибір
		clearSelectionState()
		return
	end

	-- Якщо немає обраного дослідника - обираємо човен для переміщення
	if controllerName then
		-- Якщо є контролер, перевіряємо чи це наш гравець
		if controllerName ~= player.Name then
			print("❌ Ви не контролюєте цей човен!")
			infoLabel.Text = "❌ Ви не контролюєте цей човен!\n🚤 Контролює: "
				.. controllerName
			infoLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
			task.delay(2, function()
				if infoLabel then
					infoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
					infoLabel.Text = "Оберіть човен або дослідника"
				end
			end)
			return
		end
	else
		-- Якщо контролера немає (човен пустий або нічия) - наш гравець може контролювати
		print("✅ Можете контролювати цей човен (пустий/спільний)")
	end

	-- Якщо вже обраний цей човен - скасувати вибір
	if selectedBoat == boat then
		clearBoatSelection()
		SelectBoatEvent:FireServer(nil)
	else
		-- Обрати новий човен
		clearBoatSelection()
		clearSelectionState() -- Очистити вибір дослідника

		selectedBoat = boat
		SelectBoatEvent:FireServer(boatId)

		-- Показати інформацію про човен
		selectionFrame.Visible = true
		titleLabel.Text = "🚤 ОБРАНО ЧОВЕН"

		local explorersOnBoat = 0
		local explorersList = ""
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:GetAttribute("IsExplorer") and obj:GetAttribute("BoatId") == boatId then
				explorersOnBoat = explorersOnBoat + 1
				explorersList = explorersList .. "• " .. obj:GetAttribute("Player") .. "\n"
			end
		end

		infoLabel.Text = string.format(
			"🚤 Човен #%d\n"
				.. "👤 Контролює: %s\n"
				.. "👥 Дослідників на човні: %d/3\n"
				.. "%s\n"
				.. "📍 Координати: Q=%d R=%d\n\n"
				.. "🖱️ Натисніть на доступний водний тайл для переміщення",
			boatId,
			player.Name,
			explorersOnBoat,
			explorersOnBoat > 0 and "📋 Список:\n" .. explorersList or "🪹 Човен порожній",
			boat:GetAttribute("Q") or 0,
			boat:GetAttribute("R") or 0
		)

		print("🚤 Обрано човен #", boatId, "під контролем гравця:", player.Name)
	end
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

	-- Отримуємо інформацію про човен
	local boatInfo = getBoatInfo(boat)

	-- Перевіряємо, чи є обраний дослідник
	local hasSelectedExplorer = selectedExplorer ~= nil

	selectionFrame.Visible = true
	selectionFrame.Size = UDim2.new(0, 320, 0, hasSelectedExplorer and 180 or 140)
	selectionFrame.Position = UDim2.new(0.5, -160, 0.05, 0)

	--[[titleLabel.Text = "🚤 ІНФОРМАЦІЯ ПРО ЧОВЕН"

	if hasSelectedExplorer then
		infoLabel.Text = boatInfo .. "\n\n🎯 Оберіть дію:"

		-- Додаємо кнопку "Посадити дослідника"
		local actionButton = selectionFrame:FindFirstChild("BoardBoatButton")
		if not actionButton then
			actionButton = Instance.new("TextButton")
			actionButton.Name = "BoardBoatButton"
			actionButton.Size = UDim2.new(0, 180, 0, 30)
			actionButton.Position = UDim2.new(0.5, -90, 0.8, 0)
			actionButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
			actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			actionButton.Text = "🚤 ПОСАДИТИ ДОСЛІДНИКА"
			actionButton.TextSize = 12
			actionButton.Font = Enum.Font.GothamBold
			actionButton.Parent = selectionFrame

			local UICornerBtn = Instance.new("UICorner")
			UICornerBtn.CornerRadius = UDim.new(0, 4)
			UICornerBtn.Parent = actionButton

			-- Обробник кліку на кнопку
			actionButton.MouseButton1Click:Connect(function()
				local boatQ = boat:GetAttribute("Q")
				local boatR = boat:GetAttribute("R")
				local boatId = boat:GetAttribute("BoatId")
				local explorerId = selectedExplorer:GetAttribute("ExplorerId")

				print("🚤 Користувач клікнув посадити дослідника на човен")
				MoveExplorerEvent:FireServer(explorerId, boatQ, boatR)
				clearSelectionState()
			end)
		end
		actionButton.Visible = true
	else
		infoLabel.Text = boatInfo
			.. "\n\nℹ️ Оберіть дослідника, щоб посадити на човен"

		-- Ховаємо кнопку, якщо немає обраного дослідника
		local actionButton = selectionFrame:FindFirstChild("BoardBoatButton")
		if actionButton then
			actionButton.Visible = false
		end
	end
]]
	--
	closeButton.Visible = true
	closeButton.Position = UDim2.new(0.5, -40, 1, -30)
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

local function highlightBoatMovementTiles(data)
	if not data or not data.availableTiles then
		return
	end

	-- Очистити попередні підсвічування
	for _, highlight in ipairs(boatTileHighlights) do
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end
	boatTileHighlights = {}

	-- Підсвітити доступні тайли
	for _, tileData in ipairs(data.availableTiles) do
		local tile = nil

		-- Шукаємо тайл за координатами
		local map = workspace:WaitForChild("Map")
		for _, obj in ipairs(map:GetDescendants()) do
			if obj:IsA("MeshPart") then
				local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
				local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
				if tileQ == tileData.q and tileR == tileData.r then
					tile = obj
					break
				end
			end
		end

		if tile then
			local highlight = Instance.new("Highlight")
			highlight.Name = "BoatMovementHighlight"
			highlight.FillColor = Color3.fromRGB(0, 150, 255) -- Синій для руху човна
			highlight.OutlineColor = Color3.fromRGB(0, 200, 255)
			highlight.FillTransparency = 0.5
			highlight.OutlineTransparency = 0
			highlight.Parent = tile

			-- Додати BillboardGui з інформацією
			local billboard = Instance.new("BillboardGui")
			billboard.Name = "BoatCostDisplay"
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
			costLabel.Text = "1 🚤"
			costLabel.Font = Enum.Font.GothamBlack
			costLabel.TextScaled = true
			costLabel.TextStrokeTransparency = 0
			costLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			costLabel.Parent = billboard

			table.insert(boatTileHighlights, highlight)
		end
	end

	print("📍 Показано доступні тайли для переміщення човна")
end
-- Підсвічування обраного дослідника

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

-- Обробник кліку по досліднику
local function onExplorerClick(explorer)
	if not isGamePhaseActive or not isMyTurn then
		print("❌ Не ваш хід або фаза не активна!")
		print("  isGamePhaseActive:", isGamePhaseActive)
		print("  isMyTurn:", isMyTurn)
		return
	end

	local boat = getBoatUnderCursor()
	if boat then
		print("⚠️ Клік на дослідника через човен - ігноруємо")
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
				infoLabel.Text = "Оберіть дослідника для переміщення або човен"
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
			clearSelectionState()
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
local function updateExplorerPositionOnBoat(explorer, q, r, boatId)
	if not explorer or not explorer:IsA("Model") then
		return
	end
	clearBoatAttributes(explorer)
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

		-- Знаходимо всі місця в човні
		local places = {}
		for _, part in ipairs(boat:GetDescendants()) do
			if part.Name == "place1" or part.Name == "place2" or part.Name == "place3" then
				table.insert(places, part)
			end
		end

		-- Сортуємо місця за іменем
		table.sort(places, function(a, b)
			return a.Name < b.Name
		end)

		-- Визначаємо, які місця вже зайняті
		local occupiedPlaces = {}
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:GetAttribute("IsExplorer") and obj:GetAttribute("BoatId") == boatId and obj ~= explorer then
				local placeIndex = obj:GetAttribute("BoatPlaceIndex")
				if placeIndex then
					occupiedPlaces[placeIndex] = true
				end
			end
		end

		-- Шукаємо перше вільне місце
		local selectedPlace = nil
		local selectedIndex = nil
		for i, place in ipairs(places) do
			if not occupiedPlaces[i] then
				selectedPlace = place
				selectedIndex = i
				break
			end
		end

		if selectedPlace then
			local placeHeight = selectedPlace.Size.Y
			local explorerHeight = explorer.PrimaryPart.Size.Y
			local yOffset = (placeHeight / 2) + (explorerHeight / 2)
			local rotation = CFrame.Angles(0, math.rad(90), 0)

			local newCFrame = selectedPlace.CFrame * rotation * CFrame.new(0, yOffset, 0)
			-- Позиціонуємо дослідника на вершині місця
			explorer:SetPrimaryPartCFrame(newCFrame)

			-- Оновлюємо атрибути
			explorer:SetAttribute("Q", q)
			explorer:SetAttribute("R", r)
			explorer:SetAttribute("IsOnWater", true)
			explorer:SetAttribute("OnBoat", true)
			explorer:SetAttribute("BoatId", boatId)
			explorer:SetAttribute("BoatPlaceIndex", selectedIndex)

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

			print(
				"📍 Дослідник розміщений на човні #"
					.. boatId
					.. ", місце: "
					.. selectedPlace.Name
			)
		else
			print("❌ Немає вільних місць на човні #" .. boatId)
		end
	else
		if explorer:GetAttribute("OnBoat") then
			explorer:SetAttribute("OnBoat", false)
			explorer:SetAttribute("BoatId", nil)
			explorer:SetAttribute("BoatPlaceIndex", nil)
		end
		print("❌ Човен не знайдений для позиціонування дослідника")
	end
end
local function updateExplorersOnBoatPosition(boatId, q, r)
	print("🔄 [КЛІЄНТ] Оновлення позицій дослідників на човні #", boatId)

	-- Знаходимо човен
	local boat = nil
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("IsBoat") then
			local objBoatId = tonumber(obj:GetAttribute("BoatId")) or 0
			if objBoatId == boatId then
				boat = obj
				break
			end
		end
	end

	if not boat then
		print("❌ Човен не знайдений")
		return
	end

	-- Знаходимо всі місця в човні
	local places = {}
	for _, part in ipairs(boat:GetDescendants()) do
		if part.Name == "place1" or part.Name == "place2" or part.Name == "place3" then
			places[part.Name] = part
		end
	end

	-- Сортуємо місця за іменем
	local sortedPlaces = {}
	for i = 1, 3 do
		local placeName = "place" .. i
		if places[placeName] then
			table.insert(sortedPlaces, places[placeName])
		end
	end

	-- Оновлюємо позиції всіх дослідників на човні
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") then
			local explorerBoatId = obj:GetAttribute("BoatId")
			if explorerBoatId and tostring(explorerBoatId) == tostring(boatId) then
				local boatPlaceIndex = obj:GetAttribute("BoatPlaceIndex")

				-- Оновлюємо координати дослідника
				obj:SetAttribute("Q", q)
				obj:SetAttribute("R", r)

				-- Позиціонуємо дослідника на його попередньому місці
				if boatPlaceIndex and boatPlaceIndex >= 1 and boatPlaceIndex <= #sortedPlaces then
					local selectedPlace = sortedPlaces[boatPlaceIndex]
					if selectedPlace then
						local placeHeight = selectedPlace.Size.Y
						local explorerHeight = obj.PrimaryPart.Size.Y
						local yOffset = (placeHeight / 2) + (explorerHeight / 2)
						local rotation = CFrame.Angles(0, math.rad(90), 0)

						local newCFrame = selectedPlace.CFrame * rotation * CFrame.new(0, yOffset, 0)

						-- Позиціонуємо дослідника на вершині місця
						obj:SetPrimaryPartCFrame(newCFrame)

						print(
							"📍 Дослідник #"
								.. (obj:GetAttribute("ExplorerId") or "?")
								.. " залишився на місці "
								.. boatPlaceIndex
						)
					else
						print("❌ Місце " .. boatPlaceIndex .. " не знайдено на човні")
					end
				else
					print(
						"⚠️ Дослідник не має правильного індексу місця: "
							.. tostring(boatPlaceIndex)
					)
				end
			end
		end
	end

	print("✅ Позиції дослідників на човні оновлено (збережено місця)")
end
-- Додайте цю функцію десь перед обробником UpdateReadyStatusEvent
local function updateBoatPosition(boatId, q, r)
	print("🔄 [КЛІЄНТ] Оновлення позиції човна #", boatId, "Q=", q, "R=", r)

	-- Шукаємо човен за boatId
	local boatModel = nil
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("IsBoat") then
			local objBoatId = tonumber(obj:GetAttribute("BoatId")) or 0
			if objBoatId == boatId then
				boatModel = obj
				break
			end
		end
	end

	if not boatModel then
		print("❌ [КЛІЄНТ] Човен не знайдений для оновлення позиції")
		return
	end

	print("✅ [КЛІЄНТ] Знайдено човен: ", boatModel.Name)

	-- ОНОВЛЮЄМО НАЗВУ ЧОВНА
	local newName = "Boat_"
		.. tostring(boatId)
		.. "_"
		.. (boatModel:GetAttribute("Player") or "Unknown")
		.. "_"
		.. q
		.. "_"
		.. r
	boatModel.Name = newName
	print("🔄 [КЛІЄНТ] Оновлено назву човна на: ", newName)

	boatModel:SetAttribute("Q", q)
	boatModel:SetAttribute("R", r)

	-- Шукаємо тайл за новими координатами
	local map = workspace:WaitForChild("Map")
	local targetTile = nil

	-- Шукаємо водний тайл
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
			local isWater = obj:GetAttribute("IsWater") or obj:GetAttribute("Placeboat") == true

			if tileQ == q and tileR == r and isWater then
				targetTile = obj
				print("✅ [КЛІЄНТ] Знайдено водний тайл для човна")
				break
			end
		end
	end

	if not targetTile then
		print(
			"❌ [КЛІЄНТ] Тайл не знайдений для позиціонування човна Q=",
			q,
			"R=",
			r
		)
		return
	end

	if targetTile and boatModel.PrimaryPart then
		local tileTopY = targetTile.Position.Y + targetTile.Size.Y / 2
		local boatBottomY = boatModel.PrimaryPart.Position.Y - boatModel.PrimaryPart.Size.Y / 2
		local yOffset = 2.932

		local targetPosition = targetTile.Position + Vector3.new(0, yOffset, 0)
		local targetCFrame = CFrame.new(targetPosition) * CFrame.Angles(0, math.rad(180), 0)

		boatModel:PivotTo(targetCFrame)
		print(
			"✅ [КЛІЄНТ] Човен #"
				.. tostring(boatId)
				.. " переміщений на нову позицію"
		)

		-- ВИПРАВЛЕНО: Оновлюємо дослідників на човні, зберігаючи їхні місця
		updateExplorersOnBoatPosition(boatId, q, r)
	else
		print("❌ [КЛІЄНТ] Не знайдено водний тайл для позиціонування")
	end
end

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

		-- Додаємо підказку про човни
		--[[if infoLabel then
			infoLabel.Text = infoLabel.Text
				.. "\n\n🚤 Також можна клікнути на човен безпосередньо!"
		end]]
		--
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
					infoLabel.Text =
						"Оберіть дослідника для переміщення або човен"
				end
			end)
		end
	elseif data and data.type == "boat_movement" then
		print("🚤 Отримано доступні тайли для переміщення човна")
		highlightBoatMovementTiles(data)

		if infoLabel then
			infoLabel.Text = infoLabel.Text
				.. "\\n\\n📍 Доступні водні тайли позначені синім"
		end
	elseif data and data.type == "turn_ended" then
		-- Хід завершено
		print("⏹️ Хід завершено: " .. (data.message or "Усі дії використані"))

		-- Приховуємо UI вибору
		isGamePhaseActive = false
		isMyTurn = false
		selectionFrame.Visible = false

		-- Очищаємо підсвічування
		if currentHighlight then
			currentHighlight:Destroy()
			currentHighlight = nil
		end

		if selectionHighlight then
			selectionHighlight:Destroy()
			selectionHighlight = nil
		end

		clearTileHighlights()
		clearBoatTileHighlights()

		currentHoveredExplorer = nil
		currentHoveredBoat = nil
		selectedExplorer = nil

		-- Показуємо повідомлення
		if infoLabel then
			infoLabel.Text = data.message or "Хід завершено! Чекайте наступного ходу."
			infoLabel.TextColor3 = Color3.fromRGB(255, 100, 100)

			task.delay(3, function()
				if infoLabel then
					infoLabel.Text = "Оберіть дослідника або човен"
					infoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
				end
			end)
		end
	end
end)

local function updateHoverUI(hoveredBoat, hoveredExplorer)
	if not selectionFrame.Visible then
		return
	end

	-- Якщо навели на човен
	if hoveredBoat then
		local boatInfo = getBoatInfo(hoveredBoat)
		titleLabel.Text = "🚤 ЧОВЕН"
		infoLabel.Text = boatInfo .. "\n\n🖱️ Натисніть, щоб обрати"

	-- Якщо навели на дослідника
	elseif hoveredExplorer then
		local explorerId = hoveredExplorer:GetAttribute("ExplorerId") or "?"
		local explorerPlayer = hoveredExplorer:GetAttribute("Player") or "?"
		local isMyExplorer = (explorerPlayer == player.Name)

		if isMyExplorer then
			titleLabel.Text = "🕵️ ВАШ ДОСЛІДНИК"
			infoLabel.Text = string.format(
				"📍 Дослідник #%d\n👤 Власник: %s\n\n🖱️ Натисніть, щоб обрати для переміщення",
				explorerId,
				explorerPlayer
			)
		else
			titleLabel.Text = "👤 ЧУЖИЙ ДОСЛІДНИК"
			infoLabel.Text = string.format(
				"📍 Дослідник #%d\n👤 Власник: %s\n\n❌ Це дослідник іншого гравця",
				explorerId,
				explorerPlayer
			)
		end
	end
end
-- Основний цикл для відстеження наведення на човни та дослідників
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

	-- Перевіряємо, чи наш хід
	if not isMyTurn then
		-- Не наш хід - приховуємо підсвічування
		if currentHoveredExplorer then
			highlightExplorerOnHover(currentHoveredExplorer, false)
		end
		if currentHoveredBoat then
			highlightBoatOnHover(currentHoveredBoat, false)
		end
		return
	end

	-- 1. Спочатку перевіряємо човен
	local hoveredBoat = getBoatUnderCursor()

	-- 2. Потім перевіряємо дослідника (тільки якщо не на човні)
	local hoveredExplorer = nil
	if not hoveredBoat then
		hoveredExplorer = getExplorerUnderCursor()
	end

	-- 3. Логіка для човнів
	if hoveredBoat then
		-- Навели на човен
		if hoveredBoat ~= currentHoveredBoat then
			-- Якщо був наведений на дослідника - очищаємо його підсвічування
			if currentHoveredExplorer then
				highlightExplorerOnHover(currentHoveredExplorer, false)
				currentHoveredExplorer = nil
			end

			-- Оновлюємо підсвічування човна
			highlightBoatOnHover(currentHoveredBoat, false)
			highlightBoatOnHover(hoveredBoat, true)

			-- Оновлюємо UI
			if selectedExplorer then
				--updateBoatHoverUIWithSelectedExplorer(hoveredBoat)
			else
				updateHoverUI(hoveredBoat, nil)
			end
		end
	elseif currentHoveredBoat then
		-- Зійшли з човна
		highlightBoatOnHover(currentHoveredBoat, false)
		currentHoveredBoat = nil
	end

	-- 4. Логіка для дослідників (тільки якщо не на човні)
	if hoveredExplorer then
		-- Навели на дослідника
		if hoveredExplorer ~= currentHoveredExplorer then
			-- Якщо був наведений на човен - очищаємо його підсвічування
			if currentHoveredBoat then
				highlightBoatOnHover(currentHoveredBoat, false)
				currentHoveredBoat = nil
			end

			-- Оновлюємо підсвічування дослідника
			highlightExplorerOnHover(currentHoveredExplorer, false)
			highlightExplorerOnHover(hoveredExplorer, true)

			-- Оновлюємо UI
			updateHoverUI(nil, hoveredExplorer)
		end
	elseif currentHoveredExplorer and not hoveredBoat then
		-- Зійшли з дослідника (і не навели на човен)
		highlightExplorerOnHover(currentHoveredExplorer, false)
		currentHoveredExplorer = nil
	end

	-- 5. Якщо ні на що не наведено - відновлюємо стандартний UI
	if not hoveredBoat and not hoveredExplorer and selectionFrame.Visible then
		if selectedExplorer then
			-- Якщо є обраний дослідник, показуємо інформацію про нього
			updateSelectionUI(selectedExplorer)
		elseif selectedBoat then
			-- Якщо є обраний човен, показуємо інформацію про нього
			titleLabel.Text = "🚤 ОБРАНО ЧОВЕН"
			infoLabel.Text = "Оберіть водний тайл для переміщення човна"
		else
			titleLabel.Text = "🕵️ ОБРАНО ДОСЛІДНИКА"
			infoLabel.Text = "Оберіть дослідника для переміщення"
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
			-- 1. Спочатку перевіряємо чи це човен
			local boat = getBoatUnderCursor()

			if boat then
				onBoatClick(boat)
				return
			end

			-- 2. Перевіряємо, чи це підсвічений тайл для човна
			if selectedBoat then
				local highlightedTile = target:FindFirstChild("BoatMovementHighlight")
				if highlightedTile then
					local boatId = selectedBoat:GetAttribute("BoatId")

					-- Знайти координати тайла
					local tileQ = target:GetAttribute("Q") or target:GetAttribute("q")
					local tileR = target:GetAttribute("R") or target:GetAttribute("r")

					if tileQ and tileR then
						MoveBoatEvent:FireServer(boatId, tileQ, tileR)
						clearBoatSelection()
						return
					end
				end
			end

			-- 3. Перевіряємо, чи це підсвічений тайл для дослідника
			local highlightedTile = getHighlightedTileUnderCursor()
			if highlightedTile and selectedExplorer and isMovementMode then
				moveExplorerToTile(highlightedTile)
				return
			end

			-- 4. Потім перевіряємо чи це дослідник
			local explorer = getExplorerUnderCursor()
			if explorer then
				onExplorerClick(explorer)
				return
			end

			-- 5. Якщо нічого не знайдено, але є обраний дослідник
			if selectedExplorer then
				print("⚠️ Клік поза доступними тайлами")
				infoLabel.Text = "⚠️ Клікніть на доступний тайл або човен"
				infoLabel.TextColor3 = Color3.fromRGB(255, 165, 0)

				task.delay(2, function()
					if infoLabel then
						infoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
						infoLabel.Text = "Оберіть дослідника для переміщення"
					end
				end)
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
	local isBoatTile = false -- ДОДАНО: Оголошуємо змінну тут

	-- Спочатку шукаємо тайл острова
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
			local isLand = obj:GetAttribute("IsLand")

			if tileQ == q and tileR == r and isLand == true then
				targetTile = obj
				isWaterTile = false
				isBoatTile = false -- Сушя - не човен
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

					-- Перевіряємо, чи є човен на цьому тайлі
					isBoatTile = false
					for _, boatObj in ipairs(workspace:GetChildren()) do
						if boatObj:IsA("Model") and boatObj:GetAttribute("IsBoat") then
							local boatQ = boatObj:GetAttribute("Q")
							local boatR = boatObj:GetAttribute("R")
							if boatQ == q and boatR == r then
								isBoatTile = true
								break
							end
						end
					end

					print(
						"🌊 Знайдено водний тайл для дослідника"
							.. (isBoatTile and " (з човном)" or "")
					)
					break
				end
			end
		end
	end

	-- ДОДАНО: Перевіряємо, чи дослідник був на човні
	local wasOnBoat = explorer:GetAttribute("OnBoat") == true
	local oldBoatId = explorer:GetAttribute("BoatId")

	if targetTile and explorer.PrimaryPart then
		local tilePosition = targetTile.Position

		-- ВИПРАВЛЕННЯ: ��ахуємо, скільки вже дослідників на цьому тайлі
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

		-- ВИПРАВЛЕНО: Скидаємо атрибути човна якщо це НЕ ����овен
		if wasOnBoat and not isBoatTile then
			explorer:SetAttribute("OnBoat", false)
			explorer:SetAttribute("BoatId", nil)
			explorer:SetAttribute("BoatPlaceIndex", nil)

			-- Видаляємо всі ефекти човна
			local boatEffect = explorer:FindFirstChild("BoatEffect")
			if boatEffect then
				boatEffect:Destroy()
			end

			print("🚤 Дослідник повністю зійшов з човна #" .. tostring(oldBoatId))
		end

		-- Якщо це вода без човна, очищуємо атрибути човна
		if isWaterTile and not isBoatTile then
			explorer:SetAttribute("OnBoat", false)
			explorer:SetAttribute("BoatId", nil)
			explorer:SetAttribute("BoatPlaceIndex", nil)

			-- Видаляємо ефект човна, якщо він є
			local boatEffect = explorer:FindFirstChild("BoatEffect")
			if boatEffect then
				boatEffect:Destroy()
			end
		end

		-- Якщо це суша, очищуємо атрибути човна
		if not isWaterTile then
			explorer:SetAttribute("OnBoat", false)
			explorer:SetAttribute("BoatId", nil)
			explorer:SetAttribute("BoatPlaceIndex", nil)

			-- Видаляємо ефект човна, якщо він є
			local boatEffect = explorer:FindFirstChild("BoatEffect")
			if boatEffect then
				boatEffect:Destroy()
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

-- Додайте після інших обробників подій
UpdateReadyStatusEvent.OnClientEvent:Connect(function(data)
	if data.type == "ExplorerMoved" then
		-- Оновлюємо стан дослідника, якщо він обраний
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:GetAttribute("IsExplorer") and obj:GetAttribute("ExplorerId") == data.explorerId then
				if data.isWaterTile and not data.isBoatTile then
					obj:SetAttribute("OnBoat", false)
					obj:SetAttribute("BoatId", nil)
					obj:SetAttribute("BoatPlaceIndex", nil)

					-- Видаляємо ефекти човна
					local boatEffect = obj:FindFirstChild("BoatEffect")
					if boatEffect then
						boatEffect:Destroy()
					end
				end

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
		if selectedExplorer and selectedExplorer:GetAttribute("ExplorerId") == data.explorerId then
			-- Оновлюємо атрибут IsOnWater
			selectedExplorer:SetAttribute("IsOnWater", data.isWaterTile or false)

			-- Оновлюємо UI
			updateSelectionUI(selectedExplorer)

			-- Додаткове повідомлення якщо крок на воду
			if data.isWaterTile then
				infoLabel.Text = infoLabel.Text
					.. "\n\n💧 КРОК НА ВОДУ! Рух завершено для цього до��лідника."

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
	elseif data.type == "BoatMoved" then
		print("🚤 [КЛІЄНТ] Отримано оновлення позиції човна #", data.boatId)
		updateBoatPosition(data.boatId, data.q, data.r)

		-- Оновлюємо UI
		if selectionFrame.Visible and infoLabel then
			infoLabel.Text = "🚤 Човен переміщено на Q="
				.. data.q
				.. " R="
				.. data.r
				.. "!\n🎯 Оберіть наступну дію"

			-- Через 2 секунди оновлюємо текст
			task.delay(2, function()
				if infoLabel then
					infoLabel.Text = "Оберіть човен або дослідника"
				end
			end)
		end
	end
end)
local function debugAllBoats()
	print("🔍 [ДЕБАГ] Всі човни в workspace:")
	local boatCount = 0
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("IsBoat") then
			boatCount = boatCount + 1
			local boatId = obj:GetAttribute("BoatId")
			local q = obj:GetAttribute("Q")
			local r = obj:GetAttribute("R")
			local playerName = obj:GetAttribute("Player")
			print(
				"   "
					.. boatCount
					.. ". "
					.. obj.Name
					.. " - ID: "
					.. tostring(boatId)
					.. " Q: "
					.. tostring(q)
					.. " R: "
					.. tostring(r)
					.. " Власник: "
					.. tostring(playerName)
			)
		end
	end
	print("📊 Всього човнів: " .. boatCount)
end

-- Викликати при натисканні клавіші F3
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.F3 then
		debugAllBoats()
	end
end)
