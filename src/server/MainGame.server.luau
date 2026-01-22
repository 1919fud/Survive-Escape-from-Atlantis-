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
	self.savedExplorers = {}
	self.floodPhase = nil
	self.floodPhase = require(GameModules:WaitForChild("FloodPhase")).new()
	self.floodPhase.mainGame = self

	self.creaturePhase = require(GameModules:WaitForChild("CreaturePhase")).new()
	self.creaturePhase.mainGame = self

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
	self:setupFloodPhaseHandlers()
	self:setupGameEndHandlers()

	self.floodPhase.placementPhase = self.placementPhase
	self.floodPhase.mainGame = self
	self.floodPhase.activatedVolcanoes = 0
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

	local MoveCreatureEvent = self.networkManager:getMoveCreatureEvent()
	if MoveCreatureEvent then
		MoveCreatureEvent.OnServerEvent:Connect(function(player, creatureModel, q, r)
			print("🦖 [MainGame] Отримано хід істотою від:", player.Name, "Q:", q, "R:", r)

			-- Викликаємо логіку з CreaturePhase
			if self.creaturePhase then
				self.creaturePhase:handleCreatureMove(player, creatureModel, q, r)
			else
				warn("❌ CreaturePhase не ініціалізовано!")
			end
		end)
		print("🔗 [СЕРВЕР] MoveCreatureEvent підключено: true")
	else
		warn("❌ Не вдалося знайти MoveCreatureEvent!")
	end
	-- ========================

	print("✅ Основні ігрові обробники налаштовані")

	print("✅ Основные игровые обработчики настроены")
end

function AtlantisGame:getBoatAtPosition(q, r)
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsBoat") then
			if obj:GetAttribute("Q") == q and obj:GetAttribute("R") == r then
				return obj
			end
		end
	end
	return nil
end

-- Видалити човен (для Кайдзю та Восьминога)
function AtlantisGame:removeBoat(boatObj)
	if not boatObj then
		return
	end

	local boatId = boatObj:GetAttribute("BoatId")
	local q = boatObj:GetAttribute("Q")
	local r = boatObj:GetAttribute("R")

	print("🔥 Знищення човна #" .. tostring(boatId))

	-- Сповіщаємо клієнтів про видалення
	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "boat_removed_by_effect",
		boatId = boatId,
		q = q,
		r = r,
		reason = "monster",
	})

	-- Дослідники, які були на човні, тепер у воді (оновлюємо їх статус)
	for _, exp in ipairs(workspace:GetChildren()) do
		if exp:GetAttribute("IsExplorer") and exp:GetAttribute("BoatId") == boatId then
			exp:SetAttribute("OnBoat", false)
			exp:SetAttribute("BoatId", nil)
			exp:SetAttribute("IsOnWater", true) -- Вони падають у воду
			-- Можна додати логіку, що вони стають "плавцями"
		end
	end

	boatObj:Destroy()
end

-- Примусове переміщення дослідника (для Кайдзю)
function AtlantisGame:forceMoveExplorer(explorerId, newQ, newR)
	local explorerObj = nil
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") and obj:GetAttribute("ExplorerId") == explorerId then
			explorerObj = obj
			break
		end
	end

	if explorerObj then
		-- Оновлюємо дані на сервері
		explorerObj:SetAttribute("Q", newQ)
		explorerObj:SetAttribute("R", newR)

		-- Перевіряємо, чи це вода
		local tile = self.mapManager:getTileAtPosition(newQ, newR)
		local isWater = false
		if tile and (tile.isWater or tile.meshPart:GetAttribute("IsWater")) then
			isWater = true
		end
		explorerObj:SetAttribute("IsOnWater", isWater)

		-- Відправляємо подію клієнтам для візуального оновлення
		self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
			type = "explorer_moved_by_flood",
			explorerId = explorerId,
			toQ = newQ,
			toR = newR,
		})
	end
end

-- Отримати список дослідників на тайлі
function AtlantisGame:getExplorersOnTile(q, r)
	local list = {}

	-- 1. Шукаємо у даних гравців
	for player, playerData in pairs(self.players) do
		if playerData.explorers then
			for _, explorer in ipairs(playerData.explorers) do
				if explorer.q == q and explorer.r == r then
					table.insert(list, {
						explorerId = explorer.id,
						playerName = player.Name,
						isOnBoat = explorer.isOnBoat or false,
						model = nil, -- поки що
					})
				end
			end
		end
	end

	-- 2. Додаємо візуальні об'єкти
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") then
			local eQ = obj:GetAttribute("Q")
			local eR = obj:GetAttribute("R")
			if eQ == q and eR == r then
				for i, expData in ipairs(list) do
					if expData.explorerId == obj:GetAttribute("ExplorerId") then
						expData.model = obj
						break
					end
				end
			end
		end
	end

	return list
end

function AtlantisGame:removeExplorer(explorerId, playerName)
	for player, playerData in pairs(self.players) do
		if player.Name == playerName then
			if playerData.explorers then
				for i = #playerData.explorers, 1, -1 do
					local explorer = playerData.explorers[i]
					if explorer.id == explorerId then
						table.remove(playerData.explorers, i)
						print("🗑️ Видалено дослідника", explorerId, "гравця", playerName)
						return true
					end
				end
			end
		end
	end
	return false
end

function AtlantisGame:setupCreaturePhaseHandlers()
	local MoveCreatureEvent = self.networkManager:getMoveCreatureEvent() -- Треба створити в NetworkManager
	MoveCreatureEvent.OnServerEvent:Connect(function(player, creatureId, q, r)
		self.creaturePhase:handleCreatureMove(player, creatureId, q, r)
	end)
end

function AtlantisGame:setupFloodPhaseHandlers()
	print("🌊 Налаштування обробників фази затоплення...")

	local SelectFloodTileEvent = self.networkManager:getSelectFloodTileEvent()
	local ConfirmFloodEvent = self.networkManager:getConfirmFloodEvent()

	SelectFloodTileEvent.OnServerEvent:Connect(function(player, q, r)
		print("🌊 Гравець", player.Name, "обрав тайл для затоплення Q=", q, "R=", r)
		self.floodPhase:handleTileSelection(player, q, r)
	end)

	ConfirmFloodEvent.OnServerEvent:Connect(function(player)
		print("🌊 Гравець", player.Name, "підтвердив затоплення")
		self.floodPhase:confirmFlood(player)
	end)

	print("✅ Обробники фази затоплення налаштовані")
end

function AtlantisGame:onPlayerJoined(player)
	print("👤 Игрок присоединился:", player.Name)

	self.players[player] = {
		name = player.Name,
		explorersPlaced = 0,
		maxExplorers = 4,
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
				-- ПЕРЕВІРКА НА АКТИВНИЙ ВУЛКАН - якщо активний вулкан, пропускаємо цей тайл
				if tile.isVolcanoActive and tile.isBlocked then
					print(
						"🚫 Тайл Q=",
						current.q,
						"R=",
						current.r,
						"є АКТИВНИМ вулканом - пропускаємо"
					)
				else
					-- НОВА ПЕРЕВІРКА: Чи немає на цьому тайлі істоти (акули, кайдзю, восьминога)
					local hasCreature = self:hasCreatureOnTile(current.q, current.r)

					if hasCreature then
						print(
							"🦈 Тайл Q=",
							current.q,
							"R=",
							current.r,
							"зайнято істотою - пропускаємо"
						)
					else
						-- Визначаємо тип тайла
						local isWaterTile = tile.isWater or tile.type == "Water"
						local isLandTile = not isWaterTile

						-- ДОДАНО: Перевірка, чи це човен і чи він заповнений
						local isBoatTile = self:hasBoatOnTile(current.q, current.r)
						local canEnterTile = true
						local boatId = nil

						if isBoatTile then
							boatId = self:getBoatIdAtPosition(current.q, current.r)
							local explorersOnBoat = self:getExplorersOnBoatCount(current.q, current.r, boatId)
							if explorersOnBoat >= 3 then
								canEnterTile = false -- Човен заповнений
								print(
									" 🚫 Човен #"
										.. tostring(boatId)
										.. " заповнений ("
										.. explorersOnBoat
										.. "/3)"
								)
							end
						end

						-- Додаємо тайл до доступних, якщо можна
						if canEnterTile then
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
								hasEnteredWater = current.hasEnteredWater,
								isBoatTile = isBoatTile,
								boatId = boatId,
								isVolcano = tile.isVolcano,
								isVolcanoActive = tile.isVolcanoActive,
								hasCreature = false,
							})
						end
					end
				end
			end
		end

		-- Якщо ще можемо робити кроки
		if current.steps < maxSteps then
			-- Якщо ми вже зайшли у воду
			if current.hasEnteredWater then
			-- Нічого не робимо, переходимо до наступного елемента черги
			else
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
							-- ПЕРЕВІРКА: Чи не є сусід АКТИВНИМ вулканом
							if neighborTile.isVolcanoActive and neighborTile.isBlocked then
								print(
									"🚫 Сусідній тайл Q=",
									nq,
									"R=",
									nr,
									"є АКТИВНИМ вулканом - не додаємо до черги"
								)
							else
								local isNeighborWater = neighborTile.isWater or neighborTile.type == "Water"

								-- Перевіряємо можливість переходу
								local canMoveToNeighbor = true
								local newHasEnteredWater = current.hasEnteredWater -- буде false,

								if isNeighborWater then
									-- Перший вхід у воду на цьому ходу (дозволено)
									newHasEnteredWater = true
								end

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
		end
	end

	print("📍 [СЕРВЕР] Знайдено доступних тайлів:", #availableTiles)

	-- Логування знайдених тайлів
	local landCount = 0
	local waterCount = 0
	local boatCount = 0
	local volcanoCount = 0
	local activeVolcanoCount = 0

	for _, tileData in ipairs(availableTiles) do
		if tileData.isBoatTile then
			boatCount = boatCount + 1
			print(
				"    🚤 Човен #" .. (tileData.boatId or "?") .. " Q=",
				tileData.q,
				"R=",
				tileData.r,
				"кроків:",
				tileData.steps
			)
		elseif tileData.isWater then
			waterCount = waterCount + 1
		elseif tileData.isVolcanoActive then
			activeVolcanoCount = activeVolcanoCount + 1
			print(
				"    🌋 АКТИВНИЙ Вулкан Q=",
				tileData.q,
				"R=",
				tileData.r,
				"(заблоковано - не додано до доступних)"
			)
		elseif tileData.isVolcano then
			volcanoCount = volcanoCount + 1
			print("    ⛰️ Гора з вулканом Q=", tileData.q, "R=", tileData.r, "(не активний)")
		else
			landCount = landCount + 1
		end
	end

	print(
		"  📊 Суша:",
		landCount,
		"Вода:",
		waterCount,
		"Човни:",
		boatCount,
		"Вулкани (не активні):",
		volcanoCount,
		"Активні вулкани (заблоковано):",
		activeVolcanoCount
	)

	return availableTiles
end

function AtlantisGame:hasCreatureOnTile(q, r)
	-- Перевіряємо чи є на цьому тайлі акула, кайдзю або восьминіг
	for _, obj in ipairs(workspace:GetChildren()) do
		-- Перевіряємо різні атрибути істот
		local isShark = obj:GetAttribute("IsShark")
		local isKaiju = obj:GetAttribute("IsKaiju")
		local isOctopus = obj:GetAttribute("IsOctopus")
		local creatureType = obj:GetAttribute("CreatureType")

		-- Якщо це будь-яка істота
		if
			isShark
			or isKaiju
			or isOctopus
			or creatureType == "Shark"
			or creatureType == "Kaiju"
			or creatureType == "Octopus"
		then
			local creatureQ = obj:GetAttribute("Q")
			local creatureR = obj:GetAttribute("R")

			if creatureQ == q and creatureR == r then
				-- Логуємо тип істоти для відлагодження
				local typeName = creatureType
					or (isShark and "Shark")
					or (isKaiju and "Kaiju")
					or (isOctopus and "Octopus")
					or "Unknown"
				print("🦈 Знайдено істоту " .. typeName .. " на Q=" .. q .. " R=" .. r)
				return true
			end
		end
	end

	return false
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
					--[[print(
						"  Дослідник",
						explorer.id,
						"Q=",
						explorer.q,
						"R=",
						explorer.r,
						"власник:",
						explorer.player.Name
					)]]
					--
				end
				print("  Всього дослідників:", #self.players[player].explorers)
			end
		end
	end

	-- Инициализируем TurnManager с игроками
	self.turnManager = TurnManager.new()
	self.turnManager.mainGame = self
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

function AtlantisGame:startFloodPhase(player)
	print("🌊 Початок фази затоплення для гравця:", player.Name)
	if self.gameState == "finished" then
		print("⚠️ Гра вже завершена, не починаємо новий хід")
		return
	end

	-- Зупиняємо основну гру
	self.isGameActive = false
	self.gameState = "flood"

	-- Ініціалізуємо та починаємо фазу затоплення
	self.floodPhase:start(player, self.players, self.networkManager, self.mapManager)
	self.floodPhase.mainGame = self
	self.floodPhase.currentPlayer = player

	-- Уведомляємо всіх гравців
	self.networkManager:getGameStartEvent():FireAllClients({
		phase = "flood_phase_started",
		message = "🌊 ФАЗА ЗАТОПЛЕННЯ!",
		currentPlayer = player.Name,
	})
end

function AtlantisGame:startCreaturePhase(player)
	-- ВИПРАВЛЕННЯ: Перевіряємо, чи гра не завершена
	if self.gameState == "finished" then
		print("⚠️ Гра вже завершена, не запускаємо фазу істот")
		return
	end

	--print("🦖 Початок фази істот для гравця:", player.Name)

	if not player then
		player = self.turnManager:getCurrentPlayer()
	end

	-- Зупиняємо основну гру
	self.gameState = "creatures"
	self.isGameActive = false

	-- Ініціалізуємо та починаємо фазу істот
	self.creaturePhase:start(player, self)
end

function AtlantisGame:returnToMainGame()
	print("🔄 Повернення до основної гри після затоплення")

	self.gameState = "main_game"
	self.isGameActive = true

	-- Переходимо до наступного гравця
	local nextPlayer = self.turnManager:nextTurn()
	self:startPlayerTurn()
end

function AtlantisGame:returnToMainGameAfterCreaturePhase()
	print("🔄 Повернення до основної гри після фази істот")

	-- Очищаємо всі підсвічування
	self.networkManager:getHighlightTilesEvent():FireAllClients({
		type = "clear",
	})

	-- Повертаємо стан гри
	self.gameState = "main_game"
	self.isGameActive = true

	-- ПЕРЕХІД ДО НАСТУПНОГО ГРАВЦЯ
	local nextPlayer = self.turnManager:nextTurn()

	if nextPlayer then
		print("🎮 Перехід ходу після фази істот до:", nextPlayer.Name)
		self:startPlayerTurn(nextPlayer)
	else
		-- Якщо наступного гравця немає, починаємо новий раунд
		print("🔄 Початок нового раунду після фази істот")
		self:startPlayerTurn()
	end
end

function AtlantisGame:returnToMainGameAfterFlood()
	print("🔄 Повернення до основної гри після затоплення")

	-- Очищаємо всі підсвічування
	self.networkManager:getHighlightTilesEvent():FireAllClients({
		type = "clear",
	})

	-- Повертаємо стан гри
	self.gameState = "main_game"
	self.isGameActive = true

	-- НЕ начинаем ход следующего игрока!
	-- Вместо этого продолжаем ход текущего игрока

	-- Получаем текущего игрока (который только что завершил фазу существ)
	local currentPlayer = self.turnManager:getCurrentPlayer()
	if currentPlayer then
		print("🎮 Продовження хоку гравця:", currentPlayer.Name)

		-- Скидаємо флаги входа в воду для исследователей текущего игрока
		local playerData = self.players[currentPlayer]
		if playerData and playerData.explorers then
			for _, explorer in ipairs(playerData.explorers) do
				explorer.hasEnteredWaterThisTurn = false
			end
		end

		-- Уведомляем текущего игрока
		local turnInfo = self.turnManager:getTurnInfo()
		self.networkManager:getGameStartEvent():FireClient(currentPlayer, {
			phase = "main_game_turn",
			message = "Ваш хід продовжується!",
			isYourTurn = true,
			remainingActions = turnInfo.remainingActions,
			maxActions = turnInfo.maxActions,
		})

		-- Остальным игрокам - ожидание
		for _, player in ipairs(self.turnManager.playersOrder) do
			if player ~= currentPlayer then
				self.networkManager:getGameStartEvent():FireClient(player, {
					phase = "main_game_waiting",
					message = "Чекайте поки " .. currentPlayer.Name .. " завершить хід",
				})
			end
		end

		-- Обновляем статус для всех
		self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
			type = "MainGameTurn",
			currentPlayer = currentPlayer.Name,
			turnInfo = turnInfo,
			remainingActions = turnInfo.remainingActions,
			maxActions = turnInfo.maxActions,
		})
	end

	print("✅ Ход продовжено для того ж гравця")
end
function AtlantisGame:updateExplorerPosition(explorerId, playerName, newQ, newR)
	print(
		"🔄 Оновлення позиції дослідника "
			.. explorerId
			.. " гравця "
			.. playerName
			.. " на Q="
			.. newQ
			.. " R="
			.. newR
	)

	-- Находим игрока
	local targetPlayer = nil
	for player, playerData in pairs(self.players) do
		if player.Name == playerName then
			targetPlayer = player
			break
		end
	end

	if not targetPlayer then
		print("❌ Гравець не знайдений: " .. playerName)
		return false
	end

	local playerData = self.players[targetPlayer]
	local explorerUpdated = false

	-- Обновляем позицию в данных игрока
	if playerData.explorers then
		for _, explorer in ipairs(playerData.explorers) do
			if explorer.id == explorerId then
				-- Сохраняем старые координаты для логов
				local oldQ = explorer.q
				local oldR = explorer.r

				-- Обновляем координаты
				explorer.q = newQ
				explorer.r = newR

				-- Проверяем, вода ли это
				local tile = self.mapManager:getTileAtPosition(newQ, newR)
				if tile then
					explorer.isOnWater = tile.isWater or false
				end

				explorerUpdated = true
				print(
					"✅ Оновлено позицію дослідника в даних: "
						.. oldQ
						.. ","
						.. oldR
						.. " → "
						.. newQ
						.. ","
						.. newR
				)
				break
			end
		end
	end

	if not explorerUpdated then
		print("❌ Дослідник не знайдений в даних гравця")
		return false
	end

	-- Отправляем обновление всем клиентам
	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "explorer_position_updated",
		explorerId = explorerId,
		playerName = playerName,
		q = newQ,
		r = newR,
	})

	return true
end

function AtlantisGame:startPlayerTurn()
	if self.gameState == "finished" then
		print("⚠️ Гра вже завершена, не починаємо новий хід")
		return
	end
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
	local selectBoatEvent = self.networkManager:getSelectBoatEvent()
	local moveBoatEvent = self.networkManager:getMoveBoatEvent()
	local skipTurnEvent = self.networkManager:getSkipTurnEvent()

	print("🔗 [СЕРВЕР] SelectExplorerEvent підключено:", selectExplorerEvent ~= nil)
	print("🔗 [СЕРВЕР] MoveExplorerEvent підключено:", moveExplorerEvent ~= nil)
	print("🔗 [СЕРВЕР] SelectBoatEvent підключено:", selectBoatEvent ~= nil)
	print("🔗 [СЕРВЕР] MoveBoatEvent підключено:", moveBoatEvent ~= nil)

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
	if selectBoatEvent then
		selectBoatEvent.OnServerEvent:Connect(function(player, boatId)
			print("🚤 [СЕРВЕР] Отримано SelectBoatEvent від", player.Name, "з boatId:", boatId)
			self:onPlayerSelectBoat(player, boatId)
		end)
	else
		warn("❌ [СЕРВЕР] selectBoatEvent не знайдено!")
	end

	-- Обробка руху човна (ДОДАНО)
	if moveBoatEvent then
		moveBoatEvent.OnServerEvent:Connect(function(player, boatId, q, r)
			print(
				"🚤 [СЕРВЕР] Отримано MoveBoatEvent від",
				player.Name,
				"з boatId:",
				boatId,
				"Q=",
				q,
				"R=",
				r
			)
			self:onPlayerMoveBoat(player, boatId, q, r)
		end)
	else
		warn("❌ [СЕРВЕР] moveBoatEvent не знайдено!")
	end
	if skipTurnEvent then
		skipTurnEvent.OnServerEvent:Connect(function(player)
			print("⏭️ [СЕРВЕР] Отримано SkipTurnEvent від", player.Name)
			self:skipTurn(player)
		end)
	else
		warn("❌ [СЕРВЕР] skipTurnEvent не знайдено!")
	end

	print("✅ [СЕРВЕР] Система переміщення налаштована")
end

function AtlantisGame:setupGameEndHandlers()
	print("🏁 Налаштування обробників завершення гри...")

	local EndGameUIEvent = Instance.new("RemoteEvent")
	EndGameUIEvent.Name = "EndGameUIEvent"
	EndGameUIEvent.Parent = self.networkManager:getGameStartEvent().Parent

	print("✅ Обробники завершення гри налаштовані")
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

function AtlantisGame:getExplorerCountOnTile(q, r)
	local count = 0

	for _, playerData in pairs(self.players) do
		if playerData.explorers then
			for _, explorer in ipairs(playerData.explorers) do
				if explorer.q == q and explorer.r == r and not explorer.isOnBoat then
					count = count + 1
				end
			end
		end
	end

	return count
end

--[[function AtlantisGame:getExplorersOnTile(q, r)
	local explorers = {}

	for _, playerData in pairs(self.players) do
		if playerData.explorers then
			for _, explorer in ipairs(playerData.explorers) do
				if explorer.q == q and explorer.r == r then
					table.insert(explorers, {
						player = explorer.player,
						playerName = explorer.player.Name,
						explorerId = explorer.id,
						treasureValue = explorer.treasureValue,
						hasEnteredWaterThisTurn = explorer.hasEnteredWaterThisTurn,
						isOnBoat = explorer.isOnBoat or false,
						boatId = explorer.boatId,
					})
				end
			end
		end
	end

	return explorers
end]]
--

function AtlantisGame:getBoatIdAtPosition(q, r)
	--print("🔍 Пошук човна на Q=", q, "R=", r)
	local targetQ = tonumber(q) or 0
	local targetR = tonumber(r) or 0

	-- Спершу шукаємо у всіх моделях workspace
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("IsBoat") then
			local boatQ = tonumber(obj:GetAttribute("Q")) or 0
			local boatR = tonumber(obj:GetAttribute("R")) or 0
			local boatId = tonumber(obj:GetAttribute("BoatId")) or 0

			--print("  Перевіряємо об'єкт:", obj.Name)
			--print("    Атрибути: Q=", boatQ, "R=", boatR, "BoatId=", boatId)

			if boatQ == targetQ and boatR == targetR then
				--print("✅ Знайдено човен #" .. tostring(boatId) .. " на Q=", q, "R=", r)
				return boatId
			end
		end
	end

	--print("❌ Човен не знайдений на Q=", q, "R=", r)
	return nil
end

function AtlantisGame:hasBoatOnTile(q, r)
	--print("🔍 Перевірка чи є човен на Q=", q, "R=", r)
	local boatId = self:getBoatIdAtPosition(q, r)
	local hasBoat = boatId ~= nil
	print("  Результат:", hasBoat)
	return hasBoat
end

function AtlantisGame:getExplorersOnBoat(q, r)
	local explorers = {}

	for _, playerData in pairs(self.players) do
		if playerData.explorers then
			for _, explorer in ipairs(playerData.explorers) do
				if explorer.q == q and explorer.r == r and explorer.isOnBoat then
					table.insert(explorers, explorer)
				end
			end
		end
	end

	return explorers
end

-- ДОДАНО: Функція для отримання списку зайнятих місць на човні
function AtlantisGame:getOccupiedBoatPlaces(boatId)
	local occupiedPlaces = {}

	for _, playerData in pairs(self.players) do
		if playerData.explorers then
			for _, explorer in ipairs(playerData.explorers) do
				if explorer.boatId == boatId and explorer.boatPlaceIndex then
					occupiedPlaces[explorer.boatPlaceIndex] = {
						player = explorer.player,
						explorerId = explorer.id,
						treasureValue = explorer.treasureValue,
					}
				end
			end
		end
	end

	return occupiedPlaces
end

-- ДОДАНО: Функція для знаходження вільного місця на човні
function AtlantisGame:findFreeBoatPlace(boatId)
	if not boatId then
		return nil
	end

	local occupiedPlaces = { false, false, false } -- place1, place2, place3

	for _, playerData in pairs(self.players) do
		if playerData.explorers then
			for _, explorer in ipairs(playerData.explorers) do
				if explorer.isOnBoat and explorer.boatId == boatId and explorer.boatPlaceIndex then
					if explorer.boatPlaceIndex >= 1 and explorer.boatPlaceIndex <= 3 then
						occupiedPlaces[explorer.boatPlaceIndex] = true
					end
				end
			end
		end
	end

	-- Шукаємо перше вільне місце
	for i = 1, 3 do
		if not occupiedPlaces[i] then
			return i
		end
	end

	return nil -- Всі місця зайняті
end

function AtlantisGame:getExplorersOnBoatCount(q, r, boatId)
	-- Якщо boatId не передано, шукаємо його
	if not boatId then
		boatId = self:getBoatIdAtPosition(q, r)
		print("🔍 Автоматичний пошук boatId для Q=", q, "R=", r, "знайдено:", boatId)
	end

	if not boatId then
		print("⚠️ [СЕРВЕР] Не знайдено boatId для getExplorersOnBoatCount")
		return 0
	end

	local count = 0
	for _, playerData in pairs(self.players) do
		if playerData.explorers then
			for _, explorer in ipairs(playerData.explorers) do
				-- Перетворюємо координати на числа
				local expQ = tonumber(explorer.q) or 0
				local expR = tonumber(explorer.r) or 0
				local targetQ = tonumber(q) or 0
				local targetR = tonumber(r) or 0

				-- Рахуємо тільки якщо дослідник ДІЙСНО на човні в цій позиції
				if expQ == targetQ and expR == targetR and explorer.isOnBoat and explorer.boatId == boatId then
					count = count + 1
				end
			end
		end
	end

	print("🧮 Дослідників на човні #" .. tostring(boatId) .. " (Q=", q, "R=", r, "):", count)
	return count
end

function AtlantisGame:onPlayerMoveExplorer(player, explorerId, q, r)
	print("🎯 [СЕРВЕР] onPlayerMoveExplorer вызвано")
	print(" Игрок:", player.Name, "explorerId:", explorerId, "Q=", q, "R=", r)

	if not self.isGameActive or self.gameState ~= "main_game" then
		print("❌ [СЕРВЕР] Игра не активна или не основная фаза!")
		return false
	end

	-- Проверяем чей ход
	if player ~= self.turnManager:getCurrentPlayer() then
		print("❌ [СЕРВЕР] Не ваш ход!")
		return false
	end

	-- Находим исследователя
	local playerData = self.players[player]
	if not playerData then
		print("❌ [СЕРВЕР] Данные игрока не найдены!")
		return false
	end

	local explorer = nil
	if playerData.explorers then
		explorerId = tonumber(explorerId)
		if not explorerId then
			print("❌ [СЕРВЕР] Неправильный формат explorerId")
			return false
		end

		for _, exp in ipairs(playerData.explorers) do
			if exp.id == explorerId and exp.player == player then
				explorer = exp
				print(" ✅ Найден исследователь игрока:", player.Name)
				break
			end
		end
	end

	if not explorer then
		print("❌ [СЕРВЕР] Исследователь не найден!")
		return false
	end

	-- Проверяем, не входил ли исследователь уже в воду этим ходом
	if explorer.hasEnteredWaterThisTurn then
		print(
			"❌ [СЕРВЕР] Этот исследователь уже входил в воду этим ходом!"
		)
		return false
	end

	print("✅ [СЕРВЕР] Найден исследователь ID:", explorer.id)

	-- Проверяем, является ли тайл безопасным
	local tile = self.mapManager:getTileAtPosition(q, r)
	local isSafeTile = false
	if tile and tile.meshPart and tile.meshPart:GetAttribute("TileType") == "Safe" then
		isSafeTile = true
		print("🛡️ Это безопасный тайл! Исследователь будет сохранен")
	end

	-- Проверяем, есть ли на этом тайле лодка
	local isBoatTile = self:hasBoatOnTile(q, r)
	local boatId = nil

	if isBoatTile then
		boatId = self:getBoatIdAtPosition(q, r)
		-- Проверяем, не заполнена ли лодка
		local explorersOnBoat = self:getExplorersOnBoatCount(q, r, boatId)
		if explorersOnBoat >= 3 then
			print(
				"❌ [СЕРВЕР] Лодка #"
					.. boatId
					.. " заполнена! Максимум 3 исследователя"
			)
			return false
		end
	end

	-- Находим информацию о перемещении
	local maxSteps = self.turnManager:getRemainingActions(player)
	local availableTiles = self:getAvailableMovementTiles(explorer, maxSteps)
	local moveCost = nil
	local targetTileData = nil
	local isWaterTile = false

	-- Находим тайл среди доступных
	for _, tileData in ipairs(availableTiles) do
		if tileData.q == q and tileData.r == r then
			moveCost = tileData.cost
			targetTileData = tileData
			isWaterTile = tileData.isWater or false
			break
		end
	end

	if not moveCost then
		print("❌ [СЕРВЕР] Этот тайл недоступен для перемещения!")
		return false
	end

	print("💰 [СЕРВЕР] Стоимость перемещения:", moveCost, "монет(ы)")
	print(
		" Тип тайла:",
		isWaterTile and "Вода" or "Суша",
		isBoatTile and "(лодка)" or "",
		isSafeTile and "(безопасный)" or ""
	)

	-- Используем действия (это нужно делать ДО сохранения исследователя)
	local actionsUsed = 0
	while actionsUsed < moveCost do
		if not self.turnManager:useAction(player) then
			print("❌ [СЕРВЕР] Недостаточно действий!")
			return false
		end
		actionsUsed = actionsUsed + 1
	end

	print("🚶 [СЕРВЕР] Игрок", player.Name, "перемещает своего исследователя")

	-- Если это безопасный тайл - сохраняем исследователя
	if isSafeTile then
		-- Сохраняем исследователя
		self:saveExplorerToSafeTile(explorer, player, q, r)

		-- Уведомляем всех клиентов
		self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
			type = "ExplorerSaved",
			explorerId = explorerId,
			playerName = player.Name,
			q = q,
			r = r,
			treasureValue = explorer.treasureValue,
			moveCost = moveCost, -- ДОБАВЛЕНО: отправляем стоимость
			remainingActions = self.turnManager:getRemainingActions(player), -- ДОБАВЛЕНО
		})
		self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
			type = "ExplorerMoved",
			explorerId = explorerId,
			playerName = player.Name,
			q = q,
			r = r,
			treasureValue = explorer.treasureValue,
			moveCost = moveCost, -- ДОБАВЛЕНО: отправляем стоимость
			remainingActions = self.turnManager:getRemainingActions(player), -- ДОБАВЛЕНО
		})

		-- Проверяем, закончились ли действия
		local remainingActions = self.turnManager:getRemainingActions(player)
		if remainingActions <= 0 then
			print(
				"🎯 [СЕРВЕР] Все действия использованы после сохранения исследователя"
			)
			self:endPlayerTurn(player)
		else
			-- Сбрасываем выделение
			self.networkManager:getHighlightTilesEvent():FireClient(player, {
				type = "clear",
			})
		end

		return true
	end

	-- Если исследователь был на лодке, а теперь не на лодке
	if explorer.isOnBoat and not isBoatTile then
		explorer.isOnBoat = false
		explorer.boatId = nil
		explorer.boatPlaceIndex = nil
		print("🚤 Исследователь сошел с лодки")
	end

	-- Обновляем позицию
	explorer.q = q
	explorer.r = r

	-- Обновляем информацию о лодке
	if isBoatTile and boatId then
		explorer.isOnBoat = true
		explorer.boatId = boatId

		-- Находим свободное место на лодке
		local freePlace = self:findFreeBoatPlace(boatId)
		if freePlace then
			explorer.boatPlaceIndex = freePlace
			print(
				"🚤 Исследователь сел на лодку #"
					.. tostring(boatId)
					.. " на место "
					.. freePlace
			)
		else
			print("❌ На лодке нет свободных мест!")
			-- Возвращаем потраченные действия
			for i = 1, actionsUsed do
				self.turnManager:refundAction(player)
			end
			return false
		end
	end

	-- Отмечаем, если вошел в воду (но не на лодку)
	if isWaterTile and not isBoatTile then
		explorer.hasEnteredWaterThisTurn = true
		print("💧 Исследователь вошел в воду")
	end

	-- Уведомляем всех клиентов
	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "ExplorerMoved",
		explorerId = explorerId,
		q = q,
		r = r,
		playerName = player.Name,
		moveCost = moveCost,
		isWaterTile = isWaterTile,
		isBoatTile = isBoatTile,
		boatId = isBoatTile and boatId or nil,
		remainingActions = self.turnManager:getRemainingActions(player),
	})

	-- Проверяем, закончились ли действия
	local remainingActions = self.turnManager:getRemainingActions(player)
	if remainingActions <= 0 then
		print("🎯 [СЕРВЕР] Все действия использованы")
		self:endPlayerTurn(player)
	else
		-- Сбрасываем выбор исследователя
		self.networkManager:getHighlightTilesEvent():FireClient(player, {
			type = "clear",
		})
	end

	return true
end

function AtlantisGame:saveExplorerToSafeTile(explorer, player, q, r)
	print(
		"🛡️ Сохранение исследователя #"
			.. explorer.id
			.. " игрока "
			.. player.Name
			.. " на безопасном тайле Q="
			.. q
			.. " R="
			.. r
	)

	-- Сохраняем исследователя в таблицу сохраненных
	local saveData = {
		explorerId = explorer.id,
		player = player,
		playerName = player.Name,
		treasureValue = explorer.treasureValue,
		q = q,
		r = r,
		savedAt = os.time(),
	}

	table.insert(self.savedExplorers, saveData)

	-- Удаляем исследователя из данных игрока
	local playerData = self.players[player]
	if playerData and playerData.explorers then
		for i = #playerData.explorers, 1, -1 do
			if playerData.explorers[i].id == explorer.id then
				table.remove(playerData.explorers, i)
				playerData.explorersPlaced = math.max(0, playerData.explorersPlaced - 1)
				print("🗑️ Удален исследователь из данных игрока")
				break
			end
		end
	end

	-- Ищем визуальную модель исследователя в workspace
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") and obj:GetAttribute("ExplorerId") == explorer.id then
			-- Визуальный эффект для сохранения
			local saveEffect = Instance.new("ParticleEmitter")
			saveEffect.Name = "SaveEffect"
			saveEffect.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0)) -- Золотой цвет
			saveEffect.Size = NumberSequence.new(1)
			saveEffect.Transparency = NumberSequence.new(0.7)
			saveEffect.Lifetime = NumberRange.new(2, 3)
			saveEffect.Rate = 50
			saveEffect.Speed = NumberRange.new(3, 5)
			saveEffect.Parent = obj.PrimaryPart

			-- Плавно поднимаем исследователя вверх
			local tweenService = game:GetService("TweenService")
			local targetPosition = obj.PrimaryPart.Position + Vector3.new(0, 10, 0)
			local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween = tweenService:Create(obj.PrimaryPart, tweenInfo, { Position = targetPosition })
			tween:Play()

			-- Удаляем после анимации
			game:GetService("Debris"):AddItem(obj, 3)

			print("✨ Визуальный эффект сохранения применен")
			break
		end
	end

	-- Проверяем условия победы
	self:checkWinCondition(player)

	print(
		"✅ Исследователь успешно сохранен. Всего сохранено:",
		#self.savedExplorers
	)
	print("🎯 Осталось действий у игрока:", self.turnManager:getRemainingActions(player))
end

-- Функция проверки условий победы
function AtlantisGame:checkWinCondition(player)
	local savedCount = 0
	local playerName = player.Name

	-- Считаем сколько исследователей сохранил этот игрок
	for _, saved in ipairs(self.savedExplorers) do
		if saved.playerName == playerName then
			savedCount = savedCount + 1
		end
	end

	print("📊 Игрок " .. playerName .. " сохранил " .. savedCount .. " исследователей")

	-- Если игрок сохранил всех своих исследователей (по умолчанию 4)
	local playerData = self.players[player]
	local totalExplorers = playerData.maxExplorers or 4

	if savedCount >= totalExplorers then
		print(
			"🎉 Игрок " .. playerName .. " выиграл! Все исследователи сохранены!"
		)

		-- Уведомляем всех о победе
		self.networkManager:getGameStartEvent():FireAllClients({
			phase = "game_over",
			message = "🎉 Игрок " .. playerName .. " выиграл!",
			winner = playerName,
			savedExplorers = savedCount,
		})

		-- Завершаем игру
		self.isGameActive = false
		self.gameState = "finished"
	end
end

function AtlantisGame:getBoatController(boatId)
	if not boatId then
		return nil
	end

	local playerCounts = {}
	local maxCount = 0

	-- Рахуємо кількість дослідників кожного гравця на човні
	for _, playerData in pairs(self.players) do
		if playerData.explorers then
			for _, explorer in ipairs(playerData.explorers) do
				if explorer.isOnBoat and explorer.boatId == boatId then
					local playerName = explorer.player.Name
					playerCounts[playerName] = (playerCounts[playerName] or 0) + 1
					if playerCounts[playerName] > maxCount then
						maxCount = playerCounts[playerName]
					end
				end
			end
		end
	end

	-- Якщо човен пустий (немає дослідників) - повертаємо nil, що означає "всі можуть контролювати"
	if maxCount == 0 then
		print("🚤 Човен #" .. boatId .. " пустий - можуть контролювати всі")
		return nil -- nil означає "всі гравці можуть контролювати"
	end

	-- Знаходимо гравців з максимальною кількістю дослідників
	local controllers = {}
	for playerName, count in pairs(playerCounts) do
		if count == maxCount then
			-- Знаходимо об'єкт гравця за іменем
			for playerObj, _ in pairs(self.players) do
				if playerObj.Name == playerName then
					table.insert(controllers, playerObj)
					break
				end
			end
		end
	end

	-- Якщо лише один гравець має максимальну кількість - він контролює
	if #controllers == 1 then
		print(
			"🚤 Човен #"
				.. boatId
				.. " контролює: "
				.. controllers[1].Name
				.. " ("
				.. maxCount
				.. " дослідників)"
		)
		return controllers[1]
	end

	-- Якщо декілька гравців мають однакову кількість - нічия
	if #controllers > 1 then
		local controllerNames = ""
		for i, player in ipairs(controllers) do
			controllerNames = controllerNames .. player.Name
			if i < #controllers then
				controllerNames = controllerNames .. ", "
			end
		end
		print(
			"🚤 Човен #"
				.. boatId
				.. " - нічия між: "
				.. controllerNames
				.. " (по "
				.. maxCount
				.. " дослідників)"
		)
		-- При нічиїй повертаємо nil, що означає "обидва можуть контролювати"
		return nil
	end

	return nil
end

function AtlantisGame:canPlayerControlBoat(player, boatId)
	if not boatId then
		return false
	end

	-- Отримуємо контролера човна
	local controller = self:getBoatController(boatId)

	-- Якщо контролера немає (човен пустий або нічия) - всі можуть
	if not controller then
		print(
			"✅ Гравець "
				.. player.Name
				.. " може контролювати пустий/спільний човен #"
				.. boatId
		)
		return true
	end

	-- Якщо є контролер - перевіряємо, чи це цей гравець
	if controller == player then
		print("✅ Гравець " .. player.Name .. " контролює човен #" .. boatId)
		return true
	end

	print(
		"❌ Гравець "
			.. player.Name
			.. " НЕ контролює човен #"
			.. boatId
			.. " (контролює: "
			.. controller.Name
			.. ")"
	)
	return false
end

function AtlantisGame:getAvailableBoatMovementTiles(boatId)
	print("🚤 [СЕРВЕР] Пошук доступних тайлів для човна #", boatId)

	-- Знаходимо координати човна
	local boatQ, boatR
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("IsBoat") then
			if obj:GetAttribute("BoatId") == boatId then
				boatQ = obj:GetAttribute("Q")
				boatR = obj:GetAttribute("R")
				break
			end
		end
	end

	if not boatQ or not boatR then
		print("❌ Човен не знайдений!")
		return {}
	end

	print(" Початкова позиція човна: Q=", boatQ, "R=", boatR)

	local availableTiles = {}
	local directions = {
		{ 1, 0 },
		{ 1, -1 },
		{ 0, -1 },
		{ -1, 0 },
		{ -1, 1 },
		{ 0, 1 },
	}

	for _, dir in ipairs(directions) do
		local nq = boatQ + dir[1]
		local nr = boatR + dir[2]

		-- Перевіряємо, чи це водний тайл
		local tile = self.mapManager:getTileAtPosition(nq, nr)
		if tile and tile.isWater then
			-- Перевіряємо, чи немає там іншого човна
			local hasOtherBoat = false
			for _, obj in ipairs(workspace:GetChildren()) do
				if obj:IsA("Model") and obj:GetAttribute("IsBoat") then
					local otherBoatId = obj:GetAttribute("BoatId")
					if otherBoatId ~= boatId then
						local otherQ = obj:GetAttribute("Q")
						local otherR = obj:GetAttribute("R")
						if otherQ == nq and otherR == nr then
							hasOtherBoat = true
							break
						end
					end
				end
			end

			if not hasOtherBoat then
				table.insert(availableTiles, {
					q = nq,
					r = nr,
					cost = 1, -- 1 дія для переміщення човна
					isWater = true,
				})
				print(" ✅ Доступний тайл: Q=", nq, "R=", nr)
			else
				print(" ❌ Тайл зайнятий іншим човном: Q=", nq, "R=", nr)
			end
		end
	end

	print("📍 Доступних тайлів для човна:", #availableTiles)
	return availableTiles
end

function AtlantisGame:onPlayerSelectBoat(player, boatId)
	print("🎯 [СЕРВЕР] onPlayerSelectBoat викликано")
	print(" Гравець:", player.Name, "boatId:", boatId)

	if not self.isGameActive or self.gameState ~= "main_game" then
		print("❌ [СЕРВЕР] Гра не активна або не основна фаза!")
		return false
	end

	-- Перевіряємо чи хід гравця
	local currentPlayer = self.turnManager:getCurrentPlayer()
	if player ~= currentPlayer then
		print("❌ [СЕРВЕР] Не ваш хід! Зараз ходить:", currentPlayer.Name)
		return false
	end

	-- ВИПРАВЛЕНО: Використовуємо нову функцію перевірки
	if not self:canPlayerControlBoat(player, boatId) then
		print("❌ [СЕРВЕР] Гравець не може контролювати цей човен!")
		return false
	end

	-- Знаходимо доступні тайли для переміщення
	local availableTiles = self:getAvailableBoatMovementTiles(boatId)

	-- Відправляємо клієнту список доступних тайлів
	self.networkManager:getHighlightTilesEvent():FireClient(player, {
		type = "boat_movement",
		boatId = boatId,
		availableTiles = availableTiles,
		remainingActions = self.turnManager:getRemainingActions(player),
	})

	return true
end

function AtlantisGame:onPlayerMoveBoat(player, boatId, q, r)
	print("🚤 [СЕРВЕР] onPlayerMoveBoat викликано")
	print(" Гравець:", player.Name, "boatId:", boatId, "Q=", q, "R=", r)

	if not self.isGameActive or self.gameState ~= "main_game" then
		print("❌ [СЕРВЕР] Гра не активна або не основна фаза!")
		return false
	end

	-- Перевіряємо чи хід гравця
	if player ~= self.turnManager:getCurrentPlayer() then
		print("❌ [СЕРВЕР] Не ваш хід!")
		return false
	end

	-- Перевіряємо, чи гравець контролює човен
	if not self:canPlayerControlBoat(player, boatId) then
		print("❌ [СЕРВЕР] Ви не можете контролювати цей човен!")
		return false
	end

	-- Перевіряємо доступність тайла
	local availableTiles = self:getAvailableBoatMovementTiles(boatId)
	local isTileAvailable = false
	for _, tile in ipairs(availableTiles) do
		if tile.q == q and tile.r == r then
			isTileAvailable = true
			break
		end
	end

	if not isTileAvailable then
		print("❌ [СЕРВЕР] Цей тайл недоступний для човна!")
		return false
	end

	-- Використовуємо дію
	if not self.turnManager:useAction(player) then
		print("❌ [СЕРВЕР] Недостатньо дій!")
		return false
	end

	-- Знаходимо човен у workspace
	local boatModel = nil
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("IsBoat") then
			if obj:GetAttribute("BoatId") == boatId then
				boatModel = obj
				break
			end
		end
	end

	if not boatModel then
		print("❌ [СЕРВЕР] Човен не знайд��ний у workspace!")
		return false
	end

	-- ОНОВЛЮЄМО НАЗВУ ЧОВНА
	local oldName = boatModel.Name
	local newName = "Boat_" .. tostring(boatId) .. "_" .. player.Name .. "_" .. q .. "_" .. r
	boatModel.Name = newName
	print(
		"🔄 [����������ВЕР] Оновлено назву човна: ",
		oldName,
		"→",
		newName
	)

	-- Оновлюєм�� координати човна
	boatModel:SetAttribute("Q", q)
	boatModel:SetAttribute("R", r)

	-- Оновлюємо координати всіх дослідників на човні
	for _, playerData in pairs(self.players) do
		if playerData.explorers then
			for _, explorer in ipairs(playerData.explorers) do
				if explorer.isOnBoat and explorer.boatId == boatId then
					explorer.q = q
					explorer.r = r
					print(
						"🔄 Оновлено координати дослідника",
						explorer.id,
						"на Q=",
						q,
						"R=",
						r
					)
				end
			end
		end
	end

	-- Оновлюємо позицію човна візуально
	local map = workspace:WaitForChild("Map")
	local targetTile = nil
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local tileQ = tonumber(obj:GetAttribute("Q")) or tonumber(obj:GetAttribute("q")) or 0
			local tileR = tonumber(obj:GetAttribute("R")) or tonumber(obj:GetAttribute("r")) or 0
			local isWater = obj:GetAttribute("IsWater") or obj:GetAttribute("Placeboat") == true

			if tileQ == q and tileR == r and isWater then
				targetTile = obj
				break
			end
		end
	end
	if targetTile and boatModel.PrimaryPart then
		local tileTopY = targetTile.Position.Y + targetTile.Size.Y / 2
		local boatBottomY = boatModel.PrimaryPart.Position.Y - boatModel.PrimaryPart.Size.Y / 2
		local yOffset = tileTopY - boatBottomY + 0.3

		local targetPosition = targetTile.Position + Vector3.new(0, yOffset, 0)
		local targetCFrame = CFrame.new(targetPosition) * CFrame.Angles(math.rad(180), 0, 0)

		boatModel:PivotTo(targetCFrame)
		print("🚤 Човен переміщений на нову позицію")
	else
		print("⚠️ Не знайдено водний тайл для позиціонування човна")
	end

	-- Уведомляємо всіх клієнтів
	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "BoatMoved",
		boatId = boatId,
		q = q,
		r = r,
		playerName = player.Name,
		remainingActions = self.turnManager:getRemainingActions(player),
	})

	local remainingActions = self.turnManager:getRemainingActions(player)

	if remainingActions <= 0 then
		print("🎯 [СЕРВЕР] Усі дії використані після переміщення човна")

		-- Скидаємо прапори входу у воду для всіх дослідників гравця
		local playerData = self.players[player]
		if playerData and playerData.explorers then
			for _, explorer in ipairs(playerData.explorers) do
				explorer.hasEnteredWaterThisTurn = false
				explorer.hasEnteredWaterThisTurn = nil
			end
		end

		-- Скидаємо виділення човна у клієнта
		self.networkManager:getHighlightTilesEvent():FireClient(player, {
			type = "clear",
		})

		-- Приховуємо UI вибору
		self.networkManager:getUpdateReadyStatusEvent():FireClient(player, {
			type = "turn_ended",
			message = "Хід завершено! Усі дії використані.",
		})

		-- Автоматично завершуємо хід
		self:endPlayerTurn(player)
	else
		-- Якщо ще є дії, оновлюємо інтерфейс
		self.networkManager:getUpdateReadyStatusEvent():FireClient(player, {
			type = "MainGameTurn",
			currentPlayer = player.Name,
			remainingActions = remainingActions,
			maxActions = self.turnManager.maxActions,
		})
	end

	print(
		"✅ [СЕРВЕР] Човен #" .. tostring(boatId) .. " переміщений гравцем",
		player.Name
	)

	return true
end

function AtlantisGame:skipTurn(player)
	print("⏭️ [СЕРВЕР] Гравець пропускає хід:", player.Name)

	if not self.isGameActive or self.gameState ~= "main_game" then
		print("❌ [СЕРВЕР] Не можна пропустити хід - гра не активна!")
		return false
	end

	-- Перевіряємо чи хід гравця
	local currentPlayer = self.turnManager:getCurrentPlayer()
	if player ~= currentPlayer then
		print("❌ [СЕРВЕР] Не ваш хід! Зараз ходить:", currentPlayer.Name)
		return false
	end

	-- Очищаємо виділення
	self.networkManager:getHighlightTilesEvent():FireClient(player, {
		type = "clear",
	})

	-- Очищаємо прапори входу у воду для всіх дослідників гравця
	local playerData = self.players[player]
	if playerData and playerData.explorers then
		for _, explorer in ipairs(playerData.explorers) do
			explorer.hasEnteredWaterThisTurn = false
		end
	end

	print("✅ [СЕРВЕР] Хід пропущено. Починаємо фазу затоплення...")

	-- Переходимо до фази затоплення
	self:startFloodPhase(player)

	return true
end

function AtlantisGame:endPlayerTurn(player)
	print("🎮 [СЕРВЕР] Завершення хоку гравця:", player)

	-- Скидаємо прапори входу у воду
	local playerData = self.players[player]
	if playerData and playerData.explorers then
		for _, explorer in ipairs(playerData.explorers) do
			explorer.hasEnteredWaterThisTurn = false
		end
	end

	-- Скидаємо виділення
	self.networkManager:getHighlightTilesEvent():FireClient(player, {
		type = "clear",
	})

	-- Перевіряємо, чи всі дії використані
	local remainingActions = self.turnManager:getRemainingActions(player)

	if remainingActions <= 0 then
		print("🌊 Усі дії використано - починаємо фазу затоплення")
		self:startFloodPhase(player)
	else
		-- Якщо ще є дії, продовжуємо хід
		print("🎯 Ще є дії: " .. remainingActions)
		self.networkManager:getUpdateReadyStatusEvent():FireClient(player, {
			type = "actions_remaining",
			message = "У вас ще є дії!",
			remainingActions = remainingActions,
		})
	end
end

-- Создание и запуск игры
local game = AtlantisGame.new()
game:start()

return game
