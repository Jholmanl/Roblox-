-- Shared client-side state that every controller / UI module can read.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local player = Players.LocalPlayer

local State = {
	Data = nil, -- synced profile (Owned, Loadout, Stats, Achievements, Daily...)
	MenuOpen = false, -- any full-screen menu is open (blocks shooting)
	Deployed = false, -- pressed PLAY
	Dead = false,
	Changed = Instance.new("BindableEvent"),
}

function State.HasPass(key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

function State.Overdrive(): boolean
	return (player:GetAttribute("OverdriveUntil") or 0) > workspace:GetServerTimeNow()
end

Remotes.DataSync.OnClientEvent:Connect(function(data)
	State.Data = data
	State.Changed:Fire()
end)

player.AttributeChanged:Connect(function(name)
	if string.sub(name, 1, 5) == "Pass_" or name == "Level" or name == "Cash" then
		State.Changed:Fire()
	end
end)

return State
