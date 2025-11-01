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

	-- Существующие события
	self.playerReadyEvent = Instance.new("RemoteEvent")
	self.playerReadyEvent.Name = "PlayerReadyEvent"
	self.playerReadyEvent.Parent = eventsFolder

	self.updateReadyStatusEvent = Instance.new("RemoteEvent")
	self.updateReadyStatusEvent.Name = "UpdateReadyStatusEvent"
	self.updateReadyStatusEvent.Parent = eventsFolder

	self.gameStartEvent = Instance.new("RemoteEvent")
	self.gameStartEvent.Name = "GameStartEvent"
	self.gameStartEvent.Parent = eventsFolder

	-- ДОБАВЛЕНО: Событие для размещения исследователей
	self.placeExplorerEvent = Instance.new("RemoteEvent")
	self.placeExplorerEvent.Name = "PlaceExplorerEvent"
	self.placeExplorerEvent.Parent = eventsFolder

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

-- ДОБАВЛЕНО: Геттер для размещения исследователей
function NetworkManager:getPlaceExplorerEvent()
	return self.placeExplorerEvent
end

return NetworkManager
