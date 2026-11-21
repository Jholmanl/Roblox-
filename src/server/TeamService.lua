-- Game modes + teams.
--   FFA  : everyone for themselves, spawns all over the map
--   TDM  : ALPHA vs BRAVO, spawns at opposite ends
--   TTDM : ALPHA vs BRAVO vs CHARLIE
-- Team of each fighter lives in entity.Team (nil in FFA) and is mirrored to the
-- "Team" attribute on the Player / bot holder / bot character for clients.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local TeamService = {}
TeamService.Mode = Config.ModeOrder[1]
TeamService.Fighters = {} -- set of every entity (players and bots)

-- Roblox Team objects so overhead names get team colors
local teamObjects = {}
for _, id in { "A", "B", "C" } do
	local info = Config.Teams[id]
	local t = Teams:FindFirstChild(info.Name) or Instance.new("Team")
	t.Name = info.Name
	t.TeamColor = BrickColor.new(info.Brick)
	t.AutoAssignable = false
	t.Parent = Teams
	teamObjects[id] = t
end

function TeamService.ModeDef()
	return Config.Modes[TeamService.Mode]
end

function TeamService.TeamList()
	return TeamService.ModeDef().Teams
end

function TeamService.IsTeamMode(): boolean
	return #TeamService.TeamList() > 0
end

-- true when a and b should be able to hurt each other
function TeamService.Enemies(a, b): boolean
	if a == nil or b == nil then
		return true -- environment / unknown attacker
	end
	if a == b then
		return false
	end
	return a.Team == nil or a.Team ~= b.Team
end

local function apply(entity, team)
	entity.Team = team
	entity.Holder:SetAttribute("Team", team)
	if entity.Character then
		entity.Character:SetAttribute("Team", team)
	end
	local player = entity.Player
	if player then
		player:SetAttribute("Team", team)
		if team then
			player.Neutral = false
			player.Team = teamObjects[team]
		else
			player.Team = nil
			player.Neutral = true
		end
	end
end

function TeamService.Count(team: string): number
	local n = 0
	for entity in TeamService.Fighters do
		if entity.Team == team then
			n += 1
		end
	end
	return n
end

function TeamService.Smallest(): string?
	local best, bestCount = nil, math.huge
	for _, team in TeamService.TeamList() do
		local c = TeamService.Count(team)
		if c < bestCount then
			best, bestCount = team, c
		end
	end
	return best
end

function TeamService.Largest(): string?
	local best, bestCount = nil, -1
	for _, team in TeamService.TeamList() do
		local c = TeamService.Count(team)
		if c > bestCount then
			best, bestCount = team, c
		end
	end
	return best
end

function TeamService.Register(entity)
	TeamService.Fighters[entity] = true
	apply(entity, nil)
	apply(entity, TeamService.Smallest())
end

function TeamService.Unregister(entity)
	TeamService.Fighters[entity] = nil
end

-- Re-deal every fighter onto balanced teams (players first, then bots).
function TeamService.Rebalance()
	local players, bots = {}, {}
	for entity in TeamService.Fighters do
		apply(entity, nil)
		table.insert(entity.Player and players or bots, entity)
	end
	for _, list in { players, bots } do
		for i = #list, 2, -1 do
			local j = math.random(1, i)
			list[i], list[j] = list[j], list[i]
		end
		for _, entity in list do
			apply(entity, TeamService.Smallest())
		end
	end
end

function TeamService.SetMode(mode: string)
	if not Config.Modes[mode] then
		return
	end
	TeamService.Mode = mode
	ReplicatedStorage:SetAttribute("Mode", mode)
	TeamService.Rebalance()
	TeamService.ResetScores()
end

function TeamService.ResetScores()
	for _, id in { "A", "B", "C" } do
		ReplicatedStorage:SetAttribute("Score_" .. id, 0)
	end
end

function TeamService.AddScore(team: string?, amount: number)
	if team then
		ReplicatedStorage:SetAttribute("Score_" .. team, (ReplicatedStorage:GetAttribute("Score_" .. team) or 0) + amount)
	end
end

function TeamService.Score(team: string): number
	return ReplicatedStorage:GetAttribute("Score_" .. team) or 0
end

-- Winning team by score (nil on a draw or in FFA)
function TeamService.Leader(): string?
	local best, bestScore, tie = nil, -1, false
	for _, team in TeamService.TeamList() do
		local s = TeamService.Score(team)
		if s > bestScore then
			best, bestScore, tie = team, s, false
		elseif s == bestScore then
			tie = true
		end
	end
	return (not tie) and best or nil
end

Players.PlayerRemoving:Connect(function(player)
	for entity in TeamService.Fighters do
		if entity.Player == player then
			TeamService.Fighters[entity] = nil
		end
	end
end)

ReplicatedStorage:SetAttribute("Mode", TeamService.Mode)
TeamService.ResetScores()

return TeamService
