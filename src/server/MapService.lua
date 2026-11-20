-- Loads maps (with per-map lighting), runs map voting, and picks safe spawns.
-- Map modules live in Server/Maps. To use a hand-built map instead, put a
-- Model named "Map" in Workspace with a "Spawns" folder (it is used as-is).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Combat = require(script.Parent.CombatService)

local MapsFolder = script.Parent.Maps
local MapService = {}
MapService.Spawns = {} :: { CFrame }
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
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
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
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.5
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
local function groundSpawn(marker: BasePart): CFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace:FindFirstChild("Effects"), workspace:FindFirstChild("Bots") }
	local origin = marker.Position + Vector3.new(0, 40, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -120, 0), params)
	local y = result and result.Position.Y + 3.5 or marker.Position.Y + 3
	return CFrame.new(marker.Position.X, y, marker.Position.Z) * marker.CFrame.Rotation
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

	MapService.Spawns = {}
	for _, s in map.Spawns:GetChildren() do
		if s:IsA("BasePart") then
			table.insert(MapService.Spawns, groundSpawn(s))
		end
	end
	if #MapService.Spawns == 0 then
		table.insert(MapService.Spawns, CFrame.new(0, 30, 0))
	end
	Combat.SetupPickups(map)
	ReplicatedStorage:SetAttribute("MapId", def.Id)
	ReplicatedStorage:SetAttribute("MapName", def.Name)
	if MapService.OnMapLoaded then
		MapService.OnMapLoaded(map)
	end
	Remotes.Notify:FireAllClients("Announce", { Text = def.Name, Sub = def.Desc, Color = Color3.fromRGB(255, 198, 26), Icon = def.Icon })
end

-- VOTING -----------------------------------------------------------------------
local votes = {} :: { [Player]: string }
local options = {} :: { string }

local function publishVotes()
	for _, id in MapService.Order do
		ReplicatedStorage:SetAttribute("Votes_" .. id, 0)
	end
	for _, id in votes do
		ReplicatedStorage:SetAttribute("Votes_" .. id, (ReplicatedStorage:GetAttribute("Votes_" .. id) or 0) + 1)
	end
end

function MapService.StartVote()
	votes = {}
	options = {}
	local pool = table.clone(MapService.Order)
	for i = #pool, 2, -1 do
		local j = math.random(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	for i = 1, math.min(3, #pool) do
		table.insert(options, pool[i])
	end
	ReplicatedStorage:SetAttribute("VoteOptions", table.concat(options, ","))
	publishVotes()
end

function MapService.EndVote(): string
	local counts = {}
	for _, id in votes do
		counts[id] = (counts[id] or 0) + 1
	end
	local best, bestCount = options[1] or MapService.Order[1], -1
	for _, id in options do
		local c = (counts[id] or 0) + math.random() * 0.5 -- random tie-break
		if c > bestCount then
			best, bestCount = id, c
		end
	end
	ReplicatedStorage:SetAttribute("VoteOptions", "")
	return best
end

Remotes.Vote.OnServerEvent:Connect(function(player, id)
	if typeof(id) == "string" and table.find(options, id) then
		votes[player] = id
		publishVotes()
	end
end)
Players.PlayerRemoving:Connect(function(player)
	votes[player] = nil
end)

function MapService.Init()
	local existing = workspace:FindFirstChild("Map")
	if existing and existing:FindFirstChild("Spawns") then
		-- hand-made map in the place file
		for _, s in existing.Spawns:GetChildren() do
			if s:IsA("BasePart") then
				table.insert(MapService.Spawns, groundSpawn(s))
			end
		end
		Combat.SetupPickups(existing)
		applyLighting({})
		if MapService.OnMapLoaded then
			MapService.OnMapLoaded(existing)
		end
		return
	end
	MapService.Load(MapService.Order[1])
end

-- Spawn point farthest from living enemies (with a bit of randomness).
function MapService.PickSpawn(forEntity): CFrame
	local scored = {}
	for _, cf in MapService.Spawns do
		local nearest = math.huge
		for _, other in Combat.Entities do
			if other ~= forEntity and Combat.IsAlive(other) then
				nearest = math.min(nearest, (other.Root.Position - cf.Position).Magnitude)
			end
		end
		table.insert(scored, { cf = cf, score = nearest + math.random() * 25 })
	end
	table.sort(scored, function(a, b)
		return a.score > b.score
	end)
	return scored[1].cf
end

return MapService
