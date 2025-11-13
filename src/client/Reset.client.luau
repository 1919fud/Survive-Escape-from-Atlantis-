local StarterGUI = game:GetService("StarterGui")

repeat
	local success = pcall(function()
		StarterGUI:SetCore("ResetButtonCallback", false)
	end)
	task.wait(1)
until success
