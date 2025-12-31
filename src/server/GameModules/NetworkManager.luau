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

	self.selectExplorerEvent = Instance.new("RemoteEvent")
	self.selectExplorerEvent.Name = "SelectExplorerEvent"
	self.selectExplorerEvent.Parent = eventsFolder

	self.moveExplorerEvent = Instance.new("RemoteEvent")
	self.moveExplorerEvent.Name = "MoveExplorerEvent"
	self.moveExplorerEvent.Parent = eventsFolder

	self.highlightTilesEvent = Instance.new("RemoteEvent")
	self.highlightTilesEvent.Name = "HighlightTilesEvent"
	self.highlightTilesEvent.Parent = eventsFolder

	self.selectBoatEvent = Instance.new("RemoteEvent")
	self.selectBoatEvent.Name = "SelectBoatEvent"
	self.selectBoatEvent.Parent = eventsFolder

	self.moveBoatEvent = Instance.new("RemoteEvent")
	self.moveBoatEvent.Name = "MoveBoatEvent"
	self.moveBoatEvent.Parent = eventsFolder

	self.selectFloodTileEvent = Instance.new("RemoteEvent")
	self.selectFloodTileEvent.Name = "SelectFloodTileEvent"
	self.selectFloodTileEvent.Parent = eventsFolder

	self.confirmFloodEvent = Instance.new("RemoteEvent")
	self.confirmFloodEvent.Name = "ConfirmFloodEvent"
	self.confirmFloodEvent.Parent = eventsFolder

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

function NetworkManager:getSelectExplorerEvent()
	return self.selectExplorerEvent
end

function NetworkManager:getMoveExplorerEvent()
	return self.moveExplorerEvent
end

function NetworkManager:getHighlightTilesEvent()
	return self.highlightTilesEvent
end

function NetworkManager:getSelectBoatEvent()
	return self.selectBoatEvent
end

function NetworkManager:getMoveBoatEvent()
	return self.moveBoatEvent
end

function NetworkManager:getSelectFloodTileEvent()
	return self.selectFloodTileEvent
end

function NetworkManager:getConfirmFloodEvent()
	return self.confirmFloodEvent
end

return NetworkManager
