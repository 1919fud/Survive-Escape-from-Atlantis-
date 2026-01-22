-- FloodPhase.lua
local FloodPhase = {}
FloodPhase.__index = FloodPhase

function FloodPhase.new()
	local self = setmetatable({}, FloodPhase)

	self.isActive = false
	self.floodOrder = { "Beach", "Forest", "Mountain" }
	self.currentFloodTypeIndex = 1
	self.availableTilesToFlood = {}
	self.selectedTile = nil
	self.networkManager = nil
	self.players = {}
	self.mapManager = nil
	self.currentFloodPlayer = nil
	self.activatedVolcanoes = 0

	self.globalEffects = {
		sharks = {
			count = 0, -- Поточна кількість акул на полі
			maxCount = 6, -- Максимум: 3 на пляжах + 3 у лісах
			beachTiles = 0, -- Скільки пляжів з акулою затоплено
			forestTiles = 0, -- Скільки лісів з акулою затоплено
			placedOn = {}, -- Де розміщені акули {[coordKey] = true}
		},
		kaijus = {
			count = 0,
			maxCount = 2, -- Максимум: 3 на пляжах + 2 у лісах
			beachTiles = 0,
			forestTiles = 0,
			placedOn = {},
		},
		octopus = {
			count = 0,
			maxCount = 5, -- Максимум: 5 восьминогов
			placedOn = {},
		},
		extraBoats = {
			count = 0,
			maxCount = 12, -- Максимум: 1 на пляжах + 3 у лісах
			beachTiles = 0,
			forestTiles = 0,
			placedOn = {},
		},
		whirlpools = {
			count = 0,
			maxCount = 6, -- Максимум: 2 у лісах + 4 у горах
			forestTiles = 0,
			mountainTiles = 0,
			placedOn = {},
		},
		volcanoes = {
			count = 0,
			maxCount = 4, -- Тільки в горах
			mountainTiles = 0,
			placedOn = {},
		},
	}

	return self
end

function FloodPhase:start(player, players, networkManager, mapManager)
	self.isActive = true
	self.currentFloodPlayer = player
	self.players = players
	self.networkManager = networkManager
	self.mapManager = mapManager

	-- Зупиняємо основну гру
	if self.mainGame then
		self.mainGame.isGameActive = false
		self.mainGame.gameState = "flood"

		self.placementPhase = self.mainGame.placementPhase
	end

	-- Визначаємо поточний тип тайлів для затоплення
	local currentType = self.floodOrder[self.currentFloodTypeIndex]

	-- Знаходимо всі тайли цього типу
	self:findAvailableTiles(currentType)

	if #self.availableTilesToFlood == 0 then
		print("⚠️ Немає доступних тайлів для затоплення типу: " .. currentType)
		self:moveToNextFloodType()
		return
	end

	print("🌊 Фаза затоплення почалась для гравця: " .. player.Name)
	print("🌊 Затоплюємо: " .. currentType .. " (" .. #self.availableTilesToFlood .. " тайлів)")

	-- Уведомляємо всіх клієнтів
	self.networkManager:getGameStartEvent():FireAllClients({
		phase = "flood_start",
		message = "🌊 ФАЗА ЗАТОПЛЕННЯ!",
		currentPlayer = player.Name,
		floodType = currentType,
		floodTypeName = self:getFloodTypeName(currentType),
	})

	-- Показуємо UI вибору тайлу для поточного гравця
	self:showTileSelectionForCurrentPlayer()
end

function FloodPhase:findAvailableTiles(tileType)
	self.availableTilesToFlood = {}
	local allTiles = self.mapManager:getAllTiles()

	for coordKey, tileData in pairs(allTiles) do
		if tileData.type == tileType and not tileData.isFlooded then
			-- Перевіряємо чи це гора з вулканом
			local hasVolcano = tileData.specialEffect == "volcano"
				or (tileData.meshPart and tileData.meshPart:GetAttribute("SpecialEffect") == "volcano")
			local isVolcanoActive = tileData.meshPart and tileData.meshPart:GetAttribute("VolcanoActive")

			-- Додаємо до списку навіть якщо це вулкан (але не активний)
			if hasVolcano and not isVolcanoActive then
				table.insert(self.availableTilesToFlood, {
					q = tileData.q,
					r = tileData.r,
					coordKey = coordKey,
					tileData = tileData,
					tileType = tileType,
					isVolcano = true, -- Додаємо прапорець що це вулкан
					specialEffect = "volcano",
				})
				print(
					"🌋 Додано гору з вулканом до списку затоплення: Q=",
					tileData.q,
					"R=",
					tileData.r
				)
			elseif not hasVolcano then
				-- Звичайні тайли без вулкана
				table.insert(self.availableTilesToFlood, {
					q = tileData.q,
					r = tileData.r,
					coordKey = coordKey,
					tileData = tileData,
					tileType = tileType,
					isVolcano = false,
					specialEffect = tileData.specialEffect,
				})
			end
		end
	end

	print(
		"📍 Знайдено тайлів для затоплення ("
			.. tileType
			.. "): "
			.. #self.availableTilesToFlood
	)
end

function FloodPhase:showTileSelectionForCurrentPlayer()
	if not self.currentFloodPlayer then
		return
	end
	self:clearAllFloodHighlights()

	-- Скидаємо попередні підсвічування
	self.networkManager:getHighlightTilesEvent():FireAllClients({
		type = "clear",
	})

	-- Відправляємо дані про доступні тайли
	self.networkManager:getHighlightTilesEvent():FireClient(self.currentFloodPlayer, {
		type = "flood_selection",
		availableTiles = self.availableTilesToFlood,
		floodType = self.floodOrder[self.currentFloodTypeIndex],
		floodTypeName = self:getFloodTypeName(self.floodOrder[self.currentFloodTypeIndex]),
		message = "🌊 Оберіть тайл для затоплення",
	})

	-- Показуємо UI підтвердження
	self.networkManager:getUpdateReadyStatusEvent():FireClient(self.currentFloodPlayer, {
		type = "flood_turn",
		message = "🌊 ВАША ЧЕРГА ЗАТОПЛЮВАТИ!",
		floodType = self.floodOrder[self.currentFloodTypeIndex],
		floodTypeName = self:getFloodTypeName(self.floodOrder[self.currentFloodTypeIndex]),
		availableTilesCount = #self.availableTilesToFlood,
		isYourTurn = true,
	})

	-- Іншим гравцям показуємо очікування
	for player, _ in pairs(self.players) do
		if player ~= self.currentFloodPlayer then
			self.networkManager:getUpdateReadyStatusEvent():FireClient(player, {
				type = "flood_waiting",
				message = "⏳ "
					.. self.currentFloodPlayer.Name
					.. " обирає тайл для затоплення",
				floodType = self.floodOrder[self.currentFloodTypeIndex],
				floodTypeName = self:getFloodTypeName(self.floodOrder[self.currentFloodTypeIndex]),
			})
		end
	end
end

function FloodPhase:handleTileSelection(player, q, r)
	if not self.isActive then
		warn("❌ Фаза затоплення не активна!")
		return false
	end

	if player ~= self.currentFloodPlayer then
		warn("❌ Не ваш хід у фазі затоплення!")
		return false
	end

	-- Перевіряємо чи вибраний тайл доступний
	local selectedTile = nil
	for _, tile in ipairs(self.availableTilesToFlood) do
		if tile.q == q and tile.r == r then
			selectedTile = tile
			break
		end
	end

	if not selectedTile then
		warn("❌ Обраний тайл недоступний для затоплення!")
		return false
	end

	print(
		"🌊 Гравець "
			.. player.Name
			.. " обрав тайл для затоплення: Q="
			.. q
			.. " R="
			.. r
			.. " Тип: "
			.. selectedTile.tileType
	)

	-- Скидаємо підсвічування попереднього вибраного тайла
	if self.selectedTile and self.selectedTile.q == q and self.selectedTile.r == r then
		print("✖️ Скасування вибору тайла Q=" .. q .. " R=" .. r)

		-- Скидаємо підсвічування
		self.networkManager:getHighlightTilesEvent():FireClient(player, {
			type = "flood_tile_deselected",
			q = q,
			r = r,
		})

		-- Скидаємо вибір
		self.selectedTile = nil

		-- Ховаємо кнопку підтвердження
		self.networkManager:getUpdateReadyStatusEvent():FireClient(player, {
			type = "flood_confirmation",
			message = "🌊 Оберіть тайл для затоплення",
			confirmButton = false,
		})

		return true
	end

	-- Встановлюємо новий вибраний тайл
	self.selectedTile = selectedTile

	-- Визначаємо повідомлення в залежності від типу тайла
	local message = ""
	if selectedTile.isVolcano then
		message = "🌋 ВИБРАНО ВУЛКАН!\n"
			.. "Цей тайл НЕ буде затоплено.\n"
			.. "Замість цього вулкан буде АКТИВОВАНО!\n"
			.. "📍 Q="
			.. q
			.. " R="
			.. r
			.. "\n"
			.. "📌 Натисніть ПІДТВЕРДИТИ для активації"
	else
		message = "✅ Обрано тайл Q="
			.. q
			.. " R="
			.. r
			.. "\n📌 Натисніть ПІДТВЕРДИТИ для затоплення"
	end

	-- Підсвічуємо новий вибраний тайл (зелений)
	self.networkManager:getHighlightTilesEvent():FireClient(player, {
		type = "flood_tile_selected",
		q = q,
		r = r,
		tileType = selectedTile.tileType,
		isSelected = true,
		isVolcano = selectedTile.isVolcano or false,
	})

	-- Запитуємо підтвердження
	self.networkManager:getUpdateReadyStatusEvent():FireClient(player, {
		type = "flood_confirmation",
		q = q,
		r = r,
		tileType = selectedTile.tileType,
		isVolcano = selectedTile.isVolcano or false,
		message = message,
		confirmButton = true,
	})

	return true
end

function FloodPhase:confirmFlood(player)
	if not self.isActive or not self.selectedTile then
		warn("❌ Немає обраного тайлу для затоплення!")
		return false
	end

	if player ~= self.currentFloodPlayer then
		warn("❌ Не ваш хід у фазі затоплення!")
		return false
	end

	print(
		"✅ Дія підтверджена! Тайл Q="
			.. self.selectedTile.q
			.. " R="
			.. self.selectedTile.r
			.. (self.selectedTile.isVolcano and " (вулкан - активуємо)" or " (затоплюємо)")
	)

	-- Обробляємо вулкан або звичайне затоплення
	if self.selectedTile.isVolcano then
		-- АКТИВУЄМО ВУЛКАН замість затоплення
		print("🌋 Активуємо вулкан на Q=", self.selectedTile.q, "R=", self.selectedTile.r)
		self:activateVolcanoTile(self.selectedTile.q, self.selectedTile.r)

		-- Оновлюємо дані тайла в MapManager
		local coordKey = self.mapManager:getCoordKey(self.selectedTile.q, self.selectedTile.r)
		local tileData = self.mapManager.landTiles[coordKey]

		if tileData then
			tileData.isFlooded = false -- Не затоплено
			tileData.type = "Volcano"
			tileData.tileType = "Volcano"
			tileData.isVolcanoActive = true
			tileData.isBlocked = true

			-- Оновлюємо атрибути меш-парта
			if tileData.meshPart then
				tileData.meshPart:SetAttribute("VolcanoActive", true)
				tileData.meshPart:SetAttribute("IsBlocked", true)
			end
		end

		-- Сповіщаємо всіх гравців
		self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
			type = "volcano_activated",
			q = self.selectedTile.q,
			r = self.selectedTile.r,
			message = "🌋 ВУЛКАН АКТИВОВАНО! Тайл заблоковано для руху.",
		})
	else
		-- ЗВИЧАЙНЕ ЗАТОПЛЕННЯ
		self:floodTile(self.selectedTile)
	end

	-- Очищаємо вибір
	self.selectedTile = nil
	self:clearAllFloodHighlights()

	-- Перевіряємо, чи потрібно змінити тип тайлів для наступного затоплення
	self:checkFloodTypeProgress()

	-- Завершуємо фазу затоплення
	self:endPhase()

	return true
end

function FloodPhase:findNearestWaterTile(q, r, excludeSelf)
	local map = workspace:WaitForChild("Map")
	local nearestTile = nil
	local nearestDistance = math.huge

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
			local isWater = obj:GetAttribute("IsWater") or obj:GetAttribute("Placeboat") == true

			if tileQ and tileR and isWater then
				-- Якщо виключаємо поточний тайл
				if excludeSelf and tileQ == q and tileR == r then
					continue
				end

				local distance = math.abs(tileQ - q) + math.abs(tileR - r)

				if distance < nearestDistance then
					nearestDistance = distance
					nearestTile = { q = tileQ, r = tileR }
				end
			end
		end
	end

	return nearestTile
end

function FloodPhase:moveExplorersFromTile(q, r)
	print(
		"👤 Переміщення дослідників з затопленого тайла Q=" .. q .. " R=" .. r
	)

	local explorersToMove = {}

	-- Збираємо всіх дослідників на цьому тайлі
	for _, playerData in pairs(self.players) do
		if playerData.explorers then
			for _, explorer in ipairs(playerData.explorers) do
				if explorer.q == q and explorer.r == r and not explorer.isOnBoat then
					table.insert(explorersToMove, {
						explorer = explorer,
						playerData = playerData,
					})
					print(
						"👤 Знайдено дослідника ID="
							.. explorer.id
							.. " на затопленому тайлі"
					)
				end
			end
		end
	end

	if #explorersToMove > 0 then
		-- НОВИЙ ПІДХІД: залишаємо дослідників на ЦИХ Ж координатах, бо там буде вода
		print(
			"🌊 Затоплюємо тайл - дослідники залишаються на цих координатах (тепер це буде вода)"
		)

		for _, data in ipairs(explorersToMove) do
			local explorer = data.explorer

			-- ВАЖЛИВО: координати НЕ міняємо! Дослідник залишається на Q, R
			-- Але оскільки острів затоплено, в тепер він буде на воді

			explorer.isOnBoat = false
			explorer.hasEnteredWaterThisTurn = true -- Вони тепер у воді!

			print(
				"👤 Дослідник ID="
					.. explorer.id
					.. " залишається на Q="
					.. q
					.. " R="
					.. r
					.. " (тепер вода)"
			)

			-- ВІДПРАВЛЯЄМО КООРДИНАТИ ЦІ Ж, але вказуємо що це вода
			self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
				type = "explorer_moved_by_flood",
				explorerId = explorer.id,
				playerName = explorer.player.Name,
				fromQ = q,
				fromR = r,
				toQ = q, -- ТІ Ж КООРДИНАТИ!
				toR = r, -- ТІ Ж КООРДИНАТИ!
				message = "Дослідник опинився у воді через затоплення острова",
				isNowOnWater = true,
				sameCoordinates = true, -- Додатковий прапорець
			})
		end
	else
		print("👤 Немає дослідників для переміщення з цього тайлу")
	end
end
function FloodPhase:createFloodEffectAtPosition(q, r)
	-- Знаходимо позицію де був острів
	local map = workspace:WaitForChild("Map")
	local position = Vector3.new(0, 0, 0)

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")

			if tileQ == q and tileR == r then
				position = obj.Position
				break
			end
		end
	end

	-- Створюємо партикли на цій позиції
	local particleEmitter = Instance.new("ParticleEmitter")
	particleEmitter.Name = "FloodEffect"
	particleEmitter.Color = ColorSequence.new(Color3.fromRGB(0, 150, 255))
	particleEmitter.Size = NumberSequence.new(0.5)
	particleEmitter.Transparency = NumberSequence.new(0.7)
	particleEmitter.Lifetime = NumberRange.new(1, 2)
	particleEmitter.Rate = 50
	particleEmitter.Speed = NumberRange.new(2)
	particleEmitter.VelocitySpread = 180

	-- Створюємо тимчасову частинку для ефекту
	local tempPart = Instance.new("Part")
	tempPart.Size = Vector3.new(1, 1, 1)
	tempPart.Position = position + Vector3.new(0, 5, 0) -- Трохи вище
	tempPart.Anchored = true
	tempPart.CanCollide = false
	tempPart.Transparency = 1
	tempPart.Parent = workspace

	particleEmitter.Parent = tempPart

	-- Видаляємо через 3 секунди
	game:GetService("Debris"):AddItem(tempPart, 3)
	game:GetService("Debris"):AddItem(particleEmitter, 3)
end

function FloodPhase:floodTile(tileInfo)
	local tileData = tileInfo.tileData

	if tileData and tileData.meshPart then
		-- 1. Зберігаємо інформацію
		local originalType = tileData.type
		local originalQ = tileData.q
		local originalR = tileData.r
		local specialEffect = tileData.specialEffect or tileData.meshPart:GetAttribute("SpecialEffect")

		print("🌊 Затоплюємо тайл:", originalType, "Q=", originalQ, "R=", originalR)

		-- ПЕРЕВІРКА: якщо це вулкан, не повинно бути тут (вони обробляються в confirmFlood)
		local hasVolcano = specialEffect == "volcano"
		if hasVolcano then
			warn("⚠️ Спроба затопити вулкан! Це не повинно статися.")
			return
		end

		-- 2. ПЕРЕМІЩУЄМО ДОСЛІДНИКІВ (вони залишаються на тих же координатах)
		self:moveExplorersFromTile(originalQ, originalR)

		if specialEffect then
			self:handleSpecialEffect(specialEffect, originalType, originalQ, originalR, tileData)
		end

		-- 3. ВИДАЛЯЄМО острівний тайл
		if tileData.meshPart and tileData.meshPart.Parent then
			print("🗑️ Видаляємо острівний тайл:", tileData.meshPart.Name)
			tileData.meshPart:Destroy()
		end

		-- 4. ЗНАХОДИМО та АКТИВУЄМО водний тайл під цими координатами
		local map = workspace:WaitForChild("Map")
		local waterTile = nil

		-- Шукаємо водний тайл з цими координатами
		for _, obj in ipairs(map:GetDescendants()) do
			if obj:IsA("MeshPart") then
				local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
				local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
				local isWater = obj:GetAttribute("IsWater") or obj:GetAttribute("Placeboat") == true

				if tileQ == originalQ and tileR == originalR then
					if isWater then
						waterTile = obj
						print("💧 Знайдено водний тайл під островом")
					end
				end
			end
		end

		-- 5. Якщо водний тайл не знайдено - створюємо його
		if not waterTile then
			print("💧 Водний тайл не знайдено - створюємо новий")
			waterTile = self:createWaterTileAtPosition(originalQ, originalR)
		else
			-- АКТИВУЄМО існуючий водний тайл
			waterTile.Transparency = 0
			waterTile.Color = Color3.fromRGB(0, 100, 200)
			waterTile.Material = Enum.Material.Water

			waterTile:SetAttribute("IsWater", true)
			waterTile:SetAttribute("IsLand", false)
			waterTile:SetAttribute("TileType", "Water")
			waterTile:SetAttribute("IsActive", true)
			waterTile:SetAttribute("WasFlooded", true)
			waterTile:SetAttribute("OriginalType", originalType)
		end

		-- 6. Оновлюємо MapManager
		if self.mapManager then
			local coordKey = self.mapManager:getCoordKey(originalQ, originalR)

			-- Видаляємо з landTiles
			self.mapManager.landTiles[coordKey] = nil
		end

		-- 7. Сповіщаємо всіх гравців
		self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
			type = "tile_flooded",
			q = originalQ,
			r = originalR,
			originalType = originalType,
			message = "🌊 Тайл " .. originalType .. " затоплено!",
			isNowWater = true,
			explorersStay = true, -- Дослідники залишились
		})

		-- 8. Візуальний ефект
		self:createFloodEffectAtPosition(originalQ, originalR)

		print(
			"✅ Тайл затоплено. Дослідники залишились на координатах (тепер вода)"
		)
	end
end

function FloodPhase:handleSpecialEffect(effectType, tileType, q, r, tileData)
	print("🎭 Активуємо спецефект:", effectType, "тип:", tileType, "на Q=", q, "R=", r)

	local coordKey = self.mapManager:getCoordKey(q, r)

	if effectType == "shark" then
		self:spawnShark(tileType, q, r, coordKey)
	elseif effectType == "kaiju" then
		self:spawnKaiju(tileType, q, r, coordKey)
	elseif effectType == "boat" then
		self:spawnBoat(tileType, q, r, coordKey)
	elseif effectType == "whirlpool" then
		self:createWhirlpool(tileType, q, r, coordKey)
	elseif effectType == "volcano" then
	end

	-- Оновлюємо статистику
	self:updateEffectStatistics(effectType, tileType, coordKey)
end

function FloodPhase:updateEffectStatistics(effectType, tileType, coordKey)
	print(
		"📊 Оновлено статистику:",
		effectType,
		"на",
		tileType,
		"координата:",
		coordKey
	)

	-- Виводимо загальну статистику
	print("=== ГЛОБАЛЬНА СТАТИСТИКА СПЕЦЕФЕКТІВ ===")
	for effectName, data in pairs(self.globalEffects) do
		local totalTiles = 0
		for _, count in pairs(data) do
			if type(count) == "number" and string.find(_, "Tiles") then
				totalTiles = totalTiles + count
			end
		end

		print(
			effectName
				.. ": "
				.. data.count
				.. "/"
				.. data.maxCount
				.. " (розміщено на "
				.. totalTiles
				.. " плитках)"
		)
	end
end

function FloodPhase:countSharksOnBoard()
	-- Рахуємо кількість акул на полі
	local count = 0
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsShark") then
			count = count + 1
		end
	end
	return count
end

function FloodPhase:spawnShark(tileType, q, r, coordKey)
	local sharkData = self.globalEffects.sharks

	-- Оновлюємо лічильник для типу плитки
	if tileType == "Beach" then
		sharkData.beachTiles = sharkData.beachTiles + 1
	elseif tileType == "Forest" then
		sharkData.forestTiles = sharkData.forestTiles + 1
	end

	self:removeAllExplorersFromTile(q, r, "shark")

	if sharkData.count < sharkData.maxCount then
		-- Створюємо нову акулу
		print("🦈 Створюємо нову акулу на Q=", q, "R=", r)
		sharkData.count = sharkData.count + 1
		sharkData.placedOn[coordKey] = true

		-- Тут код для створення акули
		self:createSharkVisual(q, r)
	else
		-- Переміщаємо існуючу акулу
		print("🦈 Переміщаємо існуючу акулу на Q=", q, "R=", r)

		-- Знаходимо першу акулу для переміщення
		local oldCoordKey = next(sharkData.placedOn)
		if oldCoordKey then
			-- Видаляємо зі старого місця
			sharkData.placedOn[oldCoordKey] = nil

			-- Додаємо на нове місце
			sharkData.placedOn[coordKey] = true

			-- Переміщуємо візуал акули
			self:moveSharkToPosition(oldCoordKey, q, r)
		end
	end
end

function FloodPhase:removeAllExplorersFromTile(q, r, reason)
	print(
		"🦈 Видалення всіх дослідників з тайлу Q=",
		q,
		"R=",
		r,
		"причина:",
		reason
	)

	local explorersRemoved = 0

	-- Шукаємо дослідників в даних гри
	for _, playerData in pairs(self.players) do
		if playerData.explorers then
			for i = #playerData.explorers, 1, -1 do
				local explorer = playerData.explorers[i]
				if explorer.q == q and explorer.r == r then
					print(
						"🗑️ Видаляємо дослідника",
						explorer.id,
						"гравця",
						explorer.player.Name,
						"через",
						reason
					)

					-- Сповіщаємо всіх гравців
					self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
						type = "explorer_removed_by_effect",
						explorerId = explorer.id,
						playerName = explorer.player.Name,
						q = q,
						r = r,
						reason = reason,
					})

					-- Видаляємо дослідника
					table.remove(playerData.explorers, i)
					explorersRemoved = explorersRemoved + 1
				end
			end
		end
	end

	-- Також видаляємо візуальні об'єкти дослідників
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") then
			local objQ = obj:GetAttribute("Q")
			local objR = obj:GetAttribute("R")

			if objQ == q and objR == r then
				obj:Destroy()
			end
		end
	end

	print("📊 Видалено дослідників з тайлу:", explorersRemoved)
	return explorersRemoved
end

function FloodPhase:createSharkVisual(q, r)
	print("🦈 Створення візуалу акули на Q=", q, "R=", r)

	-- Знаходимо шаблон акули
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local sharkTemplate = ReplicatedStorage:FindFirstChild("Shark")

	if not sharkTemplate then
		warn("❌ Не знайдено шаблон Shark в ReplicatedStorage")
		return nil
	end

	-- Знаходимо водний тайл для позиціонування
	local map = workspace:WaitForChild("Map")
	local targetTile = nil

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
			local isWater = obj:GetAttribute("IsWater") or obj:GetAttribute("Placeboat") == true

			if tileQ == q and tileR == r and isWater then
				targetTile = obj
				break
			end
		end
	end

	if not targetTile then
		warn("❌ Не знайдено водний тайл для розміщення акули: Q=", q, "R=", r)
		return nil
	end

	-- Створюємо акулу
	local shark = sharkTemplate:Clone()
	shark.Name = "Shark_" .. q .. "_" .. r

	-- Налаштовуємо PrimaryPart
	local primaryPart = shark.PrimaryPart
	if not primaryPart then
		for _, part in ipairs(shark:GetDescendants()) do
			if part:IsA("BasePart") then
				primaryPart = part
				shark.PrimaryPart = primaryPart
				break
			end
		end
	end

	if not shark.PrimaryPart then
		warn("❌ У моделі акули немає PrimaryPart")
		shark:Destroy()
		return nil
	end

	-- Позиціонуємо над водою
	local tileTopY = targetTile.Position.Y + targetTile.Size.Y / 2
	local sharkBottomY = primaryPart.Position.Y - primaryPart.Size.Y / 2
	local yOffset = tileTopY - sharkBottomY + 0.5

	-- Додаємо анімацію плавання
	local rotatedCFrame = (targetTile.CFrame + Vector3.new(0, yOffset, 0)) * CFrame.Angles(math.rad(180), 0, 0)

	shark:PivotTo(rotatedCFrame)

	-- Додаємо атрибути
	shark:SetAttribute("IsShark", true)
	shark:SetAttribute("Q", q)
	shark:SetAttribute("R", r)
	shark:SetAttribute("SharkId", self.globalEffects.sharks.count)

	-- Поміщаємо в workspace
	shark.Parent = workspace

	-- Додаємо ефект появи
	self:createSpecialEffectAppearance(shark, Color3.fromRGB(0, 150, 255))

	print("✅ Створено акулу на Q=", q, "R=", r)
	return shark
end

function FloodPhase:moveSharkToPosition(oldCoordKey, newQ, newR)
	print("🦈 Переміщення акули з", oldCoordKey, "на Q=", newQ, "R=", newR)

	-- Знаходимо стару акулу за координатами
	local oldQ, oldR = oldCoordKey:match("([^,]+),([^,]+)")
	oldQ = tonumber(oldQ)
	oldR = tonumber(oldR)

	-- Шукаємо акулу з старими координатами
	local shark = nil
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("IsShark") then
			local objQ = obj:GetAttribute("Q")
			local objR = obj:GetAttribute("R")
			if objQ == oldQ and objR == oldR then
				shark = obj
				break
			end
		end
	end

	if not shark then
		warn("❌ Не знайдено акулу для переміщення на", oldCoordKey)
		-- Створюємо нову
		self:createSharkVisual(newQ, newR)
		return
	end

	-- Знаходимо новий водний тайл
	local map = workspace:WaitForChild("Map")
	local targetTile = nil

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
			local isWater = obj:GetAttribute("IsWater") or obj:GetAttribute("Placeboat") == true

			if tileQ == newQ and tileR == newR and isWater then
				targetTile = obj
				break
			end
		end
	end

	if not targetTile then
		warn("❌ Не знайдено новий водний тайл для акули")
		return
	end

	-- Оновлюємо позицію
	local primaryPart = shark.PrimaryPart
	if primaryPart then
		local tileTopY = targetTile.Position.Y + targetTile.Size.Y / 2
		local sharkBottomY = primaryPart.Position.Y - primaryPart.Size.Y / 2
		local yOffset = tileTopY - sharkBottomY + 0.5

		local newCFrame = (targetTile.CFrame + Vector3.new(0, yOffset, 0)) * CFrame.Angles(0, math.rad(360), 0)

		shark:PivotTo(newCFrame)
	end

	-- Оновлюємо атрибути
	shark:SetAttribute("Q", newQ)
	shark:SetAttribute("R", newR)
	shark.Name = "Shark_" .. newQ .. "_" .. newR

	-- Ефект переміщення
	self:createMovementEffect(shark)

	print("✅ Переміщено акулу на Q=", newQ, "R=", newR)
end

function FloodPhase:createMovementEffect(model)
	-- Ефект переміщення
	if not model or not model:IsA("Model") then
		return
	end

	local trail = Instance.new("Trail")
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 0))
	trail.Lifetime = 0.5
	trail.Transparency = NumberSequence.new(0.5)
	trail.WidthScale = NumberSequence.new(0.5)

	local attachment0 = Instance.new("Attachment")
	local attachment1 = Instance.new("Attachment")

	attachment0.Position = Vector3.new(0, 1, 0)
	attachment1.Position = Vector3.new(0, -1, 0)

	attachment0.Parent = model.PrimaryPart
	attachment1.Parent = model.PrimaryPart

	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Parent = model.PrimaryPart

	game:GetService("Debris"):AddItem(trail, 1)
	game:GetService("Debris"):AddItem(attachment0, 1)
	game:GetService("Debris"):AddItem(attachment1, 1)
end

function FloodPhase:createSpecialEffectAppearance(model, color)
	-- Ефект появи для спеціальних об'єктів
	if not model or not model:IsA("Model") then
		return
	end

	local primaryPart = model.PrimaryPart
	if not primaryPart then
		return
	end

	-- Подсветка
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.6
	highlight.OutlineTransparency = 0
	highlight.Parent = model

	-- Убираем подсветку через 2 секунды
	game:GetService("Debris"):AddItem(highlight, 2)

	-- Эффект масштабирования
	local originalSize = primaryPart.Size
	primaryPart.Size = Vector3.new(0.1, 0.1, 0.1)

	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local tween = game:GetService("TweenService"):Create(primaryPart, tweenInfo, { Size = originalSize })

	tween:Play()
end

function FloodPhase:spawnKaiju(tileType, q, r, coordKey)
	local kaijuData = self.globalEffects.kaijus

	-- Оновлюємо лічильник для типу плитки
	if tileType == "Beach" then
		kaijuData.beachTiles = kaijuData.beachTiles + 1
	elseif tileType == "Forest" then
		kaijuData.forestTiles = kaijuData.forestTiles + 1
	end

	if kaijuData.count < kaijuData.maxCount then
		-- Створюємо нового кайджю
		print("👹 Створюємо нового кайджю на Q=", q, "R=", r)
		kaijuData.count = kaijuData.count + 1
		kaijuData.placedOn[coordKey] = true

		-- Тут код для створення кайджю
		self:createKaijuVisual(q, r)
	else
		-- Переміщаємо існуючого кайджю
		print("👹 Переміщаємо існуючого кайджю на Q=", q, "R=", r)

		-- Знаходимо першого кайджю для переміщення
		local oldCoordKey = next(kaijuData.placedOn)
		if oldCoordKey then
			-- Видаляємо зі старого місця
			kaijuData.placedOn[oldCoordKey] = nil

			-- Додаємо на нове місце
			kaijuData.placedOn[coordKey] = true

			-- Переміщуємо візуал кайджю
			self:moveKaijuToPosition(oldCoordKey, q, r)
		end
	end
end

function FloodPhase:createKaijuVisual(q, r)
	print("👹 Створення візуалу кайджю на Q=", q, "R=", r)

	-- Знаходимо шаблон кайджю
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local kaijuTemplate = ReplicatedStorage:FindFirstChild("Kaiju")

	if not kaijuTemplate then
		warn("❌ Не знайдено шаблон Kaiju в ReplicatedStorage")
		return nil
	end

	-- Знаходимо водний тайл
	local map = workspace:WaitForChild("Map")
	local targetTile = nil

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
			local isWater = obj:GetAttribute("IsWater") or obj:GetAttribute("Placeboat") == true

			if tileQ == q and tileR == r and isWater then
				targetTile = obj
				break
			end
		end
	end

	if not targetTile then
		warn("❌ Не знайдено водний тайл для розміщення кайджю")
		return nil
	end

	-- Створюємо кайджю
	local kaiju = kaijuTemplate:Clone()
	kaiju.Name = "Kaiju_" .. q .. "_" .. r

	-- Налаштовуємо PrimaryPart
	local primaryPart = kaiju.PrimaryPart
	if not primaryPart then
		for _, part in ipairs(kaiju:GetDescendants()) do
			if part:IsA("BasePart") then
				primaryPart = part
				kaiju.PrimaryPart = primaryPart
				break
			end
		end
	end

	if not kaiju.PrimaryPart then
		warn("❌ У моделі кайджю немає PrimaryPart")
		kaiju:Destroy()
		return nil
	end

	-- Позиціонуємо (кайджю може бути вище за акулу)
	local tileTopY = targetTile.Position.Y + targetTile.Size.Y / 2
	local kaijuBottomY = primaryPart.Position.Y - primaryPart.Size.Y / 2
	local yOffset = tileTopY - kaijuBottomY + 1.0 -- Вище ніж акула

	local rotatedCFrame = (targetTile.CFrame + Vector3.new(0, yOffset, 0)) * CFrame.Angles(math.rad(180), 0, 0)

	kaiju:PivotTo(rotatedCFrame)

	-- Додаємо атрибути
	kaiju:SetAttribute("IsKaiju", true)
	kaiju:SetAttribute("Q", q)
	kaiju:SetAttribute("R", r)
	kaiju:SetAttribute("KaijuId", self.globalEffects.kaijus.count)

	-- Поміщаємо в workspace
	kaiju.Parent = workspace

	-- Ефект появи
	self:createSpecialEffectAppearance(kaiju, Color3.fromRGB(255, 100, 0))

	print("✅ Створено кайджю на Q=", q, "R=", r)
	return kaiju
end

function FloodPhase:moveKaijuToPosition(oldCoordKey, newQ, newR)
	print("👹 Переміщення кайджю з", oldCoordKey, "на Q=", newQ, "R=", newR)

	-- Аналогічно до moveSharkToPosition
	local oldQ, oldR = oldCoordKey:match("([^,]+),([^,]+)")
	oldQ = tonumber(oldQ)
	oldR = tonumber(oldR)

	local kaiju = nil
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("IsKaiju") then
			local objQ = obj:GetAttribute("Q")
			local objR = obj:GetAttribute("R")
			if objQ == oldQ and objR == oldR then
				kaiju = obj
				break
			end
		end
	end

	if not kaiju then
		warn("❌ Не знайдено кайджю для переміщення")
		self:createKaijuVisual(newQ, newR)
		return
	end

	-- Знаходимо новий тайл
	local map = workspace:WaitForChild("Map")
	local targetTile = nil

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
			local isWater = obj:GetAttribute("IsWater") or obj:GetAttribute("Placeboat") == true

			if tileQ == newQ and tileR == newR and isWater then
				targetTile = obj
				break
			end
		end
	end

	if not targetTile then
		warn("❌ Не знайдено новий водний тайл для кайджю")
		return
	end

	-- Оновлюємо позицію
	local primaryPart = kaiju.PrimaryPart
	if primaryPart then
		local tileTopY = targetTile.Position.Y + targetTile.Size.Y / 2
		local kaijuBottomY = primaryPart.Position.Y - primaryPart.Size.Y / 2
		local yOffset = tileTopY - kaijuBottomY

		local newCFrame = (targetTile.CFrame + Vector3.new(0, yOffset, 0)) * CFrame.Angles(math.rad(180), 0, 0)

		kaiju:PivotTo(newCFrame)
	end

	-- Оновлюємо атрибути
	kaiju:SetAttribute("Q", newQ)
	kaiju:SetAttribute("R", newR)
	kaiju.Name = "Kaiju_" .. newQ .. "_" .. newR

	-- Ефект переміщення
	self:createMovementEffect(kaiju)

	print("✅ Переміщено кайджю на Q=", newQ, "R=", newR)
end

function FloodPhase:spawnBoat(tileType, q, r, coordKey)
	local boatData = self.globalEffects.extraBoats

	-- Оновлюємо лічильник для типу плитки
	if tileType == "Beach" then
		boatData.beachTiles = boatData.beachTiles + 1
	elseif tileType == "Forest" then
		boatData.forestTiles = boatData.forestTiles + 1
	end

	if boatData.count < boatData.maxCount then
		-- Створюємо новий човен
		print("🚤 Створюємо додатковий човен на Q=", q, "R=", r)
		boatData.count = boatData.count + 1
		boatData.placedOn[coordKey] = true

		local currentPlayer = self.currentFloodPlayer

		-- Тут код для створення човна
		if currentPlayer then
			-- Використовуємо метод PlacementPhase
			local boat = self.mainGame.placementPhase:createBoatVisual(nil, q, r)
			if boat then
				print("✅ Додатковий човен створено")
			end
		end
	else
		print("🚤 Усі додаткові човни вже розміщені (4 шт)")
		-- Можна додати повідомлення гравцю
	end
end

function FloodPhase:createWhirlpool(tileType, q, r, coordKey)
	local whirlpoolData = self.globalEffects.whirlpools

	-- Оновлюємо лічильник для типу плитки
	if tileType == "Forest" then
		whirlpoolData.forestTiles = whirlpoolData.forestTiles + 1
	elseif tileType == "Mountain" then
		whirlpoolData.mountainTiles = whirlpoolData.mountainTiles + 1
	end

	-- Створюємо водоверть
	print("🌀 Створюємо водоверть на Q=", q, "R=", r)
	whirlpoolData.count = whirlpoolData.count + 1
	whirlpoolData.placedOn[coordKey] = true

	-- ВИПРАВЛЕННЯ: Прибираємо всі елементи на цій та сусідніх водних ділянках
	local totalRemoved = self:removeElementsFromWhirlpoolArea(q, r)

	-- Створюємо візуал водоверті
	self:createWhirlpoolVisual(q, r)

	-- Повідомляємо всім гравцям
	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "whirlpool_created",
		q = q,
		r = r,
		message = "🌀 Створено водоверть!",
		removedElements = totalRemoved,
	})

	return totalRemoved
end

function FloodPhase:removeElementsFromWhirlpoolArea(q, r)
	print("🌀 Прибирання елементів у зоні водоверті Q=", q, "R=", r)

	-- Створюємо список координат для очищення
	local tilesToClear = {}

	-- Додаємо основну ділянку
	table.insert(tilesToClear, { q = q, r = r })

	-- Знаходимо сусідні водні ділянки
	local directions = {
		{ 1, 0 },
		{ 1, -1 },
		{ 0, -1 },
		{ -1, 0 },
		{ -1, 1 },
		{ 0, 1 },
	}

	for _, dir in ipairs(directions) do
		local nq = q + dir[1]
		local nr = r + dir[2]

		-- Перевіряємо, чи це водна ділянка
		local tile = self.mapManager:getTileAtPosition(nq, nr)
		if tile and tile.isWater then
			table.insert(tilesToClear, { q = nq, r = nr })
			print(
				"🌀 Додано сусідню водну ділянку для очищення: Q=",
				nq,
				"R=",
				nr
			)
		end
	end

	-- Видаляємо всі елементи з кожної ділянки
	local totalRemoved = {
		explorers = 0,
		sharks = 0,
		kaijus = 0,
		octopus = 0,
		boats = 0,
	}

	for _, tileCoords in ipairs(tilesToClear) do
		local removed = self:removeAllElementsFromTile(tileCoords.q, tileCoords.r)

		-- Підсумовуємо результати
		if removed then
			totalRemoved.explorers = totalRemoved.explorers + (removed.explorers or 0)
			totalRemoved.sharks = totalRemoved.sharks + (removed.sharks or 0)
			totalRemoved.kaijus = totalRemoved.kaijus + (removed.kaijus or 0)
			totalRemoved.octopus = totalRemoved.octopus + (removed.octopus or 0)
			totalRemoved.boats = totalRemoved.boats + (removed.boats or 0)
		end
	end

	print("📊 Водоверть видалила:")
	print("   Дослідників:", totalRemoved.explorers)
	print("   Акул:", totalRemoved.sharks)
	print("   Кайджю:", totalRemoved.kaijus)
	print("   Восьминогів:", totalRemoved.octopus)
	print("   Човнів:", totalRemoved.boats)

	return totalRemoved
end

function FloodPhase:removeAllElementsFromTile(q, r)
	print("🗑️ Прибирання всіх елементів з Q=", q, "R=", r)

	local removed = {
		explorers = 0,
		sharks = 0,
		kaijus = 0,
		octopus = 0,
		boats = 0,
	}

	-- 1. Спочатку видаляємо дослідників на цьому тайлі (ВИПРАВЛЕНО)
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") then
			local objQ = obj:GetAttribute("Q")
			local objR = obj:GetAttribute("R")

			-- ВИПРАВЛЕННЯ: Уважно порівнюємо значення
			if objQ ~= nil and objR ~= nil then
				local targetQ = tonumber(q)
				local targetR = tonumber(r)
				local expQ = tonumber(objQ)
				local expR = tonumber(objR)

				if targetQ and targetR and expQ and expR then
					if expQ == targetQ and expR == targetR then
						local explorerId = obj:GetAttribute("ExplorerId")
						local playerName = obj:GetAttribute("Player")

						-- Видаляємо з даних гравця
						self:removeExplorerFromPlayerData(playerName, explorerId, q, r)

						-- Повідомляємо гравців
						self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
							type = "explorer_removed_by_effect",
							explorerId = explorerId,
							playerName = playerName,
							q = q,
							r = r,
							reason = "whirlpool",
						})

						-- Видаляємо на сервері
						obj:Destroy()
						removed.explorers = removed.explorers + 1
						print("👤 Видалено дослідника ID=", explorerId, "гравця", playerName)
					end
				end
			end
		end
	end

	-- 2. Також перевіряємо дослідників в даних гри (які можуть бути у воді)
	for _, playerData in pairs(self.players) do
		if playerData.explorers then
			for i = #playerData.explorers, 1, -1 do
				local explorer = playerData.explorers[i]
				if explorer.q == q and explorer.r == r then
					print("👤 Видаляємо дослідника з даних гри ID=", explorer.id)

					self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
						type = "explorer_removed_by_effect",
						explorerId = explorer.id,
						playerName = explorer.player.Name,
						q = q,
						r = r,
						reason = "whirlpool",
					})

					table.remove(playerData.explorers, i)
					removed.explorers = removed.explorers + 1
				end
			end
		end
	end

	-- 2. Видаляємо істот (акули, кайджю)
	local creatures = {
		{ type = "IsShark", name = "sharks" },
		{ type = "IsKaiju", name = "kaijus" },
		{ type = "IsOctopus", name = "octopus" },
	}

	for _, creature in ipairs(creatures) do
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:GetAttribute(creature.type) then
				local objQ = obj:GetAttribute("Q")
				local objR = obj:GetAttribute("R")

				-- Перетворюємо на числа
				local targetQ = tonumber(q) or q
				local targetR = tonumber(r) or r
				local creatureQ = tonumber(objQ) or objQ
				local creatureR = tonumber(objR) or objR

				if creatureQ == targetQ and creatureR == targetR then
					obj:Destroy()
					removed[creature.name] = (removed[creature.name] or 0) + 1
					print("🗑️ Видалено істоту:", creature.type, "на Q=", q, "R=", r)
				end
			end
		end
	end

	-- 3. Видаляємо човни
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsBoat") then
			local objQ = obj:GetAttribute("Q")
			local objR = obj:GetAttribute("R")

			-- Перетворюємо на числа
			local targetQ = tonumber(q) or q
			local targetR = tonumber(r) or r
			local boatQ = tonumber(objQ) or objQ
			local boatR = tonumber(objR) or objR

			if boatQ == targetQ and boatR == targetR then
				local boatId = obj:GetAttribute("BoatId")
				local boatPlayer = obj:GetAttribute("Player")

				-- Спочатку видаляємо всіх дослідників, які були на цьому човні
				local explorersOnBoat = self:removeExplorersFromBoat(obj)
				removed.explorers = removed.explorers + explorersOnBoat

				-- Надсилаємо клієнтам команду на видалення човна
				self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
					type = "boat_removed_by_effect",
					boatId = boatId,
					q = q,
					r = r,
					playerName = boatPlayer,
					reason = "whirlpool",
				})

				-- Видаляємо сам човен на сервері
				obj:Destroy()
				removed.boats = removed.boats + 1
				print(
					"🚤 Видалено човен через водоверть (дослідників на човні:",
					explorersOnBoat,
					")"
				)
			end
		end
	end

	return removed
end

function FloodPhase:removeExplorersFromBoat(boat)
	local boatId = boat:GetAttribute("BoatId")
	if not boatId then
		return 0
	end

	print("👤 Видалення дослідників з човна #", boatId)

	local explorersRemoved = 0

	-- Шукаємо всіх дослідників, які знаходяться на цьому човні
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") then
			local explorerBoatId = obj:GetAttribute("BoatId")

			-- Перевіряємо, чи дослідник на цьому човні
			if explorerBoatId and tostring(explorerBoatId) == tostring(boatId) then
				local explorerId = obj:GetAttribute("ExplorerId")
				local playerName = obj:GetAttribute("Player")
				local q = boat:GetAttribute("Q")
				local r = boat:GetAttribute("R")

				-- Видаляємо з даних гравця
				self:removeExplorerFromPlayerData(playerName, explorerId, q, r)

				-- Повідомляємо про видалення
				self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
					type = "explorer_removed_by_effect",
					explorerId = explorerId,
					playerName = playerName,
					q = q,
					r = r,
					reason = "whirlpool_boat",
				})

				-- Видаляємо візуал
				obj:Destroy()
				explorersRemoved = explorersRemoved + 1
			end
		end
	end

	if explorersRemoved > 0 then
		print("👤 Видалено дослідників з човна:", explorersRemoved)
	end

	return explorersRemoved
end

function FloodPhase:removeExplorerFromPlayerData(playerName, explorerId, q, r)
	-- Шукаємо гравця за ім'ям
	for player, playerData in pairs(self.players) do
		if player.Name == playerName then
			if playerData.explorers then
				for i = #playerData.explorers, 1, -1 do
					local explorer = playerData.explorers[i]
					if explorer.id == explorerId then
						table.remove(playerData.explorers, i)
						print(
							"🗑️ Видалено дослідника",
							explorerId,
							"з даних гравця",
							playerName
						)
						return true
					end
				end
			end
		end
	end
	return false
end

function FloodPhase:createSimpleWhirlpoolEffect(q, r)
	print("🌀 Створення простого ефекту водоверті на Q=", q, "R=", r)

	-- Знаходимо тайл
	local map = workspace:WaitForChild("Map")
	local targetTile = nil

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
			local isWater = obj:GetAttribute("IsWater") or obj:GetAttribute("Placeboat") == true

			if tileQ == q and tileR == r and isWater then
				targetTile = obj
				break
			end
		end
	end

	if not targetTile then
		return nil
	end

	-- Створюємо ефект за допомогою ParticleEmitter
	local particleEmitter = Instance.new("ParticleEmitter")
	particleEmitter.Name = "WhirlpoolEffect"
	particleEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 100, 200)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 150, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 200, 255)),
	})

	particleEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 1.5),
		NumberSequenceKeypoint.new(1, 0.5),
	})

	particleEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 0.5),
	})

	particleEmitter.Lifetime = NumberRange.new(2, 3)
	particleEmitter.Rate = 100
	particleEmitter.Speed = NumberRange.new(2, 5)
	particleEmitter.VelocitySpread = 180
	particleEmitter.Rotation = NumberRange.new(0, 360)
	particleEmitter.RotSpeed = NumberRange.new(-50, 50)

	-- Створюємо контейнер для частинок
	local container = Instance.new("Part")
	container.Name = "Whirlpool_" .. q .. "_" .. r
	container.Size = Vector3.new(5, 0.1, 5)
	container.Position = targetTile.Position + Vector3.new(0, 0.5, 0)
	container.Anchored = true
	container.CanCollide = false
	container.Transparency = 1

	particleEmitter.Parent = container
	container.Parent = workspace

	-- Додаємо атрибути
	container:SetAttribute("IsWhirlpool", true)
	container:SetAttribute("Q", q)
	container:SetAttribute("R", r)

	-- Додаємо обертання
	coroutine.wrap(function()
		while container and container.Parent do
			container.CFrame = container.CFrame * CFrame.Angles(0, math.rad(1), 0)
			wait(0.01)
		end
	end)()

	print("✅ Створено простий ефект водоверті на Q=", q, "R=", r)
	return container
end

function FloodPhase:createWhirlpoolVisual(q, r)
	print("🌀 Створення візуалу водоверті на Q=", q, "R=", r)

	-- Шукаємо шаблон водоверті
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local whirlpoolTemplate = ReplicatedStorage:FindFirstChild("Whirlpool")

	if not whirlpoolTemplate then
		warn("❌ Не знайдено шаблон Whirlpool в ReplicatedStorage")
		-- Якщо немає шаблону, створимо простіший ефект
		return self:createSimpleWhirlpoolEffect(q, r)
	end

	-- Знаходимо водний тайл
	local map = workspace:WaitForChild("Map")
	local targetTile = nil

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
			local isWater = obj:GetAttribute("IsWater") or obj:GetAttribute("Placeboat") == true

			if tileQ == q and tileR == r and isWater then
				targetTile = obj
				break
			end
		end
	end

	if not targetTile then
		warn("❌ Не знайдено водний тайл для водоверті")
		return nil
	end

	-- Створюємо водоверть
	local whirlpool = whirlpoolTemplate:Clone()
	whirlpool.Name = "Whirlpool_" .. q .. "_" .. r

	-- Налаштовуємо PrimaryPart
	local primaryPart = whirlpool.PrimaryPart
	if not primaryPart then
		for _, part in ipairs(whirlpool:GetDescendants()) do
			if part:IsA("BasePart") then
				primaryPart = part
				whirlpool.PrimaryPart = primaryPart
				break
			end
		end
	end

	if not whirlpool.PrimaryPart then
		warn("❌ У моделі водоверті немає PrimaryPart")
		whirlpool:Destroy()
		return self:createSimpleWhirlpoolEffect(q, r)
	end

	-- Позиціонуємо на воді
	local tileTopY = targetTile.Position.Y + targetTile.Size.Y / 2
	local whirlpoolBottomY = primaryPart.Position.Y - primaryPart.Size.Y / 2
	local yOffset = tileTopY - whirlpoolBottomY + 0.1 -- Трохи над водою

	local baseCFrame = targetTile.CFrame + Vector3.new(0, yOffset, 0)
	whirlpool:PivotTo(baseCFrame)

	-- Додаємо атрибути
	whirlpool:SetAttribute("IsWhirlpool", true)
	whirlpool:SetAttribute("Q", q)
	whirlpool:SetAttribute("R", r)
	whirlpool:SetAttribute("WhirlpoolId", self.globalEffects.whirlpools.count)

	-- Поміщаємо в workspace
	whirlpool.Parent = workspace

	-- Ефект появи
	self:createSpecialEffectAppearance(whirlpool, Color3.fromRGB(0, 100, 200))

	print("✅ Створено водоверть на Q=", q, "R=", r)
	return whirlpool
end

function FloodPhase:activateVolcano(tileType, q, r, coordKey)
	local volcanoData = self.globalEffects.volcanoes

	-- Оновлюємо лічильник для типу плитки
	volcanoData.mountainTiles = volcanoData.mountainTiles + 1

	-- Активуємо вулкан
	print("🌋 Активуємо вулкан на Q=", q, "R=", r)
	volcanoData.count = volcanoData.count + 1
	volcanoData.placedOn[coordKey] = true

	-- Прибираємо всі елементи на цій ділянці
	self:removeAllElementsFromTile(q, r)

	-- Блокуємо ділянку
	self:activateVolcanoTile(q, r, "volcano")

	-- Перевіряємо, чи не закінчилася гра
	if volcanoData.count >= 3 then
		self:endGameDueToVolcanoes()
	end
end

function FloodPhase:activateVolcanoTile(q, r)
	print("🌋 Активація вулкана на Q=", q, "R=", r)

	-- Знаходимо тайл в workspace
	local map = workspace:WaitForChild("Map")
	local volcanoTile = nil

	self.activatedVolcanoes = self.activatedVolcanoes + 1
	print("🌋 Активовано вулканів:", self.activatedVolcanoes, "/3")

	-- 2. ПЕРЕВІРКА НА ЗАВЕРШЕННЯ ГРИ
	if self.activatedVolcanoes >= 3 then
		print("🔥 ГРА ЗАКІНЧЕНА! Активовано 3 вулкани!")
		self:endGameDueToVolcanoes()
		return volcanoTile
	end

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")

			if tileQ == q and tileR == r then
				-- Перевіряємо, чи це земля (не вода)
				local isLand = obj:GetAttribute("IsLand")
					or obj:GetAttribute("TileType") == "Mountain"
					or obj:GetAttribute("TileType") == "Volcano"

				if isLand then
					volcanoTile = obj
					break
				end
			end
		end
	end

	if not volcanoTile then
		print(
			"❌ Не знайдено земний тайл для активації вулкана на Q=",
			q,
			"R=",
			r
		)
		return nil
	end

	-- 1. СПОЧАТКУ ВИДАЛЯЄМО ВСІХ ДОСЛІДНИКІВ З ВУЛКАНА
	self:removeExplorersFromVolcano(q, r)

	-- 2. Активуємо вулкан
	volcanoTile:SetAttribute("IsVolcano", true)
	volcanoTile:SetAttribute("VolcanoActive", true)
	volcanoTile:SetAttribute("IsBlocked", true) -- Блокуємо для руху
	volcanoTile:SetAttribute("TileType", "Volcano")
	volcanoTile:SetAttribute("IsLand", true)
	volcanoTile:SetAttribute("IsWater", false)

	-- Перефарбовуємо в червоний колір
	volcanoTile.Color = Color3.fromRGB(255, 50, 50)
	volcanoTile.Material = Enum.Material.Neon

	-- 3. ОНОВЛЮЄМО MapManager
	if self.mapManager then
		local coordKey = self.mapManager:getCoordKey(q, r)
		local tileData = self.mapManager.landTiles[coordKey]

		if tileData then
			tileData.isVolcanoActive = true
			tileData.isBlocked = true
			tileData.type = "Volcano"
			tileData.tileType = "Volcano"
			tileData.isFlooded = false

			-- Оновлюємо meshPart атрибути
			if tileData.meshPart then
				tileData.meshPart:SetAttribute("VolcanoActive", true)
				tileData.meshPart:SetAttribute("IsBlocked", true)
				tileData.meshPart:SetAttribute("TileType", "Volcano")
			end
		end

		-- ВИДАЛЯЄМО водний тайл з водних тайлів MapManager
		-- щоб він не підсвічувався червоним
		if self.mapManager.waterTiles[coordKey] then
			self.mapManager.waterTiles[coordKey] = nil
			print("💧 Видалено водний тайл з MapManager для координат:", coordKey)
		end
	end

	-- 4. ВИДАЛЯЄМО ВОДНИЙ ТАЙЛ ПІД ВУЛКАНОМ (якщо він існує)
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
			local isWater = obj:GetAttribute("IsWater") or obj:GetAttribute("Placeboat") == true

			if tileQ == q and tileR == r and isWater then
				print("🗑️ Видаляємо водний тайл під вулканом:", obj.Name)
				obj:Destroy()
			end
		end
	end

	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "volcano_count_updated",
		currentCount = self.activatedVolcanoes,
		maxCount = 3,
		message = "🌋 Активовано вулканів: " .. self.activatedVolcanoes .. "/3",
	})

	self:checkGameEndAfterVolcano()

	print("🌋 Вулкан активовано на Q=", q, "R=", r)
	return volcanoTile
end

function FloodPhase:checkGameEndAfterVolcano()
	-- Проверяем количество исследователей через mainGame
	if self.mainGame and self.mainGame.countTotalExplorers then
		local totalExplorers = self.mainGame:countTotalExplorers()
		print(
			"🔍 Проверка исследователей после активации вулкана:",
			totalExplorers
		)

		if totalExplorers <= 0 then
			print("🎯 Все исследователи уничтожены! Игра завершается...")

			-- Вызываем функцию завершения игры
			if self.mainGame.endGameNoExplorers then
				self.mainGame:endGameNoExplorers()
			else
				-- Альтернативный способ завершения
				print("🏁 Игра завершена! Нет исследователей на поле")

				-- Определяем победителя (последний выживший или по очкам)
				local winner = nil
				local maxSaved = 0

				for player, playerData in pairs(self.mainGame.players) do
					local savedCount = 0
					for _, saved in ipairs(self.mainGame.savedExplorers or {}) do
						if saved.playerName == player.Name then
							savedCount = savedCount + 1
						end
					end

					if savedCount > maxSaved then
						maxSaved = savedCount
						winner = player
					end
				end

				local winnerName = winner and winner.Name or "Невідомо"

				-- Отправляем событие завершения
				if self.networkManager and self.networkManager.getGameStartEvent then
					self.networkManager:getGameStartEvent():FireAllClients({
						phase = "game_over",
						message = "🔥 ГРА ЗАКІНЧЕНА! Всі дослідники знищені!",
						winner = winnerName,
						reason = "all_explorers_destroyed",
					})
				end
			end
			return true
		end
	end
	return false
end

function FloodPhase:endGameDueToVolcanoes()
	print("🔥 ГРА ЗАКІНЧЕНА! Активовано 3 вулкани!")

	-- Зупиняємо всі ігрові процеси
	self.isActive = false
	self.mainGame.isGameActive = false
	self.mainGame.gameState = "finished"

	-- ВИПРАВЛЕННЯ: Припиняємо всі подальші фази
	self.mainGame.floodPhase.isActive = false -- Зупиняємо фазу затоплення

	-- Зупиняємо фазу істот якщо вона існує
	if self.mainGame.creaturePhase then
		self.mainGame.creaturePhase.isActive = false
		print("🛑 Фаза істот зупинена після завершення гри")
	end

	-- Зупиняємо TurnManager якщо він існує
	if self.mainGame.turnManager then
		self.mainGame.turnManager.isActive = false
		print("🛑 TurnManager зупинено після завершення гри")
	end

	-- Визначаємо переможця (той, хто зберіг найбільше дослідників)
	local winner = nil
	local maxSaved = 0

	for player, playerData in pairs(self.mainGame.players) do
		local savedCount = 0
		for _, saved in ipairs(self.mainGame.savedExplorers) do
			if saved.playerName == player.Name then
				savedCount = savedCount + 1
			end
		end

		print("📊 Гравець", player.Name, "зберіг", savedCount, "дослідників")

		if savedCount > maxSaved then
			maxSaved = savedCount
			winner = player
		end
	end

	-- Якщо ніхто не зберіг дослідників - гравець з найбільшою кількістю дослідників на полі
	if not winner or maxSaved == 0 then
		local maxExplorers = 0
		for player, playerData in pairs(self.mainGame.players) do
			local explorerCount = playerData.explorers and #playerData.explorers or 0
			if explorerCount > maxExplorers then
				maxExplorers = explorerCount
				winner = player
			end
		end
	end

	local winnerName = winner and winner.Name or "Невідомо"

	-- Уведомляємо всіх клієнтів про завершення гри
	self.networkManager:getGameStartEvent():FireAllClients({
		phase = "game_over",
		message = "🔥 ГРА ЗАКІНЧЕНА! Активовано 3 вулкани!",
		winner = winnerName,
		reason = "volcanoes",
		volcanoCount = self.activatedVolcanoes,
		maxVolcanoes = 3,
		isVolcanoEnd = true,
	})

	-- Запускаємо UI завершення гри на клієнті
	self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
		type = "game_end_ui",
		show = true,
		title = "🔥 ГРА ЗАКІНЧЕНА!",
		message = "Активовано 3 вулкани!",
		winner = winnerName,
		volcanoCount = self.activatedVolcanoes,
	})

	print("🏆 Переможець:", winnerName)

	return
end

function FloodPhase:removeExplorersFromVolcano(q, r)
	print("👤 Видалення дослідників з вулкана Q=", q, "R=", r)

	local explorersRemoved = 0

	-- Шукаємо дослідників у даних гри
	for _, playerData in pairs(self.players) do
		if playerData.explorers then
			for i = #playerData.explorers, 1, -1 do
				local explorer = playerData.explorers[i]
				if explorer.q == q and explorer.r == r then
					print("🗑️ Видаляємо дослідника", explorer.id, "з вулкана")

					-- Сповіщаємо всіх гравців
					self.networkManager:getUpdateReadyStatusEvent():FireAllClients({
						type = "explorer_removed_by_effect",
						explorerId = explorer.id,
						playerName = explorer.player.Name,
						q = q,
						r = r,
						reason = "volcano",
					})

					-- Видаляємо дослідника
					table.remove(playerData.explorers, i)
					explorersRemoved = explorersRemoved + 1
				end
			end
		end
	end

	-- Також видаляємо візуальні об'єкти дослідників
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") then
			local objQ = obj:GetAttribute("Q")
			local objR = obj:GetAttribute("R")

			if objQ == q and objR == r then
				obj:Destroy()
			end
		end
	end

	print("📊 Видалено дослідників з вулкана:", explorersRemoved)
	return explorersRemoved
end

function FloodPhase:moveExplorersFromBoat(boat)
	local boatId = boat:GetAttribute("BoatId")
	if not boatId then
		return
	end

	local boatQ = boat:GetAttribute("Q")
	local boatR = boat:GetAttribute("R")

	print("👤 Переміщення дослідників з човна #", boatId)

	-- Знаходимо найближчий вільний водний тайл
	local nearestTile = self:findNearestAvailableWaterTile(boatQ, boatR)

	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("IsExplorer") and obj:GetAttribute("BoatId") == boatId then
			-- Оновлюємо координати дослідника
			obj:SetAttribute("Q", nearestTile.q)
			obj:SetAttribute("R", nearestTile.r)
			obj:SetAttribute("IsOnBoat", false)
			obj:SetAttribute("BoatId", nil)
			obj:SetAttribute("BoatPlaceIndex", nil)

			-- Оновлюємо позицію
			self:positionExplorerOnWater(obj, nearestTile.q, nearestTile.r)

			print("👤 Дослідник переміщений на Q=", nearestTile.q, "R=", nearestTile.r)
		end
	end
end

function FloodPhase:positionExplorerOnWater(explorer, q, r)
	-- Проста позиціонування дослідника на воді
	local map = workspace:WaitForChild("Map")

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")

			if tileQ == q and tileR == r then
				local primaryPart = explorer.PrimaryPart
				if primaryPart then
					local yOffset = 4.38 -- Базова висота для води
					local angle = math.random(0, 360)
					local radius = 1.5
					local offsetX = math.cos(math.rad(angle)) * radius
					local offsetZ = math.sin(math.rad(angle)) * radius

					local newPosition = Vector3.new(obj.Position.X + offsetX, yOffset, obj.Position.Z + offsetZ)

					local rotatedCFrame = CFrame.new(newPosition) * CFrame.Angles(0, math.rad(90 + angle), 0)

					explorer:SetPrimaryPartCFrame(rotatedCFrame)
				end
				break
			end
		end
	end
end

function FloodPhase:findNearestAvailableWaterTile(fromQ, fromR)
	-- Спрощена версія - шукаємо будь-який водний тайл
	local map = workspace:WaitForChild("Map")

	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local tileQ = obj:GetAttribute("Q") or obj:GetAttribute("q")
			local tileR = obj:GetAttribute("R") or obj:GetAttribute("r")
			local isWater = obj:GetAttribute("IsWater") or obj:GetAttribute("Placeboat") == true

			if isWater then
				-- Перевіряємо, чи немає на ньому вже водоверті
				local hasWhirlpool = false
				for _, whirlpool in ipairs(workspace:GetChildren()) do
					if whirlpool:GetAttribute("IsWhirlpool") then
						local wq = whirlpool:GetAttribute("Q")
						local wr = whirlpool:GetAttribute("R")
						if wq == tileQ and wr == tileR then
							hasWhirlpool = true
							break
						end
					end
				end

				if not hasWhirlpool then
					return { q = tileQ, r = tileR }
				end
			end
		end
	end

	-- Якщо не знайшли, повертаємо оригінальні координати
	return { q = fromQ, r = fromR }
end

function FloodPhase:createFloodEffect(tile)
	-- Створюємо ефект затоплення
	local particleEmitter = Instance.new("ParticleEmitter")
	particleEmitter.Name = "FloodEffect"
	particleEmitter.Color = ColorSequence.new(Color3.fromRGB(0, 150, 255))
	particleEmitter.Size = NumberSequence.new(0.5)
	particleEmitter.Transparency = NumberSequence.new(0.7)
	particleEmitter.Lifetime = NumberRange.new(1, 2)
	particleEmitter.Rate = 50
	particleEmitter.Speed = NumberRange.new(2)
	particleEmitter.VelocitySpread = 180
	particleEmitter.Parent = tile

	-- Видаляємо через 3 секунди
	game:GetService("Debris"):AddItem(particleEmitter, 3)
end

function FloodPhase:checkFloodTypeProgress()
	local currentType = self.floodOrder[self.currentFloodTypeIndex]
	local remainingTiles = self:countRemainingTiles(currentType)

	print("📊 Залишилось тайлів " .. currentType .. ": " .. remainingTiles)

	if remainingTiles <= 0 then
		-- Переходимо до наступного типу
		self.currentFloodTypeIndex = self.currentFloodTypeIndex + 1

		if self.currentFloodTypeIndex > #self.floodOrder then
			-- Всі типи затоплено
			print("🌊 Всі типи тайлів затоплено!")
			self.networkManager:getGameStartEvent():FireAllClients({
				phase = "flood_complete",
				message = "🌊 Всі тайли затоплено!",
			})
		else
			local nextType = self.floodOrder[self.currentFloodTypeIndex]
			print("🌊 Перехід до затоплення: " .. nextType)

			self.networkManager:getGameStartEvent():FireAllClients({
				phase = "flood_type_changed",
				message = "🌊 Тепер затоплюємо: " .. nextType,
				floodType = nextType,
				floodTypeName = self:getFloodTypeName(nextType),
			})
		end
	end
end

function FloodPhase:moveToNextFloodType()
	self.currentFloodTypeIndex = self.currentFloodTypeIndex + 1

	if self.currentFloodTypeIndex > #self.floodOrder then
		-- Всі типи затоплено
		print("🌊 Всі типи тайлів затоплено!")
		self:endFloodPhase()
		return
	end

	-- Продовжуємо з наступним типом
	local nextType = self.floodOrder[self.currentFloodTypeIndex]
	self:findAvailableTiles(nextType)

	if #self.availableTilesToFlood > 0 then
		self:showTileSelectionForCurrentPlayer()
	else
		self:moveToNextFloodType()
	end
end

function FloodPhase:countRemainingTiles(tileType)
	local count = 0
	local allTiles = self.mapManager:getAllTiles()

	for _, tileData in pairs(allTiles) do
		if tileData.type == tileType and not tileData.isFlooded then
			count = count + 1
		end
	end

	return count
end

function FloodPhase:finish(player)
	print("🌊 Фаза затоплення завершена для гравця:", player.Name)

	-- Очищаем подсветку
	self:clearAllHighlights()

	-- Уведомляем клиентов
	self.networkManager:getHighlightTilesEvent():FireAllClients({
		type = "clear_flood_highlights",
	})

	-- ЗАПОМНИТЕ: НЕ переключаем ход здесь!
	-- Фаза затопления завершена, но ход игрока ЕЩЕ НЕ ЗАВЕРШЕН

	-- Начинаем фазу существ
	if self.mainGame and self.mainGame.creaturePhase then
		print("🎲 Починаємо фазу істот для гравця:", player.Name)
		self.mainGame.creaturePhase:start(player, self.mainGame)
	else
		print("⚠️ CreaturePhase не ініціалізовано, пропускаємо фазу істот")
		-- Если нет фазы существ, возвращаемся к основной игре
		-- Но НЕ переключаем ход!
		if self.mainGame then
			self.mainGame.gameState = "main_game"
			self.mainGame.isGameActive = true
			print("🎮 Повернення до основної гри для гравця:", player.Name)
		end
	end
end
function FloodPhase:clearAllFloodHighlights()
	print("🧹 Очищення всіх підсвічувань затоплення...")

	-- Очищаємо підсвічування FloodTileHighlight
	self:clearFloodTileHighlights()

	-- Очищаємо BillboardGui FloodInfo
	self:clearFloodBillboards()

	-- ВІДПРАВЛЯЄМО КЛІЄНТУ КОМАНДУ ОЧИСТИТИ
	if self.networkManager then
		self.networkManager:getHighlightTilesEvent():FireAllClients({
			type = "clear_flood_highlights",
			message = "Очищення підсвічувань затоплення",
		})
	end
end

function FloodPhase:clearFloodTileHighlights()
	local map = workspace:WaitForChild("Map")

	-- Видаляємо всі FloodTileHighlight
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local highlight = obj:FindFirstChild("FloodTileHighlight")
			if highlight then
				highlight:Destroy()
				print("🧹 Видалено FloodTileHighlight з:", obj.Name)
			end
		end
	end
end

function FloodPhase:clearFloodBillboards()
	local map = workspace:WaitForChild("Map")

	-- Видаляємо всі FloodInfo BillboardGui
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("MeshPart") then
			local billboard = obj:FindFirstChild("FloodInfo")
			if billboard then
				billboard:Destroy()
				print("🧹 Видалено FloodInfo з:", obj.Name)
			end

			-- Також видаляємо CostDisplay якщо є
			local costDisplay = obj:FindFirstChild("CostDisplay")
			if costDisplay then
				costDisplay:Destroy()
			end
		end
	end
end
function FloodPhase:endPhase()
	print("✅ Фаза затопления завершена")

	-- ВИПРАВЛЕННЯ: Перевіряємо, чи гра не завершена через вулкани
	if self.mainGame and self.mainGame.gameState == "finished" then
		print("⚠️ Гра вже завершена, не запускаємо фазу істот")
		return
	end

	-- Очищаем подсветку
	self.networkManager:getHighlightTilesEvent():FireAllClients({
		type = "clear",
	})

	-- Уведомляем всех клиентов
	self.networkManager:getGameStartEvent():FireAllClients({
		phase = "flood_phase_complete",
		message = "🌊 Фаза затопления завершена! Начинается фаза истот...",
	})

	-- Перевіряємо чи є currentPlayer
	if self.mainGame and self.currentPlayer then
		print("🦖 Перехід до фази істот для гравця:", self.currentPlayer.Name)
		self.mainGame:startCreaturePhase(self.currentPlayer) -- Запускаємо фазу істот
	else
		warn(
			"❌ [FloodPhase] Не вдалося знайти гравця для переходу до фази істот"
		)

		-- Якщо немає гравця, все одно запускаємо фазу істот через TurnManager
		if self.mainGame and self.mainGame.turnManager then
			local player = self.mainGame.turnManager:getCurrentPlayer()
			if player then
				self.mainGame:startCreaturePhase(player)
			else
				self.mainGame:returnToMainGameAfterFlood()
			end
		else
			self.mainGame:returnToMainGameAfterFlood()
		end
	end

	self.isActive = false
end
function FloodPhase:getFloodTypeName(tileType)
	local names = {
		Beach = "🏖️ Пляжі",
		Forest = "🌲 Ліси",
		Mountain = "⛰️ Гори",
	}
	return names[tileType] or tileType
end
return FloodPhase
