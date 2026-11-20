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
	Driving = false,
	Settings = { FOV = 72, Shake = 1, AdsSens = 0.7, Crosshair = "White" },
	Changed = Instance.new("BindableEvent"),
}

State.CrosshairColors = {
	White = Color3.new(1, 1, 1), Green = Color3.fromRGB(70, 255, 120), Cyan = Color3.fromRGB(0, 230, 255),
	Red = Color3.fromRGB(255, 70, 80), Yellow = Color3.fromRGB(255, 220, 40),
}

function State.HasPass(key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

function State.Overdrive(): boolean
	return (player:GetAttribute("OverdriveUntil") or 0) > workspace:GetServerTimeNow()
end

Remotes.DataSync.OnClientEvent:Connect(function(data)
	State.Data = data
	if data.Settings then
		for k, v in data.Settings do
			State.Settings[k] = v
		end
	end
	State.Changed:Fire()
end)

player.AttributeChanged:Connect(function(name)
	if string.sub(name, 1, 5) == "Pass_" or name == "Level" or name == "Cash" then
		State.Changed:Fire()
	end
end)

return State
