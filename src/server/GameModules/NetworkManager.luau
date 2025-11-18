-- NetworkManager.lua (ModuleScript в Server/GameModules/)
local NetworkManager = {}
NetworkManager.__index = NetworkManager

function NetworkManager.new()
	local self = setmetatable({}, NetworkManager)

	local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

	-- Событие для размещения исследователей
	self.placeExplorerEvent = Instance.new("RemoteEvent")
	self.placeExplorerEvent.Name = "PlaceExplorerEvent"
	self.placeExplorerEvent.Parent = eventsFolder

	self.placeBoatEvent = Instance.new("RemoteEvent")
	self.placeBoatEvent.Name = "PlaceBoatEvent"
	self.placeBoatEvent.Parent = eventsFolder

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

function NetworkManager:getPlaceExplorerEvent()
	return self.placeExplorerEvent
end

function NetworkManager:getPlaceBoatEvent()
	return self.placeBoatEvent
end

return NetworkManager
