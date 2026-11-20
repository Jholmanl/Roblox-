-- Persistent player data (cash, XP, owned guns, stats, achievements...).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local DataService = {}
DataService.Profiles = {} :: { [Player]: any }
DataService.OnLevelUp = nil :: ((Player, number) -> ())?

local STORE_NAME = "NeonStrike_PlayerData_v1"
local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore(STORE_NAME)
end)
if not storeOk then
	warn("[DataService] DataStores unavailable (enable Studio API access in Game Settings > Security). Data will not save.")
	store = nil
end

local DEFAULT = {
	Cash = Config.StartingCash,
	XP = 0,
	Level = 1,
	Owned = { Striker = true, Sidekick = true },
	Loadout = { Primary = "Striker", Secondary = "Sidekick" },
	Stats = {},
	Achievements = {},
	Daily = { Last = 0, Streak = 0 },
	BoostUntil = 0,
	Tokens = { Airstrike = 0, Nuke = 0 },
	Receipts = {},
	Settings = { FOV = 72, Shake = 1, AdsSens = 0.7, Crosshair = "White" },
}

local function key(player: Player)
	return "u_" .. player.UserId
end

function DataService.Get(player: Player)
	return DataService.Profiles[player]
end

local function applyAttributes(player: Player, data)
	player:SetAttribute("Cash", data.Cash)
	player:SetAttribute("Level", data.Level)
	player:SetAttribute("XP", data.XP)
	player:SetAttribute("XPNeeded", Config.XPForLevel(data.Level))
	player:SetAttribute("BoostUntil", data.BoostUntil)
	player:SetAttribute("AirstrikeTokens", data.Tokens.Airstrike)
	player:SetAttribute("NukeTokens", data.Tokens.Nuke)
end

-- Sends the parts of the profile the UI needs (menus, achievements).
function DataService.Sync(player: Player)
	local data = DataService.Profiles[player]
	if not data then
		return
	end
	applyAttributes(player, data)
	Remotes.DataSync:FireClient(player, {
		Owned = data.Owned,
		Loadout = data.Loadout,
		Stats = data.Stats,
		Achievements = data.Achievements,
		Daily = data.Daily,
		DailyAvailable = DataService.DailyAvailable(player),
		Settings = data.Settings,
	})
end

function DataService.Load(player: Player)
	local data
	if store then
		for attempt = 1, 4 do
			local ok, result = pcall(function()
				return store:GetAsync(key(player))
			end)
			if ok then
				data = result or {}
				break
			end
			warn("[DataService] Load failed (attempt " .. attempt .. "): " .. tostring(result))
			task.wait(attempt)
		end
	end
	local loadedFromStore = data ~= nil
	data = Util.Reconcile(data or {}, DEFAULT)
	data._canSave = loadedFromStore -- never overwrite real data after a failed load
	data._joined = os.time()
	DataService.Profiles[player] = data
	applyAttributes(player, data)
	return data
end

function DataService.Save(player: Player)
	local data = DataService.Profiles[player]
	if not data or not store or not data._canSave then
		return
	end
	local copy = Util.DeepCopy(data)
	copy._canSave = nil
	copy._joined = nil
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function()
			return copy
		end)
	end)
	if not ok then
		warn("[DataService] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

function DataService.Release(player: Player)
	DataService.Save(player)
	DataService.Profiles[player] = nil
end

local function notify(player, kind, payload)
	Remotes.Notify:FireClient(player, kind, payload)
end

function DataService.AddCash(player: Player, amount: number, useMultiplier: boolean?, reason: string?)
	local data = DataService.Profiles[player]
	if not data or amount == 0 then
		return 0
	end
	if useMultiplier and player:GetAttribute("Pass_VIP") then
		amount *= 2
	end
	amount = math.floor(amount)
	data.Cash += amount
	player:SetAttribute("Cash", data.Cash)
	if amount > 0 then
		data.Stats.CashEarned = (data.Stats.CashEarned or 0) + amount
		player:SetAttribute("MatchCash", (player:GetAttribute("MatchCash") or 0) + amount)
		if reason then
			notify(player, "Cash", { Amount = amount, Reason = reason })
		end
	end
	return amount
end

function DataService.SpendCash(player: Player, amount: number): boolean
	local data = DataService.Profiles[player]
	if not data or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	player:SetAttribute("Cash", data.Cash)
	return true
end

function DataService.XPMultiplier(player: Player): number
	local data = DataService.Profiles[player]
	local mult = 1
	if player:GetAttribute("Pass_DoubleXP") then
		mult *= 2
	end
	if data and data.BoostUntil > os.time() then
		mult *= 3
	end
	return mult
end

function DataService.AddXP(player: Player, amount: number)
	local data = DataService.Profiles[player]
	if not data then
		return 0
	end
	amount = math.floor(amount * DataService.XPMultiplier(player))
	data.XP += amount
	player:SetAttribute("MatchXP", (player:GetAttribute("MatchXP") or 0) + amount)
	while data.Level < Config.MaxLevel and data.XP >= Config.XPForLevel(data.Level) do
		data.XP -= Config.XPForLevel(data.Level)
		data.Level += 1
		local reward = data.Level * 50
		DataService.AddCash(player, reward, false)
		notify(player, "LevelUp", { Level = data.Level, Reward = reward })
		if DataService.OnLevelUp then
			DataService.OnLevelUp(player, data.Level)
		end
	end
	player:SetAttribute("Level", data.Level)
	player:SetAttribute("XP", data.XP)
	player:SetAttribute("XPNeeded", Config.XPForLevel(data.Level))
	return amount
end

-- DAILY LOGIN REWARD ---------------------------------------------------------
local DAY = 86400

function DataService.DailyAvailable(player: Player): boolean
	local data = DataService.Profiles[player]
	return data ~= nil and (os.time() // DAY) > (data.Daily.Last // DAY)
end

function DataService.ClaimDaily(player: Player)
	local data = DataService.Profiles[player]
	if not data or not DataService.DailyAvailable(player) then
		return nil
	end
	local today = os.time() // DAY
	local last = data.Daily.Last // DAY
	if today - last == 1 then
		data.Daily.Streak += 1
	else
		data.Daily.Streak = 1
	end
	data.Daily.Last = os.time()
	local index = ((data.Daily.Streak - 1) % #Config.DailyRewards) + 1
	local reward = Config.DailyRewards[index]
	DataService.AddCash(player, reward, true, "DAILY REWARD")
	return data.Daily.Streak, reward
end

-- Autosave every 2 minutes, and save everyone on shutdown.
task.spawn(function()
	while true do
		task.wait(120)
		for _, player in Players:GetPlayers() do
			task.spawn(DataService.Save, player)
		end
	end
end)

game:BindToClose(function()
	local threads = 0
	for _, player in Players:GetPlayers() do
		threads += 1
		task.spawn(function()
			DataService.Save(player)
			threads -= 1
		end)
	end
	local start = os.clock()
	while threads > 0 and os.clock() - start < 25 do
		task.wait(0.1)
	end
end)

return DataService
