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

	-- Шаблони
	local _beachTemplate = ReplicatedStorage:WaitForChild("Beach")
	local _forestTemplate = ReplicatedStorage:WaitForChild("Forest")
	local _mountainTemplate = ReplicatedStorage:WaitForChild("Mountain")

	-- Список всех нужных суш
	local landTypes = {}
	--[[for _ = 1, 16 do
		table.insert(landTypes, "Beach")
	end]]
	--
	--[[for _ = 1, 16 do
		table.insert(landTypes, "Forest")
	end]]
	--
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

	-- Спеціальні властивості для кожного типу плитки
	local specialProperties = {
		Beach = {
			shark = 3, -- тільки 3 пляжі з акулою
			kaiju = 3, -- тільки 3 пляжі з кайджю
			boat = 1, -- тільки 1 пляж з човном
		},
		Forest = {
			shark = 3, -- тільки 3 ліси з акулою
			kaiju = 2, -- тільки 2 ліси з кайджю
			boat = 3, -- тільки 3 ліси з човном
			whirlpool = 2, -- тільки 2 ліси з водоверттю
		},
		Mountain = {
			whirlpool = 4, -- тільки 4 гори з водоверттю
			volcano = 4, -- тільки 4 гори з вулканом
		},
	}

	-- Лічильники для кожного типу властивості
	local propertyCounters = {
		Beach = { shark = 0, kaiju = 0, boat = 0 },
		Forest = { shark = 0, kaiju = 0, boat = 0, whirlpool = 0 },
		Mountain = { whirlpool = 0, volcano = 0 },
	}

	-- Создаем землю на спавн-тайлах
	local index = 1
	for placeTileNumber, spawnTile in pairs(self.tilesTable) do
		if index <= #landTypes then
			local landType = landTypes[index]
			index += 1

			-- Визначаємо, яку властивість отримає ця плитка
			local specialEffect = nil

			-- Отримуємо список доступних властивостей для цього типу
			local availableProperties = {}
			for property, maxCount in pairs(specialProperties[landType] or {}) do
				local currentCount = propertyCounters[landType][property] or 0
				if currentCount < maxCount then
					table.insert(availableProperties, property)
				end
			end

			-- Якщо є доступні властивості, вибираємо випадкову
			if #availableProperties > 0 then
				local randomIndex = math.random(1, #availableProperties)
				specialEffect = availableProperties[randomIndex]

				-- Збільшуємо лічильник для цієї властивості
				propertyCounters[landType][specialEffect] = (propertyCounters[landType][specialEffect] or 0) + 1
			end

			local newLand = self:createLandTile(landType, spawnTile, placeTileNumber, specialEffect)

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
						specialEffect = specialEffect, -- Зберігаємо спецефект
					}
				else
					warn("❌ Не найден водный тайл для спавна:", placeTileNumber)
				end
			end
		end
	end

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

function MapManager:createLandTile(landType, spawnTile, placeTileNumber, specialEffect)
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

		-- Додаємо атрибут спецефекту, якщо він є
		if specialEffect then
			newLand:SetAttribute("SpecialEffect", specialEffect)

			-- Додаємо додаткові атрибути залежно від ефекту
			if specialEffect == "volcano" then
				newLand:SetAttribute("IsVolcano", true)
				newLand:SetAttribute("VolcanoActive", false)
			elseif specialEffect == "shark" then
				newLand:SetAttribute("CanHaveShark", true)
			elseif specialEffect == "kaiju" then
				newLand:SetAttribute("CanHaveKaiju", true)
			elseif specialEffect == "boat" then
				newLand:SetAttribute("CanSpawnBoat", true)
			elseif specialEffect == "whirlpool" then
				newLand:SetAttribute("CanHaveWhirlpool", true)
			end
		else
			print(
				"🌍 Поставив",
				landType,
				"на спавн",
				placeTileNumber,
				"→ Q=",
				q,
				"R=",
				r,
				"Без ефекту"
			)
		end
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

	-- Преимущество отдается островам
	if self.landTiles[coordKey] then
		local tile = self.landTiles[coordKey]
		tile.isWater = false
		tile.isLand = true
		tile.tileType = tile.type or "Land"

		-- ПЕРЕВІРКА НА АКТИВНИЙ ВУЛКАН
		if tile.meshPart then
			local isVolcano = tile.meshPart:GetAttribute("IsVolcano")
			local isVolcanoActive = tile.meshPart:GetAttribute("VolcanoActive")
			local isBlocked = tile.meshPart:GetAttribute("IsBlocked")

			tile.isVolcano = (isVolcano == true)
			tile.isVolcanoActive = (isVolcanoActive == true)
			tile.isBlocked = (isBlocked == true or isVolcanoActive == true)

			if tile.isVolcanoActive then
				tile.tileType = "Volcano"
				print("🌋 Тайл Q=", q, "R=", r, "є АКТИВНИМ вулканом - заблоковано!")
			elseif tile.isVolcano and not tile.isVolcanoActive then
				tile.tileType = "Mountain (with Volcano)"
				print("⛰️ Тайл Q=", q, "R=", r, "є горою з вулканом (не активний)")
			end
		else
			tile.isVolcano = false
			tile.isVolcanoActive = false
			tile.isBlocked = false
		end

		return tile
	elseif self.waterTiles[coordKey] then
		local waterTile = {
			meshPart = self.waterTiles[coordKey],
			type = "Water",
			q = q,
			r = r,
			coordKey = coordKey,
			isWater = true,
			isLand = false,
			tileType = "Water",
			isVolcano = false,
			isVolcanoActive = false,
			isBlocked = false,
		}

		-- Перевіряємо водний тайл на активний вулкан
		local meshPart = self.waterTiles[coordKey]
		if meshPart then
			local isVolcanoActive = meshPart:GetAttribute("VolcanoActive")
			if isVolcanoActive == true then
				waterTile.isVolcanoActive = true
				waterTile.isBlocked = true
				waterTile.tileType = "Volcano (Water)"
				print(
					"🌋 Водний тайл Q=",
					q,
					"R=",
					r,
					"є активним вулканом - заблоковано!"
				)
			end
		end

		return waterTile
	end

	return nil
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

		-- Ищем тайл
		local neighborTile = self:getTileAtPosition(nq, nr)

		if neighborTile then
			print("  ✅ Знайдено сусіда! Тип:", neighborTile.tileType or "Unknown")
			table.insert(neighbors, {
				q = nq,
				r = nr,
				coordKey = coordKey,
				tile = neighborTile,
				isWater = neighborTile.isWater or false,
				isLand = neighborTile.isLand or true,
				tileType = neighborTile.tileType or "Unknown",
			})
		end
	end

	print("📍 [СЕРВЕР] Знайдено сусідів:", #neighbors)

	-- Дополнительная информация о найденных соседях
	for _, neighbor in ipairs(neighbors) do
		if neighbor.isWater then
			print("    💧 Q=", neighbor.q, "R=", neighbor.r, "- Вода")
		else
			print("    🌍 Q=", neighbor.q, "R=", neighbor.r, "-", neighbor.tileType)
		end
	end

	return neighbors
end

return MapManager
