-- MapManager module
local MapManager = {}
MapManager.__index = MapManager

function MapManager.new()
	local self = setmetatable({}, MapManager)

	self.map = workspace:WaitForChild("Map")
	self.tilesTable = {} -- Таблица для мест с Placetitle
	self.waterTiles = {} -- Таблица водных тайлов с Q R
	self.landTiles = {} -- Готовые тайлы с землей

	return self
end

function MapManager:discoverTiles()
	-- Сначала находим ВСЕ водные тайлы с Q R
	for _, obj in ipairs(self.map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local q = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local r = obj:GetAttribute("R") or obj:GetAttribute("r")

			if q ~= nil and r ~= nil then
				local coordKey = self:getCoordKey(q, r)
				self.waterTiles[coordKey] = obj
				--print("🌊 Найден водный тайл: Q=", q, "R=", r)
			end
		end
	end

	-- Теперь находим места для спавна с Placetitle
	for _, obj in ipairs(self.map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local placeTile = obj:GetAttribute("Placetitle")
			if placeTile ~= nil then
				self.tilesTable[placeTile] = obj
				--print("📍 Найден спавн-тайл: Placetitle=", placeTile)
			end
		end
	end

	print("🎯 Усього водних тайлів з Q,R:", self:getWaterTilesCount())
	print("🎯 Усього спавн-тайлів з Placetitle:", self:getTilesCount())
end

function MapManager:getCoordKey(q, r)
	return string.format("%d,%d", q, r)
end

function MapManager:getTilesCount()
	local count = 0
	for _ in pairs(self.tilesTable) do
		count += 1
	end
	return count
end

function MapManager:getWaterTilesCount()
	local count = 0
	for _ in pairs(self.waterTiles) do
		count += 1
	end
	return count
end

function MapManager:generateLandTiles()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	-- Шаблоны
	local _beachTemplate = ReplicatedStorage:WaitForChild("Beach")
	local _forestTemplate = ReplicatedStorage:WaitForChild("Forest")
	local _mountainTemplate = ReplicatedStorage:WaitForChild("Mountain")

	-- Список всех нужных суш
	local landTypes = {}

	for _ = 1, 16 do
		table.insert(landTypes, "Beach")
	end
	for _ = 1, 16 do
		table.insert(landTypes, "Forest")
	end
	for _ = 1, 8 do
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

	-- Создаем землю на спавн-тайлах
	local index = 1
	for placeTileNumber, spawnTile in pairs(self.tilesTable) do
		if index <= #landTypes then
			local landType = landTypes[index]
			index += 1

			local newLand = self:createLandTile(landType, spawnTile, placeTileNumber)
			if newLand then
				-- Находим ближайший водный тайл и копируем его Q R
				local waterTile = self:findNearestWaterTile(spawnTile.Position)
				if waterTile then
					local q = waterTile:GetAttribute("Q") or waterTile:GetAttribute("q")
					local r = waterTile:GetAttribute("R") or waterTile:GetAttribute("r")
					local coordKey = self:getCoordKey(q, r)

					self.landTiles[coordKey] = {
						meshPart = newLand,
						type = landType,
						q = q,
						r = r,
						coordKey = coordKey,
						spawnPosition = placeTileNumber,
						isFlooded = false,
					}
				else
					warn("❌ Не найден водный тайл для спавна:", placeTileNumber)
				end
			end
		end
	end

	--print("🌍 Усього створено тайлів землі:", self:getLandTilesCount())
	return self.landTiles
end

function MapManager:findNearestWaterTile(position)
	local nearestTile = nil
	local nearestDistance = math.huge

	for _, waterTile in pairs(self.waterTiles) do
		local distance = (waterTile.Position - position).Magnitude
		if distance < nearestDistance then
			nearestDistance = distance
			nearestTile = waterTile
		end
	end

	return nearestTile
end

function MapManager:getLandTilesCount()
	local count = 0
	for _ in pairs(self.landTiles) do
		count += 1
	end
	return count
end

function MapManager:createLandTile(landType, spawnTile, placeTileNumber)
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
	newLand.Name = landType .. "_Spawn_" .. placeTileNumber

	-- Позиционируем над спавн-тайлом
	local yOffset = newLand.Size.Y / 2 + spawnTile.Size.Y / 2
	newLand.CFrame = spawnTile.CFrame + Vector3.new(0, yOffset, 0)

	-- Находим ближайший водный тайл и копируем его Q R
	local waterTile = self:findNearestWaterTile(spawnTile.Position)
	if waterTile then
		local q = waterTile:GetAttribute("Q") or waterTile:GetAttribute("q")
		local r = waterTile:GetAttribute("R") or waterTile:GetAttribute("r")

		newLand:SetAttribute("TileType", landType)
		newLand:SetAttribute("Q", q)
		newLand:SetAttribute("R", r)
		newLand:SetAttribute("Placetitle", placeTileNumber)
		newLand:SetAttribute("IsLand", true)

		--print("🌍 Поставив", landType, "на спавн", placeTileNumber, "→ Q=", q, "R=", r)
	else
		warn("❌ Не удалось найти Q,R для спавна:", placeTileNumber)
	end

	return newLand
end

function MapManager:getAllTiles()
	return self.landTiles
end

function MapManager:getTileAtPosition(q, r)
	local coordKey = self:getCoordKey(q, r)
	return self.landTiles[coordKey]
end

function MapManager:getNeighbors(q, r)
	print("🗺️ [СЕРВЕР] Пошук сусідів для Q=", q, "R=", r)

	local directions = {
		{ 1, 0 },
		{ 1, -1 },
		{ 0, -1 },
		{ -1, 0 },
		{ -1, 1 },
		{ 0, 1 },
	}

	local neighbors = {}

	for _, dir in ipairs(directions) do
		local nq = q + dir[1]
		local nr = r + dir[2]
		local coordKey = self:getCoordKey(nq, nr)

		print("  🔍 Перевіряємо координати: Q=", nq, "R=", nr, "Ключ:", coordKey)

		if self.landTiles[coordKey] then
			print("  ✅ Знайдено сусіда!")
			table.insert(neighbors, {
				q = nq,
				r = nr,
				coordKey = coordKey,
				tile = self.landTiles[coordKey],
			})
		end
	end

	print("📍 [СЕРВЕР] Знайдено сусідів:", #neighbors)
	return neighbors
end

return MapManager
