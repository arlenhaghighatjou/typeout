local serverstorage = game:GetService("ServerStorage")
local soundservice = game:GetService("SoundService")

local maxlength = 600
local gap = 1

local function songs(folder: Instance): { Sound }
	local list = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Sound") then
			table.insert(list, child)
		end
	end
	return list
end

return function()
	local folder = serverstorage:WaitForChild("Songs")
	local rng = Random.new()
	local last: Sound? = nil

	task.spawn(function()
		while true do
			local list = songs(folder)
			if #list == 0 then
				task.wait(5)
				continue
			end

			local pick = list[rng:NextInteger(1, #list)]
			while #list > 1 and pick == last do
				pick = list[rng:NextInteger(1, #list)]
			end
			last = pick

			local sound = pick:Clone()
			sound.Name = "Music"
			sound.Looped = false
			sound.Parent = soundservice

			local ended = false
			sound.Ended:Once(function()
				ended = true
			end)
			sound:Play()

			local started = os.clock()
			while not ended do
				task.wait(0.5)
				local elapsed = os.clock() - started
				local length = sound.TimeLength
				if (length > 0 and elapsed > length + 1) or elapsed > maxlength then
					break
				end
			end

			sound:Destroy()
			task.wait(gap)
		end
	end)
end
