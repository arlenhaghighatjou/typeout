local players = game:GetService("Players")
local userinputservice = game:GetService("UserInputService")

local player = players.LocalPlayer
local guis = require(script.Parent.Guis)

local spectatezoom = 14
local firstpersonzoom = 0.5

local function humanoidof(other: Player): Humanoid?
	local character = other.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

return function()
	local gui = guis.get("Spectate")
	local label = gui:WaitForChild("Label")

	local spectating = false
	local target: Player? = nil

	local function candidates(): { Player }
		local list = {}
		for _, other in players:GetPlayers() do
			if other ~= player and other:GetAttribute("Alive") and humanoidof(other) then
				table.insert(list, other)
			end
		end
		table.sort(list, function(a, b)
			return a.UserId < b.UserId
		end)
		return list
	end

	local function watch(other: Player?)
		target = other
		local humanoid = other and humanoidof(other)
		if other and humanoid then
			workspace.CurrentCamera.CameraSubject = humanoid
			label.Text = "spectating " .. other.DisplayName
		else
			label.Text = "spectating"
		end
	end

	local function switch()
		local list = candidates()
		if #list == 0 then
			watch(nil)
			return
		end
		local index = (target and table.find(list, target)) or 0
		watch(list[index % #list + 1])
	end

	local function hide()
		if spectating then
			spectating = false
			target = nil
			gui.Enabled = false
		end
	end

	local function start()
		if spectating then
			return
		end
		spectating = true
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = spectatezoom
		gui.Enabled = true
		switch()
	end

	local function firstperson()
		hide()
		if player.CameraMode ~= Enum.CameraMode.LockFirstPerson then
			player.CameraMinZoomDistance = firstpersonzoom
			player.CameraMode = Enum.CameraMode.LockFirstPerson
		end
	end

	userinputservice.InputBegan:Connect(function(input, processed)
		if processed or not spectating then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			switch()
		end
	end)

	while true do
		if not player:GetAttribute("InGame") then
			hide()
		elseif humanoidof(player) then
			firstperson()
		else
			start()
			if not target or not target:GetAttribute("Alive") or not humanoidof(target) then
				switch()
			end
		end
		task.wait(0.3)
	end
end
