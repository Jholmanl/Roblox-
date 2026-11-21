-- TIMBERLINE: forest valley with a river, bridges, cabins, watchtowers and jeeps.
local MapKit = require(script.Parent.MapKit)
local M = Enum.Material
local P = MapKit.Palette
local rgb = Color3.fromRGB

local Map = {
	Id = "Timberline",
	Name = "TIMBERLINE",
	Desc = "Forest valley split by a river. Snipe from the towers.",
	Icon = "🌲",
	Lighting = {
		ClockTime = 16.4, Brightness = 2.6,
		Ambient = rgb(80, 90, 80), OutdoorAmbient = rgb(130, 140, 130),
		Atmosphere = { Density = 0.35, Haze = 1.4, Color = rgb(200, 225, 210), Decay = rgb(90, 120, 110) },
		Tint = rgb(245, 255, 240), Saturation = 0.2, Contrast = 0.2, SunRays = 0.22, WaterColor = rgb(30, 100, 95),
	},
}

local HALF = 160

local function riverX(z: number): number
	return 38 * math.sin(z / 70)
end

function Map.Build()
	local kit = MapKit.new(21)
	local rng = kit.Rng

	-- ground + hills
	kit:Fill(M.Grass, CFrame.new(0, -8, 0), Vector3.new(HALF * 2 + 60, 16, HALF * 2 + 60))
	local avoid = {} -- circles {x, z, r} kept flat & free of trees

	local structures = {
		{ "Cabin", -100, -60 }, { "Cabin", -128, 60 }, { "Cabin", 98, -62 }, { "Cabin", 128, 58 },
		{ "Tower", -60, 105 }, { "Tower", 42, -60 }, { "Tower", 140, -8 },
		{ "Camp", -80, -12 }, { "Lumber", 75, -108 },
	}
	for _, s in structures do
		table.insert(avoid, { s[2], s[3], s[1] == "Lumber" and 30 or 24 })
	end
	-- keep tunnel entrances and both spawn bases clear
	for _, tx in { -112, 112 } do
		for _, tz in { -108, -20, 20, 108 } do
			table.insert(avoid, { tx, tz, 16 })
		end
	end
	table.insert(avoid, { -90, -135, 40 })
	table.insert(avoid, { 90, 135, 40 })

	local function blocked(x: number, z: number, pad: number): boolean
		if math.abs(x - riverX(z)) < 24 + pad then
			return true
		end
		if math.abs(z) < 12 + pad then
			return true -- road
		end
		for _, a in avoid do
			if (Vector3.new(x - a[1], 0, z - a[2])).Magnitude < a[3] + pad then
				return true
			end
		end
		return false
	end

	for _ = 1, 14 do
		local x, z = rng:NextNumber(-170, 170), rng:NextNumber(-170, 170)
		local r = rng:NextNumber(22, 38)
		if not blocked(x, z, r * 0.6) then
			kit:FillBall(M.Grass, Vector3.new(x, -r * 0.78, z), r)
			table.insert(avoid, { x, z, r * 0.7 })
		end
	end
	-- mountains around the edge form a natural wall
	for i = 0, 35 do
		local a = i / 36 * math.pi * 2
		local r = rng:NextNumber(45, 60)
		local d = HALF + 45
		kit:FillBall(i % 3 == 0 and M.Rock or M.Grass, Vector3.new(math.cos(a) * d, -10, math.sin(a) * d), r)
	end

	-- river
	for z = -HALF - 30, HALF + 30, 8 do
		local x = riverX(z)
		kit:Fill(M.Sand, CFrame.new(x, -1.5, z), Vector3.new(40, 3, 10))
		kit:Fill(M.Mud, CFrame.new(x, -8, z), Vector3.new(30, 2, 10))
		kit:Fill(M.Air, CFrame.new(x, -3.5, z), Vector3.new(30, 7, 10))
		kit:Water(CFrame.new(x, -4, z), Vector3.new(28, 6, 10))
	end

	-- dirt road east-west with a bridge
	kit:Fill(M.Ground, CFrame.new(0, -1, 0), Vector3.new(HALF * 2 + 40, 2.4, 16))
	local bx = riverX(0)
	kit:Part(Vector3.new(44, 1, 16), CFrame.new(bx, 1.2, 0), P.WoodLight, M.WoodPlanks)
	kit:Ramp(Vector3.new(bx - 34, 0, 0), Vector3.new(bx - 22, 1.7, 0), 16, P.WoodLight, M.WoodPlanks)
	kit:Ramp(Vector3.new(bx + 34, 0, 0), Vector3.new(bx + 22, 1.7, 0), 16, P.WoodLight, M.WoodPlanks)
	for _, side in { -1, 1 } do
		kit:Part(Vector3.new(44, 3, 0.6), CFrame.new(bx, 3.2, side * 7.7), P.WoodDark, M.Wood)
		for x = -20, 20, 10 do
			kit:Pillar(Vector3.new(bx + x, -8, side * 7.5), 9.2, 1.4, P.WoodDark, M.Wood)
		end
	end
	-- footbridges
	for _, z in { -110, 110 } do
		local x = riverX(z)
		kit:Part(Vector3.new(40, 0.8, 6), CFrame.new(x, 1, z), P.Wood, M.WoodPlanks)
		for _, side in { -1, 1 } do
			kit:Part(Vector3.new(40, 2.5, 0.4), CFrame.new(x, 2.6, z + side * 2.9), P.WoodDark, M.Wood)
		end
	end

	-- cabins, watchtowers, camp, lumber yard
	for _, s in structures do
		local kind, x, z = s[1], s[2], s[3]
		if kind == "Cabin" then
			kit:Fill(M.Ground, CFrame.new(x, -0.6, z), Vector3.new(30, 1.2, 26))
			local cabinCf = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 3) * 90), 0)
			kit:Building({
				Name = "Cabin", Origin = cabinCf,
				W = 24, D = 18, Floors = 1, FloorH = 11, Color = P.Wood, Material = M.WoodPlanks, Trim = P.WoodDark,
				Floor = P.WoodLight, Roof = "Gable", RoofColor = rgb(70, 50, 40), RoofAccess = false,
				Doors = { Front = true, Back = true }, Awning = P.WoodDark, OpenWindows = 0.6, Pilasters = false, AC = false,
			})
			for _, side in { -1, 1 } do
				kit:Lantern(cabinCf * CFrame.new(4.2, 7.6, side * 9.7))
			end
			kit:HealthPack(Vector3.new(x + 15, 0, z))
			for i = 1, 3 do
				kit:Cylinder(4, 1.4, CFrame.new(x - 15, 0.7 + (i - 1) * 1.2, z - 4 + i * 1.5) * CFrame.Angles(0, math.rad(90), 0), P.Trunk, M.Wood)
			end
		elseif kind == "Tower" then
			kit:Watchtower(Vector3.new(x, 0, z), 24)
		elseif kind == "Camp" then
			kit:Campfire(Vector3.new(x, 0, z))
			for i = 1, 3 do
				local a = i / 3 * math.pi * 2
				kit:Tent(CFrame.new(x + math.cos(a) * 12, 0, z + math.sin(a) * 12) * CFrame.Angles(0, -a, 0), ({ rgb(60, 110, 70), rgb(180, 90, 40), rgb(50, 80, 140) })[i])
				kit:Cylinder(5, 1.2, CFrame.new(x + math.cos(a + 1) * 5, 0.6, z + math.sin(a + 1) * 5) * CFrame.Angles(0, -a, 0), P.Trunk, M.Wood)
			end
		elseif kind == "Lumber" then
			kit:Fill(M.Ground, CFrame.new(x, -0.6, z), Vector3.new(50, 1.2, 44))
			-- open sawmill shed
			for _, px in { -14, 0, 14 } do
				for _, pz in { -9, 9 } do
					kit:Part(Vector3.new(1.2, 12, 1.2), CFrame.new(x + px, 6, z + pz), P.WoodDark, M.Wood)
				end
			end
			kit:Wedge(Vector3.new(32, 4, 10), CFrame.new(x, 14, z - 5), rgb(110, 110, 116), M.CorrodedMetal)
			kit:Wedge(Vector3.new(32, 4, 10), CFrame.new(x, 14, z + 5) * CFrame.Angles(0, math.rad(180), 0), rgb(110, 110, 116), M.CorrodedMetal)
			kit:Part(Vector3.new(20, 3, 3), CFrame.new(x, 1.5, z), P.MetalDark, M.Metal)
			-- log piles (good cover)
			for _, pile in { { -20, 18 }, { 18, 18 }, { -22, -18 } } do
				for row = 0, 2 do
					for i = 0, 3 - row do
						kit:Cylinder(14, 2, CFrame.new(x + pile[1], 1 + row * 1.8, z + pile[2] - 3 + i * 2 + row) * CFrame.Angles(0, 0, 0), P.Trunk, M.Wood)
					end
				end
			end
		end
	end

	-- forest
	local placed = 0
	for _ = 1, 600 do
		if placed >= 170 then
			break
		end
		local x, z = rng:NextNumber(-HALF + 10, HALF - 10), rng:NextNumber(-HALF + 10, HALF - 10)
		if not blocked(x, z, 4) then
			local pine = rng:NextNumber() < 0.6
			kit:Tree(Vector3.new(x, 0, z), rng:NextNumber(0.9, 1.6), pine and "Pine" or "Oak")
			placed += 1
		end
	end
	for _ = 1, 45 do
		local x, z = rng:NextNumber(-180, 180), rng:NextNumber(-180, 180)
		if not blocked(x, z, 1) then
			if rng:NextNumber() < 0.5 then
				kit:Bush(Vector3.new(x, 0, z), rng:NextNumber(0.8, 1.3))
			else
				kit:Rock(Vector3.new(x, 0, z), rng:NextNumber(0.8, 1.6))
			end
		end
	end
	-- reeds & rocks along the river
	for z = -180, 180, 24 do
		kit:Rock(Vector3.new(riverX(z) + (z % 48 == 0 and 17 or -17), -0.5, z), 0.9)
	end

	-- vehicles
	kit:VehicleSpot(CFrame.new(-150, 1, 5) * CFrame.Angles(0, math.rad(-90), 0), "Jeep", rgb(80, 100, 60))
	kit:VehicleSpot(CFrame.new(150, 1, -5) * CFrame.Angles(0, math.rad(90), 0), "Jeep", rgb(140, 120, 80))
	kit:VehicleSpot(CFrame.new(120, 1, 100) * CFrame.Angles(0, math.rad(180), 0), "Truck", rgb(160, 60, 40))
	kit:VehicleSpot(CFrame.new(-80, 1, -8) * CFrame.Angles(0, math.rad(-90), 0), "Jeep", rgb(60, 80, 100))

	-- MINE TUNNELS on both sides of the river (spawn to spawn)
	for _, tx in { -112, 112 } do
		kit:Tunnel({
			Axis = "Z", Cross = tx, From = -122, To = 122, Floor = -14, Width = 14, Height = 9, Style = "Mine", Terrain = true,
			Entrances = { { At = -118, Dir = 1 }, { At = -10, Dir = -1 }, { At = 10, Dir = 1 }, { At = 118, Dir = -1 } },
		})
	end

	-- cover: sandbags at both ends of every bridge, log walls, hiding bushes
	for _, z in { -110, 0, 110 } do
		local x = riverX(z)
		for _, side in { -1, 1 } do
			kit:Sandbags(CFrame.new(x + side * 26, 0, z + 9) * CFrame.Angles(0, math.rad(90), 0), 8, 3)
		end
	end
	for _ = 1, 10 do
		local x, z = rng:NextNumber(-140, 140), rng:NextNumber(-120, 120)
		if not blocked(x, z, 4) then
			for row = 0, 1 do
				kit:Cylinder(10, 1.6, CFrame.new(x, 0.8 + row * 1.5, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), P.Trunk, M.Wood)
			end
		end
	end
	for _ = 1, 40 do
		local x, z = rng:NextNumber(-145, 145), rng:NextNumber(-140, 140)
		if not blocked(x, z, 2) then
			kit:HideBush(Vector3.new(x, 0, z), rng:NextNumber(0.9, 1.2))
		end
	end
	kit:Ladder(Vector3.new(75 + 16.5, 0, -108), 16)

	-- TEAM SPAWNS at both ends (clear of the river)
	kit:SpawnBase(Vector3.new(-90, 0, -135), Vector3.new(-60, 0, 0), "A", 70)
	kit:SpawnBase(Vector3.new(90, 0, 135), Vector3.new(60, 0, 0), "B", 70)
	-- TRIPLE TEAM base (east) + FREE FOR ALL spawns spread through the forest
	kit:SpawnBase(Vector3.new(140, 0, -55), Vector3.new(0, 0, 0), "C", 55)
	local ffa = {}
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		for _, r in { 105, 75, 130 } do
			local x, z = math.cos(a) * r, math.sin(a) * r
			if not blocked(x, z, 3) then
				table.insert(ffa, Vector3.new(x, 0, z))
				break
			end
		end
	end
	kit:FFASpawns(ffa, 30)
	-- MORE COVER: log piles, rocks, fallen trees and sandbag nests in the clearings
	kit:CoverField({ { 135, 27 }, { -87, -103 }, { -131, -25 }, { -71, -39 }, { -51, 87 }, { -129, 25 }, { -67, 123 }, { -115, 83 }, { 83, 111 }, { 59, -53 }, { -113, -85 }, { -97, -35 }, { 39, 21 }, { 71, -129 }, { 109, -85 }, { 5, -45 }, { -7, -141 }, { 73, -89 }, { 71, 19 }, { 103, 89 }, { 115, -43 }, { 45, -77 }, { -61, 19 } }, "Forest")
	-- ground cover everywhere that isn't river, road or a structure
	kit:Scatter(-HALF + 6, HALF - 6, -HALF + 6, HALF - 6, 520, function(x, z)
		return blocked(x, z, 0)
	end)
	kit:Mountains(HALF + 18, HALF + 18, { Margin = 95, GroundY = -0.5 })
	kit:Boundary(HALF, HALF, 260)
	return kit
end

return Map
