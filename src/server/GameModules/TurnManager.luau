-- TurnManager.lua (ModuleScript)
local TurnManager = {}
TurnManager.__index = TurnManager

function TurnManager.new()
	local self = setmetatable({}, TurnManager)

	self.playersOrder = {}
	self.currentPlayerIndex = 1
	self.currentRound = 1
	self.maxExplorersPerPlayer = 10

	return self
end

-- Инициализация очереди игроков
function TurnManager:initialize(players)
	-- Создаем случайный порядок игроков
	local playerList = {}
	for player, _ in pairs(players) do
		table.insert(playerList, player)
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
		print("   " .. i .. ". " .. player.Name)
	end
end

-- Получить текущего игрока
function TurnManager:getCurrentPlayer()
	return self.playersOrder[self.currentPlayerIndex]
end

-- Переход к следующему игроку
function TurnManager:nextPlayer()
	self.currentPlayerIndex += 1

	-- Если дошли до конца очереди, начинаем новый раунд
	if self.currentPlayerIndex > #self.playersOrder then
		self.currentPlayerIndex = 1
		self.currentRound += 1
		print("🔄 Начинается раунд размещения:", self.currentRound)
	end

	return self:getCurrentPlayer()
end

-- Проверить, все ли игроки завершили размещение
function TurnManager:allPlayersFinished(playersData)
	for _, player in ipairs(self.playersOrder) do
		local playerData = playersData[player]
		if playerData and playerData.explorersPlaced < self.maxExplorersPerPlayer then
			return false
		end
	end
	return true
end

-- Получить информацию об очереди
function TurnManager:getTurnInfo()
	return {
		currentPlayer = self:getCurrentPlayer(),
		currentPlayerIndex = self.currentPlayerIndex,
		totalPlayers = #self.playersOrder,
		currentRound = self.currentRound,
		playersOrder = self.playersOrder,
	}
end

return TurnManager
