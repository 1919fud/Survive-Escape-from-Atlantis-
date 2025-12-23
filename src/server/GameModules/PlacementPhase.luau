-- PlacementPhase.lua (ModuleScript)
local PlacementPhase = {}
PlacementPhase.__index = PlacementPhase

function PlacementPhase.new()
	local self = setmetatable({}, PlacementPhase)
	--treasureLimits
	self.isActive = false
	self.turnManager = nil
	self.playersData = {}
	self.playerTreasureLimits = {
		[1] = 2,
		[2] = 2,
		[3] = 2,
		[4] = 2,
		[5] = 2,
	}
	self.phase = "explorers"
	self.boatTemplate = nil
	self.boatsPlaced = {}
	self.boatsPerPlayer = 2
	return self
end

local function canPlayerPlaceTreasureValue(playerData, treasureValue, playerLimits)
	if not playerData then
		warn("❌ playerData is nil in canPlayerPlaceTreasureValue")
		return false
	end

	local currentCount = 0

	-- Рахуємо скільки цей гравець вже поставив з цим значенням скарбів
	if playerData.explorers then
		for _, explorer in ipairs(playerData.explorers) do
			if explorer.treasureValue == treasureValue then
				currentCount += 1
			end
		end
	end

	local limit = playerLimits[treasureValue] or 0
	return currentCount < limit
end

-- Начать фазу размещения
function PlacementPhase:start(players, networkManager)
	self.isActive = true
	self.networkManager = networkManager

	-- Инициализируем данные игроков
	self.playersData = {}
	for player, _ in pairs(players) do
		self.playersData[player] = {
			explorersPlaced = 0,
			maxExplorers = 10,
			explorers = {},
		}
	end

	-- Инициализируем менеджер очереди
	self.turnManager = require(script.Parent.TurnManager).new()
	self.turnManager:initialize(players)

	print("🎯 Фаза размещения исследователей начата!")

	-- Уведомляем всех клиентов
	self.networkManager:getGameStartEvent():FireAllClients({
		phase = "placement",
		message = "Фаза розміщення дослідників!",
	})

	-- Начинаем ход первого игрока
	self:startPlayerTurn()
end

-- Начать ход игрока
function PlacementPhase:startPlayerTurn()
	local currentPlayer = self.turnManager:getCurrentPlayer()
	local turnInfo = self.turnManager:getTurnInfo()

	print("🎮 Ход игрока:", currentPlayer.Name)

	-- Уведомляем всех о текущем игроке
	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "PlayerTurn",
		currentPlayer = currentPlayer.Name,
		turnInfo = turnInfo,
		playersData = self:getPlayersDataForClients(),
		playerTreasureLimits = self:getTreasureLimitsStatus(currentPlayer), -- Ліміти поточного гравця
	})

	-- Активируем UI для текущего игрока
	self.networkManager:getGameStartEvent():FireClient(currentPlayer, {
		phase = "player_turn",
		message = "Ваш хід! Розмістіть всіх дослідників",
		isYourTurn = true,
	})

	-- Відправляємо іншим гравцям очікування
	for _, player in ipairs(turnInfo.playersOrder) do
		if player ~= currentPlayer then
			self.networkManager:getGameStartEvent():FireClient(player, {
				phase = "waiting_turn",
				message = "Чекайте поки "
					.. currentPlayer.Name
					.. " завершить розміщення",
			})
		end
	end
end

function PlacementPhase:countExplorersOnTile(q, r)
	local count = 0

	for _, playerData in pairs(self.playersData) do
		if playerData.explorers then
			for _, explorer in ipairs(playerData.explorers) do
				if explorer.q == q and explorer.r == r then
					count = count + 1
				end
			end
		end
	end

	return count
end

-- Обработка размещения исследователя
function PlacementPhase:handlePlaceExplorer(player, treasureValue, q, r)
	if not self.isActive then
		warn("❌ Фаза размещения не активна")
		return false
	end

	-- Проверяем, что ход правильного игрока
	local currentPlayer = self.turnManager:getCurrentPlayer()
	if player ~= currentPlayer then
		warn("❌ Не ваш ход! Сейчас ходит:", currentPlayer.Name)
		return false
	end

	local playerData = self.playersData[player]
	if not playerData then
		warn("❌ Данные игрока не найдены")
		return false
	end

	-- НОВОЕ: Проверяем лимит размещения - МАКСИМУМ 1 исследователь на тайле во время фазы размещения
	local explorersOnTile = self:countExplorersOnTile(q, r)
	if explorersOnTile >= 1 then
		warn(
			"❌ На этом тайле уже есть исследователь! Фаза размещения - лиміт 1 на тайле"
		)

		-- Отправляем ошибку клиенту
		if self.networkManager then
			self.networkManager:getGameStartEvent():FireClient(player, {
				type = "error",
				message = "❌ На цьому тайлі вже є дослідник! Фаза розміщення - лиміт 1 дослідник на тайлі",
			})
		end

		return false
	end

	-- Проверяем лимит сокровищ
	if not canPlayerPlaceTreasureValue(playerData, treasureValue, self.playerTreasureLimits) then
		warn("❌ Гравець", player.Name, "досяг ліміту для скарбів:", treasureValue)
		return false
	end

	-- Проверяем лимит исследователей для игрока
	if playerData.explorersPlaced >= playerData.maxExplorers then
		warn("❌ Игрок уже разместил всех исследователей")
		return false
	end

	-- Проверяем валидность сокровищ
	if treasureValue < 1 or treasureValue > 5 then
		warn("❌ Неверное значение сокровищ:", treasureValue)
		return false
	end

	print(
		"🎯 Игрок",
		player.Name,
		"размещает исследователя с сокровищами",
		treasureValue,
		"на Q=",
		q,
		"R=",
		r
	)

	-- Создаем исследователя
	local globalExplorerId = #self:getAllExplorers() + 1
	local explorer = {
		id = globalExplorerId,
		player = player,
		treasureValue = treasureValue,
		q = q,
		r = r,
		hasEnteredWaterThisTurn = false,
	}
	table.insert(playerData.explorers, explorer)
	playerData.explorersPlaced += 1

	-- Уведомляем всех игроков
	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "ExplorerPlaced",
		playerName = player.Name,
		explorerId = globalExplorerId,
		explorerCount = playerData.explorersPlaced,
		maxExplorers = playerData.maxExplorers,
		q = q,
		r = r,
		treasureValue = treasureValue,
		playersData = self:getPlayersDataForClients(),
		playerTreasureLimits = self:getTreasureLimitsStatus(currentPlayer),
	})

	print(
		"✅ Игрок",
		player.Name,
		"разместил исследователя",
		playerData.explorersPlaced,
		"/",
		playerData.maxExplorers
	)

	self:moveToNextPlayer()
	return true
end

function PlacementPhase:getAllExplorers()
	local allExplorers = {}
	for _, playerData in pairs(self.playersData) do
		if playerData.explorers then
			for _, explorer in ipairs(playerData.explorers) do
				table.insert(allExplorers, explorer)
			end
		end
	end
	return allExplorers
end

function PlacementPhase:createExplorerVisual(player, treasureValue, q, r, explorerId)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
		warn("❌ Не найден тайл для размещения исследователя: Q=", q, "R=", r)
		return
	end

	-- Создаем исследователя
	local explorer = explorerTemplate:Clone()
	explorer.Name = "Explorer_" .. player.Name .. "_" .. treasureValue

	-- Позиционируем над тайлом
	--local yOffset = explorer.Size.Y / 2 + targetTile.Size.Y / 2 + 0.5
	local yOffset = 1
	explorer.CFrame = targetTile.CFrame + Vector3.new(0, yOffset, 0)

	-- Устанавливаем цвет в зависимости от игрока
	local playerColor = self:getPlayerColor(player)
	explorer.BrickColor = playerColor

	-- Добавляем атрибуты
	explorer:SetAttribute("Player", player.Name)
	explorer:SetAttribute("TreasureValue", treasureValue)
	explorer:SetAttribute("ExplorerId", explorerId)
	explorer:SetAttribute("Q", q)
	explorer:SetAttribute("R", r)
	explorer:SetAttribute("IsExplorer", true)

	-- Помещаем в workspace
	explorer.Parent = workspace

	print(
		"👤 Создан визуал исследователя для игрока",
		player.Name,
		"на Q=",
		q,
		"R=",
		r
	)
	return explorer
end

-- Продолжить ход того же игрока
function PlacementPhase:continuePlayerTurn(player)
	-- Просто обновляем UI для текущего игрока
	self.networkManager:getGameStartEvent():FireClient(player, {
		phase = "player_turn",
		message = "Ваш хід! Оберіть дослідника",
		isYourTurn = true,
		explorersLeft = self.playersData[player].maxExplorers - self.playersData[player].explorersPlaced,
	})
end

function PlacementPhase:getTreasureLimitsStatus(targetPlayer)
	local status = {}
	local playerData = self.playersData[targetPlayer]

	if not playerData then
		for treasureValue = 1, 5 do
			status[treasureValue] = {
				current = 0,
				max = self.playerTreasureLimits[treasureValue],
				available = true,
			}
		end
		return status
	end

	for treasureValue = 1, 5 do
		local currentCount = 0

		-- Рахуємо скільки цей гравець вже поставив
		if playerData.explorers then
			for _, explorer in ipairs(playerData.explorers) do
				if explorer.treasureValue == treasureValue then
					currentCount += 1
				end
			end
		end

		local maxCount = self.playerTreasureLimits[treasureValue]
		status[treasureValue] = {
			current = currentCount,
			max = maxCount,
			available = currentCount < maxCount,
		}
	end

	return status
end

-- Переход к следующему игроку
function PlacementPhase:moveToNextPlayer()
	-- Проверяем, все ли игроки завершили размещение
	if self.turnManager:allPlayersFinished(self.playersData) then
		self:endPhase()
		return
	end

	-- Переходим к следующему игроку
	local nextPlayer = self.turnManager:nextPlayer()

	-- Уведомляем предыдущего игрока о завершении хода
	local previousPlayer = self.turnManager:getCurrentPlayer()

	-- Начинаем ход следующего игрока
	self:startPlayerTurn()

	print("🔄 Переход к игроку:", nextPlayer.Name)
end

-- Завершить фазу размещения
function PlacementPhase:endPhase()
	self.isActive = false
	print("🎯 Фаза размещения исследователей завершена!")

	-- Уведомляем всех клиентов
	self.networkManager:getGameStartEvent():FireAllClients({
		phase = "placement_complete",
		message = "Усі дослідники розміщені! Гра починається...",
	})
	self:startBoatsPhase()
end

function PlacementPhase:startBoatsPhase()
	self.phase = "boats"
	self.isActive = true

	-- Знаходимо шаблон човна
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	self.boatTemplate = ReplicatedStorage:FindFirstChild("Boat")

	if not self.boatTemplate then
		warn("❌ Не найден шаблон Boat в ReplicatedStorage")
		return
	end

	self.boatsPlaced = {}
	for player, _ in pairs(self.playersData) do
		self.boatsPlaced[player] = 0
	end

	print(
		"🚤 Фаза размещения лодок начата! У каждого игрока по 2 човна"
	)

	-- Уведомляем всех клиентов
	self.networkManager:getGameStartEvent():FireAllClients({
		phase = "boats_placement",
		message = "Фаза розміщення човнів!",
		boatsPerPlayer = self.boatsPerPlayer,
	})

	-- Включаем подсветку тайлов с човнами
	self:highlightBoatTiles(true)

	self:startBoatTurn()
end

function PlacementPhase:startBoatTurn()
	local currentPlayer = self.turnManager:getCurrentPlayer()

	print("🚤 Ход игрока для размещения човна:", currentPlayer.Name)

	-- Уведомляем всех о текущем игроке
	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "BoatTurn",
		currentPlayer = currentPlayer.Name,
		boatsPlaced = self.boatsPlaced[currentPlayer] or 0,
		maxBoats = self.boatsPerPlayer,
		playersData = self:getPlayersBoatsData(),
	})

	-- Активируем UI для текущего игрока
	self.networkManager:getGameStartEvent():FireClient(currentPlayer, {
		phase = "boat_turn",
		message = "Ваш хід! Розмістіть човен",
		isYourTurn = true,
		boatsLeft = self.boatsPerPlayer - (self.boatsPlaced[currentPlayer] or 0),
	})

	-- Відправляємо іншим гравцям очікування
	for _, player in ipairs(self.turnManager.playersOrder) do
		if player ~= currentPlayer then
			self.networkManager:getGameStartEvent():FireClient(player, {
				phase = "boat_waiting",
				message = "Чекайте поки " .. currentPlayer.Name .. " розмістить човен",
			})
		end
	end
end

function PlacementPhase:countAvailableBoats()
	local count = 0
	local map = workspace:WaitForChild("Map")

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") and obj:GetAttribute("Placeboat") == true then
			count += 1
		end
	end

	return count
end

function PlacementPhase:highlightBoatTiles(highlight)
	local map = workspace:WaitForChild("Map")

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") and obj:GetAttribute("Placeboat") == true then
			if highlight then
				-- Включаем подсветку
				local highlight = Instance.new("Highlight")
				highlight.Name = "BoatHighlight"
				highlight.FillColor = Color3.fromRGB(255, 136, 0)
				highlight.OutlineColor = Color3.fromRGB(255, 136, 0)
				highlight.FillTransparency = 0.8
				highlight.OutlineTransparency = 0
				highlight.Parent = obj
			else
				-- Выключаем подсветку
				local existingHighlight = obj:FindFirstChild("BoatHighlight")
				if existingHighlight then
					existingHighlight:Destroy()
				end
			end
		end
	end
end

function PlacementPhase:handlePlaceBoat(player, q, r)
	if not self.isActive or self.phase ~= "boats" then
		warn("❌ Фаза размещения лодок не активна")
		return false
	end

	-- Проверяем, что ход правильного игрока
	local currentPlayer = self.turnManager:getCurrentPlayer()
	if player ~= currentPlayer then
		warn("❌ Не ваш ход! Сейчас ходит:", currentPlayer.Name)
		return false
	end

	-- Проверяем лимит човнів гравця
	local playerBoats = self.boatsPlaced[player] or 0
	if playerBoats >= self.boatsPerPlayer then
		warn("❌ Игрок", player.Name, "уже разместил всех човнов")
		return false
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
		warn("❌ Тайл не найден: Q=", q, "R=", r)
		return false
	end

	-- Проверяем не стоит ли уже човен
	if self:hasBoatOnTile(q, r) then
		warn("❌ На этом тайле уже есть човен")
		return false
	end

	print("🚤 Игрок", player.Name, "размещает човен на Q=", q, "R=", r)

	local boat = self:createBoatVisual(player, q, r)
	local boatId = boat and boat:GetAttribute("BoatId") -- ПОЛУЧАЕМ ID ИЗ ЛОДКИ

	-- Если не удалось получить, используем счетчик
	if not boatId then
		boatId = self.boatsPlaced[player] or 1
	end

	self.boatsPlaced[player] = (self.boatsPlaced[player] or 0) + 1

	-- Создаем човен
	--self:createBoatVisual(player, q, r)

	-- Убираем подсветку с этого тайла
	local highlight = targetTile:FindFirstChild("BoatHighlight")
	if highlight then
		highlight:Destroy()
	end

	-- Уведомляем всех игроков
	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "BoatPlaced",
		playerName = player.Name,
		boatsPlaced = self.boatsPlaced[player] or 0,
		maxBoats = self.boatsPerPlayer,
		q = q,
		r = r,
		boatId = boatId,
		playersData = self:getPlayersBoatsData(),
	})

	print(
		"✅ Игрок",
		player.Name,
		"разместил човен",
		self.boatsPlaced[player],
		"/",
		self.boatsPerPlayer
	)

	-- Переходимо до наступного гравця
	self:moveToNextBoatPlayer()

	return true
end

function PlacementPhase:moveToNextBoatPlayer()
	-- Переходим к следующему игроку
	local nextPlayer = self.turnManager:nextPlayer()

	-- Проверяем завершение фазы човнів (всі поставили по 2 човни)
	if self:allPlayersPlacedBoats() then
		self:endBoatsPhase()
		return
	end

	-- Шукаємо наступного гравця який ще не поставив всі човни
	local currentPlayer = self.turnManager:getCurrentPlayer()
	local attempts = 0

	while (self.boatsPlaced[currentPlayer] or 0) >= self.boatsPerPlayer do
		self.turnManager:nextPlayer()
		currentPlayer = self.turnManager:getCurrentPlayer()
		attempts += 1

		if attempts >= #self.turnManager.playersOrder then
			-- Всі поставили човни
			self:endBoatsPhase()
			return
		end
	end

	-- Начинаем ход следующего игрока
	self:startBoatTurn()

	print("🔄 Переход к игроку для размещения човна:", currentPlayer.Name)
end

function PlacementPhase:allPlayersPlacedBoats()
	for player, _ in pairs(self.playersData) do
		if (self.boatsPlaced[player] or 0) < self.boatsPerPlayer then
			return false
		end
	end
	return true
end

function PlacementPhase:getPlayersBoatsData()
	local data = {}
	for player, playerData in pairs(self.playersData) do
		data[player.Name] = {
			boatsPlaced = self.boatsPlaced[player] or 0,
			maxBoats = self.boatsPerPlayer,
			displayName = player.DisplayName,
		}
	end
	return data
end

function PlacementPhase:hasBoatOnTile(q, r)
	-- Ищем човен по координатам
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsBoat") then
			local boatQ = obj:GetAttribute("Q")
			local boatR = obj:GetAttribute("R")

			if boatQ == q and boatR == r then
				return true
			end
		end
	end
	return false
end

function PlacementPhase:hasExplorerOnTile(q, r)
	-- Ищем исследователя по координатам
	for player, playerData in pairs(self.playersData) do
		if playerData.explorers then
			for _, explorer in ipairs(playerData.explorers) do
				if explorer.q == q and explorer.r == r then
					return true
				end
			end
		end
	end
	return false
end

function PlacementPhase:createBoatVisual(player, q, r)
	if not self.boatTemplate then
		warn("❌ Шаблон човна не найден")
		return
	end

	-- ВАЖЛИВО: Генеруємо унікальний ID для човна
	local boatId = 1 -- Завжди починаємо з 1

	-- Рахуємо скільки човнів вже створено
	local boatCount = 0
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("IsBoat") then
			boatCount = boatCount + 1
		end
	end

	boatId = boatCount + 1 -- Унікальний ID

	print("🆔 Створюємо човен з ID:", boatId, "для гравця:", player.Name)

	-- Іщем тайл
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
		warn("❌ Тайл не найден: Q=", q, "R=", r)
		return
	end

	-- Создаем човен
	local boat = self.boatTemplate:Clone()

	-- ВАЖЛИВО: Правильне ім'я з ID
	boat.Name = "Boat_" .. boatId .. "_" .. player.Name .. "_" .. q .. "_" .. r

	local primaryPart = boat.PrimaryPart

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

	-- Додаємо обертання на 180 градусів
	local rotatedCFrame = (targetTile.CFrame + Vector3.new(0, yOffset, 0)) * CFrame.Angles(math.rad(180), 0, 0)
	boat:PivotTo(rotatedCFrame)

	-- ВАЖЛИВО: Встановлюємо всі атрибути
	boat:SetAttribute("BoatId", boatId)
	boat:SetAttribute("IsBoat", true)
	boat:SetAttribute("Player", player.Name)
	boat:SetAttribute("Q", q)
	boat:SetAttribute("R", r)

	-- Помещаем в workspace
	boat.Parent = workspace

	-- Эффект появления
	self:createBoatAppearanceEffect(boat)

	print(
		"🚤 Создан визуал човна #" .. tostring(boatId) .. " для",
		player.Name,
		"на Q=",
		q,
		"R=",
		r
	)

	-- Перевіряємо, чи правильно встановлені атрибути
	task.delay(0.2, function()
		if boat and boat.Parent then
			print("🔍 ПОВНА ПЕРЕВІРКА атрибутів човна після створення:")
			print("  Назва:", boat.Name)
			print("  BoatId:", boat:GetAttribute("BoatId"))
			print("  IsBoat:", boat:GetAttribute("IsBoat"))
			print("  Q:", boat:GetAttribute("Q"), "Тип:", typeof(boat:GetAttribute("Q")))
			print("  R:", boat:GetAttribute("R"), "Тип:", typeof(boat:GetAttribute("R")))
			print("  Player:", boat:GetAttribute("Player"))

			-- Перевірка координат на числа
			local qNum = tonumber(boat:GetAttribute("Q"))
			local rNum = tonumber(boat:GetAttribute("R"))
			if qNum == nil or rNum == nil then
				print("❌ КООРДИНАТИ НЕ ЧИСЛА!")
				boat:SetAttribute("Q", tonumber(q) or 0)
				boat:SetAttribute("R", tonumber(r) or 0)
			end
		end
	end)

	return boat
end

function PlacementPhase:createBoatAppearanceEffect(boat)
	if not boat:IsA("Model") then
		return
	end

	local primaryPart = boat.PrimaryPart
	if not primaryPart then
		return
	end

	-- Эффект подсветки
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(0, 100, 255)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0
	highlight.Parent = boat

	-- Убираем подсветку через 2 секунды
	game:GetService("Debris"):AddItem(highlight, 2)
end

function PlacementPhase:endBoatsPhase()
	self.isActive = false

	-- Убираем подсветку
	self:highlightBoatTiles(false)

	print("🚤 Фаза размещения лодок завершена!")

	-- Сохраняем данные игроков перед передачей
	print("💾 Сохраняем данные игроков для основной игры:")
	for player, playerData in pairs(self.playersData) do
		print("  Игрок", player.Name, "исследователей:", #playerData.explorers)
		for i, explorer in ipairs(playerData.explorers) do
			explorer.id = explorer.id or i
			--[[print(
				"    Исследователь",
				explorer.id,
				"Q=",
				explorer.q,
				"R=",
				explorer.r,
				"сокровища:",
				explorer.treasureValue
			)]]
			--
		end
	end

	-- Уведомляем всех клиентов о начале основной игры
	self.networkManager:getGameStartEvent():FireAllClients({
		phase = "main_game_active",
		message = "🎮 ОСНОВНА ГРА ПОЧИНАЄТЬСЯ!",
		countdown = 3,
	})

	-- Задержка перед началом основной фазы

	if self.mainGame and self.mainGame.startMainGamePhase then
		self.mainGame:startMainGamePhase()
	else
		warn("❌ mainGame не доступен для старта основной фазы")
	end
end

function PlacementPhase:initializeMainGameTurnManager()
	-- Отримуємо TurnManager з основної гри
	if not self.turnManager then
		warn("❌ TurnManager не знайдено")
		return
	end

	-- Переключаємо на основну фазу
	self.turnManager:startMainGamePhase()

	-- Уведомляем всех клиентов
	self.networkManager:getGameStartEvent():FireAllClients({
		phase = "main_game_active",
		message = "🎮 ОСНОВНА ГРА ПОЧИНАЄТЬСЯ!",
		currentPlayer = self.turnManager:getCurrentPlayer().Name,
		round = self.turnManager.currentRound,
	})

	-- Запускаємо перший хід
	self:startMainGamePlayerTurn()
end

function PlacementPhase:startMainGame()
	print("🎮 ПЕРЕХІД ДО ОСНОВНОЇ ГРИ!")

	-- Уведомляем всех клиентов о начале основной фазы
	self.networkManager:getGameStartEvent():FireAllClients({
		phase = "main_game",
		message = "ОСНОВНА ГРА ПОЧИНАЄТЬСЯ!",
		countdown = 3,
	})

	if self.mainGame and self.mainGame.startMainGamePhase then
		self.mainGame:startMainGamePhase()
	end
end

function PlacementPhase:startMainGamePlayerTurn()
	local currentPlayer = self.turnManager:getCurrentPlayer()
	local turnInfo = self.turnManager:getTurnInfo()

	print("🎮 Початок ходу в основній грі:", currentPlayer.Name)

	-- Уведомляем всіх про поточного гравця
	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "MainGameTurn",
		currentPlayer = currentPlayer.Name,
		turnInfo = turnInfo,
		remainingActions = turnInfo.remainingActions,
		maxActions = turnInfo.maxActions,
	})

	-- Активируємо UI для поточного гравця
	self.networkManager:getGameStartEvent():FireClient(currentPlayer, {
		phase = "main_game_turn",
		message = "Ваш хід! Використайте дії для переміщення дослідників",
		isYourTurn = true,
		remainingActions = turnInfo.remainingActions,
		maxActions = turnInfo.maxActions,
	})

	-- Інші гравці чекають
	for _, player in ipairs(turnInfo.playersOrder) do
		if player ~= currentPlayer then
			self.networkManager:getGameStartEvent():FireClient(player, {
				phase = "main_game_waiting",
				message = "Чекайте поки " .. currentPlayer.Name .. " завершить хід",
			})
		end
	end
end

-- Получить данные игроков для клиентов
function PlacementPhase:getPlayersDataForClients()
	local data = {}
	for player, playerData in pairs(self.playersData) do
		data[player.Name] = {
			explorersPlaced = playerData.explorersPlaced,
			maxExplorers = playerData.maxExplorers,
			displayName = player.DisplayName,
		}
	end
	return data
end

return PlacementPhase
