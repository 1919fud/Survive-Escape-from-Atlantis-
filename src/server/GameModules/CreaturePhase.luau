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

	-- 1. СИНХРОНІЗАЦІЯ (на всяк випадок)
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

	-- Перевіряємо дистанцію (гексова)
	local distance = self:getHexDistance(startQ, startR, q, r)
	if distance > 2 or distance < 1 then
		print("❌ Акула може рухатися лише на 1-2 ділянки")
		return false
	end

	local tile = self.mainGame.mapManager:getTileAtPosition(q, r)
	if not tile or not (tile.isWater or tile.meshPart:GetAttribute("IsWater")) then
		print("❌ Акула може рухатися тільки на водні ділянки")
		return false
	end

	-- Перевіряємо, чи всі проміжні ділянки (якщо distance = 2) також вода
	if distance == 2 then
		local intermediate = self:getIntermediateHex(startQ, startR, q, r)
		if intermediate then
			local interTile = self.mainGame.mapManager:getTileAtPosition(intermediate.q, intermediate.r)
			if not interTile or not (interTile.isWater or interTile.meshPart:GetAttribute("IsWater")) then
				print("❌ Проміжна ділянка не водна")
				return false
			end
		end
	end

	self:updateCreaturePosition(shark, q, r)

	local eatenCount = 0

	-- 1. Отримуємо дослідників на цьому тайлі
	local explorersData = self.mainGame:getExplorersOnTile(q, r)
	for _, exp in ipairs(explorersData) do
		if not exp.isOnBoat then
			print("🦈 Акула їсть (дані) ID:", exp.explorerId)

			-- 2. Видаляємо з даних MainGame
			self.mainGame:removeExplorer(exp.explorerId, exp.playerName)

			-- 3. Видаляємо візуальний об'єкт
			if exp.model then
				exp.model:Destroy()
			end

			-- 4. Сповіщаємо клієнтів
			self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
				type = "explorer_removed_by_effect",
				explorerId = exp.explorerId,
				reason = "shark",
			})
			eatenCount = eatenCount + 1
		end
	end

	-- 5. Додатково очищуємо інші візуальні об'єкти (якщо щось залишилося)
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

	local distance = self:getHexDistance(startQ, startR, q, r)
	if distance > 2 or distance < 1 then
		print("❌ Кайдзю може рухатися лише на 1-2 ділянки")
		return false
	end

	local tile = self.mainGame.mapManager:getTileAtPosition(q, r)
	if not tile then
		print("❌ Тайл не існує")
		return false
	end

	-- Перевіряємо, чи на цій ділянці вже є кайдзю
	local otherKaiju = self:getCreatureAt(q, r, "Kaiju")
	if otherKaiju and otherKaiju ~= kaiju then
		-- Витісняємо іншого кайдзю
		self:pushCreatureToNeighbor(otherKaiju, q, r)
	end

	-- Перевіряємо проміжні ділянки (якщо distance = 2)
	if distance == 2 then
		local intermediate = self:getIntermediateHex(startQ, startR, q, r)
		if intermediate then
			local interTile = self.mainGame.mapManager:getTileAtPosition(intermediate.q, intermediate.r)
			if not interTile then
				print("❌ Проміжна ділянка не існує")
				return false
			end
			-- Проміжна ділянка не повинна бути активним вулканом
			if interTile.isVolcanoActive and interTile.isBlocked then
				print("❌ Проміжна ділянка — активний вулкан")
				return false
			end
		end
	end

	-- Цільова ділянка не повинна бути активним вулканом
	if tile.isVolcanoActive and tile.isBlocked then
		print("❌ Цільова ділянка — активний вулкан")
		return false
	end

	self:updateCreaturePosition(kaiju, q, r)

	-- Знищує човни
	local boat = self.mainGame:getBoatAtPosition(q, r)
	if boat then
		print("🦖 Кайдзю розтрощив човен!")
		self.mainGame:removeBoat(boat)
	end

	-- Відштовхує шукачів
	local explorers = self.mainGame:getExplorersOnTile(q, r)
	for _, exp in ipairs(explorers) do
		self:pushExplorerToNeighbor(exp, q, r)
	end

	-- Витісняє монстрів
	local shark = self:getCreatureAt(q, r, "Shark")
	if shark then
		self:pushCreatureToNeighbor(shark, q, r)
	end

	local octopus = self:getCreatureAt(q, r, "Octopus")
	if octopus then
		self:pushCreatureToNeighbor(octopus, q, r)
	end

	return true
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
	local q = creature:GetAttribute("Q")
	local r = creature:GetAttribute("R")
	local cType = creature:GetAttribute("CreatureType")

	local available = {}
	local allTiles = self.mainGame.mapManager:getAllTiles()

	for coordKey, tileData in pairs(allTiles) do
		local tQ = tileData.q
		local tR = tileData.r

		local distance = self:getHexDistance(q, r, tQ, tR)
		if distance >= 1 and distance <= maxDistance then
			local isValid = false

			-- Перевірки для кожного типу
			if cType == "Shark" then
				if tileData.isWater then
					isValid = true
				end
			elseif cType == "Kaiju" then
				if not (tileData.isVolcanoActive and tileData.isBlocked) then
					-- Перевіряємо, чи немає там іншого кайдзю
					if not self:hasKaijuOnTile(tQ, tR) or (tQ == q and tR == r) then
						isValid = true
					end
				end
			elseif cType == "Octopus" then
				if tileData.isWater and distance == 1 then
					isValid = true
				end
			end

			if isValid then
				table.insert(available, {
					q = tQ,
					r = tR,
					distance = distance,
					tileType = tileData.type or "Unknown",
				})
			end
		end
	end

	return available
end

function CreaturePhase:pushExplorerToNeighbor(explorerObj, currentQ, currentR)
	local neighbors = self.mainGame.mapManager:getNeighbors(currentQ, currentR)
	local target = neighbors[math.random(1, #neighbors)]

	if target then
		-- Примусово оновлюємо дані на сервері
		if explorerObj.model then
			explorerObj.model:SetAttribute("Q", target.q)
			explorerObj.model:SetAttribute("R", target.r)

			-- Перевіряємо воду
			local tile = self.mainGame.mapManager:getTileAtPosition(target.q, target.r)
			local isWater = false
			if tile and (tile.isWater or tile.meshPart:GetAttribute("IsWater")) then
				isWater = true
			end
			explorerObj.model:SetAttribute("IsOnWater", isWater)
		end

		self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
			type = "explorer_moved_by_flood",
			explorerId = explorerObj.explorerId,
			toQ = target.q,
			toR = target.r,
		})
	end
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
