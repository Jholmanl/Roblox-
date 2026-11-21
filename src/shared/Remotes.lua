-- Creates (server) or finds (client) every RemoteEvent / RemoteFunction.
-- Usage: Remotes.Fire:FireServer(...)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EVENTS = {
	-- client -> server
	"Deploy", "Fire", "Reload", "Knife", "Grenade", "Slam", "JumpPad",
	"BuyWeapon", "SetLoadout", "ClaimDaily", "UseToken", "Vote", "SaveSettings", "SelfRevive", "SetKnife",
	-- server -> client
	"Effect", "HitConfirm", "Damaged", "KillFeed", "Notify", "KillInfo",
	"DataSync", "Killstreak", "MatchResults",
}
local FUNCTIONS = { "GetData" }

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local f = Instance.new("RemoteFunction")
			f.Name = name
			f.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local cache = {}
return setmetatable({}, {
	__index = function(_, key)
		if not cache[key] then
			cache[key] = folder:WaitForChild(key)
		end
		return cache[key]
	end,
})
