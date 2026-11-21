-- NEON ARENA: the original symmetrical arena (fast, close-quarters).
local MapKit = require(script.Parent.MapKit)
local M = Enum.Material
local rgb = Color3.fromRGB

local Map = {
	Id = "Arena",
	Name = "NEON ARENA",
	Desc = "Compact neon arena with jump pads. Pure gunplay.",
	Icon = "⚡",
	Lighting = {
		ClockTime = 15.5, Brightness = 2.5,
		Ambient = rgb(70, 70, 85), OutdoorAmbient = rgb(120, 120, 140),
		Atmosphere = { Density = 0.3, Haze = 1.2, Color = rgb(200, 210, 255), Decay = rgb(110, 90, 160) },
		Tint = rgb(255, 255, 255), Saturation = 0.15,
	},
}

local ACCENT = rgb(255, 198, 26)
local ACCENT2 = rgb(0, 204, 255)
local DARK = rgb(40, 44, 54)
local MID = rgb(72, 78, 94)
local LIGHT = rgb(110, 118, 136)
local CRATE = rgb(176, 128, 66)

function Map.Build()
	local kit = MapKit.new(3)
	local HALF = 125
	local holes = kit:Tunnel({
		Axis = "Z", Cross = 0, From = -118, To = 118, Floor = -14, Width = 14, Height = 9, Style = "Subway",
		Entrances = { { At = -104, Dir = 1 }, { At = 104, Dir = -1 } },
	})
	-- a deeper cross tunnel passes under the first one
	local crossHoles = kit:Tunnel({
		Axis = "X", Cross = 0, From = -118, To = 118, Floor = -26, Width = 14, Height = 9, Style = "Sewer",
		Entrances = { { At = -110, Dir = 1 }, { At = 110, Dir = -1 } },
	})
	for _, h in crossHoles do
		table.insert(holes, h)
	end
	kit:Ground(0, -HALF - 5, HALF + 5, -HALF - 5, HALF + 5, 2, holes, DARK, M.Concrete)
	for i = -HALF + 25, HALF - 25, 25 do
		kit:Neon(Vector3.new(0.25, 0.05, HALF * 2), CFrame.new(i, 0.03, 0), ACCENT2).Transparency = 0.75
		kit:Neon(Vector3.new(HALF * 2, 0.05, 0.25), CFrame.new(0, 0.03, i), ACCENT2).Transparency = 0.75
	end
	for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local x, z = side[1], side[2]
		local size = x ~= 0 and Vector3.new(4, 40, HALF * 2 + 8) or Vector3.new(HALF * 2 + 8, 40, 4)
		local cf = CFrame.new(x * (HALF + 2), 20, z * (HALF + 2))
		kit:Part(size, cf, MID, M.Metal)
		kit:Neon(Vector3.new(size.X + 0.2, 0.6, size.Z + 0.2), cf * CFrame.new(0, -14, 0), ACCENT2)
		kit:Neon(Vector3.new(size.X + 0.2, 0.6, size.Z + 0.2), cf * CFrame.new(0, 20, 0), ACCENT)
	end

	kit:Part(Vector3.new(20, 10, 20), CFrame.new(0, 5, 0), MID, M.Metal)
	kit:Neon(Vector3.new(20.4, 0.4, 20.4), CFrame.new(0, 10, 0), ACCENT)
	for _, dir in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		kit:Ramp(dir * 34, dir * 10 + Vector3.new(0, 10, 0), 8, LIGHT, M.DiamondPlate)
		local side = Vector3.new(dir.Z, 0, dir.X)
		for _, s in { 1, -1 } do
			kit:Part(Vector3.new(1, 3.5, 1) + side:Abs() * 5, CFrame.new(dir * 9.5 + side * 7 * s + Vector3.new(0, 11.75, 0)), LIGHT, M.Metal)
		end
	end
	local beacon = kit:Neon(Vector3.new(2, 2, 2), CFrame.new(0, 13, 0), ACCENT)
	kit:Light(beacon, "PointLight", ACCENT, 40, 2)

	local crates = {
		{ 22, 40, Vector3.new(6, 6, 6) }, { 40, 22, Vector3.new(6, 6, 6) }, { 30, 30, Vector3.new(4, 12, 4) },
		{ 60, 45, Vector3.new(12, 6, 3) }, { 45, 60, Vector3.new(3, 6, 12) }, { 100, 40, Vector3.new(6, 6, 6) },
		{ 40, 100, Vector3.new(6, 6, 6) }, { 75, 55, Vector3.new(6, 4, 6) }, { 55, 75, Vector3.new(6, 4, 6) },
		{ 108, 15, Vector3.new(10, 5, 3) }, { 15, 108, Vector3.new(3, 5, 10) },
	}
	for _, sx in { 1, -1 } do
		for _, sz in { 1, -1 } do
			local trim = (sx * sz > 0) and ACCENT or ACCENT2
			for i, c in crates do
				local size = c[3]
				local cf = CFrame.new(c[1] * sx, size.Y / 2, c[2] * sz)
				local isCrate = size.X == size.Z
				kit:Part(size, cf, isCrate and CRATE or MID, isCrate and M.WoodPlanks or M.Metal)
				if not isCrate or i % 2 == 0 then
					kit:Neon(Vector3.new(size.X + 0.1, 0.25, size.Z + 0.1), cf * CFrame.new(0, size.Y / 2, 0), trim)
				end
			end
			local base = Vector3.new(88 * sx, 0, 88 * sz)
			kit:Part(Vector3.new(36, 8, 36), CFrame.new(base + Vector3.new(0, 4, 0)), MID, M.Metal)
			kit:Neon(Vector3.new(36.4, 0.4, 36.4), CFrame.new(base + Vector3.new(0, 8, 0)), trim)
			kit:Ramp(Vector3.new(54 * sx, 0, 88 * sz), Vector3.new(70 * sx, 8, 88 * sz), 8, LIGHT, M.DiamondPlate)
			kit:Ramp(Vector3.new(88 * sx, 0, 54 * sz), Vector3.new(88 * sx, 8, 70 * sz), 8, LIGHT, M.DiamondPlate)
			kit:Part(Vector3.new(10, 4, 1.5), CFrame.new(base + Vector3.new(-8 * sx, 10, -15 * sz)), LIGHT, M.Metal)
			kit:Part(Vector3.new(1.5, 4, 10), CFrame.new(base + Vector3.new(-15 * sx, 10, -8 * sz)), LIGHT, M.Metal)
			kit:HealthPack(Vector3.new(52 * sx, 0, 52 * sz))
		end
	end
	for _, pos in { Vector3.new(70, 0, 0), Vector3.new(-70, 0, 0), Vector3.new(0, 0, 70), Vector3.new(0, 0, -70) } do
		kit:JumpPad(pos, 115)
	end
	-- ladders up the corner bases + sandbag cover in the lanes
	for _, sx in { 1, -1 } do
		for _, sz in { 1, -1 } do
			kit:Ladder(Vector3.new(88 * sx - 19 * sx, 0, 88 * sz + 8 * sz), 12)
		end
	end
	for _, s in { { 40, 0, 0 }, { -40, 0, 0 }, { 0, 40, 90 }, { 0, -40, 90 } } do
		kit:Sandbags(CFrame.new(s[1], 0, s[2]) * CFrame.Angles(0, math.rad(s[3]), 0), 10, 3)
	end
	-- FREE FOR ALL spawns around the edges + TRIPLE TEAM base on the west side
	local ffa = {}
	for _, along in { -60, -20, 20, 60 } do
		for _, edge in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			table.insert(ffa, edge[1] ~= 0 and Vector3.new(edge[1] * 115, 0, along) or Vector3.new(along, 0, edge[2] * 115))
		end
	end
	kit:FFASpawns(ffa)
	kit:SpawnBase(Vector3.new(-114, 0, 0), Vector3.new(0, 0, 0), "C", 100)
	kit:Mountains(HALF + 10, HALF + 10, { Margin = 70, GroundY = -0.5 })
	-- TEAM SPAWNS at both ends
	kit:SpawnBase(Vector3.new(0, 0, -114), Vector3.new(0, 0, 0), "A", 110)
	kit:SpawnBase(Vector3.new(0, 0, 114), Vector3.new(0, 0, 0), "B", 110)
	kit:Boundary(HALF + 4, HALF + 4, 260)
	return kit
end

return Map
