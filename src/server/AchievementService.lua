-- Tracks stats and unlocks achievements (with a toast + cash reward).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Achievements)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)

local AchievementService = {}

local pendingSync = {}

local function scheduleSync(player: Player)
	-- batch several stat changes into a single DataSync
	if pendingSync[player] then
		return
	end
	pendingSync[player] = true
	task.delay(1, function()
		pendingSync[player] = nil
		if player.Parent then
			DataService.Sync(player)
		end
	end)
end

local function check(player: Player, data, stat: string)
	local list = Achievements.ByStat[stat]
	if not list then
		return
	end
	local value = data.Stats[stat] or 0
	for _, a in list do
		if not data.Achievements[a.Id] and value >= a.Goal then
			data.Achievements[a.Id] = os.time()
			DataService.AddCash(player, a.Reward, false)
			Remotes.Notify:FireClient(player, "Achievement", {
				Id = a.Id, Name = a.Name, Desc = a.Desc, Reward = a.Reward, Icon = a.Icon,
			})
		end
	end
end

function AchievementService.Add(player: Player?, stat: string, amount: number?)
	if not player or not player:IsA("Player") then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Stats[stat] = (data.Stats[stat] or 0) + (amount or 1)
	check(player, data, stat)
	scheduleSync(player)
end

function AchievementService.SetMax(player: Player?, stat: string, value: number)
	if not player or not player:IsA("Player") then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	if value > (data.Stats[stat] or 0) then
		data.Stats[stat] = value
		check(player, data, stat)
		scheduleSync(player)
	end
end

function AchievementService.CheckAll(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Stats.Level = data.Level
	local owned = 0
	for _ in data.Owned do
		owned += 1
	end
	data.Stats.WeaponsOwned = owned
	for stat in Achievements.ByStat do
		check(player, data, stat)
	end
end

function AchievementService.Init()
	DataService.OnLevelUp = function(player, level)
		AchievementService.SetMax(player, "Level", level)
	end
	-- play time tracker
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				AchievementService.Add(player, "Minutes", 1)
			end
		end
	end)
end

return AchievementService
