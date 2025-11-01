-- ExplorerSelector.lua (LocalScript в StarterPlayerScripts/Client/)
local Players = game:GetService("Players")
local _ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- Создаем UI для выбора исследователей
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ExplorerSelector"
screenGui.Parent = PlayerGui

-- Основной фрейм
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 150)
mainFrame.Position = UDim2.new(0.5, -150, 0, 20)
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Заголовок
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
titleLabel.Text = "Виберіть дослідника"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = mainFrame

-- Контейнер для кнопок сокровищ
local buttonsContainer = Instance.new("Frame")
buttonsContainer.Size = UDim2.new(1, -20, 0, 80)
buttonsContainer.Position = UDim2.new(0, 10, 0, 40)
buttonsContainer.BackgroundTransparency = 1
buttonsContainer.Parent = mainFrame

-- Создаем кнопки для каждого значения сокровищ
local treasureValues = { 1, 2, 3, 4, 5 }
local treasureButtons = {}

for i, value in ipairs(treasureValues) do
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 45, 0, 45)
	button.Position = UDim2.new(0, (i - 1) * 50, 0, 0)
	button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	button.Text = tostring(value)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Parent = buttonsContainer

	-- Сохраняем кнопку
	treasureButtons[value] = button
end

-- Статус выбора
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 30)
statusLabel.Position = UDim2.new(0, 10, 0, 120)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Оберіть значення скарбів"
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = mainFrame

-- Переменные
local selectedTreasureValue = nil

-- Функция для подсветки выбранной кнопки
local function updateButtonsHighlight()
	for value, button in pairs(treasureButtons) do
		if value == selectedTreasureValue then
			button.BackgroundColor3 = Color3.fromRGB(0, 150, 255) -- Синий для выбранного
		else
			button.BackgroundColor3 = Color3.fromRGB(70, 70, 70) -- Серый для остальных
		end
	end
end

-- Обработчики нажатия кнопок
for value, button in pairs(treasureButtons) do
	button.MouseButton1Click:Connect(function()
		selectedTreasureValue = value
		updateButtonsHighlight()
		statusLabel.Text = "Обрано скарбів: " .. value .. " → Клікніть на тайл"

		print("🎒 Выбрано исследователя с сокровищами:", value)
	end)
end

-- Функция для скрытия/показа UI
function screenGui:setVisible(visible)
	self.Enabled = visible
end

-- Функция для получения выбранного значения
function screenGui:getSelectedTreasure()
	return selectedTreasureValue
end

-- Функция для сброса выбора
function screenGui:resetSelection()
	selectedTreasureValue = nil
	updateButtonsHighlight()
	statusLabel.Text = "Оберіть значення скарбів"
end

print("✅ UI выбора исследователей загружен")

return screenGui
