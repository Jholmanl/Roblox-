-- Match loop: VOTE (map + mode) -> WARMUP -> LIVE MATCH -> RESULTS -> repeat.
-- State is replicated through attributes on ReplicatedStorage:
--   MatchState ("Voting" | "Intermission" | "Active" | "Results"), MatchEnd (server time),
--   Leader / LeaderScore.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local AchievementService = require(script.Parent.AchievementService)
local TeamService = require(script.Parent.TeamService)

local RoundService = {}
RoundService.State = "Intermission"
RoundService.FirstBlood = false
RoundService.ForcedWinner = nil
-- Injected by Main:
RoundService.GetHolders = function()
	return {}
end
RoundService.OnEntityDied = function(_entity) end
RoundService.RespawnAll = function() end
RoundService.Map = nil -- MapService (injected)

local function setState(state: string, duration: number)
	RoundService.State = state
	ReplicatedStorage:SetAttribute("MatchState", state)
	ReplicatedStorage:SetAttribute("MatchEnd", workspace:GetServerTimeNow() + duration)
end

local function timeLeft(): number
	return (ReplicatedStorage:GetAttribute("MatchEnd") or 0) - workspace:GetServerTimeNow()
end

function RoundService.IsCounting(): boolean
	return RoundService.State == "Active"
end

function RoundService.TakeFirstBlood(): boolean
	if RoundService.State == "Active" and not RoundService.FirstBlood then
		RoundService.FirstBlood = true
		return true
	end
	return false
end

function RoundService.OnDeath(entity)
	RoundService.OnEntityDied(entity)
end

local function killsToWin(): number
	return TeamService.ModeDef().KillsToWin
end

function RoundService.OnKill(killer)
	if RoundService.State ~= "Active" then
		return
	end
	if TeamService.IsTeamMode() then
		if killer.Team and TeamService.Score(killer.Team) >= killsToWin() then
			RoundService.EndMatch(killer)
		end
	elseif (killer.Holder:GetAttribute("Kills") or 0) >= killsToWin() then
		RoundService.EndMatch(killer)
	end
end

local function ranking()
	local list = {}
	for _, h in RoundService.GetHolders() do
		local holder = h.Holder
		table.insert(list, {
			Name = h.Name,
			IsBot = h.IsBot,
			Player = h.Player,
			VIP = holder:GetAttribute("Pass_VIP") == true,
			Team = holder:GetAttribute("Team"),
			Kills = holder:GetAttribute("Kills") or 0,
			Deaths = holder:GetAttribute("Deaths") or 0,
			Score = holder:GetAttribute("Score") or 0,
		})
	end
	table.sort(list, function(a, b)
		if a.Score ~= b.Score then
			return a.Score > b.Score
		end
		return a.Kills > b.Kills
	end)
	return list
end

function RoundService.EndMatch(winnerEntity)
	if RoundService.State ~= "Active" then
		return
	end
	RoundService.ForcedWinner = winnerEntity
	setState("Results", Config.ResultsLength)
	local mapId = ReplicatedStorage:GetAttribute("MapId") or "Arena"

	local list = ranking()
	if winnerEntity then
		for i, row in list do
			if row.Name == winnerEntity.Name then
				table.remove(list, i)
				table.insert(list, 1, row)
				break
			end
		end
	end

	local publicRows = {}
	for i, row in list do
		publicRows[i] = { Name = row.Name, IsBot = row.IsBot, VIP = row.VIP, Kills = row.Kills, Deaths = row.Deaths, Score = row.Score, Team = row.Team }
	end

	local teamMode = TeamService.IsTeamMode()
	local winnerTeam = nil
	if teamMode then
		winnerTeam = (winnerEntity and winnerEntity.Team) or TeamService.Leader()
	end
	local scores = {}
	for _, team in TeamService.TeamList() do
		scores[team] = TeamService.Score(team)
	end

	for place, row in list do
		local player = row.Player
		if player and player.Parent then
			AchievementService.Add(player, "Matches", 1)
			DataService.AddXP(player, Config.MatchPlayXP)
			local won = (teamMode and winnerTeam ~= nil and row.Team == winnerTeam) or (not teamMode and place == 1)
			if won then
				AchievementService.Add(player, "Wins", 1)
				AchievementService.Add(player, "Wins_" .. mapId, 1)
				DataService.AddCash(player, Config.WinCash, true, "VICTORY")
				DataService.AddXP(player, Config.WinXP)
			end
			if place <= 3 then
				AchievementService.Add(player, "Top3", 1)
				DataService.AddCash(player, Config.Top3Cash, true, "TOP 3")
			end
			Remotes.MatchResults:FireClient(player, {
				Rows = publicRows,
				Winner = list[1] and list[1].Name or "Nobody",
				Place = place,
				Mode = TeamService.Mode,
				WinnerTeam = winnerTeam,
				MyTeam = row.Team,
				Won = won,
				Scores = scores,
				Nuke = winnerEntity ~= nil and RoundService.NukeEnding == true,
				Cash = player:GetAttribute("MatchCash") or 0,
				XP = player:GetAttribute("MatchXP") or 0,
				Kills = row.Kills,
				Deaths = row.Deaths,
				Score = row.Score,
			})
			task.spawn(DataService.Save, player)
		end
	end
end

local function resetMatchStats()
	TeamService.ResetScores()
	for _, h in RoundService.GetHolders() do
		for _, attr in { "Kills", "Deaths", "Score", "Streak" } do
			h.Holder:SetAttribute(attr, 0)
		end
		if h.Player then
			h.Player:SetAttribute("MatchCash", 0)
			h.Player:SetAttribute("MatchXP", 0)
		end
	end
end

local function updateLeader()
	local list = ranking()
	local top = list[1]
	ReplicatedStorage:SetAttribute("Leader", top and top.Name or "")
	ReplicatedStorage:SetAttribute("LeaderScore", top and top.Kills or 0)
	ReplicatedStorage:SetAttribute("KillsToWin", killsToWin())
end

function RoundService.Start()
	local function runVote()
		if not RoundService.Map then
			return
		end
		RoundService.Map.StartVote()
		setState("Voting", Config.VoteLength)
		while timeLeft() > 0 do
			task.wait(0.25)
		end
		local nextMap, nextMode = RoundService.Map.EndVote()
		if nextMode and nextMode ~= TeamService.Mode then
			TeamService.SetMode(nextMode)
		end
		if nextMap ~= ReplicatedStorage:GetAttribute("MapId") then
			RoundService.Map.Load(nextMap)
		end
		updateLeader()
		RoundService.RespawnAll()
	end

	task.spawn(function()
		task.wait(1)
		runVote()
		while true do
			-- WARMUP (kills still earn XP, cash & achievements, but not match score)
			resetMatchStats()
			setState("Intermission", Config.IntermissionLength)
			while timeLeft() > 0 do
				task.wait(0.25)
			end

			-- LIVE MATCH
			resetMatchStats()
			RoundService.FirstBlood = false
			RoundService.ForcedWinner = nil
			RoundService.NukeEnding = false
			setState("Active", Config.MatchLength)
			local mode = TeamService.ModeDef()
			local goal = TeamService.IsTeamMode() and ("First team to " .. mode.KillsToWin .. " kills wins") or ("First to " .. mode.KillsToWin .. " kills wins")
			Remotes.Notify:FireAllClients("Announce", { Text = mode.Name, Sub = goal, Color = Config.Colors.Accent, Icon = "⚔️" })
			RoundService.RespawnAll()
			while RoundService.State == "Active" and timeLeft() > 0 do
				updateLeader()
				task.wait(0.25)
			end
			if RoundService.State == "Active" then
				RoundService.EndMatch(nil)
			end

			-- RESULTS, then everyone votes on the next map + mode
			while timeLeft() > 0 do
				task.wait(0.25)
			end
			runVote()
		end
	end)
end

return RoundService
