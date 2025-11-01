-- NetworkManager.lua (ModuleScript в Server/GameModules/)
local NetworkManager = {}
NetworkManager.__index = NetworkManager

function NetworkManager.new()
	local self = setmetatable({}, NetworkManager)

	-- Создаем RemoteEvents в ReplicatedStorage
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	-- Папка для сетевых событий
	local eventsFolder = Instance.new("Folder")
	eventsFolder.Name = "GameEvents"
	eventsFolder.Parent = ReplicatedStorage

	-- Игрок нажал "Готов"
	self.playerReadyEvent = Instance.new("RemoteEvent")
	self.playerReadyEvent.Name = "PlayerReadyEvent"
	self.playerReadyEvent.Parent = eventsFolder

	-- Обновление статуса готовности для всех игроков
	self.updateReadyStatusEvent = Instance.new("RemoteEvent")
	self.updateReadyStatusEvent.Name = "UpdateReadyStatusEvent"
	self.updateReadyStatusEvent.Parent = eventsFolder

	-- Начало игры
	self.gameStartEvent = Instance.new("RemoteEvent")
	self.gameStartEvent.Name = "GameStartEvent"
	self.gameStartEvent.Parent = eventsFolder

	self.updatePlayerColorsEvent = Instance.new("RemoteEvent")
	self.updatePlayerColorsEvent.Name = "UpdatePlayerColorsEvent"
	self.updatePlayerColorsEvent.Parent = eventsFolder

	return self
end

-- Геттеры для событий
function NetworkManager:getPlayerReadyEvent()
	return self.playerReadyEvent
end

function NetworkManager:getUpdateReadyStatusEvent()
	return self.updateReadyStatusEvent
end

function NetworkManager:getGameStartEvent()
	return self.gameStartEvent
end

function NetworkManager:getUpdatePlayerColorsEvent()
	return self.updatePlayerColorsEvent
end

return NetworkManager
