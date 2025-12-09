-- MainGame.lua (Server Script в Server/)
local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")
local GameModules = Server:WaitForChild("GameModules")
local MapManager = require(GameModules:WaitForChild("MapManager"))
local NetworkManager = require(GameModules:WaitForChild("NetworkManager"))
local TurnManager = require(GameModules:WaitForChild("TurnManager"))
local PlacementPhase = require(GameModules:WaitForChild("PlacementPhase"))

local AtlantisGame = {}
AtlantisGame.__index = AtlantisGame

function AtlantisGame.new()
	local self = setmetatable({}, AtlantisGame)

	self.mapManager = MapManager.new()
	self.networkManager = NetworkManager.new()
	self.isGameActive = false
	self.players = {}
	self.readyPlayers = {}
	self.waitingForReady = true

	-- ДОБАВЛЕНО: Система размещения
	self.placementPhase = PlacementPhase.new()
	self.gameState = "ready" -- ready, placement, main_game

	print("✅ AtlantisGame инициализирован")

	return self
end

function AtlantisGame:start()
	print("🎮 Запуск игры Atlantis...")

	self:initializeMap()
	self:setupReadySystem()
	self:setupPlayerHandlers()
	self:setupExplorerPlacement()
	self:setupMainGameHandlers()
end

function AtlantisGame:initializeMap()
	print("🗺️ Инициализация карты...")
	self.mapManager:discoverTiles()
	self.mapManager:generateLandTiles()
	print("✅ Карта успешно инициализирована!")
end

function AtlantisGame:setupReadySystem()
	print("🎮 Настройка системы готовности...")

	self.networkManager:getPlayerReadyEvent().OnServerEvent:Connect(function(player, isReady)
		self:onPlayerReadyChanged(player, isReady)
	end)

	print("✅ Система готовности настроена")
end

function AtlantisGame:setupPlayerHandlers()
	game.Players.PlayerAdded:Connect(function(player)
		self:onPlayerJoined(player)
	end)

	-- Обработка уже подключенных игроков
	for _, player in ipairs(game.Players:GetPlayers()) do
		self:onPlayerJoined(player)
	end

	print("✅ Обработчики игроков настроены")
end

-- ДОБАВЛЕНО: Система размещения исследователей
function AtlantisGame:setupExplorerPlacement()
	print("🎯 Настройка системы размещения исследователей...")

	local PlaceExplorerEvent = self.networkManager:getPlaceExplorerEvent()
	local PlaceBoatEvent = self.networkManager:getPlaceBoatEvent()

	PlaceExplorerEvent.OnServerEvent:Connect(function(player, treasureValue, q, r)
		local success = self.placementPhase:handlePlaceExplorer(player, treasureValue, q, r)
		return success
	end)

	PlaceBoatEvent.OnServerEvent:Connect(function(player, q, r)
		local success = self.placementPhase:handlePlaceBoat(player, q, r)
		return success
	end)

	print("✅ Система размещения исследователей настроена")
end

function AtlantisGame:setupMainGameHandlers()
	print("🎮 Настройка основных игровых обработчиков...")

	-- add

	print("✅ Основные игровые обработчики настроены")
end

function AtlantisGame:onPlayerJoined(player)
	print("👤 Игрок присоединился:", player.Name)

	self.players[player] = {
		name = player.Name,
		explorersPlaced = 0,
		maxExplorers = 10,
		explorers = {},
	}

	-- При подключении игрок не готов
	self.readyPlayers[player] = false

	-- Обновляем статус для всех игроков
	self:updateReadyStatusForAll()

	print("👥 Всего игроков:", self:getPlayerCount())
end

function AtlantisGame:onPlayerReadyChanged(player, isReady)
	if not self.waitingForReady then
		return
	end

	print("👤 Игрок", player.Name, isReady and "готов" or "не готов")

	self.readyPlayers[player] = isReady

	-- Обновляем статус у всех игроков
	self:updateReadyStatusForAll()

	-- Проверяем можно ли начинать игру
	self:checkGameStartCondition()
end

-- ДОБАВЛЕНО: Обработка размещения исследователя
function AtlantisGame:onPlayerPlaceExplorer(player, treasureValue, q, r)
	if not self.isGameActive then
		warn("❌ Игра еще не началась!")
		return false
	end

	local playerData = self.players[player]
	if not playerData then
		return false
	end

	-- Проверяем лимит исследователей
	if playerData.explorersPlaced >= playerData.maxExplorers then
		warn("❌ Игрок", player.Name, "уже разместил всех исследователей!")
		return false
	end

	-- Проверяем валидность сокровищ
	if treasureValue < 1 or treasureValue > 5 then
		warn("❌ Неверное значение сокровищ:", treasureValue)
		return false
	end

	-- Проверяем тайл через MapManager
	local tile = self.mapManager:getTileAtPosition(q, r)
	if not tile then
		warn("❌ Тайл не найден: Q=", q, "R=", r)
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
	local explorerId = #playerData.explorers + 1
	local explorer = {
		id = explorerId,
		player = player,
		treasureValue = treasureValue,
		q = q,
		r = r,
		position = tile.meshPart.Position,
	}

	table.insert(playerData.explorers, explorer)
	playerData.explorersPlaced += 1

	-- Уведомляем всех игроков
	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "ExplorerPlaced",
		playerName = player.Name,
		explorerCount = playerData.explorersPlaced,
		maxExplorers = playerData.maxExplorers,
		q = q,
		r = r,
		treasureValue = treasureValue,
	})

	print(
		"✅ Игрок",
		player.Name,
		"разместил исследователя",
		playerData.explorersPlaced,
		"/",
		playerData.maxExplorers
	)

	return true
end

function AtlantisGame:updateReadyStatusForAll()
	-- Собираем информацию о статусе всех игроков
	local statusData = {}

	for player, _ in pairs(self.players) do
		statusData[player.Name] = {
			isReady = self.readyPlayers[player] == true,
			displayName = player.DisplayName,
			explorersPlaced = self.players[player].explorersPlaced or 0,
			maxExplorers = self.players[player].maxExplorers or 10,
		}
	end

	-- Отправляем всем игрокам
	self.networkManager:getUpdateReadyStatusEvent():FireAllClients(statusData)
end

function AtlantisGame:checkGameStartCondition()
	local totalPlayers = self:getPlayerCount()
	local readyPlayers = self:getReadyPlayerCount()

	print(string.format("📊 Готовы: %d/%d игроков", readyPlayers, totalPlayers))

	-- Если все игроки готовы и их хотя бы 2
	if readyPlayers >= 1 and readyPlayers == totalPlayers then
		print("🚀 Все игроки готовы! Начинаем игру через 3 секунды...")

		-- Отправляем уведомление о скором начале
		self.networkManager:getGameStartEvent():FireAllClients({
			countdown = 3,
			message = "Гра починається!",
		})

		-- Запускаем таймер начала игры
		task.delay(3, function()
			if self.waitingForReady then
				self:startMainGame()
			end
		end)
	end
end

function AtlantisGame:getPlayerCount()
	local count = 0
	for _ in pairs(self.players) do
		count += 1
	end
	return count
end

function AtlantisGame:getReadyPlayerCount()
	local count = 0
	for player, isReady in pairs(self.readyPlayers) do
		if isReady then
			count += 1
		end
	end
	return count
end

function AtlantisGame:startMainGame()
	print("🎯 НАЧАЛО ОСНОВНОЙ ИГРЫ!")
	self.waitingForReady = false
	self.isGameActive = true
	self.gameState = "placement"
	self.placementPhase.mainGame = self
	self.placementPhase:start(self.players, self.networkManager)

	print("🎮 Основная игра начата! Фаза размещения исследователей.")
end

function AtlantisGame:startMainGamePhase()
	print("🎮 НАЧАЛО ОСНОВНОЙ ИГРОВОЙ ФАЗЫ!")

	self.gameState = "main_game"
	self.isGameActive = true

	-- ПЕРЕДАЕМ ЭКСПЛОРЕРОВ ИЗ PLACEMENTPHASE В ОСНОВНУЮ ИГРУ
	if self.placementPhase and self.placementPhase.playersData then
		for player, placementData in pairs(self.placementPhase.playersData) do
			if self.players[player] then
				self.players[player].explorers = {}
				print("🔄 Передаємо дослідників гравцю", player.Name)

				for i, exp in ipairs(placementData.explorers) do
					-- ВАЖНО: Сохраняем ссылку на объект игрока
					local explorer = {
						id = exp.id or i,
						player = player, -- Ссылка на объект игрока!
						treasureValue = exp.treasureValue,
						q = exp.q,
						r = exp.r,
					}
					table.insert(self.players[player].explorers, explorer)
					print(
						"  Дослідник",
						explorer.id,
						"Q=",
						explorer.q,
						"R=",
						explorer.r,
						"власник:",
						explorer.player.Name
					)
				end
				print("  Всього дослідників:", #self.players[player].explorers)
			end
		end
	end

	-- Инициализируем TurnManager с игроками
	self.turnManager = TurnManager.new()
	self.turnManager:initialize(self.players)
	self.turnManager:startMainGamePhase()

	-- Налаштовуємо систему руху
	self:setupMovementSystem()

	-- Уведомляем всіх гравців
	self.networkManager:getGameStartEvent():FireAllClients({
		phase = "main_game_active",
		message = "🎮 ОСНОВНА ГРА ПОЧИНАЄТЬСЯ!",
	})

	-- Запускаємо перший хід
	self:startPlayerTurn()
end

function AtlantisGame:startPlayerTurn()
	local currentPlayer = self.turnManager:getCurrentPlayer()
	local turnInfo = self.turnManager:getTurnInfo()

	print("🎮 [СЕРВЕР] Початок ходу гравця:", currentPlayer.Name)
	print("  Залишилось дій:", turnInfo.remainingActions, "/", turnInfo.maxActions)

	-- Отправляем информацию о ходе всем клиентам через GameStartEvent
	for _, player in ipairs(self.turnManager.playersOrder) do
		if player == currentPlayer then
			-- Текущему игроку - его ход
			self.networkManager:getGameStartEvent():FireClient(player, {
				phase = "main_game_turn",
				message = "Ваш хід! Використайте дії для переміщення дослідників",
				isYourTurn = true,
				remainingActions = turnInfo.remainingActions,
				maxActions = turnInfo.maxActions,
			})
		else
			-- Остальным игрокам - ожидание
			self.networkManager:getGameStartEvent():FireClient(player, {
				phase = "main_game_waiting",
				message = "Чекайте поки " .. currentPlayer.Name .. " завершить хід",
			})
		end
	end

	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "MainGameTurn",
		currentPlayer = currentPlayer.Name,
		turnInfo = turnInfo,
		remainingActions = turnInfo.remainingActions,
		maxActions = turnInfo.maxActions,
	})
end

function AtlantisGame:setupMovementSystem()
	print("🚶 [СЕРВЕР] Налаштування системи переміщення...")

	-- Отримуємо події для руху
	local moveExplorerEvent = self.networkManager:getMoveExplorerEvent()
	local selectExplorerEvent = self.networkManager:getSelectExplorerEvent()

	print("🔗 [СЕРВЕР] SelectExplorerEvent підключено:", selectExplorerEvent ~= nil)
	print("🔗 [СЕРВЕР] MoveExplorerEvent підключено:", moveExplorerEvent ~= nil)

	-- Обробка вибору дослідника
	if selectExplorerEvent then
		selectExplorerEvent.OnServerEvent:Connect(function(player, explorerId)
			print(
				"🎯 [СЕРВЕР] Отримано SelectExplorerEvent від",
				player.Name,
				"з explorerId:",
				explorerId
			)
			self:onPlayerSelectExplorer(player, explorerId)
		end)
	else
		warn("❌ [СЕРВЕР] selectExplorerEvent не знайдено!")
	end

	-- Обробка руху дослідника
	if moveExplorerEvent then
		moveExplorerEvent.OnServerEvent:Connect(function(player, explorerId, q, r)
			print(
				"🚶 [СЕРВЕР] Отримано MoveExplorerEvent від",
				player.Name,
				"з explorerId:",
				explorerId,
				"Q=",
				q,
				"R=",
				r
			)
			self:onPlayerMoveExplorer(player, explorerId, q, r)
		end)
	else
		warn("❌ [СЕРВЕР] moveExplorerEvent не знайдено!")
	end

	print("✅ [СЕРВЕР] Система переміщення налаштована")
end

function AtlantisGame:onPlayerSelectExplorer(player, explorerId)
	print("🎯 [СЕРВЕР] onPlayerSelectExplorer викликано")
	print("  Гравець:", player.Name)
	print("  Запитує explorerId:", explorerId, "тип:", type(explorerId))

	if not self.isGameActive then
		print("❌ [СЕРВЕР] Гра не активна!")
		return false
	end

	if self.gameState ~= "main_game" then
		print("❌ [СЕРВЕР] Не основна фаза гри!")
		return false
	end

	-- Перевіряємо чи хід гравця
	local currentPlayer = self.turnManager:getCurrentPlayer()
	if player ~= currentPlayer then
		print("❌ [СЕРВЕР] Не ваш хід! Зараз ходить:", currentPlayer.Name)
		return false
	end

	-- Знаходимо дослідника
	local playerData = self.players[player]
	if not playerData then
		print("❌ [СЕРВЕР] Дані гравця не знайдені!")
		return false
	end

	print("  Кількість дослідників у гравця:", #(playerData.explorers or {}))

	local explorer = nil
	if playerData.explorers then
		-- Преобразуем explorerId для сравнения
		explorerId = tonumber(explorerId)
		if not explorerId then
			print("❌ [СЕРВЕР] Неправильний формат explorerId")
			return false
		end

		for i, exp in ipairs(playerData.explorers) do
			print(
				"  Перевіряємо дослідника:",
				i,
				"ID:",
				exp.id,
				"тип:",
				type(exp.id),
				"власник:",
				exp.player and exp.player.Name
			)

			if exp.id == explorerId then
				-- ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА: принадлежит ли исследователь этому игроку
				if exp.player == player then
					explorer = exp
					print("  ✅ Знайдено дослідника гравця:", player.Name)
				else
					print("❌ [СЕРВЕР] Дослідник належить іншому гравцю!")
					print("    Очікуваний гравець:", player.Name)
					print("    Фактичний гравець:", exp.player and exp.player.Name)
					return false
				end
				break
			end
		end
	end

	if not explorer then
		print(
			"❌ [СЕРВЕР] Дослідник не знайдений або не належить гравцю!"
		)
		-- Покажем всех исследователей для отладки
		if playerData.explorers then
			for i, exp in ipairs(playerData.explorers) do
				print(
					"  Дослідник",
					i,
					"ID:",
					exp.id,
					"Q:",
					exp.q,
					"R:",
					exp.r,
					"Treasure:",
					exp.treasureValue,
					"Player:",
					exp.player and exp.player.Name
				)
			end
		end
		return false
	end

	print(
		"✅ [СЕРВЕР] Знайдено дослідника ID:",
		explorer.id,
		"на Q=",
		explorer.q,
		"R=",
		explorer.r
	)

	-- Знаходимо доступні тайли для руху
	local availableTiles = self.mapManager:getNeighbors(explorer.q, explorer.r)
	print("📍 [СЕРВЕР] Знайдено доступних тайлів:", #availableTiles)

	-- Надсилаємо клієнту список доступних тайлів
	self.networkManager:getHighlightTilesEvent():FireClient(player, {
		type = "movement",
		explorerId = explorerId,
		availableTiles = availableTiles,
	})

	print("✅ [СЕРВЕР] Подія HighlightTilesEvent відправлена клієнту")
	return true
end

function AtlantisGame:onPlayerMoveExplorer(player, explorerId, q, r)
	print("🚶 [СЕРВЕР] onPlayerMoveExplorer викликано")
	print("  Гравець:", player.Name, "explorerId:", explorerId, "Q=", q, "R=", r)

	if not self.isGameActive or self.gameState ~= "main_game" then
		print("❌ [СЕРВЕР] Гра не активна або не основна фаза!")
		return false
	end

	-- Перевіряємо чи хід гравця
	if player ~= self.turnManager:getCurrentPlayer() then
		print("❌ [СЕРВЕР] Не ваш хід!")
		return false
	end

	-- Використовуємо дію
	if not self.turnManager:useAction(player) then
		print("❌ [СЕРВЕР] Немає доступних дій!")
		return false
	end

	-- Знаходимо дослідника с проверкой владельца
	local playerData = self.players[player]
	if not playerData then
		print("❌ [СЕРВЕР] Дані гравця не знайдені!")
		return false
	end

	explorerId = tonumber(explorerId)
	if not explorerId then
		print("❌ [СЕРВЕР] Неправильний формат explorerId")
		return false
	end

	local explorer = nil
	for _, exp in ipairs(playerData.explorers) do
		if exp.id == explorerId then
			-- Проверяем владельца
			if exp.player == player then
				explorer = exp
				break
			else
				print("❌ [СЕРВЕР] Цей дослідник не належить гравцю!")
				return false
			end
		end
	end

	if not explorer then
		print("❌ [СЕРВЕР] Дослідник не знайдений у гравця")
		return false
	end

	print(
		"🚶 [СЕРВЕР] Гравець",
		player.Name,
		"переміщує свого дослідника",
		explorerId,
		"на Q=",
		q,
		"R=",
		r
	)

	-- Обновляем позицию
	explorer.q = q
	explorer.r = r

	-- Уведомляємо всіх клієнтів про переміщення
	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "ExplorerMoved",
		explorerId = explorerId,
		q = q,
		r = r,
		playerName = player.Name, -- Важно отправлять имя владельца
	})

	-- Перевіряємо чи закінчились дії
	local remainingActions = self.turnManager:getRemainingActions(player)
	if remainingActions <= 0 then
		print(
			"🎯 [СЕРВЕР] Усі дії використані, перехід до наступного гравця"
		)
		self:endPlayerTurn(player)
	end

	return true
end

function AtlantisGame:endPlayerTurn(player)
	print("🎮 [СЕРВЕР] Завершення ходу гравця:", player.Name)

	-- Переходимо до наступного гравця
	local nextPlayer = self.turnManager:nextTurn()

	-- Уведомляємо всіх про новий хід
	self:startPlayerTurn()

	return nextPlayer
end

-- Создание и запуск игры
local game = AtlantisGame.new()
game:start()

return game
