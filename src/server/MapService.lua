-- Loads maps (with per-map lighting), runs map voting, and picks safe spawns.
-- Map modules live in Server/Maps. To use a hand-built map instead, put a
-- Model named "Map" in Workspace with a "Spawns" folder (it is used as-is).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Combat = require(script.Parent.CombatService)
local TeamService = require(script.Parent.TeamService)
local Config = require(Shared.Config)

local MapsFolder = script.Parent.Maps
local MapService = {}
MapService.Spawns = {} -- list of { CFrame = CFrame, Team = "A"|"B"|"C"|"FFA"|nil }
MapService.Current = nil
MapService.OnMapLoaded = nil :: ((Instance) -> ())?
MapService.Order = { "Downtown", "Harbor", "Timberline", "Arena" }
MapService.Defs = {}
for _, id in MapService.Order do
	MapService.Defs[id] = require(MapsFolder:WaitForChild(id))
end

local function ensure(class: string, parent: Instance)
	local inst = parent:FindFirstChildOfClass(class) or Instance.new(class)
	inst.Parent = parent
	return inst
end

local function applyLighting(L)
	Lighting.ClockTime = L.ClockTime or 14
	Lighting.Brightness = L.Brightness or 2.5
	Lighting.Ambient = L.Ambient or Color3.fromRGB(70, 70, 80)
	Lighting.OutdoorAmbient = L.OutdoorAmbient or Color3.fromRGB(120, 120, 130)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ShadowSoftness = 0.25
	Lighting.ExposureCompensation = L.Exposure or 0
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	local atmo = ensure("Atmosphere", Lighting)
	local a = L.Atmosphere or {}
	atmo.Density = a.Density or 0.3
	atmo.Haze = a.Haze or 1
	atmo.Color = a.Color or Color3.fromRGB(200, 210, 230)
	atmo.Decay = a.Decay or Color3.fromRGB(100, 100, 130)
	atmo.Glare = 0.2
	local bloom = ensure("BloomEffect", Lighting)
	bloom.Intensity = 0.9
	bloom.Size = 30
	bloom.Threshold = 1.25 -- lets neon windows / lamps glow
	local cc = ensure("ColorCorrectionEffect", Lighting)
	cc.Saturation = L.Saturation or 0.15
	cc.Contrast = 0.12
	cc.Brightness = 0.02
	cc.TintColor = L.Tint or Color3.new(1, 1, 1)
	local rays = ensure("SunRaysEffect", Lighting)
	rays.Intensity = 0.06
	rays.Spread = 0.7
	local dof = ensure("DepthOfFieldEffect", Lighting)
	dof.FarIntensity = 0.12
	dof.FocusDistance = 120
	dof.InFocusRadius = 120
	dof.NearIntensity = 0
	pcall(function()
		local clouds = ensure("Clouds", workspace.Terrain)
		clouds.Cover = 0.55
		clouds.Density = 0.6
	end)
	pcall(function()
		workspace.Terrain.Decoration = true -- animated grass blades
	end)
	workspace.Terrain.WaterColor = Color3.fromRGB(30, 110, 140)
	workspace.Terrain.WaterTransparency = 0.6
	workspace.Terrain.WaterWaveSize = 0.15
	workspace.Terrain.WaterReflectance = 0.6
end

-- Snap spawn markers to whatever surface is under them.
-- Snap a spawn marker onto the floor right under it. The ray starts only a few
-- studs above the marker so it never lands on a roof, canopy, crane or tree.
local function groundSpawn(marker: BasePart): CFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace:FindFirstChild("Effects"), workspace:FindFirstChild("Bots"), workspace:FindFirstChild("Vehicles") }
	local pos = marker.Position
	local result = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	if not result then
		-- marker might be buried in a hill: look a little higher, but never more than 14 studs up
		local high = workspace:Raycast(pos + Vector3.new(0, 14, 0), Vector3.new(0, -20, 0), params)
		if high and high.Position.Y < pos.Y + 14 then
			result = high
		end
	end
	local y = result and result.Position.Y + 3.2 or pos.Y
	return CFrame.new(pos.X, y, pos.Z) * marker.CFrame.Rotation
end

function MapService.Load(id: string)
	local def = MapService.Defs[id]
	if not def then
		warn("[MapService] unknown map " .. tostring(id))
		return
	end
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local effects = workspace:FindFirstChild("Effects")
	if effects then
		effects:ClearAllChildren()
	else
		effects = Instance.new("Folder")
		effects.Name = "Effects"
		effects.Parent = workspace
	end
	workspace.Terrain:Clear()

	local kit = def.Build()
	local map = kit.Model
	map.Parent = workspace
	MapService.Current = def
	applyLighting(def.Lighting or {})

	MapService.CollectSpawns(map)
	Combat.SetupPickups(map)
	ReplicatedStorage:SetAttribute("MapId", def.Id)
	ReplicatedStorage:SetAttribute("MapName", def.Name)
	if MapService.OnMapLoaded then
		MapService.OnMapLoaded(map)
	end
	Remotes.Notify:FireAllClients("Announce", { Text = def.Name, Sub = def.Desc, Color = Color3.fromRGB(255, 198, 26), Icon = def.Icon })
end

function MapService.CollectSpawns(map: Instance)
	MapService.Spawns = {}
	local folder = map:FindFirstChild("Spawns")
	for _, s in folder and folder:GetChildren() or {} do
		if s:IsA("BasePart") then
			table.insert(MapService.Spawns, { CFrame = groundSpawn(s), Team = s:GetAttribute("Team") })
		end
	end
	if #MapService.Spawns == 0 then
		table.insert(MapService.Spawns, { CFrame = CFrame.new(0, 30, 0) })
	end
end

-- VOTING -----------------------------------------------------------------------
local votes = {} :: { [Player]: string }
local modeVotes = {} :: { [Player]: string }
local voteCursor = 0
local options = {} :: { string }

local function publishVotes()
	for _, id in MapService.Order do
		ReplicatedStorage:SetAttribute("Votes_" .. id, 0)
	end
	for _, id in Config.ModeOrder do
		ReplicatedStorage:SetAttribute("Votes_" .. id, 0)
	end
	for _, list in { votes, modeVotes } do
		for _, id in list do
			ReplicatedStorage:SetAttribute("Votes_" .. id, (ReplicatedStorage:GetAttribute("Votes_" .. id) or 0) + 1)
		end
	end
end

function MapService.StartVote()
	votes = {}
	modeVotes = {}
	options = {}
	-- 3 maps per vote, sliding through the map list so every round offers a new set
	local n = #MapService.Order
	for i = 0, math.min(3, n) - 1 do
		table.insert(options, MapService.Order[(voteCursor + i) % n + 1])
	end
	voteCursor = (voteCursor + math.min(3, n)) % n
	ReplicatedStorage:SetAttribute("VoteOptions", table.concat(options, ","))
	publishVotes()
end

local function winner(list, choices, fallback)
	local counts = {}
	for _, id in list do
		counts[id] = (counts[id] or 0) + 1
	end
	local best, bestCount = fallback, -1
	for _, id in choices do
		local c = (counts[id] or 0) + math.random() * 0.5 -- random tie-break
		if c > bestCount then
			best, bestCount = id, c
		end
	end
	return best
end

-- Returns the winning map id and game mode id.
function MapService.EndVote(): (string, string)
	local map = winner(votes, options, options[1] or MapService.Order[1])
	-- no mode votes: rotate to the next mode so every mode gets played
	local mode
	if next(modeVotes) == nil then
		local i = table.find(Config.ModeOrder, TeamService.Mode) or 0
		mode = Config.ModeOrder[i % #Config.ModeOrder + 1]
	else
		mode = winner(modeVotes, Config.ModeOrder, TeamService.Mode)
	end
	ReplicatedStorage:SetAttribute("VoteOptions", "")
	return map, mode
end

Remotes.Vote.OnServerEvent:Connect(function(player, id)
	if typeof(id) ~= "string" then
		return
	end
	if table.find(options, id) then
		votes[player] = id
		publishVotes()
	elseif Config.Modes[id] then
		modeVotes[player] = id
		publishVotes()
	end
end)
Players.PlayerRemoving:Connect(function(player)
	votes[player] = nil
	modeVotes[player] = nil
end)

function MapService.Init()
	local existing = workspace:FindFirstChild("Map")
	if existing and existing:FindFirstChild("Spawns") then
		-- hand-made map in the place file
		MapService.CollectSpawns(existing)
		Combat.SetupPickups(existing)
		applyLighting({})
		if MapService.OnMapLoaded then
			MapService.OnMapLoaded(existing)
		end
		return
	end
	MapService.Load(MapService.Order[1])
end

-- Spawn for this fighter in the current mode (team base, or anywhere in FFA),
-- picking the point farthest from living enemies (with a bit of randomness).
function MapService.PickSpawn(forEntity): CFrame
	local want = (forEntity and forEntity.Team) or (TeamService.IsTeamMode() and nil or "FFA")
	local candidates = {}
	for _, sp in MapService.Spawns do
		if sp.Team == want then
			table.insert(candidates, sp)
		end
	end
	if #candidates == 0 then
		-- maps without FFA points fall back to every spawn
		candidates = MapService.Spawns
	end
	local scored = {}
	for _, sp in candidates do
		local cf = sp.CFrame
		local nearest = math.huge
		for _, other in Combat.Entities do
			if other ~= forEntity and TeamService.Enemies(forEntity, other) and Combat.IsAlive(other) then
				nearest = math.min(nearest, (other.Root.Position - cf.Position).Magnitude)
			end
		end
		table.insert(scored, { cf = cf, score = math.min(nearest, 400) + math.random() * 25 })
	end
	table.sort(scored, function(a, b)
		return a.score > b.score
	end)
	return scored[1].cf
end

-- Any spawn point (bots use these as places to wander to)
function MapService.RandomPoint(): Vector3
	local sp = MapService.Spawns[math.random(1, #MapService.Spawns)]
	return sp.CFrame.Position
end

return MapService
