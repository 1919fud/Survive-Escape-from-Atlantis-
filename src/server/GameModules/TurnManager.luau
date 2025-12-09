-- TurnManager.lua
local TurnManager = {}
TurnManager.__index = TurnManager

function TurnManager.new()
	local self = setmetatable({}, TurnManager)
	self.playersOrder = {}
	self.currentPlayerIndex = 1
	self.currentRound = 1
	self.maxExplorersPerPlayer = 10
	self.placementCompleted = {} -- Трекаємо хто завершив розміщення

	self.gamePhase = "placement" -- placement, main_game
	self.turnActionsLeft = 3
	self.PlayerActionsUsed = {}
	return self
end

function TurnManager:initialize(players)
	local playerList = {}
	for player, _ in pairs(players) do
		table.insert(playerList, player)
		self.placementCompleted[player] = false -- Спочатку всі не завершили
	end

	-- Перемешиваем игроков
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

-- Переход к следующему игроку
function TurnManager:nextPlayer()
	-- НЕ помечаємо поточного гравця як завершившего
	-- Він може ще ставити дослідників у наступних колах

	-- Шукаємо наступного гравця який ще не завершив
	local startIndex = self.currentPlayerIndex
	local attempts = 0

	repeat
		self.currentPlayerIndex += 1
		attempts += 1

		-- Якщо дошли до кінця списку, починаємо з початку
		if self.currentPlayerIndex > #self.playersOrder then
			self.currentPlayerIndex = 1
			self.currentRound += 1
			print("🔄 Раунд:", self.currentRound)
		end

		-- Якщо перевірили всіх гравців, виходимо
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
	self.currentPlayerIndex += 1

	-- Якщо дошли до кінця списку, починаємо новий раунд
	if self.currentPlayerIndex > #self.playersOrder then
		self.currentPlayerIndex = 1
		self.currentRound += 1
		print("🔄 Новий раунд основної гри:", self.currentRound)
	end

	local nextPlayer = self:getCurrentPlayer()

	-- Скидаємо лічильник дій для нового гравця
	self.playerActionsUsed[nextPlayer] = 0

	print("🎮 Перехід ходу: ", currentPlayer.Name, "→", nextPlayer.Name)
	return nextPlayer
end

function TurnManager:useAction(player)
	if self.gamePhase ~= "main_game" then
		warn("❌ Не основна фаза гри!")
		return false
	end

	if player ~= self:getCurrentPlayer() then
		warn("❌ Не ваш хід!")
		return false
	end

	local actionsUsed = self.playerActionsUsed[player] or 0

	if actionsUsed >= self.turnActionsLeft then
		warn("❌ Усі дії використані!")
		return false
	end

	self.playerActionsUsed[player] = actionsUsed + 1

	-- Перевіряємо чи закінчились дії
	if self.playerActionsUsed[player] >= self.turnActionsLeft then
		print("✅ Гравець", player.Name, "використав усі дії. Кінець ходу.")
	end

	return true
end

function TurnManager:getRemainingActions(player)
	if self.gamePhase ~= "main_game" then
		return 0
	end

	local actionsUsed = self.playerActionsUsed[player] or 0
	return math.max(0, self.turnActionsLeft - actionsUsed)
end

-- Перевіряємо, чи всі гравці завершили розміщення
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
		maxActions = self.turnActionsLeft,
	}
end

function TurnManager:startPlayerTurn(player)
	if self.gamePhase ~= "main_game" then
		return false
	end

	if player ~= self:getCurrentPlayer() then
		return false
	end

	-- Скидаємо лічильник дій для початку нового ходу
	self.playerActionsUsed[player] = 0

	print("🎮 Початок ходу гравця:", player.Name)
	return true
end

function TurnManager:startMainGamePhase()
	print("🎮 [TURN MANAGER] Основна фаза гри розпочата!")

	self.gamePhase = "main_game"
	self.currentPlayerIndex = 1
	self.currentRound = 1

	-- Скидаємо лічильники дій для всіх гравців
	self.playerActionsUsed = {}
	for _, player in ipairs(self.playersOrder) do
		self.playerActionsUsed[player] = 0
	end

	print("🎮 Основна фаза гри розпочата!")
	return self:getCurrentPlayer()
end

function TurnManager:endPlayerTurn(player)
	print("🎮 [TURN MANAGER] Завершення ходу гравця:", player.Name)

	-- Скидаємо дії для цього гравця
	self.remainingActions[player] = 0

	-- Переходимо до наступного гравця
	self.currentPlayerIndex = self.currentPlayerIndex + 1
	if self.currentPlayerIndex > #self.playersOrder then
		self.currentPlayerIndex = 1
		self.currentRound = self.currentRound + 1
		print("🔄 [TURN MANAGER] Новий раунд:", self.currentRound)
	end

	local nextPlayer = self.playersOrder[self.currentPlayerIndex]

	-- Скидаємо дії для нового гравця
	self.remainingActions[nextPlayer] = self.maxActions

	print("🎮 [TURN MANAGER] Наступний хід грає:", nextPlayer.Name)
	print("  Залишилось дій:", self.remainingActions[nextPlayer])

	return nextPlayer
end

return TurnManager
