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
			table.insert(self.availableTilesToFlood, {
				q = tileData.q,
				r = tileData.r,
				coordKey = coordKey,
				tileData = tileData,
				tileType = tileType,
			})
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

	-- Підсвічуємо новий вибраний тайл (зелений)
	self.networkManager:getHighlightTilesEvent():FireClient(player, {
		type = "flood_tile_selected",
		q = q,
		r = r,
		tileType = selectedTile.tileType,
		isSelected = true,
	})

	-- Запитуємо підтвердження
	self.networkManager:getUpdateReadyStatusEvent():FireClient(player, {
		type = "flood_confirmation",
		q = q,
		r = r,
		tileType = selectedTile.tileType,
		message = "✅ Обрано тайл Q="
			.. q
			.. " R="
			.. r
			.. "\n📌 Натисніть ПІДТВЕРДИТИ для затоплення",
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
		"✅ Затоплення підтверджено! Затоплюємо тайл Q="
			.. self.selectedTile.q
			.. " R="
			.. self.selectedTile.r
	)

	-- Затоплюємо тайл
	self:floodTile(self.selectedTile)

	-- Очищаємо вибір
	self.selectedTile = nil
	self:clearAllFloodHighlights()

	-- Перевіряємо, чи потрібно змінити тип тайлів для наступного затоплення
	self:checkFloodTypeProgress()

	-- Завершуємо фазу затоплення
	self:endFloodPhase()

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

		print("🌊 Затоплюємо тайл:", originalType, "Q=", originalQ, "R=", originalR)

		-- 2. ПЕРЕМІЩУЄМО ДОСЛІДНИКІВ (вони залишаються на тих же координатах)
		self:moveExplorersFromTile(originalQ, originalR)

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

			-- Додаємо/оновлюємо waterTiles
			--[[if waterTile then
				self.mapManager.waterTiles[coordKey] = waterTile

				-- Оновлюємо getTileAtPosition
				--[[self.mapManager:updateTileData(originalQ, originalR, {
					meshPart = waterTile,
					type = "Water",
					q = originalQ,
					r = originalR,
					coordKey = coordKey,
					isWater = true,
					isLand = false,
					tileType = "Water",
					wasFlooded = true,
					originalType = originalType,
				})
			end]]
			--
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

function FloodPhase:endFloodPhase()
	print(
		"🌊 Фаза затоплення завершена для гравця: "
			.. (self.currentFloodPlayer and self.currentFloodPlayer.Name or "?")
	)

	self.isActive = false
	self.selectedTile = nil
	self.currentFloodPlayer = nil

	-- Очищаємо підсвічування
	self:clearAllFloodHighlights()

	-- Повертаємося до основної гри
	if self.mainGame then
		self.mainGame:returnToMainGameAfterFlood()
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

function FloodPhase:getFloodTypeName(tileType)
	local names = {
		Beach = "🏖️ Пляжі",
		Forest = "🌲 Ліси",
		Mountain = "⛰️ Гори",
	}
	return names[tileType] or tileType
end

return FloodPhase
