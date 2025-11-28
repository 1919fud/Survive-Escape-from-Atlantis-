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

	self.placementPhase:start(self.players, self.networkManager)

	print("🎮 Основная игра начата! Фаза размещения исследователей.")
end

function AtlantisGame:startMainGamePhase()
	print("🎯 НАЧАЛО ОСНОВНОЙ ИГРОВОЙ ФАЗЫ!")
	self.gameState = "main_game"
	--self:setupMovementSystem()

	-- Уведомляем всех игроков о начале основной игровой фазы
	if self.networkManager then
		self.networkManager:getGameStartEvent():FireAllClients({
			phase = "main_game_active",
			message = "Гра триває! Можна переміщати шукачів.",
		})
	end
end

-- Создание и запуск игры
local game = AtlantisGame.new()
game:start()

return game
