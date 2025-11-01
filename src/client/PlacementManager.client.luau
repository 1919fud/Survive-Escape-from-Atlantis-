-- PlacementManager.lua (LocalScript в StarterPlayerScripts/Client/)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- Ждем UI выбора
local explorerSelector = PlayerGui:WaitForChild("ExplorerSelector")

-- RemoteEvents для связи с сервером
local GameEvents = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents")
local PlaceExplorerEvent = Instance.new("RemoteEvent")
PlaceExplorerEvent.Name = "PlaceExplorerEvent"
PlaceExplorerEvent.Parent = GameEvents

-- Переменные
local isPlacingMode = false
local currentHoverTile = nil

-- Функция для определения тайла под курсором
local function getTileUnderCursor()
	local mouse = player:GetMouse()
	local target = mouse.Target

	if target and target:GetAttribute("IsLand") then
		return target
	end

	return nil
end

-- Подсветка тайла при наведении
local function highlightTile(tile, highlight)
	if tile then
		if highlight then
			tile.BrickColor = BrickColor.new("Bright green")
		else
			-- Возвращаем оригинальный цвет в зависимости от типа
			local tileType = tile:GetAttribute("TileType")
			if tileType == "Beach" then
				tile.BrickColor = BrickColor.new("Bright yellow")
			elseif tileType == "Forest" then
				tile.BrickColor = BrickColor.new("Dark green")
			elseif tileType == "Mountain" then
				tile.BrickColor = BrickColor.new("Medium stone grey")
			end
		end
	end
end

-- Обработчик клика по тайлу
local function onTileClick(tile)
	if not isPlacingMode then
		return
	end

	local selectedTreasure = explorerSelector:getSelectedTreasure()
	if not selectedTreasure then
		print("⚠️ Сначала выберите значение сокровищ!")
		return
	end

	local tileType = tile:GetAttribute("TileType")
	local tilePosition = tile:GetAttribute("TilePosition")

	print(
		"📍 Размещение исследователя на",
		tileType,
		"тайл",
		tilePosition,
		"с сокровищами:",
		selectedTreasure
	)

	-- Отправляем на сервер
	PlaceExplorerEvent:FireServer(selectedTreasure, tilePosition, tileType)

	-- Сбрасываем выбор
	explorerSelector:resetSelection()
end

-- Основной цикл для отслеживания мыши
RunService.Heartbeat:Connect(function()
	if not isPlacingMode then
		return
	end

	local tile = getTileUnderCursor()

	-- Обновляем подсветку
	if tile ~= currentHoverTile then
		if currentHoverTile then
			highlightTile(currentHoverTile, false)
		end
		currentHoverTile = tile
		if currentHoverTile then
			highlightTile(currentHoverTile, true)
		end
	end
end)

-- Обработчик клика мыши
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local tile = getTileUnderCursor()
		if tile and isPlacingMode then
			onTileClick(tile)
		end
	end
end)

-- Функции управления режимом размещения
local PlacementManager = {}

function PlacementManager:startPlacingMode()
	isPlacingMode = true
	explorerSelector:setVisible(true)
	print("🎯 Режим размещения исследователей активирован")
end

function PlacementManager:stopPlacingMode()
	isPlacingMode = false
	explorerSelector:setVisible(false)

	-- Сбрасываем подсветку
	if currentHoverTile then
		highlightTile(currentHoverTile, false)
		currentHoverTile = nil
	end

	print("🎯 Режим размещения исследователей деактивирован")
end

function PlacementManager:isPlacingMode()
	return isPlacingMode
end

print("✅ Менеджер размещения загружен")

return PlacementManager
