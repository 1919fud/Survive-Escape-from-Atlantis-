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
local floodHighlights = {}
local isGamePhaseActive = false
local isMyTurn = false
local availableTiles = {} -- Таблиця доступних для переміщення тайлів
local tileHighlights = {} -- Підсвічування тайлів
local isMovementMode = false
local isCreaturePhase = false
local currentCreatureTurn = nil -- "Shark", "Kaiju", "Octopus"
local selectedCreatureObj = nil -- Об'єкт вибраної істоти

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
			local objBoatId = obj:GetAttribute("BoatId")
			-- ВИПРАВЛЕНО: перетворюємо на строку для порівняння
			if tostring(objBoatId) == tostring(boatId) then
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

	local controllerName = getBoatControllerClient(boatModel)
	local canControl = false

	-- Вибираємо колір залежно від гравця та стану
	if controllerName == nil then
		-- Човен пустий або нічия - всі можуть контролювати
		canControl = true
		print("✅ Човен #" .. boatId .. " пустий/спільний - можна контролювати")
	elseif controllerName == player.Name then
		-- Ми контролюємо човен
		canControl = true
		print("✅ Човен #" .. boatId .. " під вашим контролем")
	else
		-- Хтось інший контролює човен
		canControl = false
		print("❌ Човен #" .. boatId .. " контролює " .. controllerName)
	end

	-- Якщо є обраний дослідник - показуємо спеціальний колір
	if selectedExplorer then
		-- Якщо є обраний дослідник
		if canControl then
			-- Можемо посадити дослідника на човен - ЖОВТИЙ
			highlightObj.FillColor = Color3.fromRGB(0, 255, 0)
			highlightObj.OutlineColor = Color3.fromRGB(0, 200, 0)
			print("🚤 Човен доступний для посадки дослідника")
		else
			-- Не можемо посадити - ЧЕРВОНИЙ
			highlightObj.FillColor = Color3.fromRGB(255, 50, 50)
			highlightObj.OutlineColor = Color3.fromRGB(200, 0, 0)
			print("❌ Човен недоступний для посадки")
		end
	else
		-- Немає обраного дослідника
		if canControl then
			-- Можемо рухати човен - ЗЕЛЕНИЙ
			highlightObj.FillColor = Color3.fromRGB(0, 255, 0)
			highlightObj.OutlineColor = Color3.fromRGB(0, 200, 0)
			print("✅ Можна рухати човен")
		else
			-- Не можемо рухати човен - ЧЕРВОНИЙ
			highlightObj.FillColor = Color3.fromRGB(255, 50, 50)
			highlightObj.OutlineColor = Color3.fromRGB(200, 0, 0)
			print("❌ Не можна рухати човен")
		end
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

	-- Создаем разные цвета для разных стоимостей и типов
	local colorByCost = {
		[1] = Color3.fromRGB(0, 255, 0), -- Зеленый для 1 шага (суша)
		[2] = Color3.fromRGB(255, 255, 0), -- Желтый для 2 шагов
		[3] = Color3.fromRGB(255, 165, 0), -- Оранжевый для 3 шагов
	}

	-- Для воды специальные цвета
	local waterColor = Color3.fromRGB(0, 150, 255) -- Синий для воды
	local safeColor = Color3.fromRGB(255, 215, 0) -- Золотой для безопасных тайлов
	local creatureColor = Color3.fromRGB(255, 50, 50)

	for _, tileData in ipairs(data.availableTiles) do
		local tile = tileData.tile and tileData.tile.meshPart
		if tile then
			local highlight = Instance.new("Highlight")
			highlight.Name = "AvailableTileHighlight"
			local cost = tileData.cost or 1
			local isWater = tileData.isWater or false
			local isSafe = tileData.isSafe or false -- ДОБАВЛЕНО
			local hasCreature = tileData.hasCreature or false

			if hasCreature then
				highlight.FillColor = creatureColor
				highlight.OutlineColor = Color3.fromRGB(200, 0, 0)
				highlight.FillTransparency = 0.4
				highlight.OutlineTransparency = 0

				-- Добавляем специальный текст для тайлов с существами
				local billboard = Instance.new("BillboardGui")
				billboard.Name = "CreatureWarning"
				billboard.Size = UDim2.new(2, 0, 2, 0)
				billboard.StudsOffset = Vector3.new(0, 3, 0)
				billboard.AlwaysOnTop = true
				billboard.Adornee = tile
				billboard.Parent = tile

				local warningLabel = Instance.new("TextLabel")
				warningLabel.Name = "WarningLabel"
				warningLabel.Size = UDim2.new(1, 0, 1, 0)
				warningLabel.BackgroundTransparency = 1
				warningLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
				warningLabel.Text = "🦈" -- Иконка акулы
				warningLabel.Font = Enum.Font.GothamBlack
				warningLabel.TextScaled = true
				warningLabel.TextStrokeTransparency = 0
				warningLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
				warningLabel.Parent = billboard
			elseif isSafe then
				-- ДОБАВЛЕНО: Золотое свечение для безопасных тайлов
				highlight.FillColor = safeColor
				highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
				highlight.FillTransparency = 0.3
				highlight.OutlineTransparency = 0

				-- Эффект пульсации для безопасных тайлов
				coroutine.wrap(function()
					while highlight and highlight.Parent == tile do
						local tweenInfo1 = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
						local tween1 = TweenService:Create(highlight, tweenInfo1, { FillTransparency = 0.1 })
						tween1:Play()
						tween1.Completed:Wait()

						if not highlight or highlight.Parent ~= tile then
							break
						end

						local tweenInfo2 = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
						local tween2 = TweenService:Create(highlight, tweenInfo2, { FillTransparency = 0.5 })
						tween2:Play()
						tween2.Completed:Wait()
					end
				end)()

				-- Добавляем иконку сокровища
				local billboard = Instance.new("BillboardGui")
				billboard.Name = "SafeTileDisplay"
				billboard.Size = UDim2.new(2, 0, 2, 0)
				billboard.StudsOffset = Vector3.new(0, 3, 0)
				billboard.AlwaysOnTop = true
				billboard.Adornee = tile
				billboard.Parent = tile

				local safeLabel = Instance.new("TextLabel")
				safeLabel.Name = "SafeLabel"
				safeLabel.Size = UDim2.new(1, 0, 1, 0)
				safeLabel.BackgroundTransparency = 1
				safeLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
				safeLabel.Text = cost .. " 🛡️" -- Иконка щита
				safeLabel.Font = Enum.Font.GothamBlack
				safeLabel.TextScaled = true
				safeLabel.TextStrokeTransparency = 0
				safeLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
				safeLabel.Parent = billboard
			elseif isWater then
				-- Водные тайлы синие с специальным эффектом
				highlight.FillColor = waterColor
				highlight.OutlineColor = Color3.fromRGB(0, 100, 200)
				highlight.FillTransparency = 0.3 -- Меньшая прозрачность для воды
				highlight.OutlineTransparency = 0

				-- Добавляем эффект волн для воды
				coroutine.wrap(function()
					while highlight and highlight.Parent == tile do
						local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
						local tween = TweenService:Create(highlight, tweenInfo, { FillTransparency = 0.6 })
						tween:Play()
						task.wait(1)
					end
				end)()
			else
				-- Сухопутные тайлы по стоимости
				highlight.FillColor = colorByCost[cost] or Color3.fromRGB(0, 255, 0)
				highlight.OutlineColor = Color3.fromRGB(0, 200, 0)
				highlight.FillTransparency = 0.7
				highlight.OutlineTransparency = 0
			end

			if not hasCreature and not isSafe then
				-- Добавляем BillboardGui с информацией о стоимости
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
					costLabel.Text = cost .. " 💧" -- Иконка воды
					costLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
					costLabel.Font = Enum.Font.GothamBlack
				else
					costLabel.Font = Enum.Font.GothamBold
				end
				costLabel.TextScaled = true
				costLabel.TextStrokeTransparency = 0
				costLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
				costLabel.Parent = billboard
			end

			-- Сохраняем информацию о стоимости
			highlight:SetAttribute("Cost", cost)
			highlight:SetAttribute("Q", tileData.q)
			highlight:SetAttribute("R", tileData.r)
			highlight:SetAttribute("IsWater", isWater)
			highlight:SetAttribute("IsSafe", isSafe) -- ДОБАВЛЕНО
			highlight:SetAttribute("HasCreature", hasCreature)
			highlight.Parent = tile

			table.insert(tileHighlights, highlight)
		end
	end

	isMovementMode = true
	print("📍 Показано доступные тайлы для перемещения")

	-- Обновляем UI с информацией о правилах
	if data.remainingActions then
		closeButton.Visible = true

		-- Проверяем есть ли безопасные тайлы
		local hasSafeTiles = false
		for _, tileData in ipairs(data.availableTiles) do
			if tileData.isSafe then
				hasSafeTiles = true
				break
			end
		end

		local safeWarning = ""
		if hasSafeTiles then
			safeWarning =
				"\n\n🛡️ БЕЗОПАСНЫЕ ТАЙЛЫ: Достигнув их, исследователь будет спасен и выведен из игры!"
		end

		-- Проверяем есть ли водные тайлы
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
				"\n⚠️ ВНИМАНИЕ: Шаг в воду завершит ход этого исследователя!"
		end

		infoLabel.Position = UDim2.new(0, 10, 0, 15)
		infoLabel.Size = UDim2.new(0, 335, 0, 140)
		infoLabel.Text = string.format(
			"📍 Исследователь #%d\n"
				.. "💰 Осталось монет: %d/3\n"
				.. "📜 Правила движения:\n"
				.. " ⛰️ По суше: без ограничений\n"
				.. " 🌊 В воду: МАКСИМУМ 1 раз за ход\n"
				.. " ⛔ После воды: движение завершено"
				.. "%s%s",
			selectedExplorer:GetAttribute("ExplorerId"),
			data.remainingActions,
			waterWarning,
			safeWarning
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

	if tileData.hasCreature then
		print("❌ Не можна переміститися на тайл з істотою!")

		-- Показуємо повідомлення гравцеві
		if infoLabel then
			infoLabel.Text =
				"❌ НЕ МОЖНА: На цьому тайлі є істота!\nОберіть інший тайл."
			infoLabel.TextColor3 = Color3.fromRGB(255, 100, 100)

			task.delay(2, function()
				if infoLabel then
					infoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
					infoLabel.Text = "Оберіть доступний тайл для переміщення"
				end
			end)
		end

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

local function highlightFloodTiles(tiles, floodType)
	clearTileHighlights() -- Очищаємо попередні підсвічування

	for _, tileData in ipairs(tiles) do
		local tile = tileData.tileData and tileData.tileData.meshPart
		if tile then
			local highlight = Instance.new("Highlight")
			highlight.Name = "FloodTileHighlight"

			-- Різні кольори для різних типів тайлів
			local colors = {
				Beach = Color3.fromRGB(255, 200, 0), -- Жовтий для пляжів
				Forest = Color3.fromRGB(0, 200, 0), -- Зелений для лісів
				Mountain = Color3.fromRGB(150, 150, 150), -- Сірий для гір
			}

			highlight.FillColor = colors[floodType] or Color3.fromRGB(255, 100, 100)
			highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
			highlight.FillTransparency = 0.5
			highlight.OutlineTransparency = 0
			highlight.Parent = tile

			-- Додаємо BillboardGui з інформацією
			local billboard = Instance.new("BillboardGui")
			billboard.Name = "FloodInfo"
			billboard.Size = UDim2.new(2, 0, 2, 0)
			billboard.StudsOffset = Vector3.new(0, 3, 0)
			billboard.AlwaysOnTop = true
			billboard.Adornee = tile
			billboard.Parent = tile

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
			label.Text = "🌊 Затопити"
			label.Font = Enum.Font.GothamBold
			label.TextScaled = true
			label.Parent = billboard
		end
	end
end

local creatureGui = Instance.new("ScreenGui")
creatureGui.Name = "CreaturePhaseUI"
creatureGui.Parent = PlayerGui
creatureGui.Enabled = false

local creatureFrame = Instance.new("Frame")
creatureFrame.Size = UDim2.new(0, 200, 0, 200)
creatureFrame.Position = UDim2.new(0.5, -100, 0.5, -100) -- Центр екрану
creatureFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
creatureFrame.BorderSizePixel = 3
creatureFrame.BorderColor3 = Color3.fromRGB(255, 200, 0)
creatureFrame.Visible = true
creatureFrame.Parent = creatureGui

local creatureLabel = Instance.new("TextLabel")
creatureLabel.Size = UDim2.new(1, 0, 0.8, 0)
creatureLabel.Position = UDim2.new(0, 0, 0, 0)
creatureLabel.BackgroundTransparency = 1
creatureLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
creatureLabel.TextScaled = true
creatureLabel.Font = Enum.Font.FredokaOne
creatureLabel.Text = "SHARK"
creatureLabel.Parent = creatureFrame

local instructionLabel = Instance.new("TextLabel")
instructionLabel.Size = UDim2.new(1, 0, 0.2, 0)
instructionLabel.Position = UDim2.new(0, 0, 0.8, 0)
instructionLabel.BackgroundTransparency = 1
instructionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
instructionLabel.Text = "Випало на кубику!"
instructionLabel.Parent = creatureFrame

local floodScreenGui = Instance.new("ScreenGui")
floodScreenGui.Name = "FloodPhaseUI"
floodScreenGui.Parent = PlayerGui
floodScreenGui.Enabled = false

local floodFrame = Instance.new("Frame")
floodFrame.Size = UDim2.new(0, 400, 0, 200)
floodFrame.Position = UDim2.new(0.5, -200, 0.5, -100)
floodFrame.BackgroundColor3 = Color3.fromRGB(0, 50, 100)
floodFrame.BackgroundTransparency = 0.2
floodFrame.BorderSizePixel = 0
floodFrame.Visible = false
floodFrame.Parent = floodScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = floodFrame

local floodTitle = Instance.new("TextLabel")
floodTitle.Name = "FloodTitle"
floodTitle.Size = UDim2.new(1, 0, 0, 40)
floodTitle.Position = UDim2.new(0, 0, 0, 0)
floodTitle.BackgroundColor3 = Color3.fromRGB(0, 30, 60)
floodTitle.BackgroundTransparency = 0.3
floodTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
floodTitle.Text = "🌊 ФАЗА ЗАТОПЛЕННЯ"
floodTitle.TextSize = 20
floodTitle.Font = Enum.Font.GothamBold
floodTitle.Parent = floodFrame

local floodInfo = Instance.new("TextLabel")
floodInfo.Name = "FloodInfo"
floodInfo.Size = UDim2.new(1, -20, 0, 120)
floodInfo.Position = UDim2.new(0, 10, 0, 50)
floodInfo.BackgroundTransparency = 1
floodInfo.TextColor3 = Color3.fromRGB(220, 220, 220)
floodInfo.TextSize = 16
floodInfo.TextWrapped = true
floodInfo.Font = Enum.Font.Gotham
floodInfo.Text = "Оберіть тайл для затоплення"
floodInfo.Parent = floodFrame

local confirmButton = Instance.new("TextButton")
confirmButton.Name = "ConfirmButton"
confirmButton.Size = UDim2.new(0, 150, 0, 40)
confirmButton.Position = UDim2.new(0.5, -75, 1, -60)
confirmButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
confirmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
confirmButton.Text = "ПІДТВЕРДИТИ"
confirmButton.TextSize = 16
confirmButton.Font = Enum.Font.GothamBold
confirmButton.Visible = false
confirmButton.Parent = floodFrame

local UICorner2 = Instance.new("UICorner")
UICorner2.CornerRadius = UDim.new(0, 5)
UICorner2.Parent = confirmButton

local function showFloodPhaseUI(data)
	floodScreenGui.Enabled = true
	floodFrame.Visible = true

	-- Оновлюємо інформацію в UI
	-- ...
end

local function clearFloodHighlightsOnClient()
	local map = workspace:WaitForChild("Map")

	-- Очищаємо FloodTileHighlight
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			-- FloodTileHighlight
			local floodHighlight = obj:FindFirstChild("FloodTileHighlight")
			if floodHighlight then
				floodHighlight:Destroy()
			end

			-- FloodInfo Billboard
			local floodInfo = obj:FindFirstChild("FloodInfo")
			if floodInfo then
				floodInfo:Destroy()
			end

			-- CostDisplay (якщо залишився)
			local costDisplay = obj:FindFirstChild("CostDisplay")
			if costDisplay then
				costDisplay:Destroy()
			end

			-- BoatMovementHighlight (для безпеки)
			local boatHighlight = obj:FindFirstChild("BoatMovementHighlight")
			if boatHighlight then
				boatHighlight:Destroy()
			end

			-- BoatCostDisplay
			local boatCost = obj:FindFirstChild("BoatCostDisplay")
			if boatCost then
				boatCost:Destroy()
			end
		end
	end

	-- Також очищаємо AvailableTileHighlight
	for _, highlight in ipairs(tileHighlights) do
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end
	tileHighlights = {}

	-- Очищаємо boatTileHighlights
	for _, highlight in ipairs(boatTileHighlights) do
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end
	boatTileHighlights = {}

	-- Очищаємо floodHighlights
	for _, highlight in ipairs(floodHighlights) do
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end
	floodHighlights = {}

	print("✅ [КЛІЄНТ] Всі підсвічування затоплення очищені")
end

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
		clearBoatTileHighlights()
		isMovementMode = false
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
	elseif data.type == "flood_selection" then
		print("🌊 Доступні тайли для затоплення: " .. #data.availableTiles)

		-- ОЧИЩАЄМО всі попередні підсвічування
		clearTileHighlights()
		clearBoatTileHighlights()

		-- Вимикаємо режим руху
		isMovementMode = false

		-- Підсвічуємо доступні тайли для затоплення
		highlightFloodTiles(data.availableTiles, data.floodType)

		-- Оновлюємо UI
		if floodFrame.Visible then
			floodInfo.Text = "🌊 Оберіть тайл для затоплення\n\nТип: "
				.. data.floodTypeName
				.. "\nДоступно: "
				.. #data.availableTiles
				.. " тайлів"
			confirmButton.Visible = false
		end
	elseif data.type == "flood_tile_selected" then
		print("✅ Обрано тайл для затоплення: Q=" .. data.q .. " R=" .. data.r)

		-- Показуємо кнопку підтвердження
		if floodFrame.Visible then
			floodInfo.Text = "✅ Обрано тайл Q="
				.. data.q
				.. " R="
				.. data.r
				.. "\n\n📌 Натисніть ПІДТВЕРДИТИ"
			confirmButton.Visible = true
		end
	elseif data.type == "tile_flooded" then
		print("🌊 Тайл затоплено: Q=" .. data.q .. " R=" .. data.r .. " (" .. data.originalType .. ")")

		-- ОЧИЩАЄМО всі підсвічування
		clearTileHighlights()
		clearBoatTileHighlights()

		-- Вимикаємо режим руху
		isMovementMode = false

		-- Оновлюємо UI
		if floodFrame.Visible then
			floodInfo.Text =
				"✅ Тайл затоплено!\n\n🔄 Повернення до основної гри..."
		end

		-- Ховаємо UI затоплення через 2 секунди
		task.delay(2, function()
			if floodFrame then
				floodScreenGui.Enabled = false
				floodFrame.Visible = false
				confirmButton.Visible = false
			end
		end)
	elseif data.type == "clear_flood_highlights" then
		print("🧹 [КЛІЄНТ] Очищення підсвічувань затоплення")
		clearFloodHighlightsOnClient()
	elseif data.type == "tile_flooded" then
		-- Після затоплення також очищаємо
		task.delay(0.5, function() -- Трохи затримки для анімації
			clearFloodHighlightsOnClient()
		end)
	end
end)

local function clearAllHighlights()
	print("🧹 Очищення всіх підсвічувань...")

	-- 1. Очищаем подсветку тайлов для движения
	for _, highlight in ipairs(tileHighlights) do
		if highlight and highlight.Parent then
			-- Удаляем Billboard с информацией о стоимости
			local tile = highlight.Parent
			local sharkCostDisplay = tile:FindFirstChild("SharkMoveCost")
			if sharkCostDisplay then
				sharkCostDisplay:Destroy()
			end

			highlight:Destroy()
		end
	end
	tileHighlights = {}

	-- 2. Очищаем подсветку тайлов для човнов
	for _, highlight in ipairs(boatTileHighlights) do
		if highlight and highlight.Parent then
			local tile = highlight.Parent
			local boatCostDisplay = tile:FindFirstChild("BoatCostDisplay")
			if boatCostDisplay then
				boatCostDisplay:Destroy()
			end

			highlight:Destroy()
		end
	end
	boatTileHighlights = {}

	-- 3. Очищаем подсветку тайлов для затопления
	for _, highlight in ipairs(floodHighlights) do
		if highlight and highlight.Parent then
			local tile = highlight.Parent
			local floodInfo = tile:FindFirstChild("FloodInfo")
			if floodInfo then
				floodInfo:Destroy()
			end

			highlight:Destroy()
		end
	end
	floodHighlights = {}

	-- 4. Очищаем подсветку существ для движения
	local map = workspace:WaitForChild("Map")
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			-- Удаляем CreatureMoveHighlight
			local creatureHighlight = obj:FindFirstChild("CreatureMoveHighlight")
			if creatureHighlight then
				creatureHighlight:Destroy()
			end

			-- Удаляем SharkMoveCost
			local sharkCost = obj:FindFirstChild("SharkMoveCost")
			if sharkCost then
				sharkCost:Destroy()
			end

			-- Удаляем другие возможные BillboardGui
			local otherBillboards = {
				"CostDisplay",
				"BoatCostDisplay",
				"FloodInfo",
				"SharkMoveCost",
				"CreatureCostDisplay",
				"KaijuMoveCost",
			}

			for _, billboardName in ipairs(otherBillboards) do
				local billboard = obj:FindFirstChild(billboardName)
				if billboard then
					billboard:Destroy()
				end
			end
		end
	end

	isMovementMode = false
end
local function highlightFloodTiles(tiles, floodType)
	-- Очищаємо попередні підсвічування
	for _, highlight in ipairs(floodHighlights) do
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end
	floodHighlights = {}

	-- Кольори для різних типів тайлів
	local colors = {
		Beach = Color3.fromRGB(255, 200, 0), -- Жовтий
		Forest = Color3.fromRGB(0, 200, 100), -- Зелений
		Mountain = Color3.fromRGB(150, 150, 150), -- Сірий
	}

	for _, tileData in ipairs(tiles) do
		local tile = tileData.tileData and tileData.tileData.meshPart
		if tile then
			local highlight = Instance.new("Highlight")
			highlight.Name = "FloodTileHighlight"

			highlight.FillColor = colors[floodType] or Color3.fromRGB(255, 100, 100)
			highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
			highlight.FillTransparency = 0.5
			highlight.OutlineTransparency = 0
			highlight.Parent = tile

			-- Ефект пульсації
			coroutine.wrap(function()
				while highlight and highlight.Parent == tile do
					local tweenInfo1 = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					local tween1 = TweenService:Create(highlight, tweenInfo1, { FillTransparency = 0.3 })
					tween1:Play()
					tween1.Completed:Wait()

					if not highlight or highlight.Parent ~= tile then
						break
					end

					local tweenInfo2 = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					local tween2 = TweenService:Create(highlight, tweenInfo2, { FillTransparency = 0.7 })
					tween2:Play()
					tween2.Completed:Wait()
				end
			end)()

			table.insert(floodHighlights, highlight)
		end
	end
end

-- Обробник кліку на кнопку підтвердження
confirmButton.MouseButton1Click:Connect(function()
	local SelectFloodTileEvent = GameEvents:WaitForChild("SelectFloodTileEvent")
	local ConfirmFloodEvent = GameEvents:WaitForChild("ConfirmFloodEvent")

	-- Відправляємо підтвердження на сервер
	ConfirmFloodEvent:FireServer()

	-- Ховаємо кнопку
	confirmButton.Visible = false
	floodInfo.Text = "⏳ Затоплення виконується..."
end)

-- Обробник кліків по тайлах у фазі затоплення
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local target = mouse.Target
		if target then
			-- Перевіряємо, чи це підсвічений тайл для затоплення
			local highlight = target:FindFirstChild("FloodTileHighlight")
			if highlight then
				-- Отримуємо координати тайлу
				local q = target:GetAttribute("Q") or target:GetAttribute("q")
				local r = target:GetAttribute("R") or target:GetAttribute("r")

				if q and r then
					print("🌊 Клік по тайлу для затоплення: Q=" .. q .. " R=" .. r)

					-- Відправляємо вибір на сервер
					local SelectFloodTileEvent = GameEvents:WaitForChild("SelectFloodTileEvent")
					SelectFloodTileEvent:FireServer(q, r)
				end
			end
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
		infoLabel.Text = boatInfo .. "\n\n🖱️ Натисніть, ��об обрати"

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
			-- Якщо є обраний дослідник, показуємо інформацію про нь��го
			updateSelectionUI(selectedExplorer)
		elseif selectedBoat then
			-- Якщ�� є обраний човен, показуємо інформацію про нього
			titleLabel.Text = "🚤 ОБРАНО ЧОВЕН"
			infoLabel.Text = "Оберіть водний тайл для переміщення човна"
		else
			titleLabel.Text = "🕵️ ОБРАНО ДОСЛІДНИКА"
			infoLabel.Text = "Оберіть дослідника для переміщення"
		end
	end
end)

local function getTileType(tile)
	local map = workspace:WaitForChild("Map")
	local isWater = tile:GetAttribute("IsWater") or tile:GetAttribute("Placeboat")
	local isLand = tile:GetAttribute("IsLand")

	-- Якщо це вода, перевіряємо чи немає острова зверху
	if isWater and not isLand then
		local q = tile:GetAttribute("Q")
		local r = tile:GetAttribute("R")

		-- Шукаємо landTile з такими ж координатами
		for _, checkTile in ipairs(map:GetDescendants()) do
			if checkTile:IsA("MeshPart") and checkTile:GetAttribute("IsLand") then
				local checkQ = checkTile:GetAttribute("Q")
				local checkR = checkTile:GetAttribute("R")
				if checkQ == q and checkR == r then
					-- Знайшли острів на цих координатах!
					return "land" -- Це земля, не вода
				end
			end
		end

		return "water" -- Дійсно вода
	elseif isLand then
		return "land" -- Земля
	else
		return "unknown"
	end
end

-- Функція для отримання типу тайла за координатами
local function getTileTypeAt(q, r)
	local map = workspace:WaitForChild("Map")
	for _, tile in ipairs(map:GetDescendants()) do
		if tile:IsA("MeshPart") and tile:GetAttribute("Q") then
			local tileQ = tile:GetAttribute("Q")
			local tileR = tile:GetAttribute("R")
			if tileQ == q and tileR == r then
				return getTileType(tile)
			end
		end
	end
	return "unknown"
end
local function hasLandOnPath(startQ, startR, targetQ, targetR)
	local dq = targetQ - startQ
	local dr = targetR - startR
	local distance = (math.abs(dq) + math.abs(dr) + math.abs(dq + dr)) / 2

	if distance ~= 2 then
		return false -- Тільки для дистанції 2
	end

	-- Знаходимо проміжні координати
	local midQ = math.floor((startQ + targetQ) / 2 + 0.5)
	local midR = math.floor((startR + targetR) / 2 + 0.5)

	-- Перевіряємо тип проміжної ділянки
	local midTileType = getTileTypeAt(midQ, midR)
	if midTileType == "land" then
		return true -- На шляху острів!
	end

	return false
end
local function highlightKaijuMoves(kaijuModel)
	local cQ = kaijuModel:GetAttribute("Q")
	local cR = kaijuModel:GetAttribute("R")

	-- Функция для вычисления гекс-дистанции
	local function getHexDistance(q1, r1, q2, r2)
		local dx = q2 - q1
		local dy = r2 - r1
		return (math.abs(dx) + math.abs(dy) + math.abs(dx + dy)) / 2
	end

	-- Функция для нахождения промежуточного гекса
	local function getIntermediateHex(startQ, startR, endQ, endR)
		local distance = getHexDistance(startQ, startR, endQ, endR)

		if distance == 2 then
			local directions = {
				{ 1, 0 },
				{ 1, -1 },
				{ 0, -1 },
				{ -1, 0 },
				{ -1, 1 },
				{ 0, 1 },
			}

			-- Проверяем все возможные промежуточные точки
			for _, dir1 in ipairs(directions) do
				local midQ = startQ + dir1[1]
				local midR = startR + dir1[2]

				-- Проверяем, что это соседняя клетка от старта
				if getHexDistance(startQ, startR, midQ, midR) == 1 then
					-- Проверяем, что это также соседняя клетка от цели
					if getHexDistance(midQ, midR, endQ, endR) == 1 then
						return { q = midQ, r = midR }
					end
				end
			end
		end

		return nil
	end

	-- Функция для проверки доступности промежуточных клеток
	local function checkIntermediatePaths(startQ, startR, endQ, endR)
		local distance = getHexDistance(startQ, startR, endQ, endR)

		if distance == 1 then
			return true
		elseif distance == 2 then
			-- Для дистанции 2 ищем все возможные промежуточные пути
			local directions = {
				{ 1, 0 },
				{ 1, -1 },
				{ 0, -1 },
				{ -1, 0 },
				{ -1, 1 },
				{ 0, 1 },
			}

			-- Проверяем все возможные промежуточные точки
			for _, dir1 in ipairs(directions) do
				local midQ = startQ + dir1[1]
				local midR = startR + dir1[2]

				-- Проверяем, что это соседняя клетка от старта
				if getHexDistance(startQ, startR, midQ, midR) == 1 then
					-- Проверяем, что это также соседняя клетка от цели
					if getHexDistance(midQ, midR, endQ, endR) == 1 then
						-- Проверяем, что промежуточная клетка не активный вулкан
						local tileType = getTileTypeAt(midQ, midR)
						local isActiveVolcano = false

						-- Проверяем, является ли тайл активным вулканом
						local map = workspace:WaitForChild("Map")
						for _, obj in ipairs(map:GetDescendants()) do
							if obj:IsA("MeshPart") then
								local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
								local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
								if tileQ == midQ and tileR == midR then
									if obj:GetAttribute("VolcanoActive") and obj:GetAttribute("IsBlocked") then
										isActiveVolcano = true
									end
									break
								end
							end
						end

						if not isActiveVolcano then
							-- Нашли доступный путь!
							print(
								"✅ Найден доступный путь для кайдзю через Q="
									.. midQ
									.. " R="
									.. midR
							)
							return true
						end
					end
				end
			end

			return false
		end

		return false
	end

	-- Собираем все тайлы на карте
	local map = workspace:WaitForChild("Map")
	local allTiles = {}
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") and (obj:GetAttribute("Q") or obj:GetAttribute("q")) then
			local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")

			if tileQ == nil or tileR == nil then
				continue
			end

			table.insert(allTiles, {
				obj = obj,
				q = tileQ,
				r = tileR,
				type = getTileType(obj),
			})
		end
	end

	print("🔍 Поиск доступных ходов для кайдзю из Q=" .. cQ .. " R=" .. cR)

	-- Проверяем каждый тайл
	for _, tile in ipairs(allTiles) do
		-- Пропускаем текущую позицию
		if tile.q == cQ and tile.r == cR then
			continue
		end

		local distance = getHexDistance(cQ, cR, tile.q, tile.r)

		-- Проверяем дистанцию (1-2 клетки)
		if distance >= 1 and distance <= 2 then
			-- Проверяем, не активный ли это вулкан
			local isActiveVolcano = false
			if tile.obj:GetAttribute("VolcanoActive") and tile.obj:GetAttribute("IsBlocked") then
				isActiveVolcano = true
			end

			if not isActiveVolcano then
				-- Проверяем, нет ли другого кайдзю на этом тайле
				local hasOtherKaiju = false
				for _, obj in ipairs(workspace:GetChildren()) do
					if obj:GetAttribute("IsKaiju") or obj:GetAttribute("CreatureType") == "Kaiju" then
						local objQ = obj:GetAttribute("Q")
						local objR = obj:GetAttribute("R")
						if objQ == tile.q and objR == tile.r and obj ~= kaijuModel then
							hasOtherKaiju = true
							break
						end
					end
				end

				if not hasOtherKaiju then
					-- Проверяем доступность пути
					local isValid = checkIntermediatePaths(cQ, cR, tile.q, tile.r)

					if isValid then
						-- Подсвечиваем тайл
						local hl = Instance.new("Highlight")
						hl.Name = "CreatureMoveHighlight"

						-- Разный цвет для разной дистанции и типа местности
						local isWater = (tile.type == "water")

						if distance == 1 then
							if isWater then
								hl.FillColor = Color3.fromRGB(0, 150, 255) -- Синий для воды
							else
								hl.FillColor = Color3.fromRGB(0, 200, 0) -- Зеленый для суши
							end
						else
							if isWater then
								hl.FillColor = Color3.fromRGB(100, 100, 255) -- Голубой для воды (дальний)
							else
								hl.FillColor = Color3.fromRGB(255, 150, 0) -- Оранжевый для суши (дальний)
							end
						end

						hl.OutlineColor = Color3.fromRGB(255, 255, 0)
						hl.FillTransparency = 0.5
						hl.OutlineTransparency = 0
						hl.Parent = tile.obj

						-- Добавляем Billboard с информацией
						local billboard = Instance.new("BillboardGui")
						billboard.Name = "KaijuMoveCost"
						billboard.Size = UDim2.new(2, 0, 2, 0)
						billboard.StudsOffset = Vector3.new(0, 3, 0)
						billboard.AlwaysOnTop = true
						billboard.Adornee = tile.obj
						billboard.Parent = tile.obj

						local costLabel = Instance.new("TextLabel")
						costLabel.Name = "CostLabel"
						costLabel.Size = UDim2.new(1, 0, 1, 0)
						costLabel.BackgroundTransparency = 1
						costLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
						costLabel.Text = tostring(distance) .. " 🦖"
						costLabel.Font = Enum.Font.GothamBlack
						costLabel.TextScaled = true
						costLabel.TextStrokeTransparency = 0
						costLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
						costLabel.Parent = billboard

						table.insert(tileHighlights, hl)

						print(
							"✅ Подсвечено для кайдзю: Q="
								.. tile.q
								.. " R="
								.. tile.r
								.. " (дистанция: "
								.. distance
								.. ", тип: "
								.. tile.type
								.. ")"
						)
					end
				end
			end
		end
	end
end

local function highlightCreatureMoves(creatureModel)
	clearAllHighlights()

	local cQ = creatureModel:GetAttribute("Q")
	local cR = creatureModel:GetAttribute("R")
	local cType = creatureModel:GetAttribute("CreatureType")

	if cType == "Shark" then
		-- Для акулы ищем все водные тайлы на расстоянии 1-2 без островов сверху
		local map = workspace:WaitForChild("Map")
		local highlightedCount = 0

		-- Функция для вычисления гекс-дистанции
		local function getHexDistance(q1, r1, q2, r2)
			local dx = q2 - q1
			local dy = r2 - r1
			return (math.abs(dx) + math.abs(dy) + math.abs(dx + dy)) / 2
		end

		-- Функция для проверки, есть ли остров сверху
		local function hasLandAboveWater(tileQ, tileR)
			-- Ищем landTile с такими же координатами
			for _, checkTile in ipairs(map:GetDescendants()) do
				if checkTile:IsA("MeshPart") and checkTile:GetAttribute("IsLand") then
					local checkQ = checkTile:GetAttribute("Q") or checkTile:GetAttribute("q")
					local checkR = checkTile:GetAttribute("R") or checkTile:GetAttribute("r")
					if checkQ == tileQ and checkR == tileR then
						return true
					end
				end
			end
			return false
		end

		-- Функция для проверки доступности промежуточных клеток
		local function checkIntermediatePaths(startQ, startR, endQ, endR)
			local distance = getHexDistance(startQ, startR, endQ, endR)

			if distance == 1 then
				-- Для дистанции 1 не нужны промежуточные клетки
				return true
			elseif distance == 2 then
				-- Для дистанции 2 ищем все возможные промежуточные пути
				local directions = {
					{ 1, 0 },
					{ 1, -1 },
					{ 0, -1 },
					{ -1, 0 },
					{ -1, 1 },
					{ 0, 1 },
				}

				-- Проверяем все возможные промежуточные точки
				for _, dir1 in ipairs(directions) do
					local midQ = startQ + dir1[1]
					local midR = startR + dir1[2]

					-- Проверяем, что это соседняя клетка от старта
					if getHexDistance(startQ, startR, midQ, midR) == 1 then
						-- Проверяем, что это также соседняя клетка от цели
						if getHexDistance(midQ, midR, endQ, endR) == 1 then
							-- Проверяем, что промежуточная клетка - вода без острова
							local interTileType = getTileTypeAt(midQ, midR)

							if interTileType == "water" and not hasLandAboveWater(midQ, midR) then
								-- Нашли доступный путь!
								print(
									"✅ Найден доступный путь через Q="
										.. midQ
										.. " R="
										.. midR
								)
								return true
							end
						end
					end
				end

				-- Не нашли ни одного доступного пути
				return false
			end

			return false
		end

		-- Сначала собираем все тайлы на карте
		local allTiles = {}
		for _, obj in ipairs(map:GetDescendants()) do
			if obj:IsA("MeshPart") and (obj:GetAttribute("Q") or obj:GetAttribute("q")) then
				local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
				local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")

				-- Пропускаем тайлы без координат
				if tileQ == nil or tileR == nil then
					continue
				end

				table.insert(allTiles, {
					obj = obj,
					q = tileQ,
					r = tileR,
					type = getTileType(obj),
				})
			end
		end

		print("🔍 Поиск доступных ходов для акулы из Q=" .. cQ .. " R=" .. cR)
		print("📊 Всего тайлов на карте: " .. #allTiles)

		-- Проверяем каждый тайл
		for _, tile in ipairs(allTiles) do
			-- Пропускаем текущую позицию
			if tile.q == cQ and tile.r == cR then
				continue
			end

			local distance = getHexDistance(cQ, cR, tile.q, tile.r)

			-- Проверяем дистанцию (1-2 клетки)
			if distance >= 1 and distance <= 2 then
				-- Должен быть водным тайлом
				if tile.type == "water" then
					-- Проверяем, нет ли острова сверху
					if not hasLandAboveWater(tile.q, tile.r) then
						-- Проверяем, нет ли другой акулы на этом тайле
						local hasOtherShark = false
						for _, obj in ipairs(workspace:GetChildren()) do
							if obj:GetAttribute("IsShark") or obj:GetAttribute("CreatureType") == "Shark" then
								local objQ = obj:GetAttribute("Q")
								local objR = obj:GetAttribute("R")
								if objQ == tile.q and objR == tile.r and obj ~= creatureModel then
									hasOtherShark = true
									break
								end
							end
						end

						if not hasOtherShark then
							-- Проверяем доступность пути
							local isValid = checkIntermediatePaths(cQ, cR, tile.q, tile.r)

							if isValid then
								-- Подсвечиваем тайл
								local hl = Instance.new("Highlight")
								hl.Name = "CreatureMoveHighlight"

								-- Разный цвет для разной дистанции
								if distance == 1 then
									hl.FillColor = Color3.fromRGB(0, 200, 0) -- Зеленый для 1 шага
									hl.OutlineColor = Color3.fromRGB(0, 255, 0)
								else
									hl.FillColor = Color3.fromRGB(255, 150, 0) -- Оранжевый для 2 шагов
									hl.OutlineColor = Color3.fromRGB(255, 200, 0)
								end

								hl.FillTransparency = 0.5
								hl.OutlineTransparency = 0
								hl.Parent = tile.obj

								-- Добавляем Billboard с информацией
								local billboard = Instance.new("BillboardGui")
								billboard.Name = "SharkMoveCost"
								billboard.Size = UDim2.new(2, 0, 2, 0)
								billboard.StudsOffset = Vector3.new(0, 3, 0)
								billboard.AlwaysOnTop = true
								billboard.Adornee = tile.obj
								billboard.Parent = tile.obj

								local costLabel = Instance.new("TextLabel")
								costLabel.Name = "CostLabel"
								costLabel.Size = UDim2.new(1, 0, 1, 0)
								costLabel.BackgroundTransparency = 1
								costLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
								costLabel.Text = tostring(distance) .. " 🦈"
								costLabel.Font = Enum.Font.GothamBlack
								costLabel.TextScaled = true
								costLabel.TextStrokeTransparency = 0
								costLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
								costLabel.Parent = billboard

								table.insert(tileHighlights, hl)
								highlightedCount = highlightedCount + 1

								print(
									"✅ Подсвечено для акулы: Q="
										.. tile.q
										.. " R="
										.. tile.r
										.. " (дистанция: "
										.. distance
										.. ")"
								)
							else
								print(
									"❌ Тайл Q="
										.. tile.q
										.. " R="
										.. tile.r
										.. " недоступен (нет доступного пути)"
								)
							end
						else
							print(
								"❌ Тайл Q="
									.. tile.q
									.. " R="
									.. tile.r
									.. " занят другой акулой"
							)
						end
					else
						print("❌ Тайл Q=" .. tile.q .. " R=" .. tile.r .. " имеет остров сверху")
					end
				else
					print("❌ Тайл Q=" .. tile.q .. " R=" .. tile.r .. " не вода, тип: " .. tile.type)
				end
			end
		end

		print("📍 Подсвечено " .. highlightedCount .. " тайлов для акулы")
	elseif cType == "Kaiju" then
		highlightKaijuMoves(creatureModel)
	elseif cType == "Octopus" then
		-- Для восьминогой показываем только соседние водные клетки
		local directions = {
			{ 1, 0 },
			{ 1, -1 },
			{ 0, -1 },
			{ -1, 0 },
			{ -1, 1 },
			{ 0, 1 },
		}

		for _, dir in ipairs(directions) do
			local nq = cQ + dir[1]
			local nr = cR + dir[2]

			-- Проверяем тип тайла
			local tileType = getTileTypeAt(nq, nr)

			-- Восьминогой может ходить только на воду
			if tileType == "water" then
				-- Находим тайл для подсветки
				local tile = nil
				local map = workspace:WaitForChild("Map")
				for _, obj in ipairs(map:GetDescendants()) do
					if obj:IsA("MeshPart") then
						local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
						local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
						if tileQ == nq and tileR == nr then
							tile = obj
							break
						end
					end
				end

				if tile then
					local hl = Instance.new("Highlight")
					hl.Name = "CreatureMoveHighlight"
					hl.FillColor = Color3.fromRGB(255, 50, 50) -- Красный для восьминогой
					hl.OutlineColor = Color3.fromRGB(255, 100, 100)
					hl.FillTransparency = 0.5
					hl.OutlineTransparency = 0
					hl.Parent = tile

					table.insert(tileHighlights, hl)
				end
			end
		end
	end
end

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
			if isCreaturePhase and isMyTurn then
				-- 1. Клік по істоті
				local model = target:FindFirstAncestorOfClass("Model")
				if model and model:GetAttribute("CreatureType") == currentCreatureTurn then
					print("🦖 Вибрано істоту: " .. currentCreatureTurn)
					selectedCreatureObj = model

					-- Підсвітити доступні тайли
					highlightCreatureMoves(model)
					return
				end

				-- 2. Клік по тайлу для переміщення істоти
				if selectedCreatureObj then
					local moveHighlight = target:FindFirstChild("CreatureMoveHighlight")
					if moveHighlight then
						local q = target:GetAttribute("Q")
						local r = target:GetAttribute("R")

						print("📤 [КЛІЄНТ] Відправка ходу істотою: Q=" .. q .. " R=" .. r)

						-- Відправляємо хід на сервер
						local MoveCreatureEvent = GameEvents:WaitForChild("MoveCreatureEvent")
						MoveCreatureEvent:FireServer(selectedCreatureObj, q, r)

						-- Очищення
						clearAllHighlights()
						selectedCreatureObj = nil
						creatureGui.Enabled = false
						return
					else
						-- Клік по недоступному тайлу
						print("❌ Цей тайл недоступний для руху")
					end
				end
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
	elseif data.type == "ExplorerSaved" then
		print(
			"🛡️ Исследователь #"
				.. data.explorerId
				.. " сохранен на безопасном тайле!"
		)
		print("💰 Потрачено действий:", data.moveCost or 1)
		print("🎯 Осталось действий:", data.remainingActions or 0)

		-- Находим исследователя в workspace
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:GetAttribute("IsExplorer") and obj:GetAttribute("ExplorerId") == data.explorerId then
				-- Визуальный эффект сохранения
				local saveEffect = Instance.new("ParticleEmitter")
				saveEffect.Name = "SaveEffect"
				saveEffect.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0)) -- Золотой
				saveEffect.Size = NumberSequence.new(1)
				saveEffect.Transparency = NumberSequence.new(0.7)
				saveEffect.Lifetime = NumberRange.new(2, 3)
				saveEffect.Rate = 50
				saveEffect.Speed = NumberRange.new(3, 5)
				saveEffect.Parent = obj.PrimaryPart

				-- Плавно поднимаем исследователя
				local tweenService = game:GetService("TweenService")
				local targetPosition = obj.PrimaryPart.Position + Vector3.new(0, 10, 0)
				local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				local tween = tweenService:Create(obj.PrimaryPart, tweenInfo, { Position = targetPosition })
				tween:Play()

				-- Удаляем после анимации
				game:GetService("Debris"):AddItem(obj, 3)

				-- Очищаем выбор если это был выбранный исследователь
				if selectedExplorer and selectedExplorer:GetAttribute("ExplorerId") == data.explorerId then
					clearSelectionState()
				end

				break
			end
		end

		-- Обновляем UI с информацией об оставшихся действиях
		if isMyTurn and selectionFrame.Visible then
			if data.remainingActions <= 0 then
				infoLabel.Text = "🎯 Все действия использованы! Ход завершен."
				infoLabel.TextColor3 = Color3.fromRGB(255, 100, 100)

				-- Автоматически закрываем через 2 секунды
				task.delay(2, function()
					if selectionFrame.Visible then
						clearSelectionState()
					end
				end)
			else
				infoLabel.Text = string.format(
					"🛡️ Исследователь сохранен!\n"
						.. "💰 Потрачено действий: %d\n"
						.. "🎯 Осталось действий: %d/3\n\n"
						.. "Оберіть другого дослідника для переміщення",
					data.moveCost or 1,
					data.remainingActions or 0
				)
				infoLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- Золотой
			end
		end
		print(
			"🛡️ Исследователь #"
				.. data.explorerId
				.. " сохранен на безопасном тайле!"
		)

		-- Находим исследователя в workspace
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:GetAttribute("IsExplorer") and obj:GetAttribute("ExplorerId") == data.explorerId then
				-- Визуальный эффект сохранения
				local saveEffect = Instance.new("ParticleEmitter")
				saveEffect.Name = "SaveEffect"
				saveEffect.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0)) -- Золотой
				saveEffect.Size = NumberSequence.new(1)
				saveEffect.Transparency = NumberSequence.new(0.7)
				saveEffect.Lifetime = NumberRange.new(2, 3)
				saveEffect.Rate = 50
				saveEffect.Speed = NumberRange.new(3, 5)
				saveEffect.Parent = obj.PrimaryPart

				-- Плавно поднимаем исследователя
				local tweenService = game:GetService("TweenService")
				local targetPosition = obj.PrimaryPart.Position + Vector3.new(0, 10, 0)
				local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				local tween = tweenService:Create(obj.PrimaryPart, tweenInfo, { Position = targetPosition })
				tween:Play()

				-- Удаляем после анимации
				game:GetService("Debris"):AddItem(obj, 3)

				-- Очищаем выбор если это был выбранный исследователь
				if selectedExplorer and selectedExplorer:GetAttribute("ExplorerId") == data.explorerId then
					clearSelectionState()
				end

				break
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
	elseif data.type == "explorer_moved_by_flood" then
		print("👤 Дослідник переміщений через затоплення: ID=" .. data.explorerId)

		-- Знаходимо дослідника в workspace
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:GetAttribute("IsExplorer") and obj:GetAttribute("ExplorerId") == data.explorerId then
				-- Оновлюємо позицію
				updateExplorerPosition(obj, data.toQ, data.toR)
				break
			end
		end
	elseif data.type == "boat_removed_by_effect" then
		print(
			"🚤 [КЛІЄНТ] Отримано команду на видалення човна #",
			data.boatId,
			"причина:",
			data.reason
		)

		-- Шукаємо човен за ID
		local boatToRemove = nil
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:GetAttribute("IsBoat") then
				local boatId = obj:GetAttribute("BoatId")
				if boatId and tostring(boatId) == tostring(data.boatId) then
					boatToRemove = obj
					break
				end
			end
		end

		-- Або шукаємо за координатами
		if not boatToRemove then
			for _, obj in ipairs(workspace:GetChildren()) do
				if obj:GetAttribute("IsBoat") then
					local objQ = obj:GetAttribute("Q")
					local objR = obj:GetAttribute("R")
					if objQ == data.q and objR == data.r then
						boatToRemove = obj
						break
					end
				end
			end
		end

		-- Видаляємо човен
		if boatToRemove then
			print("🗑️ [КЛІЄНТ] Видаляємо човен:", boatToRemove.Name)
			boatToRemove:Destroy()

			-- Також очищаємо підсвічування тайлів для цього човна
			clearBoatTileHighlights()

			-- Якщо цей човен був обраний, скидаємо вибір
			if selectedBoat and selectedBoat == boatToRemove then
				clearBoatSelection()
			end
		else
			print("⚠️ [КЛІЄНТ] Човен для видалення не знайдений")
		end
	elseif data.type == "explorer_pushed_by_kaiju" then
		print(
			"👤 Дослідник відштовхнутий кайдзю: ID="
				.. data.explorerId
				.. " з Q="
				.. data.fromQ
				.. " R="
				.. data.fromR
				.. " на Q="
				.. data.toQ
				.. " R="
				.. data.toR
		)

		-- Находим исследователя в workspace
		local explorerModel = nil
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:GetAttribute("IsExplorer") and obj:GetAttribute("ExplorerId") == data.explorerId then
				explorerModel = obj
				break
			end
		end

		if explorerModel then
			-- Очищаем эффекты човна если есть
			clearBoatAttributes(explorerModel)

			-- Обновляем атрибуты
			explorerModel:SetAttribute("Q", data.toQ)
			explorerModel:SetAttribute("R", data.toR)

			-- Проверяем, вода ли это
			local tileType = getTileTypeAt(data.toQ, data.toR)
			local isWater = (tileType == "water")
			explorerModel:SetAttribute("IsOnWater", isWater)

			-- Если это вода, проверяем есть ли човен
			local boat = getBoatOnTile(data.toQ, data.toR)
			if boat and isWater then
				-- Дослідник може опинитись на човні
				local boatId = boat:GetAttribute("BoatId")
				if boatId then
					-- Перевіряємо, чи є місце на човні
					if hasSpaceOnBoat(boatId) then
						updateExplorerPositionOnBoat(explorerModel, data.toQ, data.toR, boatId)
						print(
							"🚤 Дослідник опинився на човні після відштовхування"
						)
					else
						-- Човен заповнений - дослідник у воді
						updateExplorerPosition(explorerModel, data.toQ, data.toR)
						print("💧 Дослідник у воді (човен заповнений)")
					end
				else
					updateExplorerPosition(explorerModel, data.toQ, data.toR)
					print("💧 Дослідник у воді")
				end
			else
				-- Звичайне переміщення на сушу
				updateExplorerPosition(explorerModel, data.toQ, data.toR)
				print("📍 Дослідник на суші")
			end

			-- Додаємо візуальний ефект для відштовхування
			local pushEffect = explorerModel:FindFirstChild("PushEffect")
			if not pushEffect then
				pushEffect = Instance.new("ParticleEmitter")
				pushEffect.Name = "PushEffect"
				pushEffect.Color = ColorSequence.new(Color3.fromRGB(255, 100, 100))
				pushEffect.Size = NumberSequence.new(0.5)
				pushEffect.Transparency = NumberSequence.new(0.7)
				pushEffect.Lifetime = NumberRange.new(1, 2)
				pushEffect.Rate = 30
				pushEffect.Speed = NumberRange.new(3, 5)
				pushEffect.VelocitySpread = 180
				pushEffect.Parent = explorerModel.PrimaryPart

				-- Видаляємо через 2 секунди
				game:GetService("Debris"):AddItem(pushEffect, 2)
			end

			print(
				"✅ Візуально оновлено позицію дослідника після відштовхування"
			)

			-- Якщо цей дослідник був обраний, оновлюємо UI
			if selectedExplorer and selectedExplorer:GetAttribute("ExplorerId") == data.explorerId then
				updateSelectionUI(explorerModel)
			end
		end
	elseif data.type == "explorer_removed_by_effect" then
		print(
			"👤 [КЛІЄНТ] Отримано команду на видалення дослідника #",
			data.explorerId
		)

		-- Шукаємо дослідника за ID
		local explorerToRemove = nil
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:GetAttribute("IsExplorer") then
				local explorerId = obj:GetAttribute("ExplorerId")
				if explorerId and tostring(explorerId) == tostring(data.explorerId) then
					explorerToRemove = obj
					break
				end
			end
		end

		-- Або шукаємо за координатами та гравцем
		if not explorerToRemove then
			for _, obj in ipairs(workspace:GetChildren()) do
				if obj:GetAttribute("IsExplorer") then
					local objQ = obj:GetAttribute("Q")
					local objR = obj:GetAttribute("R")
					local playerName = obj:GetAttribute("Player")

					if objQ == data.q and objR == data.r and playerName == data.playerName then
						explorerToRemove = obj
						break
					end
				end
			end
		end

		-- Видаляємо дослідника
		if explorerToRemove then
			print("🗑️ [КЛІЄНТ] Видаляємо дослідника:", explorerToRemove.Name)
			explorerToRemove:Destroy()

			-- Якщо цей дослідник був обраний, скидаємо вибір
			if selectedExplorer and selectedExplorer == explorerToRemove then
				clearSelectionState()
			end
		else
			print("⚠️ [КЛІЄНТ] Дослідник для видалення не знайдений")
		end
	end

	if data.type == "boat_removed_by_effect" then
		print("🚤 [КЛІЄНТ] Отримано команду на видалення човна #", data.boatId)

		-- Шукаємо човен за ID
		local boatToRemove = nil
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:GetAttribute("IsBoat") then
				local boatId = obj:GetAttribute("BoatId")
				if boatId and tostring(boatId) == tostring(data.boatId) then
					boatToRemove = obj
					break
				end
			end
		end

		-- Або шукаємо за координатами
		if not boatToRemove then
			for _, obj in ipairs(workspace:GetChildren()) do
				if obj:GetAttribute("IsBoat") then
					local objQ = obj:GetAttribute("Q")
					local objR = obj:GetAttribute("R")
					if objQ == data.q and objR == data.r then
						boatToRemove = obj
						break
					end
				end
			end
		end

		-- Видаляємо човен
		if boatToRemove then
			print("🗑️ [КЛІЄНТ] Видаляємо човен:", boatToRemove.Name)
			boatToRemove:Destroy()

			-- Очищаємо підсвічування
			clearBoatTileHighlights()

			-- Якщо цей човен був обраний, скидаємо вибір
			if selectedBoat and selectedBoat == boatToRemove then
				clearBoatSelection()
			end
		else
			print("⚠️ [КЛІЄНТ] Човен для видалення не знайдений")
		end
	elseif data.type == "tile_flooded" then
		print("🌊 [КЛІЄНТ] Тайл затоплено: Q=" .. data.q .. " R=" .. data.r)

		-- Видаляємо візуал острова
		local map = workspace:WaitForChild("Map")
		for _, obj in ipairs(map:GetDescendants()) do
			if obj:IsA("MeshPart") then
				local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
				local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
				local isLand = obj:GetAttribute("IsLand")

				if tileQ == data.q and tileR == data.r and isLand == true then
					print("🗑️ [КЛІЄНТ] Видаляємо острівний тайл:", obj.Name)
					obj:Destroy()
				end
			end
		end

		-- АКТИВУЄМО водний тайл
		for _, obj in ipairs(map:GetDescendants()) do
			if obj:IsA("MeshPart") then
				local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
				local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
				local isWater = obj:GetAttribute("IsWater") or obj:GetAttribute("Placeboat")

				if tileQ == data.q and tileR == data.r and isWater then
					print("💧 [КЛІЄНТ] Активуємо водний тайл:", obj.Name)

					-- Відтворюємо анімацію появи води
					obj.Transparency = 1 -- Спочатку невидимий

					local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					local tween = TweenService:Create(obj, tweenInfo, {
						Transparency = 0,
						Color = Color3.fromRGB(0, 100, 200),
					})
					tween:Play()

					obj.Material = Enum.Material.Water
					break
				end
			end
		end
	end
end)

GameStartEvent.OnClientEvent:Connect(function(data)
	print("📡 Отримано подію гри:", data.phase)

	if data.phase == "main_game_active" then
		-- Основная игра началась
		isGamePhaseActive = true
		isMyTurn = false -- Пока не наш хід
		print("🎮 Основна гра активна. Чекаємо на хід...")
	elseif data.phase == "main_game_turn" and data.isYourTurn then
		clearAllHighlights()
		-- Наш хід в основной игре
		floodScreenGui.Enabled = false
		floodFrame.Visible = false
		confirmButton.Visible = false

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
		floodScreenGui.Enabled = false
		floodFrame.Visible = false
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
	elseif data.phase == "flood_phase_started" then
		-- ОЧИЩАЄМО всі підсвічування
		clearAllHighlights()

		-- Приховуємо основне UI
		selectionFrame.Visible = false

		-- Показуємо UI затоплення
		floodScreenGui.Enabled = true
		floodFrame.Visible = true

		if data.currentPlayer == player.Name then
			floodTitle.Text = "🌊 ВАША ЧЕРГА ЗАТОПЛЮВАТИ"
			floodInfo.Text = "Оберіть тайл для затоплення\n\nТип: "
				.. (data.floodTypeName or "Пляжі")
			isMyTurn = true
		else
			floodTitle.Text = "🌊 ФАЗА ЗАТОПЛЕННЯ"
			floodInfo.Text = data.message
				or "⏳ Чекайте поки " .. data.currentPlayer .. " обере тайл"
			isMyTurn = false
		end

		confirmButton.Visible = false
		isGamePhaseActive = false
	elseif data.phase == "creature_phase_start" then
		print("🎲 ФАЗА ІСТОТ: " .. data.rolledCreature)

		-- Очищаємо все старе
		clearAllHighlights()
		floodScreenGui.Enabled = false
		selectionFrame.Visible = false

		-- Показуємо Кубик UI
		creatureGui.Enabled = true
		creatureLabel.Text = data.rolledCreature:upper()

		-- Анімація/Колір залежно від типу
		if data.rolledCreature == "Shark" then
			creatureLabel.TextColor3 = Color3.fromRGB(0, 150, 255) -- Синій
		elseif data.rolledCreature == "Kaiju" then
			creatureLabel.TextColor3 = Color3.fromRGB(50, 255, 50) -- Зелений
		elseif data.rolledCreature == "Octopus" then
			creatureLabel.TextColor3 = Color3.fromRGB(255, 50, 50) -- Червоний
		end

		isCreaturePhase = true
		currentCreatureTurn = data.rolledCreature

		-- Якщо це наш хід і є іс��оти
		if data.currentPlayer == player.Name and data.creaturesCount > 0 then
			instructionLabel.Text = "ВАШ ХІД! Оберіть істоту."
			isMyTurn = true
		else
			instructionLabel.Text = "Хід гравця " .. data.currentPlayer
			isMyTurn = false
		end

		-- Ховаємо UI через 3 секунди, якщо це не наш хід або істот немає
		if data.creaturesCount == 0 then
			task.delay(3, function()
				creatureGui.Enabled = false
			end)
		else
			-- Залишаємо UI маленьким збоку, щоб нагадувати кого рухати
			task.delay(2, function()
				creatureFrame:TweenSizeAndPosition(
					UDim2.new(0, 100, 0, 60),
					UDim2.new(1, -120, 0, 20), -- Пр��вий верхній кут
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.5
				)
				creatureLabel.TextSize = 14
			end)
		end
	elseif data.phase == "creature_phase_no_creatures" then
		print("😴 Немає істот типу " .. data.rolledCreature)
		creatureGui.Enabled = true
		creatureLabel.Text = data.rolledCreature:upper()
		instructionLabel.Text = "Немає на полі!"

		-- Ховаємо через 3 секунди
		task.delay(3, function()
			creatureGui.Enabled = false
		end)
	elseif data.phase == "creature_phase_no_moves" then
		print("🚫 Істоти типу " .. data.rolledCreature .. " не мають ходів")
		creatureGui.Enabled = true
		creatureLabel.Text = data.rolledCreature:upper()
		instructionLabel.Text = "Немає куди ходити!"

		-- Ховаємо через 3 секунди
		task.delay(3, function()
			creatureGui.Enabled = false
		end)
	elseif data.phase == "flood_start" then
		-- Показуємо загальну інформацію
		floodScreenGui.Enabled = true
		floodFrame.Visible = true
		floodTitle.Text = "🌊 ФАЗА ЗАТОПЛЕННЯ"
		floodInfo.Text = data.message .. "\n\nЗатоплюємо: " .. data.floodTypeName
		confirmButton.Visible = false
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
