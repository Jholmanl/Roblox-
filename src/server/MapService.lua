-- Builds the arena (if you haven't made your own) and picks safe spawn points.
-- To use your own map: put a Model/Folder named "Map" in Workspace with a
-- child folder "Spawns" containing parts. Parts with attribute JumpPad (number)
-- launch players, parts with attribute HealthPack (true) heal & refill ammo.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Combat = require(script.Parent.CombatService)

local MapService = {}
MapService.Spawns = {} :: { CFrame }

local DARK = Color3.fromRGB(40, 44, 54)
local MID = Color3.fromRGB(72, 78, 94)
local LIGHT = Color3.fromRGB(110, 118, 136)
local CRATE = Color3.fromRGB(176, 128, 66)

local function block(parent, name, size: Vector3, cf: CFrame, color: Color3, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function neon(parent, size, cf, color)
	local p = block(parent, "Trim", size, cf, color, Enum.Material.Neon)
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	return p
end

-- A tilted slab from a low point to a high point (top surface touches both).
local function ramp(parent, low: Vector3, high: Vector3, width: number, color)
	local length = (high - low).Magnitude
	local cf = CFrame.lookAt((low + high) / 2, high) * CFrame.new(0, -0.5, 0)
	local p = block(parent, "Ramp", Vector3.new(width, 1, length), cf, color, Enum.Material.DiamondPlate)
	neon(parent, Vector3.new(0.3, 0.3, length), cf * CFrame.new(width / 2, 0.5, 0), Config.Colors.Accent)
	neon(parent, Vector3.new(0.3, 0.3, length), cf * CFrame.new(-width / 2, 0.5, 0), Config.Colors.Accent)
	return p
end

local function build()
	local map = Instance.new("Model")
	map.Name = "Map"
	local geo = Instance.new("Folder")
	geo.Name = "Geometry"
	geo.Parent = map
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = map

	local HALF = 125
	block(geo, "Floor", Vector3.new(HALF * 2 + 10, 2, HALF * 2 + 10), CFrame.new(0, -1, 0), DARK, Enum.Material.Concrete)
	for i = -HALF + 25, HALF - 25, 25 do
		neon(geo, Vector3.new(0.25, 0.05, HALF * 2), CFrame.new(i, 0.03, 0), Config.Colors.Accent2).Transparency = 0.75
		neon(geo, Vector3.new(HALF * 2, 0.05, 0.25), CFrame.new(0, 0.03, i), Config.Colors.Accent2).Transparency = 0.75
	end

	-- outer walls
	for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local x, z = side[1], side[2]
		local size = x ~= 0 and Vector3.new(4, 40, HALF * 2 + 8) or Vector3.new(HALF * 2 + 8, 40, 4)
		local cf = CFrame.new(x * (HALF + 2), 20, z * (HALF + 2))
		block(geo, "Wall", size, cf, MID, Enum.Material.Metal)
		neon(geo, Vector3.new(size.X + 0.2, 0.6, size.Z + 0.2), cf * CFrame.new(0, 6 - 20, 0), Config.Colors.Accent2)
		neon(geo, Vector3.new(size.X + 0.2, 0.6, size.Z + 0.2), cf * CFrame.new(0, 20, 0), Config.Colors.Accent)
	end

	-- center core with 4 ramps
	block(geo, "Core", Vector3.new(20, 10, 20), CFrame.new(0, 5, 0), MID, Enum.Material.Metal)
	neon(geo, Vector3.new(20.4, 0.4, 20.4), CFrame.new(0, 10, 0), Config.Colors.Accent)
	for _, dir in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		ramp(geo, dir * 34, dir * 10 + Vector3.new(0, 10, 0), 8, LIGHT)
		local side = Vector3.new(dir.Z, 0, dir.X)
		block(geo, "CoreCover", Vector3.new(1, 3.5, 1) + side:Abs() * 5, CFrame.new(dir * 9.5 + side * 7 + Vector3.new(0, 11.75, 0)), LIGHT)
		block(geo, "CoreCover", Vector3.new(1, 3.5, 1) + side:Abs() * 5, CFrame.new(dir * 9.5 - side * 7 + Vector3.new(0, 11.75, 0)), LIGHT)
	end
	local beacon = neon(geo, Vector3.new(2, 2, 2), CFrame.new(0, 13, 0), Config.Colors.Accent)
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 2
	light.Color = Config.Colors.Accent
	light.Parent = beacon

	-- mirrored quadrant content
	local crates = {
		{ 22, 40, Vector3.new(6, 6, 6) }, { 40, 22, Vector3.new(6, 6, 6) },
		{ 30, 30, Vector3.new(4, 12, 4) },
		{ 60, 45, Vector3.new(12, 6, 3) }, { 45, 60, Vector3.new(3, 6, 12) },
		{ 100, 40, Vector3.new(6, 6, 6) }, { 40, 100, Vector3.new(6, 6, 6) },
		{ 75, 55, Vector3.new(6, 4, 6) }, { 55, 75, Vector3.new(6, 4, 6) },
		{ 108, 15, Vector3.new(10, 5, 3) }, { 15, 108, Vector3.new(3, 5, 10) },
	}
	for _, sx in { 1, -1 } do
		for _, sz in { 1, -1 } do
			local trim = (sx * sz > 0) and Config.Colors.Accent or Config.Colors.Accent2
			for i, c in crates do
				local size = c[3]
				local cf = CFrame.new(c[1] * sx, size.Y / 2, c[2] * sz)
				local isCrate = size.X == size.Z
				block(geo, "Cover", size, cf, isCrate and CRATE or MID, isCrate and Enum.Material.WoodPlanks or Enum.Material.Metal)
				if not isCrate or i % 2 == 0 then
					neon(geo, Vector3.new(size.X + 0.1, 0.25, size.Z + 0.1), cf * CFrame.new(0, size.Y / 2, 0), trim)
				end
			end

			-- raised corner base
			local base = Vector3.new(88 * sx, 0, 88 * sz)
			block(geo, "Base", Vector3.new(36, 8, 36), CFrame.new(base + Vector3.new(0, 4, 0)), MID, Enum.Material.Metal)
			neon(geo, Vector3.new(36.4, 0.4, 36.4), CFrame.new(base + Vector3.new(0, 8, 0)), trim)
			ramp(geo, Vector3.new(54 * sx, 0, 88 * sz), Vector3.new(70 * sx, 8, 88 * sz), 8, LIGHT)
			ramp(geo, Vector3.new(88 * sx, 0, 54 * sz), Vector3.new(88 * sx, 8, 70 * sz), 8, LIGHT)
			block(geo, "BaseCover", Vector3.new(10, 4, 1.5), CFrame.new(base + Vector3.new(-8 * sx, 10, -15 * sz)), LIGHT)
			block(geo, "BaseCover", Vector3.new(1.5, 4, 10), CFrame.new(base + Vector3.new(-15 * sx, 10, -8 * sz)), LIGHT)

			-- health pack
			local hp = block(geo, "HealthPack", Vector3.new(2.5, 2.5, 2.5), CFrame.new(52 * sx, 1.5, 52 * sz), Config.Colors.Green, Enum.Material.Neon)
			hp.CanCollide = false
			hp:SetAttribute("HealthPack", true)
			local hl = Instance.new("PointLight")
			hl.Color = Config.Colors.Green
			hl.Range = 12
			hl.Parent = hp
		end
	end

	-- jump pads in each lane
	for _, pos in { Vector3.new(70, 0, 0), Vector3.new(-70, 0, 0), Vector3.new(0, 0, 70), Vector3.new(0, 0, -70) } do
		local pad = block(geo, "JumpPad", Vector3.new(0.6, 8, 8), CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Config.Colors.Purple, Enum.Material.Neon)
		pad.Shape = Enum.PartType.Cylinder
		pad:SetAttribute("JumpPad", 115)
		local pl = Instance.new("PointLight")
		pl.Color = Config.Colors.Purple
		pl.Range = 16
		pl.Brightness = 3
		pl.Parent = pad
	end

	-- spawn points around the edge (facing the middle)
	for _, along in { -60, -20, 20, 60 } do
		for _, edge in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local pos
			if edge[1] ~= 0 then
				pos = Vector3.new(edge[1] * 115, 3, along)
			else
				pos = Vector3.new(along, 3, edge[2] * 115)
			end
			local s = Instance.new("Part")
			s.Name = "Spawn"
			s.Anchored = true
			s.CanCollide = false
			s.CanQuery = false
			s.Transparency = 1
			s.Size = Vector3.new(2, 1, 2)
			s.CFrame = CFrame.lookAt(pos, Vector3.new(0, 3, 0))
			s.Parent = spawns
		end
	end

	map.Parent = workspace
	return map
end

local function setupLighting()
	Lighting.ClockTime = 15.5
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(70, 70, 85)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 140)
	Lighting.GlobalShadows = true
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	local function ensure(class, props)
		local inst = Lighting:FindFirstChildOfClass(class) or Instance.new(class)
		for k, v in props do
			inst[k] = v
		end
		inst.Parent = Lighting
	end
	ensure("Atmosphere", { Density = 0.3, Haze = 1.2, Color = Color3.fromRGB(200, 210, 255), Decay = Color3.fromRGB(110, 90, 160) })
	ensure("BloomEffect", { Intensity = 0.8, Size = 30, Threshold = 1.6 })
	ensure("ColorCorrectionEffect", { Saturation = 0.15, Contrast = 0.1, Brightness = 0.02 })
	ensure("SunRaysEffect", { Intensity = 0.05, Spread = 0.6 })
end

function MapService.Init()
	setupLighting()
	local effects = workspace:FindFirstChild("Effects") or Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = workspace

	local map = workspace:FindFirstChild("Map") or build()
	local spawnFolder = map:FindFirstChild("Spawns")
	if spawnFolder then
		for _, s in spawnFolder:GetChildren() do
			if s:IsA("BasePart") then
				table.insert(MapService.Spawns, s.CFrame + Vector3.new(0, 3, 0))
			end
		end
	end
	if #MapService.Spawns == 0 then
		table.insert(MapService.Spawns, CFrame.new(0, 20, 0))
	end
	Combat.SetupPickups(map)
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
