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

function AtlantisGame:getAvailableMovementTiles(explorer, maxSteps)
	print("🗺️ [СЕРВЕР] Пошук доступних тайлів для дослідника", explorer.id)
	print("  Початкова позиція: Q=", explorer.q, "R=", explorer.r)
	print("  Максимум кроків:", maxSteps)

	local visited = {}
	local availableTiles = {}
	local q = explorer.q
	local r = explorer.r

	-- Система BFS з обмеженням по воді
	local queue = { { q = q, r = r, steps = 0, hasEnteredWater = false } }
	visited[self.mapManager:getCoordKey(q, r)] = true

	while #queue > 0 do
		local current = table.remove(queue, 1)
		local currentKey = self.mapManager:getCoordKey(current.q, current.r)

		-- Якщо не початкова позиція і не перевищили ліміт кроків
		if current.steps > 0 and current.steps <= maxSteps then
			-- Отримуємо тайл
			local tile = self.mapManager:getTileAtPosition(current.q, current.r)
			if tile then
				-- Перевіряємо чи на тайлі немає іншого дослідника
				local hasOtherExplorer = false
				for _, playerData in pairs(self.players) do
					if playerData.explorers then
						for _, otherExplorer in ipairs(playerData.explorers) do
							if otherExplorer.q == current.q and otherExplorer.r == current.r then
								if otherExplorer.id ~= explorer.id then -- Ігноруємо самого себе
									hasOtherExplorer = true
									break
								end
							end
						end
					end
					if hasOtherExplorer then
						break
					end
				end

				if not hasOtherExplorer then
					-- Визначаємо тип тайла
					local isWaterTile = tile.isWater or tile.type == "Water"
					local isLandTile = not isWaterTile

					-- Додаємо тайл до доступних
					table.insert(availableTiles, {
						q = current.q,
						r = current.r,
						steps = current.steps,
						cost = current.steps,
						coordKey = currentKey,
						tile = tile,
						isWater = isWaterTile,
						isLand = isLandTile,
						tileType = tile.tileType or (isWaterTile and "Water" or "Land"),
						hasEnteredWater = current.hasEnteredWater, -- Чи входив у воду на цьому шляху
					})
				end
			end
		end

		-- Якщо ще можемо робити кроки
		if current.steps < maxSteps then
			local directions = {
				{ 1, 0 },
				{ 1, -1 },
				{ 0, -1 },
				{ -1, 0 },
				{ -1, 1 },
				{ 0, 1 },
			}

			for _, dir in ipairs(directions) do
				local nq = current.q + dir[1]
				local nr = current.r + dir[2]
				local neighborKey = self.mapManager:getCoordKey(nq, nr)

				if not visited[neighborKey] then
					-- Отримуємо тайл сусіда
					local neighborTile = self.mapManager:getTileAtPosition(nq, nr)
					if neighborTile then
						local isNeighborWater = neighborTile.isWater or neighborTile.type == "Water"
						local isNeighborLand = not isNeighborWater

						-- Перевіряємо можливість переходу
						local canMoveToNeighbor = true
						local newHasEnteredWater = current.hasEnteredWater

						if isNeighborWater then
							-- Перехід на воду
							if current.hasEnteredWater then
								-- Вже входив у воду на цьому ходу - не може знову
								canMoveToNeighbor = false
							else
								-- Перший вхід у воду на цьому ходу
								newHasEnteredWater = true
							end
						end
						-- Перехід на сушу завжди дозволений

						if canMoveToNeighbor then
							visited[neighborKey] = true
							table.insert(queue, {
								q = nq,
								r = nr,
								steps = current.steps + 1,
								hasEnteredWater = newHasEnteredWater,
							})
						end
					end
				end
			end
		end
	end

	print("📍 [СЕРВЕР] Знайдено доступних тайлів:", #availableTiles)

	-- Логування знайдених тайлів
	local landCount = 0
	local waterCount = 0

	for _, tileData in ipairs(availableTiles) do
		if tileData.isWater then
			waterCount = waterCount + 1
			print("    💧 Q=", tileData.q, "R=", tileData.r, "кроків:", tileData.steps)
		else
			landCount = landCount + 1
			print(
				"    🌍 Q=",
				tileData.q,
				"R=",
				tileData.r,
				"тип:",
				tileData.tileType,
				"кроків:",
				tileData.steps
			)
		end
	end

	print("  📊 Суша:", landCount, "Вода:", waterCount)

	return availableTiles
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
	print("  Запитує explorerId:", explorerId)

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

	-- Перевіряємо скільки дій залишилось
	local remainingActions = self.turnManager:getRemainingActions(player)
	if remainingActions <= 0 then
		print("❌ [СЕРВЕР] Немає доступних дій!")
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
		explorerId = tonumber(explorerId)
		if not explorerId then
			print("❌ [СЕРВЕР] Неправильний формат explorerId")
			return false
		end

		for _, exp in ipairs(playerData.explorers) do
			if exp.id == explorerId and exp.player == player then
				explorer = exp
				print("  ✅ Знайдено дослідника гравця:", player.Name)
				-- ВИПРАВЛЕННЯ: Перевіряємо стан дослідника САМЕ ТУТ
				if explorer.hasEnteredWaterThisTurn then
					print(
						"❌ [СЕРВЕР] Цей дослідник вже входив у воду цього ходу!"
					)

					-- Відправляємо спеціальне повідомлення клієнту
					self.networkManager:getHighlightTilesEvent():FireClient(player, {
						type = "explorer_water_blocked",
						explorerId = explorerId,
						message = "Цей дослідник вже входив у воду цього ходу і не може рухатися!",
						remainingActions = self.turnManager:getRemainingActions(player),
					})

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

	-- Знаходимо доступні тайли для руху (максимум 3 кроки)
	local maxSteps = remainingActions -- Максимум кроків = залишок дій
	local availableTiles = self:getAvailableMovementTiles(explorer, maxSteps)

	print("📍 [СЕРВЕР] Знайдено доступних тайлів:", #availableTiles)

	-- Групуємо тайли за вартістю
	local tilesByCost = {}
	for _, tile in ipairs(availableTiles) do
		if not tilesByCost[tile.cost] then
			tilesByCost[tile.cost] = {}
		end
		table.insert(tilesByCost[tile.cost], tile)
	end

	-- Відправляємо клієнту список доступних тайлів з інформацією про вартість
	self.networkManager:getHighlightTilesEvent():FireClient(player, {
		type = "movement",
		explorerId = explorerId,
		availableTiles = availableTiles,
		tilesByCost = tilesByCost,
		remainingActions = remainingActions,
		maxSteps = maxSteps,
	})

	print("✅ [СЕРВЕР] Подія HighlightTilesEvent відправлена клієнту")
	return true
end

function AtlantisGame:onPlayerMoveExplorer(player, explorerId, q, r)
	print("🎯 [СЕРВЕР] onPlayerSelectExplorer викликано")
	print("  Гравець:", player.Name)
	print("  Запитує explorerId:", explorerId)

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
		explorerId = tonumber(explorerId)
		if not explorerId then
			print("❌ [СЕРВЕР] Неправильний формат explorerId")
			return false
		end

		for _, exp in ipairs(playerData.explorers) do
			if exp.id == explorerId and exp.player == player then
				explorer = exp
				print("  ✅ Знайдено дослідника гравця:", player.Name)
				break
			end
		end
	end

	if not explorer then
		print(
			"❌ [СЕРВЕР] Дослідник не знайдений або не належить гравцю!"
		)
		return false
	end

	-- ВИПРАВЛЕННЯ: Перевіряємо, чи дослідник вже входив у воду цього ходу
	if explorer.hasEnteredWaterThisTurn then
		print("❌ [СЕРВЕР] Цей дослідник вже входив у воду цього ходу!")

		-- Відправляємо спеціальне повідомлення клієнту
		self.networkManager:getHighlightTilesEvent():FireClient(player, {
			type = "explorer_water_blocked",
			explorerId = explorerId,
			message = "Цей дослідник вже входив у воду цього ходу і не може рухатися!",
			remainingActions = self.turnManager:getRemainingActions(player),
		})

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

	-- Знаходимо інформацію про переміщення
	local maxSteps = self.turnManager:getRemainingActions(player)
	local availableTiles = self:getAvailableMovementTiles(explorer, maxSteps)

	local moveCost = nil
	local targetTileData = nil
	local isWaterTile = false

	-- Знаходимо тайл серед доступних і отримуємо його вартість
	for _, tileData in ipairs(availableTiles) do
		if tileData.q == q and tileData.r == r then
			moveCost = tileData.cost
			targetTileData = tileData
			isWaterTile = tileData.isWater or false
			break
		end
	end

	if not moveCost then
		print("❌ [СЕРВЕР] Цей тайл недоступний для переміщення!")
		return false
	end

	print("💰 [СЕРВЕР] Вартість переміщення:", moveCost, "монет(и)")
	print("  Тип тайла:", isWaterTile and "Вода" or "Сушя")

	-- Використовуємо дії
	local actionsUsed = 0
	while actionsUsed < moveCost do
		if not self.turnManager:useAction(player) then
			print("❌ [СЕРВЕР] Недостатньо дій!")
			return false
		end
		actionsUsed = actionsUsed + 1
	end

	print(
		"🚶 [СЕРВЕР] Гравець",
		player.Name,
		"переміщує свого дослідника",
		explorerId,
		"на Q=",
		q,
		"R=",
		r,
		"вартістю",
		moveCost,
		"монет"
	)

	-- Обновляем позицию
	explorer.q = q
	explorer.r = r

	-- Позначаємо, якщо входив у воду
	if isWaterTile then
		explorer.hasEnteredWaterThisTurn = true
		print(
			"  💧 Дослідник ввійшов у воду - більше не може рухатися цього ходу"
		)
	end

	-- Уведомляємо всіх клієнтів про переміщення
	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "ExplorerMoved",
		explorerId = explorerId,
		q = q,
		r = r,
		playerName = player.Name,
		moveCost = moveCost,
		isWaterTile = isWaterTile,
		remainingActions = self.turnManager:getRemainingActions(player),
	})

	-- Перевіряємо чи закінчились дії
	local remainingActions = self.turnManager:getRemainingActions(player)
	if remainingActions <= 0 then
		print(
			"🎯 [СЕРВЕР] Усі дії використані, перехід до наступного гравця"
		)
		self:endPlayerTurn(player)
	else
		-- Скидаємо вибір дослідника, щоб гравець міг обрати іншого
		self.networkManager:getHighlightTilesEvent():FireClient(player, {
			type = "clear",
		})
	end

	return true
end

function AtlantisGame:endPlayerTurn(player)
	print("🎮 [СЕРВЕР] Завершення ходу гравця:", player.Name)

	-- Скидаємо прапори входу у воду для всіх дослідників гравця
	local playerData = self.players[player]
	if playerData and playerData.explorers then
		for _, explorer in ipairs(playerData.explorers) do
			explorer.hasEnteredWaterThisTurn = nil
		end
		print(
			"  💧 Скинуто прапори входу у воду для всіх дослідників гравця"
		)
	end

	-- Переходимо до наступного гравця
	local nextPlayer = self.turnManager:nextTurn()

	-- Скидаємо прапори входу у воду для нового гравця
	local nextPlayerData = self.players[nextPlayer]
	if nextPlayerData and nextPlayerData.explorers then
		for _, explorer in ipairs(nextPlayerData.explorers) do
			explorer.hasEnteredWaterThisTurn = nil
		end
	end

	-- Уведомляємо всіх про новий хід
	self:startPlayerTurn()

	return nextPlayer
end

-- Создание и запуск игры
local game = AtlantisGame.new()
game:start()

return game
