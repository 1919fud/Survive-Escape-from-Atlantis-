-- MapManager module
local MapManager = {}
MapManager.__index = MapManager

function MapManager.new()
	local self = setmetatable({}, MapManager)

	self.map = workspace:WaitForChild("Map")
	self.tilesTable = {}
	self.landTiles = {}

	return self
end

function MapManager:discoverTiles()
	-- Поиск тайлов по атрибуту Placetitle
	for _, obj in ipairs(self.map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local placeTile = obj:GetAttribute("Placetitle")
			if placeTile ~= nil then
				self.tilesTable[placeTile] = obj
			end
		end
	end
	print("🎯 Усього тайлів знайдено:", self:getTilesCount())
end

function MapManager:getTilesCount()
	local count = 0
	for _ in pairs(self.tilesTable) do
		count += 1
	end
	return count
end

function MapManager:generateLandTiles()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	-- Шаблоны
	local beachTemplate = ReplicatedStorage:WaitForChild("Beach")
	local forestTemplate = ReplicatedStorage:WaitForChild("Forest")
	local mountainTemplate = ReplicatedStorage:WaitForChild("Mountain")

	-- Список всех нужных суш
	local landTypes = {}

	for i = 1, 16 do
		table.insert(landTypes, "Beach")
	end
	for i = 1, 16 do
		table.insert(landTypes, "Forest")
	end
	for i = 1, 8 do
		table.insert(landTypes, "Mountain")
	end

	-- Перемешивание
	local function shuffle(tbl)
		for i = #tbl, 2, -1 do
			local j = math.random(i)
			tbl[i], tbl[j] = tbl[j], tbl[i]
		end
	end

	shuffle(landTypes)

	-- Создаем землю на тайлах
	local index = 1
	for placeTile, meshPart in pairs(self.tilesTable) do
		if index <= #landTypes then
			local landType = landTypes[index]
			index += 1

			local newLand = self:createLandTile(landType, meshPart, placeTile)
			if newLand then
				self.landTiles[placeTile] = {
					meshPart = newLand,
					type = landType,
					position = placeTile,
					isFlooded = false,
				}
			end
		end
	end

	print("🌍 Усього створено тайлів землі:", self:getLandTilesCount())
	return self.landTiles
end

function MapManager:getLandTilesCount()
	local count = 0
	for _ in pairs(self.landTiles) do
		count += 1
	end
	return count
end

function MapManager:createLandTile(landType, baseTile, position)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local template

	if landType == "Beach" then
		template = ReplicatedStorage:WaitForChild("Beach")
	elseif landType == "Forest" then
		template = ReplicatedStorage:WaitForChild("Forest")
	elseif landType == "Mountain" then
		template = ReplicatedStorage:WaitForChild("Mountain")
	end

	if not template then
		warn("❌ Не найден шаблон для:", landType)
		return nil
	end

	local newLand = template:Clone()
	newLand.Parent = self.map
	newLand.Name = landType .. "_Tile_" .. position

	-- Позиционируем над базовым тайлом
	local yOffset = newLand.Size.Y / 2 + baseTile.Size.Y / 2
	newLand.CFrame = baseTile.CFrame + Vector3.new(0, yOffset, 0)

	-- Добавляем атрибуты
	newLand:SetAttribute("TileType", landType)
	newLand:SetAttribute("TilePosition", position)

	--print("🌍 Поставив", landType, "на тайл", position)
	return newLand
end

function MapManager:getAllTiles()
	return self.landTiles
end

return MapManager
