local TurnManager = {}
TurnManager.__index = TurnManager

function TurnManager.new()
	local self = setmetatable({}, TurnManager)
	self.playersOrder = {}
	self.currentPlayerIndex = 1
	self.currentRound = 1
	self.maxExplorersPerPlayer = 10
	self.placementCompleted = {}

	self.gamePhase = "placement" -- placement, main_game
	self.maxActions = 3
	self.playerActionsUsed = {} -- Виправлено регістр (було PlayerActionsUsed)

	self.mainGame = nil -- Сюди ми запишемо посилання на MainGame
	return self
end

function TurnManager:initialize(players)
	local playerList = {}
	for player, _ in pairs(players) do
		table.insert(playerList, player)
		self.placementCompleted[player] = false
	end

	-- Перемішуємо гравців
	for i = #playerList, 2, -1 do
		local j = math.random(i)
		playerList[i], playerList[j] = playerList[j], playerList[i]
	end

	self.playersOrder = playerList
	self.currentPlayerIndex = 1
	self.currentRound = 1

	print("🎯 Очередь игроков установлена:")
	for i, player in ipairs(self.playersOrder) do
		print(" " .. i .. ". " .. player.Name)
	end
end

-- Переход к следующему игроку (для фази розміщення)
function TurnManager:nextPlayer()
	local startIndex = self.currentPlayerIndex
	local attempts = 0

	repeat
		self.currentPlayerIndex = self.currentPlayerIndex + 1
		attempts = attempts + 1

		if self.currentPlayerIndex > #self.playersOrder then
			self.currentPlayerIndex = 1
			self.currentRound = self.currentRound + 1
			print("🔄 Раунд:", self.currentRound)
		end

		if attempts >= #self.playersOrder then
			break
		end
	until not self.placementCompleted[self:getCurrentPlayer()]

	return self:getCurrentPlayer()
end

function TurnManager:nextTurn()
	if self.gamePhase ~= "main_game" then
		warn("❌ Не основна фаза гри!")
		return self:getCurrentPlayer()
	end

	local currentPlayer = self:getCurrentPlayer()
	print("🎮 Завершення ходу гравця:", currentPlayer.Name)

	-- Переходимо до наступного гравця
	self.currentPlayerIndex = self.currentPlayerIndex + 1

	-- Якщо дійшли до кінця списку, починаємо новий раунд
	if self.currentPlayerIndex > #self.playersOrder then
		self.currentPlayerIndex = 1
		self.currentRound = self.currentRound + 1
		print("🔄 Новий раунд основної гри:", self.currentRound)
	end

	local nextPlayer = self:getCurrentPlayer()

	-- Скидаємо лічильник дій для нового гравця
	self.playerActionsUsed[nextPlayer] = 0
	print("🎮 Перехід ходу: ", currentPlayer.Name, "→", nextPlayer.Name)

	-- [ВИПРАВЛЕННЯ] Викликаємо MainGame для старту ходу
	if self.mainGame then
		print("🔄 [TurnManager] Ініціалізація ходу через MainGame для: " .. nextPlayer.Name)
		-- Ця функція скине дії візуально і відправить подію клієнту
		-- ВИПРАВЛЕННЯ: використовуємо startPlayerTurn замість startTurn
		self.mainGame:startPlayerTurn()
	else
		warn(
			"⚠️ [TurnManager] self.mainGame is nil! Гравець змінився, але клієнт не повідомлений."
		)
	end

	return nextPlayer
end

function TurnManager:useAction(player)
	if self.gamePhase ~= "main_game" then
		return false
	end
	if player ~= self:getCurrentPlayer() then
		return false
	end

	local actionsUsed = self.playerActionsUsed[player] or 0

	if actionsUsed >= self.maxActions then
		return false
	end

	self.playerActionsUsed[player] = actionsUsed + 1
	return true
end

function TurnManager:useMultipleActions(player, count)
	local actionsUsed = self.playerActionsUsed[player] or 0

	if actionsUsed + count > self.maxActions then
		warn("❌ Недостатньо дій! Потрібно:", count, "Є:", self.maxActions - actionsUsed)
		return false
	end

	self.playerActionsUsed[player] = actionsUsed + count
	print(
		"💰 Використано",
		count,
		"дій. Залишилось:",
		self.maxActions - self.playerActionsUsed[player]
	)
	return true
end

function TurnManager:getRemainingActions(player)
	if self.gamePhase ~= "main_game" then
		return 0
	end
	local actionsUsed = self.playerActionsUsed[player] or 0
	return math.max(0, self.maxActions - actionsUsed)
end

function TurnManager:allPlayersFinished(playersData)
	if not playersData then
		return false
	end
	for _, player in ipairs(self.playersOrder) do
		local playerData = playersData[player]
		if playerData and playerData.explorersPlaced < self.maxExplorersPerPlayer then
			return false
		end
	end
	return true
end

function TurnManager:getCurrentPlayer()
	if #self.playersOrder == 0 then
		return nil
	end
	return self.playersOrder[self.currentPlayerIndex]
end

function TurnManager:getTurnInfo()
	local currentPlayer = self:getCurrentPlayer()
	local remainingActions = 0

	if currentPlayer and self.gamePhase == "main_game" then
		remainingActions = self:getRemainingActions(currentPlayer)
	end

	return {
		currentPlayer = currentPlayer,
		currentPlayerIndex = self.currentPlayerIndex,
		totalPlayers = #self.playersOrder,
		currentRound = self.currentRound,
		playersOrder = self.playersOrder,
		placementCompleted = self.placementCompleted,
		gamePhase = self.gamePhase,
		remainingActions = remainingActions,
		maxActions = self.maxActions,
	}
end

function TurnManager:startPlayerTurn(player)
	if self.gamePhase ~= "main_game" then
		return false
	end
	if player ~= self:getCurrentPlayer() then
		return false
	end

	self.playerActionsUsed[player] = 0
	print("🎮 Початок ходу гравця:", player.Name)
	return true
end

function TurnManager:startMainGamePhase()
	print("🎮 [TURN MANAGER] Основна фаза гри розпочата!")
	self.gamePhase = "main_game"
	self.currentPlayerIndex = 1
	self.currentRound = 1
	self.playerActionsUsed = {}
	for _, player in ipairs(self.playersOrder) do
		self.playerActionsUsed[player] = 0
	end
	return self:getCurrentPlayer()
end

return TurnManager
