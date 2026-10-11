local players = game:GetService("Players")
local replicatedstorage = game:GetService("ReplicatedStorage")

local armpose = require(replicatedstorage.Shared.ArmPose)
local words = require(replicatedstorage.Shared.Words)

local signwidth = 3.2
local signheight = 1.1
local thickness = 0.3
local border = 0.14
local boardcolor = Color3.fromRGB(255, 255, 255)
local framecolor = Color3.fromRGB(208, 211, 222)
local textcolor = Color3.fromRGB(184, 187, 198)
local textscale = Vector2.new(0.6, 0.42)

local rng = Random.new()
local signs: { [Player]: Model } = {}
local inuse: { [string]: boolean } = {}

local function pickword(): string
	local free = {}
	for _, word in words do
		if not inuse[word] then
			table.insert(free, word)
		end
	end
	local pool = if #free > 0 then free else words
	return pool[rng:NextInteger(1, #pool)]
end

local function posed(motor: Motor6D): CFrame
	local rotation = motor.C0.Rotation
	local pose = armpose[motor.Name] or CFrame.identity
	return motor.C0 * (rotation:Inverse() * pose * rotation) * motor.C1:Inverse()
end

local function handtip(character: Model, torso: BasePart, side: string): Vector3?
	local r6shoulder = torso:FindFirstChild(side .. " Shoulder")
	if r6shoulder and r6shoulder:IsA("Motor6D") and r6shoulder.Part1 then
		return (posed(r6shoulder) * CFrame.new(0, -r6shoulder.Part1.Size.Y / 2, 0)).Position
	end

	local upper = character:FindFirstChild(side .. "UpperArm")
	local lower = character:FindFirstChild(side .. "LowerArm")
	local hand = character:FindFirstChild(side .. "Hand")
	local shoulder = upper and upper:FindFirstChild(side .. "Shoulder")
	local elbow = lower and lower:FindFirstChild(side .. "Elbow")
	local wrist = hand and hand:FindFirstChild(side .. "Wrist")
	if shoulder and elbow and wrist and hand:IsA("BasePart") then
		local tohand = posed(shoulder :: Motor6D) * posed(elbow :: Motor6D) * posed(wrist :: Motor6D)
		return (tohand * CFrame.new(0, -hand.Size.Y / 2, 0)).Position
	end
	return nil
end

local function headtop(character: Model, torso: BasePart): number
	local head = character:FindFirstChild("Head")
	local neck = (head and head:FindFirstChild("Neck")) or torso:FindFirstChild("Neck")
	if head and head:IsA("BasePart") and neck and neck:IsA("Motor6D") then
		return (neck.C0 * neck.C1:Inverse()).Position.Y + head.Size.Y / 2
	end
	return 2
end

local function newpart(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	return part
end

local function addlabel(board: Part, face: Enum.NormalId, word: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60

	local label = Instance.new("TextLabel")
	label.Name = "Word"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(textscale.X, textscale.Y)
	label.BackgroundTransparency = 1
	label.Text = word
	label.TextScaled = true
	label.TextColor3 = textcolor
	label.FontFace = Font.fromEnum(Enum.Font.Gotham)
	label.Parent = gui

	gui.Parent = board
end

local function removesign(player: Player)
	local sign = signs[player]
	if sign then
		signs[player] = nil
		sign:Destroy()
	end
	local word = player:GetAttribute("Word")
	if word then
		inuse[word] = nil
		player:SetAttribute("Word", nil)
	end
end

local function givesign(player: Player, character: Model, folder: Folder)
	local deadline = os.clock() + 8
	while not player:HasAppearanceLoaded() and os.clock() < deadline and player.Character == character do
		task.wait(0.1)
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if player.Character ~= character or not humanoid or not (torso and torso:IsA("BasePart")) then
		return
	end

	removesign(player)
	local word = pickword()
	inuse[word] = true
	player:SetAttribute("Word", word)

	local right = handtip(character, torso, "Right") or Vector3.new(1.8, 1.8, -0.35)
	local left = handtip(character, torso, "Left") or Vector3.new(-1.8, 1.8, -0.35)
	local bottom = math.max(math.min(right.Y, left.Y) - 0.1, headtop(character, torso) + 0.1)
	local offset = CFrame.new((right.X + left.X) / 2, bottom + signheight / 2 + border, (right.Z + left.Z) / 2)

	local sign = Instance.new("Model")
	sign.Name = player.Name

	local board = newpart("Board", Vector3.new(signwidth, signheight, thickness), boardcolor)
	board.CFrame = torso.CFrame * offset
	board.Parent = sign
	sign.PrimaryPart = board
	addlabel(board, Enum.NormalId.Front, word)

	local frame = newpart(
		"Frame",
		Vector3.new(signwidth + border * 2, signheight + border * 2, thickness - 0.1),
		framecolor
	)
	frame.CFrame = board.CFrame
	frame.Parent = sign
	local frameweld = Instance.new("WeldConstraint")
	frameweld.Part0 = board
	frameweld.Part1 = frame
	frameweld.Parent = frame

	local hold = Instance.new("Weld")
	hold.Name = "Hold"
	hold.Part0 = torso
	hold.Part1 = board
	hold.C0 = offset
	hold.Parent = board

	humanoid.NameDisplayDistance = 0

	signs[player] = sign
	sign.Parent = folder

	humanoid.Died:Once(function()
		if signs[player] == sign then
			removesign(player)
		end
	end)
end

return function()
	local folder = Instance.new("Folder")
	folder.Name = "WordSigns"
	folder.Parent = workspace

	local function onplayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			givesign(player, character, folder)
		end)
		player.CharacterRemoving:Connect(function()
			removesign(player)
		end)
		if player.Character then
			task.spawn(givesign, player, player.Character, folder)
		end
	end

	players.PlayerAdded:Connect(onplayer)
	players.PlayerRemoving:Connect(removesign)
	for _, player in players:GetPlayers() do
		onplayer(player)
	end
end
