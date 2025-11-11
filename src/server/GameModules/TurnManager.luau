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
	return self.playersOrder[self.currentPlayerIndex]
end

function TurnManager:getTurnInfo()
	return {
		currentPlayer = self:getCurrentPlayer(),
		currentPlayerIndex = self.currentPlayerIndex,
		totalPlayers = #self.playersOrder,
		currentRound = self.currentRound,
		playersOrder = self.playersOrder,
		placementCompleted = self.placementCompleted,
	}
end

return TurnManager
