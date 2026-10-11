local raise = math.rad(165)
local spread = math.rad(12)

return {
	RightShoulder = CFrame.Angles(raise, 0, spread),
	LeftShoulder = CFrame.Angles(raise, 0, -spread),
	RightElbow = CFrame.identity,
	LeftElbow = CFrame.identity,
	RightWrist = CFrame.identity,
	LeftWrist = CFrame.identity,
	["Right Shoulder"] = CFrame.Angles(raise, 0, spread),
	["Left Shoulder"] = CFrame.Angles(raise, 0, -spread),
}
