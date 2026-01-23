-- PlayerColorManager.lua (ModuleScript в Server/GameModules/)
local PlayerColorManager = {}
PlayerColorManager.__index = PlayerColorManager

function PlayerColorManager.new()
	local self = setmetatable({}, PlayerColorManager)

	-- Доступные цвета согласно игровой механике (5 цветов для 5 игроков)
	self.availableColors = {
		{
			name = "Червоний",
			color = Color3.fromRGB(220, 20, 60),
			brickColor = BrickColor.new("Bright red"),
		},
		{
			name = "Синій",
			color = Color3.fromRGB(30, 144, 255),
			brickColor = BrickColor.new("Bright blue"),
		},
		{
			name = "Зелений",
			color = Color3.fromRGB(50, 205, 50),
			brickColor = BrickColor.new("Bright green"),
		},
		{
			name = "Жовтий",
			color = Color3.fromRGB(255, 215, 0),
			brickColor = BrickColor.new("Bright yellow"),
		},
		{
			name = "Фіолетовий",
			color = Color3.fromRGB(186, 85, 211),
			brickColor = BrickColor.new("Bright violet"),
		},
	}

	self.usedColors = {} -- Занятые цвета: key = player, value = colorData

	return self
end

-- Получить случайный свободный цвет для игрока
function PlayerColorManager:getRandomColorForPlayer(player)
	-- Находим все свободные цвета
	local freeColors = {}

	for _, colorData in ipairs(self.availableColors) do
		local isColorUsed = false
		for _, usedColorData in pairs(self.usedColors) do
			if usedColorData.color == colorData.color then
				isColorUsed = true
				break
			end
		end

		if not isColorUsed then
			table.insert(freeColors, colorData)
		end
	end

	-- Если есть свободные цвета, выбираем случайный
	if #freeColors > 0 then
		local selectedColor = freeColors[math.random(1, #freeColors)]
		self.usedColors[player] = selectedColor

		print("🎨 Игроку", player.Name, "выдан цвет:", selectedColor.name)
		return selectedColor
	else
		-- Если все цвета заняты, возвращаем случайный из доступных
		local fallbackColor = self.availableColors[math.random(1, #self.availableColors)]
		print(
			"⚠️ Все цвета заняты! Игроку",
			player.Name,
			"выдан цвет:",
			fallbackColor.name
		)
		return fallbackColor
	end
end

-- Освободить цвет когда игрок выходит
function PlayerColorManager:releasePlayerColor(player)
	if self.usedColors[player] then
		local colorName = self.usedColors[player].name
		self.usedColors[player] = nil
		print("🎨 Цвет освобожден для игрока:", player.Name, "(" .. colorName .. ")")
	end
end

-- Получить цвет игрока
function PlayerColorManager:getPlayerColor(player)
	return self.usedColors[player]
end

-- Получить список всех занятых цветов
function PlayerColorManager:getUsedColors()
	return self.usedColors
end

return PlayerColorManager
