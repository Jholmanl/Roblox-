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
		ClockTime = 13.5, Brightness = 2.8,
		Ambient = rgb(80, 90, 80), OutdoorAmbient = rgb(130, 140, 130),
		Atmosphere = { Density = 0.35, Haze = 1.4, Color = rgb(200, 225, 210), Decay = rgb(90, 120, 110) },
		Tint = rgb(240, 255, 240), Saturation = 0.2,
	},
}

local HALF = 200

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
		{ "Cabin", -100, -60 }, { "Cabin", -125, 75 }, { "Cabin", 105, -95 }, { "Cabin", 130, 65 },
		{ "Tower", -60, 140 }, { "Tower", 75, -150 }, { "Tower", 155, -10 },
		{ "Camp", -45, -140 }, { "Lumber", 115, 140 },
	}
	for _, s in structures do
		table.insert(avoid, { s[2], s[3], s[1] == "Lumber" and 34 or 24 })
	end

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
		local d = HALF + 25
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
			kit:Building({
				Name = "Cabin", Origin = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 3) * 90), 0),
				W = 24, D = 18, Floors = 1, FloorH = 11, Color = P.Wood, Material = M.WoodPlanks, Trim = P.WoodDark,
				Floor = P.WoodLight, Roof = "Gable", RoofColor = rgb(70, 50, 40), RoofAccess = false,
				Doors = { Front = true, Back = true }, Awning = P.WoodDark,
			})
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
			kit:Fill(M.Ground, CFrame.new(x, -0.6, z), Vector3.new(60, 1.2, 50))
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
	kit:VehicleSpot(CFrame.new(120, 1, 120) * CFrame.Angles(0, math.rad(180), 0), "Truck", rgb(160, 60, 40))
	kit:VehicleSpot(CFrame.new(-80, 1, -8) * CFrame.Angles(0, math.rad(-90), 0), "Jeep", rgb(60, 80, 100))

	-- spawns in a ring (east & west banks)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local x, z = math.cos(a) * 140, math.sin(a) * 140
		if math.abs(x - riverX(z)) < 30 then
			x += 40
		end
		kit:Spawn(Vector3.new(x, 6, z))
	end
	kit:Boundary(HALF, HALF, 200)
	return kit
end

return Map
