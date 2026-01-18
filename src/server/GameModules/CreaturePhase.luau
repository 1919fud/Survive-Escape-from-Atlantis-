-- CreaturePhase.lua (Server/GameModules/)
local CreaturePhase = {}
CreaturePhase.__index = CreaturePhase

function CreaturePhase.new()
	local self = setmetatable({}, CreaturePhase)
	self.isActive = false
	self.mainGame = nil
	self.networkManager = nil
	self.currentPlayer = nil
	self.creatureTypes = { "Shark", "Kaiju", "Octopus" }
	self.rolledCreature = nil
	return self
end

function CreaturePhase:start(player, mainGame)
	self.mainGame = mainGame
	self.networkManager = mainGame.networkManager

	if not player then
		player = self.mainGame.turnManager.currentPlayer
	end

	self.currentPlayer = player
	self.isActive = true

	self:syncCreatureAttributes()

	print("* Початок ФАЗИ ІСТОТ для гравця:", player.Name)

	local rollIndex = math.random(1, 3)
	self.rolledCreature = self.creatureTypes[rollIndex]

	print("* Випало на кубику:", self.rolledCreature)

	local creaturesCount = self:countCreaturesOnBoard(self.rolledCreature)

	self.networkManager:getGameStartEvent():FireAllClients({
		phase = "creature_phase_start",
		rolledCreature = self.rolledCreature,
		currentPlayer = player.Name,
		creaturesCount = creaturesCount,
		message = "Фаза істот: " .. self:getCreatureNameUa(self.rolledCreature),
	})

	if creaturesCount == 0 then
		print("* Істот типу " .. self.rolledCreature .. " немає. Пропуск.")
		task.wait(3)
		self:endPhase()
	else
		print("* Очікуємо хід гравця істотою... (Знайдено: " .. creaturesCount .. ")")
	end
end

function CreaturePhase:syncCreatureAttributes()
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsShark") and not obj:GetAttribute("CreatureType") then
			obj:SetAttribute("CreatureType", "Shark")
		elseif obj:GetAttribute("IsKaiju") and not obj:GetAttribute("CreatureType") then
			obj:SetAttribute("CreatureType", "Kaiju")
		elseif obj:GetAttribute("IsOctopus") and not obj:GetAttribute("CreatureType") then
			obj:SetAttribute("CreatureType", "Octopus")
		end
	end
end

function CreaturePhase:handleCreatureMove(player, creatureModel, q, r)
	if not self.isActive or player ~= self.currentPlayer then
		return
	end

	-- 1. СИНХРОНИЗАЦИЯ
	local cType = creatureModel:GetAttribute("CreatureType")
	if not cType then
		if creatureModel:GetAttribute("IsShark") then
			cType = "Shark"
		end
		if creatureModel:GetAttribute("IsKaiju") then
			cType = "Kaiju"
		end
		if creatureModel:GetAttribute("IsOctopus") then
			cType = "Octopus"
		end
		if cType then
			creatureModel:SetAttribute("CreatureType", cType)
		else
			return
		end
	end

	if cType ~= self.rolledCreature then
		warn("❌ Гравець намагається походити не тією істотою!")
		return
	end

	local success = false

	if cType == "Shark" then
		-- Проверяем ход напрямую в moveShark
		success = self:moveShark(creatureModel, q, r)
	elseif cType == "Kaiju" then
		success = self:moveKaiju(creatureModel, q, r)
	elseif cType == "Octopus" then
		success = self:moveOctopus(creatureModel, q, r)
	end

	if success then
		self:endPhase()
	end
end

-- === ЛОГІКА АКУЛИ (ОНОВЛЕНО ЯК У ВУЛКАНА) ===
function CreaturePhase:moveShark(shark, q, r)
	local startQ = shark:GetAttribute("Q")
	local startR = shark:GetAttribute("R")

	-- Акула может ходить на 1-2 клетки
	local distance = self:getHexDistance(startQ, startR, q, r)
	if distance > 2 or distance < 1 then
		print("❌ Акула може рухатися лише на 1-2 ділянки")
		return false
	end

	-- Получаем тайл
	local tile = self.mainGame.mapManager:getTileAtPosition(q, r)
	if not tile then
		print("❌ Тайл не існує")
		return false
	end

	-- Проверяем, что это водный тайл
	if not tile.isWater then
		print("❌ Акула може рухатися тільки на водні ділянки")
		return false
	end

	-- Проверяем, что сверху нет острова на ЦЕЛЕВОМ тайле
	if self:hasLandAboveWater(q, r) then
		print("❌ На цьому водному тайлі є острів!")
		return false
	end

	-- Проверяем, нет ли на этом тайле другой акулы
	local otherShark = self:getCreatureAt(q, r, "Shark")
	if otherShark and otherShark ~= shark then
		print("❌ На цьому тайлі вже є акула!")
		return false
	end

	-- ДОДАНО: Проверяем доступные пути (особенно для дистанции 2)
	local isValidMove = false

	if distance == 1 then
		-- Для дистанции 1 не нужны промежуточные проверки
		isValidMove = true
	elseif distance == 2 then
		-- Для дистанции 2 ищем хотя бы один доступный путь
		local directions = {
			{ 1, 0 },
			{ 1, -1 },
			{ 0, -1 },
			{ -1, 0 },
			{ -1, 1 },
			{ 0, 1 },
		}

		-- Проверяем все возможные промежуточные точки
		for _, dir1 in ipairs(directions) do
			local midQ = startQ + dir1[1]
			local midR = startR + dir1[2]

			-- Проверяем, что это соседняя клетка от старта
			if self:getHexDistance(startQ, startR, midQ, midR) == 1 then
				-- Проверяем, что это также соседняя клетка от цели
				if self:getHexDistance(midQ, midR, q, r) == 1 then
					-- Проверяем, что промежуточная клетка - вода без острова
					local interTile = self.mainGame.mapManager:getTileAtPosition(midQ, midR)

					if interTile and interTile.isWater then
						if not self:hasLandAboveWater(midQ, midR) then
							-- Нашли доступный путь!
							print(
								"✅ Знайдено доступний шлях через Q="
									.. midQ
									.. " R="
									.. midR
							)
							isValidMove = true
							break
						end
					end
				end
			end
		end

		if not isValidMove then
			print("❌ Не знайдено доступного шляху для акули")
			return false
		end
	end

	-- Перемещаем акулу
	self:updateCreaturePosition(shark, q, r)

	-- Логика поедания исследователей
	local eatenCount = 0

	-- 1. Получаем исследователей на этом тайле
	local explorersData = self.mainGame:getExplorersOnTile(q, r)
	for _, exp in ipairs(explorersData) do
		if not exp.isOnBoat then
			print("🦈 Акула їсть (дані) ID:", exp.explorerId)

			-- 2. Удаляем из данных MainGame
			self.mainGame:removeExplorer(exp.explorerId, exp.playerName)

			-- 3. Удаляем визуальный объект
			if exp.model then
				exp.model:Destroy()
			end

			-- 4. Уведомляем клиентов
			self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
				type = "explorer_removed_by_effect",
				explorerId = exp.explorerId,
				reason = "shark",
			})

			eatenCount = eatenCount + 1
		end
	end

	-- 5. Дополнительно очищаем другие визуальные объекты
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") then
			local objQ = obj:GetAttribute("Q")
			local objR = obj:GetAttribute("R")
			local isOnBoat = obj:GetAttribute("OnBoat") == true

			if objQ == q and objR == r and not isOnBoat then
				print("🦈 Акула знищує візуальний об'єкт", obj.Name)
				obj:Destroy()
			end
		end
	end

	if eatenCount > 0 then
		self.networkManager:getGameStartEvent():FireAllClients({
			phase = "creature_action",
			message = "🦈 Акула з'їла " .. eatenCount .. " плавців!",
		})
	end

	return true
end

-- === ЛОГІКА ВОСЬМИНОГА (ОНОВЛЕНО ЯК У ВУЛКАНА) ===
function CreaturePhase:moveOctopus(octopus, q, r)
	local startQ = octopus:GetAttribute("Q")
	local startR = octopus:GetAttribute("R")

	local distance = self:getHexDistance(startQ, startR, q, r)
	if distance ~= 1 then
		print("❌ Восьминіг може рухатися лише на 1 ділянку")
		return false
	end

	local tile = self.mainGame.mapManager:getTileAtPosition(q, r)
	if not tile or not (tile.isWater or tile.meshPart:GetAttribute("IsWater")) then
		print("❌ Восьминіг може рухатися тільки на водні ділянки")
		return false
	end

	self:updateCreaturePosition(octopus, q, r)

	-- 1. Знищуємо човен
	local boat = self.mainGame:getBoatAtPosition(q, r)
	if boat then
		print("🐙 Восьминіг знищив човен!")
		self.mainGame:removeBoat(boat)
	end

	local eatenCount = 0

	-- 2. Отримуємо всіх дослідників на тайлі
	local explorersData = self.mainGame:getExplorersOnTile(q, r)
	for _, exp in ipairs(explorersData) do
		print("🐙 Восьминіг їсть (дані) ID:", exp.explorerId)

		-- Видаляємо з MainGame даних
		self.mainGame:removeExplorer(exp.explorerId, exp.playerName)

		-- Видаляємо візуал
		if exp.model then
			exp.model:Destroy()
		end

		self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
			type = "explorer_removed_by_effect",
			explorerId = exp.explorerId,
			reason = "octopus",
		})
		eatenCount = eatenCount + 1
	end

	-- 3. Додаткова очистка візуальних об'єктів
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") then
			local objQ = obj:GetAttribute("Q")
			local objR = obj:GetAttribute("R")
			if objQ == q and objR == r then
				print("🐙 Восьминіг знищує візуальний об'єкт", obj.Name)
				obj:Destroy()
			end
		end
	end

	if eatenCount > 0 then
		self.networkManager:getGameStartEvent():FireAllClients({
			phase = "creature_action",
			message = "🐙 Восьминіг знищив " .. eatenCount .. " дослідників!",
		})
	end

	return true
end

-- === ЛОГІКА КАЙДЗЮ ===
function CreaturePhase:moveKaiju(kaiju, q, r)
	local startQ = kaiju:GetAttribute("Q")
	local startR = kaiju:GetAttribute("R")

	print("🦖 Спроба ходу кайдзю з Q=" .. startQ .. " R=" .. startR .. " на Q=" .. q .. " R=" .. r)

	-- Кайдзю может ходить на 1-2 клетки
	local distance = self:getHexDistance(startQ, startR, q, r)
	print("📏 Дистанція: " .. distance)

	if distance > 2 or distance < 1 then
		print("❌ Кайдзю може рухатися лише на 1-2 ділянки")
		return false
	end

	-- Получаем тайл
	local tile = self.mainGame.mapManager:getTileAtPosition(q, r)
	if not tile then
		print("❌ Тайл не існує")
		return false
	end

	print(
		"📊 Цільовий тайл: isWater="
			.. tostring(tile.isWater)
			.. ", isVolcanoActive="
			.. tostring(tile.isVolcanoActive)
	)

	-- Кайдзю НЕ может ходить на активный вулкан
	if tile.isVolcanoActive and tile.isBlocked then
		print("❌ Кайдзю не може ходити на активний вулкан!")
		return false
	end

	-- Проверяем, нет ли на этом тайле другого кайдзю (кроме себя)
	local otherKaiju = self:getCreatureAt(q, r, "Kaiju")
	if otherKaiju and otherKaiju ~= kaiju then
		print("❌ На цьому тайлі вже є кайдзю! Витісняємо...")
		-- Витісняємо іншого кайдзю
		self:pushCreatureToNeighbor(otherKaiju, q, r)
	end

	-- ДОДАНО: Проверяем доступные пути (особенно для дистанции 2)
	local isValidMove = false

	if distance == 1 then
		-- Для дистанции 1 не нужны промежуточные проверки
		isValidMove = true
	elseif distance == 2 then
		-- Для дистанции 2 ищем хотя бы один доступный путь
		local directions = {
			{ 1, 0 },
			{ 1, -1 },
			{ 0, -1 },
			{ -1, 0 },
			{ -1, 1 },
			{ 0, 1 },
		}

		-- Проверяем все возможные промежуточные точки
		for _, dir1 in ipairs(directions) do
			local midQ = startQ + dir1[1]
			local midR = startR + dir1[2]

			-- Проверяем, что это соседняя клетка от старта
			if self:getHexDistance(startQ, startR, midQ, midR) == 1 then
				-- Проверяем, что это также соседняя клетка от цели
				if self:getHexDistance(midQ, midR, q, r) == 1 then
					-- Проверяем, что промежуточная клетка не активный вулкан
					local interTile = self.mainGame.mapManager:getTileAtPosition(midQ, midR)

					if interTile and not (interTile.isVolcanoActive and interTile.isBlocked) then
						-- Нашли доступный путь!
						print("✅ Знайдено доступний шлях через Q=" .. midQ .. " R=" .. midR)
						isValidMove = true
						break
					else
						print(
							"❌ Проміжний тайл Q="
								.. midQ
								.. " R="
								.. midR
								.. " - активний вулкан або не існує"
						)
					end
				end
			end
		end

		if not isValidMove then
			print("❌ Не знайдено доступного шляху для кайдзю")
			return false
		end
	end

	-- Перемещаем кайдзю
	self:updateCreaturePosition(kaiju, q, r)

	-- Знищує човни
	local boat = self.mainGame:getBoatAtPosition(q, r)
	if boat then
		print("🦖 Кайдзю розтрощив човен #" .. (boat:GetAttribute("BoatId") or "?"))
		self.mainGame:removeBoat(boat)
	end

	-- Відштовхує шукачів
	local explorers = self.mainGame:getExplorersOnTile(q, r)
	print("🔍 Знайдено дослідників на тайлі: " .. #explorers)

	for _, exp in ipairs(explorers) do
		-- Создаем правильный объект исследователя для функции pushExplorerToNeighbor
		local explorerObj = {
			explorerId = exp.explorerId,
			playerName = exp.playerName,
			q = exp.q or q,
			r = exp.r or r,
		}
		self:pushExplorerToNeighbor(explorerObj, q, r)
	end

	-- Витісняє інших монстрів
	local shark = self:getCreatureAt(q, r, "Shark")
	if shark then
		print("🦖 Витісняє акулу з Q=" .. q .. " R=" .. r)
		self:pushCreatureToNeighbor(shark, q, r)
	end

	local octopus = self:getCreatureAt(q, r, "Octopus")
	if octopus then
		print("🦖 Витісняє восьминога з Q=" .. q .. " R=" .. r)
		self:pushCreatureToNeighbor(octopus, q, r)
	end

	-- Додаємо ефект для кайдзю (можна додати анімацію чи звук)
	self.networkManager:getGameStartEvent():FireAllClients({
		phase = "creature_action",
		message = "🦖 Кайдзю пройшов! Знищено човенів: " .. (boat and 1 or 0),
	})

	return true
end

function CreaturePhase:getAvailableKaijuMoves(kaiju)
	local availableMoves = {}
	local q = kaiju:GetAttribute("Q")
	local r = kaiju:GetAttribute("R")

	-- Получаем все тайлы на карте
	local allTiles = self.mainGame.mapManager:getAllTiles()

	for _, tileData in pairs(allTiles) do
		local distance = self:getHexDistance(q, r, tileData.q, tileData.r)

		-- Проверяем дистанцию (1-2 клетки)
		if distance >= 1 and distance <= 2 then
			-- Не может ходить на активный вулкан
			if not (tileData.isVolcanoActive and tileData.isBlocked) then
				-- Проверяем, нет ли другого кайдзю на этом тайле (кроме себя)
				local otherKaiju = self:getCreatureAt(tileData.q, tileData.r, "Kaiju")
				if not otherKaiju or (tileData.q == q and tileData.r == r) then
					-- Если дистанция = 2, проверяем промежуточную клетку
					local isValid = true

					if distance == 2 then
						local intermediate = self:getIntermediateHex(q, r, tileData.q, tileData.r)

						if intermediate then
							-- Промежуточная клетка не должна быть активным вулканом
							local interTile = self.mainGame.mapManager:getTileAtPosition(intermediate.q, intermediate.r)
							if not interTile or (interTile.isVolcanoActive and interTile.isBlocked) then
								isValid = false
							end
						else
							isValid = false
						end
					end

					if isValid then
						table.insert(availableMoves, {
							q = tileData.q,
							r = tileData.r,
							distance = distance,
							isWater = tileData.isWater,
							isLand = not tileData.isWater,
							isVolcano = tileData.isVolcano,
							isVolcanoActive = tileData.isVolcanoActive,
						})
					end
				end
			end
		end
	end

	return availableMoves
end

function CreaturePhase:getHexDistance(q1, r1, q2, r2)
	local dx = q2 - q1
	local dy = r2 - r1
	return (math.abs(dx) + math.abs(dy) + math.abs(dx + dy)) / 2
end

function CreaturePhase:getIntermediateHex(q1, r1, q2, r2)
	-- Знаходимо проміжний гекс (округлення до найближчого)
	local midQ = math.floor((q1 + q2) / 2 + 0.5)
	local midR = math.floor((r1 + r2) / 2 + 0.5)

	-- Перевіряємо, чи це дійсно проміжний гекс
	local dist1 = self:getHexDistance(q1, r1, midQ, midR)
	local dist2 = self:getHexDistance(midQ, midR, q2, r2)

	if dist1 == 1 and dist2 == 1 then
		return { q = midQ, r = midR }
	end

	return nil
end

function CreaturePhase:getAvailableTilesForCreature(creature, maxDistance)
	local availableTiles = {}
	local q = creature.q or creature:GetAttribute("Q")
	local r = creature.r or creature:GetAttribute("R")
	local cType = creature.type or creature:GetAttribute("CreatureType")

	-- Отримуємо всі тайли
	local allTiles = self.mainGame.mapManager:getAllTiles()
	local waterTiles = self.mainGame.mapManager.waterTiles

	for coordKey, tileData in pairs(allTiles) do
		local distance = self:getHexDistance(q, r, tileData.q, tileData.r)

		-- Перевіряємо діапазон
		if distance >= 1 and distance <= maxDistance then
			local isValid = false

			if cType == "Shark" then
				-- Акула: тільки вода, і не затоплена земля
				if tileData.isWater and not tileData.isFlooded then
					-- Перевіряємо проміжні ділянки (якщо distance = 2)
					if distance == 2 then
						local intermediate = self:getIntermediateHex(q, r, tileData.q, tileData.r)
						if intermediate then
							local interTile = self.mainGame.mapManager:getTileAtPosition(intermediate.q, intermediate.r)
							if interTile and interTile.isWater and not interTile.isFlooded then
								isValid = true
							end
						end
					else
						isValid = true
					end
				end
			elseif cType == "Kaiju" then
				-- Кайдзю: може на землю та воду
				-- Не може на активний вулкан
				if not (tileData.isVolcanoActive and tileData.isBlocked) then
					-- Перевіряємо, чи немає там іншого кайдзю (крім себе)
					if not self:hasKaijuOnTile(tileData.q, tileData.r) or (tileData.q == q and tileData.r == r) then
						-- Перевіряємо проміжні ділянки
						if distance == 2 then
							local intermediate = self:getIntermediateHex(q, r, tileData.q, tileData.r)
							if intermediate then
								local interTile =
									self.mainGame.mapManager:getTileAtPosition(intermediate.q, intermediate.r)
								if interTile and not (interTile.isVolcanoActive and interTile.isBlocked) then
									isValid = true
								end
							end
						else
							isValid = true
						end
					end
				end
			elseif cType == "Octopus" then
				-- Восьминіг: тільки вода, 1 крок
				if tileData.isWater and not tileData.isFlooded and distance == 1 then
					isValid = true
				end
			end

			if isValid then
				table.insert(availableTiles, {
					q = tileData.q,
					r = tileData.r,
					distance = distance,
					tileType = tileData.type or "Unknown",
					isWater = tileData.isWater,
				})
			end
		end
	end

	return availableTiles
end

function CreaturePhase:hasLandAboveWater(q, r)
	-- Получаем тайл через MapManager
	local tile = self.mainGame.mapManager:getTileAtPosition(q, r)

	if not tile then
		return false
	end

	-- Если tile.isWater == false, значит это земля
	if not tile.isWater then
		return true
	end

	-- Дополнительная проверка через атрибуты meshPart
	if tile.meshPart then
		local isLand = tile.meshPart:GetAttribute("IsLand")
		if isLand == true then
			return true
		end
	end

	return false
end

function CreaturePhase:getAvailableSharkMoves(shark)
	local availableMoves = {}
	local q = shark:GetAttribute("Q")
	local r = shark:GetAttribute("R")

	-- Получаем все тайлы на карте
	local allTiles = self.mainGame.mapManager:getAllTiles()

	for _, tileData in pairs(allTiles) do
		local distance = self:getHexDistance(q, r, tileData.q, tileData.r)

		-- Проверяем дистанцию (1-2 клетки)
		if distance >= 1 and distance <= 2 then
			-- Должен быть водным тайлом
			if tileData.isWater then
				-- Проверяем, нет ли сверху острова
				if not self:hasLandAboveWater(tileData.q, tileData.r) then
					-- Проверяем, нет ли другой акулы
					local otherShark = self:getCreatureAt(tileData.q, tileData.r, "Shark")
					if not otherShark then
						-- Если дистанция = 2, проверяем промежуточную клетку
						local isValid = true

						if distance == 2 then
							local intermediate = self:getIntermediateHex(q, r, tileData.q, tileData.r)
							if intermediate then
								-- Промежуточная клетка должна быть водой без острова
								local interTile =
									self.mainGame.mapManager:getTileAtPosition(intermediate.q, intermediate.r)
								if not interTile or not interTile.isWater then
									isValid = false
								elseif self:hasLandAboveWater(intermediate.q, intermediate.r) then
									isValid = false
								end
							else
								isValid = false
							end
						end

						if isValid then
							table.insert(availableMoves, {
								q = tileData.q,
								r = tileData.r,
								distance = distance,
								tileType = "water",
								isWater = true,
							})
						end
					end
				end
			end
		end
	end

	return availableMoves
end

function CreaturePhase:hasLandBetween(q1, r1, q2, r2)
	local distance = self:getHexDistance(q1, r1, q2, r2)

	if distance ~= 2 then
		return false -- Тільки для дистанції 2
	end

	-- Знаходимо проміжний гекс
	local intermediate = self:getIntermediateHex(q1, r1, q2, r2)
	if not intermediate then
		return false
	end

	-- Перевіряємо, чи це земля
	local tile = self.mainGame.mapManager:getTileAtPosition(intermediate.q, intermediate.r)
	if tile and not tile.isWater then
		return true -- Це острів на шляху!
	end

	return false
end

function CreaturePhase:pushExplorerToNeighbor(explorerObj, currentQ, currentR)
	local neighbors = self.mainGame.mapManager:getNeighbors(currentQ, currentR)
	local validTargets = {}

	-- Собираем все доступные соседние клетки
	for _, neighbor in ipairs(neighbors) do
		local tile = self.mainGame.mapManager:getTileAtPosition(neighbor.q, neighbor.r)
		if tile then
			-- Проверяем, что клетка существует и доступна
			table.insert(validTargets, neighbor)
		end
	end

	if #validTargets > 0 then
		-- Выбираем случайную соседнюю клетку
		local target = validTargets[math.random(1, #validTargets)]

		print("🦖 Кайдзю відштовхує дослідника до Q=" .. target.q .. " R=" .. target.r)

		-- ВИПРАВЛЕНО: Находим исследователя в данных игрока и обновляем его позицию
		local explorerFound = false

		-- Ищем исследователя во всех данных игроков
		for player, playerData in pairs(self.mainGame.players) do
			if playerData.explorers then
				for _, explorer in ipairs(playerData.explorers) do
					-- Проверяем, что это тот же исследователь
					if explorer.id == explorerObj.explorerId and explorer.q == currentQ and explorer.r == currentR then
						-- Обновляем позицию в данных
						explorer.q = target.q
						explorer.r = target.r

						-- Проверяем, вода ли это
						local tile = self.mainGame.mapManager:getTileAtPosition(target.q, target.r)
						if tile then
							explorer.isOnWater = tile.isWater or false
						end

						explorerFound = true
						print(
							"✅ Оновлено позицію дослідника в даних гравця "
								.. player.Name
						)
						break
					end
				end
			end
			if explorerFound then
				break
			end
		end

		-- Также обновляем визуальный объект если он существует
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:GetAttribute("IsExplorer") and obj:GetAttribute("ExplorerId") == explorerObj.explorerId then
				-- Обновляем атрибуты объекта
				obj:SetAttribute("Q", target.q)
				obj:SetAttribute("R", target.r)

				-- Обновляем атрибут IsOnWater
				local tile = self.mainGame.mapManager:getTileAtPosition(target.q, target.r)
				if tile then
					obj:SetAttribute("IsOnWater", tile.isWater or false)
				end

				print("✅ Оновлено атрибути візуального об'єкта дослідника")
				break
			end
		end

		-- Отправляем уведомление всем клиентам
		self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
			type = "explorer_pushed_by_kaiju",
			explorerId = explorerObj.explorerId,
			fromQ = currentQ,
			fromR = currentR,
			toQ = target.q,
			toR = target.r,
			playerName = explorerObj.playerName or "Unknown",
		})

		return target
	end

	print("❌ Немає доступних сусідніх клітин для відштовхування")
	return nil
end

function CreaturePhase:pushCreatureToNeighbor(creatureObj, currentQ, currentR)
	local neighbors = self.mainGame.mapManager:getNeighbors(currentQ, currentR)
	local validTargets = {}

	local cType = creatureObj:GetAttribute("CreatureType")
	if not cType then
		if creatureObj:GetAttribute("IsShark") then
			cType = "Shark"
		end
		if creatureObj:GetAttribute("IsKaiju") then
			cType = "Kaiju"
		end
		if creatureObj:GetAttribute("IsOctopus") then
			cType = "Octopus"
		end
	end

	for _, n in ipairs(neighbors) do
		local tile = self.mainGame.mapManager:getTileAtPosition(n.q, n.r)
		if tile then
			local isWater = tile.isWater or tile.meshPart:GetAttribute("IsWater")
			if cType == "Kaiju" or isWater then
				table.insert(validTargets, n)
			end
		end
	end

	if #validTargets > 0 then
		local t = validTargets[math.random(1, #validTargets)]
		self:updateCreaturePosition(creatureObj, t.q, t.r)
	else
		creatureObj:Destroy()
	end
end

function CreaturePhase:updateCreaturePosition(model, q, r)
	model:SetAttribute("Q", q)
	model:SetAttribute("R", r)

	local tile = self.mainGame.mapManager:getTileAtPosition(q, r)
	if tile and tile.meshPart then
		local yOffset = 3
		local cType = model:GetAttribute("CreatureType")
		if cType == "Shark" or model:GetAttribute("IsShark") then
			yOffset = 0
		end

		local targetPos = tile.meshPart.Position + Vector3.new(0, yOffset, 0)
		model:PivotTo(CFrame.new(targetPos))
	end

	local cType = model:GetAttribute("CreatureType") or "Unknown"
	if cType == "Unknown" and model:GetAttribute("IsShark") then
		cType = "Shark"
	end
	if cType == "Unknown" and model:GetAttribute("IsKaiju") then
		cType = "Kaiju"
	end
	if cType == "Unknown" and model:GetAttribute("IsOctopus") then
		cType = "Octopus"
	end

	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "CreatureMoved",
		creatureType = cType,
		q = q,
		r = r,
	})
end

function CreaturePhase:getCreatureAt(q, r, typeName)
	for _, obj in ipairs(workspace:GetChildren()) do
		local isTarget = false
		if obj:GetAttribute("CreatureType") == typeName then
			isTarget = true
		end
		if typeName == "Shark" and obj:GetAttribute("IsShark") then
			isTarget = true
		end
		if typeName == "Kaiju" and obj:GetAttribute("IsKaiju") then
			isTarget = true
		end
		if typeName == "Octopus" and obj:GetAttribute("IsOctopus") then
			isTarget = true
		end

		if isTarget and obj:GetAttribute("Q") == q and obj:GetAttribute("R") == r then
			return obj
		end
	end
	return nil
end

function CreaturePhase:countCreaturesOnBoard(type)
	local count = 0
	for _, obj in ipairs(workspace:GetChildren()) do
		local matches = false
		if obj:GetAttribute("CreatureType") == type then
			matches = true
		end
		if type == "Shark" and obj:GetAttribute("IsShark") then
			matches = true
		end
		if type == "Kaiju" and obj:GetAttribute("IsKaiju") then
			matches = true
		end
		if type == "Octopus" and obj:GetAttribute("IsOctopus") then
			matches = true
		end

		if matches then
			count = count + 1
		end
	end
	return count
end

function CreaturePhase:getCreatureNameUa(t)
	if t == "Shark" then
		return "Акула"
	end
	if t == "Kaiju" then
		return "Кайдзю"
	end
	if t == "Octopus" then
		return "Восьминіг"
	end
	return t
end

function CreaturePhase:endPhase()
	self.isActive = false
	print("✅ Фаза істот завершена.")
	self.mainGame:returnToMainGame()
end

return CreaturePhase
