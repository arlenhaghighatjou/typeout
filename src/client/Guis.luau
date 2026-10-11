local players = game:GetService("Players")
local replicatedstorage = game:GetService("ReplicatedStorage")

local player = players.LocalPlayer

local cache: { [string]: ScreenGui } = {}

local guis = {}

function guis.get(name: string): ScreenGui
	local existing = cache[name]
	if existing then
		return existing
	end
	local source = replicatedstorage:WaitForChild("Shared"):WaitForChild("Guis"):WaitForChild(name)
	local copy = source:Clone()
	cache[name] = copy
	copy.Parent = player:WaitForChild("PlayerGui")
	return copy
end

return guis
