local players = game:GetService("Players")
local replicatedstorage = game:GetService("ReplicatedStorage")
local userinputservice = game:GetService("UserInputService")

local player = players.LocalPlayer
local guis = require(script.Parent.Guis)
local submitword = replicatedstorage:WaitForChild("Shared"):WaitForChild("SubmitWord")

local wrongcolor = Color3.fromRGB(226, 92, 92)
local rightcolor = Color3.fromRGB(96, 190, 110)

return function()
	local gui = guis.get("WordInput")
	local backdrop = gui:WaitForChild("Backdrop")
	local frame = gui:WaitForChild("Box")
	local stroke = frame:WaitForChild("UIStroke")
	local textbox = frame:WaitForChild("Word")

	local hint = textbox.PlaceholderText
	local idlecolor = stroke.Color

	local open = false
	local busy = false
	local lockeduntil = 0

	local frozen: Humanoid? = nil
	local savedspeed = 0
	local savedpower = 0
	local savedheight = 0

	local function freeze()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		frozen = humanoid
		savedspeed = humanoid.WalkSpeed
		savedpower = humanoid.JumpPower
		savedheight = humanoid.JumpHeight
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end

	local function unfreeze()
		local humanoid = frozen
		frozen = nil
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = savedspeed
			humanoid.JumpPower = savedpower
			humanoid.JumpHeight = savedheight
		end
	end

	local function refresh()
		local remaining = lockeduntil - os.clock()
		if remaining > 0 then
			textbox.TextEditable = false
			textbox.Text = ""
			textbox.PlaceholderText = string.format("wrong! wait %d", math.ceil(remaining))
			stroke.Color = wrongcolor
		else
			textbox.TextEditable = true
			textbox.PlaceholderText = hint
			stroke.Color = idlecolor
		end
	end

	local function focus()
		if open and lockeduntil <= os.clock() then
			textbox:CaptureFocus()
		end
	end

	local function countdown()
		local mine = lockeduntil
		task.spawn(function()
			while os.clock() < mine and lockeduntil == mine do
				refresh()
				task.wait(0.2)
			end
			if lockeduntil == mine then
				refresh()
				focus()
			end
		end)
	end

	local function close()
		if not open then
			return
		end
		open = false
		gui.Enabled = false
		textbox:ReleaseFocus()
		unfreeze()
	end

	local function show()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if open or not humanoid or humanoid.Health <= 0 then
			return
		end
		open = true
		refresh()
		gui.Enabled = true
		freeze()
		task.defer(focus)
	end

	textbox.FocusLost:Connect(function(enterpressed)
		if not open or not enterpressed or busy then
			return
		end
		local guess = string.match(textbox.Text, "^%s*(.-)%s*$") or ""
		if guess == "" then
			close()
			return
		end
		if lockeduntil > os.clock() then
			return
		end

		busy = true
		local ok, result = pcall(function()
			return submitword:InvokeServer(guess)
		end)
		busy = false
		textbox.Text = ""

		if not ok or typeof(result) ~= "table" then
			refresh()
			focus()
		elseif result.correct then
			stroke.Color = rightcolor
			textbox.TextEditable = false
			textbox.PlaceholderText = "typed out " .. tostring(result.name)
			task.wait(1)
			close()
		elseif typeof(result.wait) == "number" and result.wait > 0 then
			lockeduntil = os.clock() + result.wait
			countdown()
		else
			refresh()
			focus()
		end
	end)

	userinputservice.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			if open then
				close()
			else
				show()
			end
		end
	end)

	backdrop.Activated:Connect(close)
	player.CharacterAdded:Connect(close)
end
