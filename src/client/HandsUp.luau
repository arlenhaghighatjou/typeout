local players = game:GetService("Players")
local replicatedstorage = game:GetService("ReplicatedStorage")
local runservice = game:GetService("RunService")

local poses = require(replicatedstorage:WaitForChild("Shared"):WaitForChild("ArmPose"))

local armparts = {
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	["Right Arm"] = true,
	["Left Arm"] = true,
}

local rigs: { [Model]: { [Motor6D]: CFrame } } = {}

local function oncharacter(character: Model)
	local joints = {}
	rigs[character] = joints

	local function track(instance: Instance)
		if instance:IsA("Motor6D") and poses[instance.Name] then
			joints[instance] = poses[instance.Name]
		end
	end

	character.DescendantAdded:Connect(track)
	character.DescendantRemoving:Connect(function(instance)
		joints[instance :: any] = nil
	end)
	for _, descendant in character:GetDescendants() do
		track(descendant)
	end
end

local function onplayer(player: Player)
	player.CharacterAdded:Connect(oncharacter)
	player.CharacterRemoving:Connect(function(character)
		rigs[character] = nil
	end)
	if player.Character then
		oncharacter(player.Character)
	end
end

return function()
	players.PlayerAdded:Connect(onplayer)
	for _, player in players:GetPlayers() do
		onplayer(player)
	end

	runservice.Stepped:Connect(function()
		for _, joints in rigs do
			for motor, pose in joints do
				local c0 = motor.C0.Rotation
				motor.Transform = c0:Inverse() * pose * c0
			end
		end
	end)

	runservice:BindToRenderStep("HandsUpShowArms", Enum.RenderPriority.Camera.Value + 1, function()
		local character = players.LocalPlayer.Character
		if not character then
			return
		end
		for _, child in character:GetChildren() do
			if armparts[child.Name] and child:IsA("BasePart") then
				child.LocalTransparencyModifier = 0
			end
		end
	end)
end
