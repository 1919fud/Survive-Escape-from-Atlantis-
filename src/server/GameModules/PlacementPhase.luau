-- PlacementPhase.lua (ModuleScript)
local PlacementPhase = {}
PlacementPhase.__index = PlacementPhase

function PlacementPhase.new()
	local self = setmetatable({}, PlacementPhase)

	self.isActive = false
	self.turnManager = nil
	self.playersData = {}

	return self
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
	})

	-- Активируем UI для текущего игрока
	self.networkManager:getGameStartEvent():FireClient(currentPlayer, {
		phase = "player_turn",
		message = "Ваш хід! Оберіть дослідника",
		isYourTurn = true,
	})
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

	-- Проверяем лимит исследователей
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
	local explorerId = #playerData.explorers + 1
	local explorer = {
		id = explorerId,
		player = player,
		treasureValue = treasureValue,
		q = q,
		r = r,
	}

	table.insert(playerData.explorers, explorer)
	playerData.explorersPlaced += 1

	-- СОЗДАЕМ ВИЗУАЛЬНОГО ИССЛЕДОВАТЕЛЯ ДЛЯ ВСЕХ ИГРОКОВ
	function PlacementPhase:createExplorerVisual(player, treasureValue, q, r)
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
			warn(
				"❌ Не найден тайл для размещения исследователя: Q=",
				q,
				"R=",
				r
			)
			return
		end

		-- Создаем исследователя
		local explorer = explorerTemplate:Clone()
		explorer.Name = "Explorer_" .. player.Name .. "_" .. treasureValue

		-- Позиционируем над тайлом
		local yOffset = explorer.Size.Y / 2 + targetTile.Size.Y / 2 + 0.5
		explorer.CFrame = targetTile.CFrame + Vector3.new(0, yOffset, 0)

		-- Устанавливаем цвет в зависимости от игрока
		local playerColor = self:getPlayerColor(player)
		explorer.BrickColor = playerColor

		-- Добавляем атрибуты
		explorer:SetAttribute("Player", player.Name)
		explorer:SetAttribute("TreasureValue", treasureValue)
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
	end

	-- Уведомляем всех игроков
	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "ExplorerPlaced",
		playerName = player.Name,
		explorerCount = playerData.explorersPlaced,
		maxExplorers = playerData.maxExplorers,
		q = q,
		r = r,
		treasureValue = treasureValue,
		playersData = self:getPlayersDataForClients(),
	})

	print(
		"✅ Игрок",
		player.Name,
		"разместил исследователя",
		playerData.explorersPlaced,
		"/",
		playerData.maxExplorers
	)

	-- Проверяем завершение хода
	if playerData.explorersPlaced >= playerData.maxExplorers then
		-- Игрок разместил всех исследователей
		self:moveToNextPlayer()
	else
		-- Игрок продолжает ход
		self:continuePlayerTurn(player)
	end

	return true
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
	local currentPlayer = self.turnManager:getCurrentPlayer()
	if currentPlayer then
		self.networkManager:getGameStartEvent():FireClient(currentPlayer, {
			phase = "waiting_turn",
			message = "Чекайте свій хід",
		})
	end

	-- Начинаем ход следующего игрока
	self:startPlayerTurn()
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

	-- Здесь будет переход к основной игре
	-- self:startMainGame()
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
