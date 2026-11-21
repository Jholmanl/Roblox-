-- HARBOR: container maze, cranes, warehouses, a boardable cargo ship and a
-- storm-drain tunnel. Team ALPHA spawns west, BRAVO east.
local MapKit = require(script.Parent.MapKit)
local M = Enum.Material
local P = MapKit.Palette
local rgb = Color3.fromRGB

local Map = {
	Id = "Harbor",
	Name = "HARBOR",
	Desc = "Shipping docks at sunset. Container maze, cranes and a storm drain.",
	Icon = "⚓",
	Lighting = {
		ClockTime = 17.4, Brightness = 2.4,
		Ambient = rgb(100, 80, 80), OutdoorAmbient = rgb(150, 120, 110),
		Atmosphere = { Density = 0.3, Haze = 2, Color = rgb(255, 190, 150), Decay = rgb(150, 90, 100) },
		Tint = rgb(255, 232, 212), Saturation = 0.16, Contrast = 0.22, SunRays = 0.2, CloudColor = rgb(255, 210, 180), WaterColor = rgb(20, 80, 110),
	},
}

local HALF = 150

function Map.Build()
	local kit = MapKit.new(33)
	local rng = kit.Rng

	-- STORM DRAIN under the crane lane, spawn to spawn
	local holes = kit:Tunnel({
		Axis = "X", Cross = -74, From = -146, To = 146, Floor = -14, Width = 14, Height = 9, Style = "Sewer",
		Entrances = { { At = -142, Dir = 1 }, { At = -30, Dir = -1 }, { At = 30, Dir = 1 }, { At = 142, Dir = -1 } },
	})

	-- land + sea
	kit:Ground(0, -HALF - 10, HALF + 10, -HALF - 10, 40, 4, holes, P.ConcreteDark, M.Concrete)
	kit:Part(Vector3.new(HALF * 2 + 20, 0.3, 1.5), CFrame.new(0, 0.15, 39.2), P.Yellow, M.SmoothPlastic)
	kit:Part(Vector3.new(HALF * 2 + 20, 6, 2), CFrame.new(0, -3, 40.5), P.ConcreteDark, M.Concrete)
	kit:Fill(M.Sand, CFrame.new(0, -14, 330), Vector3.new(HALF * 2 + 900, 6, 600))
	kit:Water(CFrame.new(0, -6, 330), Vector3.new(HALF * 2 + 900, 10, 600))
	-- distant islands on the sea side
	for _, isl in { { -260, 420, 70 }, { 40, 520, 110 }, { 320, 380, 80 }, { -480, 300, 90 }, { 520, 470, 120 } } do
		kit:FillBall(M.Rock, Vector3.new(isl[1], -isl[3] * 0.45, isl[2]), isl[3])
		kit:FillBall(M.Grass, Vector3.new(isl[1], -isl[3] * 0.6, isl[2]), isl[3] * 0.98)
	end
	for x = -HALF + 10, HALF - 10, 20 do
		kit:Pillar(Vector3.new(x, 0, 37.5), 1.5, 1.4, rgb(40, 40, 44), M.Metal)
	end
	kit:Road("X", Vector3.new(0, 0, 20), HALF * 2, 20, {})
	for x = -120, 120, 40 do
		kit:Manhole(Vector3.new(x + 7, 0.3, 14))
	end

	-- CONTAINER YARD (west-middle) with the crane lane through the middle
	local cols = { -112, -100, -88, -64, -52, -40 }
	local rows = { -136, -112, -94, -54, -32, -10 }
	for ci, x in cols do
		for ri, z in rows do
			if rng:NextNumber() > 0.14 then
				local stack = rng:NextInteger(1, 3)
				for level = 0, stack - 1 do
					kit:Container(CFrame.new(x, level * 8.5, z), nil, level == 0 and rng:NextNumber() < 0.3)
				end
				-- ladder up the tall stacks so you can fight on top
				if stack >= 2 and (ci + ri) % 3 == 0 then
					kit:Ladder(Vector3.new(x + 5, 0, z + 6), stack * 8.5 + 3)
				end
			end
		end
	end
	kit:Crane(CFrame.new(-76, 0, -74), 76, 40)
	kit:Ladder(Vector3.new(-76 - 38 + 2, 0, -74 - 8), 42)
	kit:Crane(CFrame.new(50, 0, 30) * CFrame.Angles(0, math.rad(90), 0), 34, 50)

	-- WAREHOUSES (east)
	kit:Building({
		Name = "Warehouse", Origin = CFrame.new(70, 0, -112), W = 56, D = 40, Floors = 1, FloorH = 18,
		Color = rgb(90, 110, 130), Material = M.CorrodedMetal, Trim = rgb(50, 60, 70), Floor = rgb(110, 110, 110),
		Doors = { Front = true, Back = true, Left = true, Right = true }, Awning = rgb(240, 180, 30),
		OpenWindows = 0.5, Ladder = "Back", Pilasters = false,
	})
	kit:Building({
		Name = "PortOffice", Origin = CFrame.new(70, 0, -42), W = 46, D = 26, Floors = 2, FloorH = 12,
		Color = rgb(220, 214, 200), Material = M.Concrete, Trim = rgb(40, 90, 140),
		Doors = { Front = true, Back = true }, Awning = rgb(40, 90, 140),
		OpenWindows = 0.4, FireEscape = "Right",
	})
	-- fuel tanks (south)
	for _, x in { -10, 22 } do
		kit:Pillar(Vector3.new(x, 0, -132), 24, 22, rgb(225, 225, 220), M.Metal)
		kit:Cylinder(0.8, 22.5, CFrame.new(x, 17, -132) * CFrame.Angles(0, 0, math.rad(90)), rgb(200, 60, 50), M.Metal)
	end
	kit:Ladder(Vector3.new(-10, 0, -120), 26)

	-- CARGO SHIP + gangway + stern ladder
	kit:Ship(CFrame.new(0, 0, 77) * CFrame.Angles(0, math.rad(90), 0), 130, -20)
	kit:Ramp(Vector3.new(-20, 0, 36), Vector3.new(-20, 12.6, 62.5), 6, P.MetalDark, M.DiamondPlate)

	-- PIERS + boats
	for _, x in { -112, 112 } do
		kit:Pier(Vector3.new(x, 0, 41), Vector3.new(x, 0, 120), 10, 0.6)
		for _, side in { -1, 1 } do
			local bx, bz = x + side * 12, 90 + side * 10
			kit:Part(Vector3.new(8, 4, 20), CFrame.new(bx, -1.5, bz), side > 0 and P.White or rgb(40, 80, 140), M.SmoothPlastic)
			kit:Wedge(Vector3.new(8, 4, 6), CFrame.new(bx, -1.5, bz - 13), side > 0 and P.White or rgb(40, 80, 140), M.SmoothPlastic)
			kit:Part(Vector3.new(6, 4, 7), CFrame.new(bx, 2.5, bz + 3), P.White, M.SmoothPlastic)
			kit:Glass(Vector3.new(6.2, 1.5, 7.2), CFrame.new(bx, 3.2, bz + 3))
		end
		kit:Sandbags(CFrame.new(x, 0.6, 70), 8, 3)
	end

	-- LIGHTHOUSE island
	kit:FillBall(M.Rock, Vector3.new(118, -16, 130), 22)
	kit:Pillar(Vector3.new(118, 4, 130), 34, 8, P.White, M.SmoothPlastic)
	for y = 10, 34, 10 do
		kit:Cylinder(3, 8.2, CFrame.new(118, y, 130) * CFrame.Angles(0, 0, math.rad(90)), P.Red, M.SmoothPlastic)
	end
	local lamp = kit:Neon(Vector3.new(5, 5, 5), CFrame.new(118, 40.5, 130), rgb(255, 240, 180))
	kit:Light(lamp, "PointLight", rgb(255, 230, 170), 60, 3)

	-- dockside dressing
	for x = -136, 136, 34 do
		kit:Tree(Vector3.new(x, 0, 30), rng:NextNumber(0.9, 1.2), "Palm")
		kit:StreetLight(Vector3.new(x + 17, 0, 30), Vector3.new(0, 0, -1))
	end
	for i = 1, 16 do
		local x, z = rng:NextNumber(-25, 30), rng:NextNumber(-115, 5)
		if i % 2 == 0 then
			kit:Crate(Vector3.new(x, 0, z), 4, rng:NextNumber(0, 1))
			kit:Crate(Vector3.new(x + 4.2, 0, z), 4, rng:NextNumber(0, 1))
			kit:Crate(Vector3.new(x + 2, 4, z), 4, rng:NextNumber(0, 1))
		else
			for b = 0, 2 do
				kit:Pillar(Vector3.new(x + b * 2.3, 0, z), 3.6, 2.2, ({ rgb(30, 80, 160), rgb(200, 60, 40), rgb(60, 140, 70) })[b + 1], M.Metal)
			end
		end
	end
	-- sandbag lines across the open ground
	for _, s in { { -8, -50, 0 }, { 20, -90, 0 }, { 0, -20, 90 }, { 34, 0, 0 }, { -24, -110, 90 }, { 104, -74, 90 }, { -28, 4, 0 } } do
		kit:Sandbags(CFrame.new(s[1], 0, s[2]) * CFrame.Angles(0, math.rad(s[3]), 0), 10, 3)
	end
	for _, b in { { 10, -60, 0 }, { 40, -10, 60 }, { -10, -140, 30 } } do
		kit:Barrier(CFrame.new(b[1], 0, b[2]) * CFrame.Angles(0, math.rad(b[3]), 0))
	end

	-- pickups, vehicles
	for _, p in { Vector3.new(-76, 0, -74), Vector3.new(30, 0, -74), Vector3.new(0, 0, 10), Vector3.new(40, 0, -128) } do
		kit:HealthPack(p)
	end
	kit:VehicleSpot(CFrame.new(-90, 0.5, 20) * CFrame.Angles(0, math.rad(-90), 0), "Truck")
	kit:VehicleSpot(CFrame.new(70, 0.5, 16) * CFrame.Angles(0, math.rad(90), 0), "Sedan")
	kit:VehicleSpot(CFrame.new(120, 0.5, -10), "Jeep")
	kit:VehicleSpot(CFrame.new(-120, 0.5, -10), "Jeep")
	local parked = kit:VehicleSpot(CFrame.new(0, 0.5, -100), "Truck")
	parked:SetAttribute("Parked", true)

	-- TEAM SPAWNS at both ends
	kit:SpawnBase(Vector3.new(-138, 0, -74), Vector3.new(0, 0, -74), "A", 130)
	kit:SpawnBase(Vector3.new(138, 0, -74), Vector3.new(0, 0, -74), "B", 130)
	-- TRIPLE TEAM base (on the quay) + FREE FOR ALL spawns everywhere
	kit:SpawnBase(Vector3.new(0, 0, 22), Vector3.new(0, 0, -60), "C", 100)
	local ffa = {}
	for _, p in { { -130, -110 }, { -130, -35 }, { 130, -130 }, { 130, -20 }, { -20, -60 }, { 10, -30 }, { -60, 10 }, { 100, 8 }, { -100, 8 }, { 40, -145 }, { -25, -118 }, { 110, -60 }, { 60, 0 }, { -76, -40 } } do
		table.insert(ffa, Vector3.new(p[1], 0, p[2]))
	end
	kit:FFASpawns(ffa)
	-- MORE COVER in the open yards + along the quay road
	kit:CoverField({ { 79, -73 }, { -19, -23 }, { 83, -13 }, { 109, -37 }, { 15, -7 }, { -81, -115 }, { 111, -97 }, { 35, -25 }, { 29, -109 }, { -95, -75 }, { 9, -49 }, { 111, -133 }, { -61, -73 }, { 87, -121 } }, "Harbor")
	kit:RoadCover("X", 20, -140, -64, 26, 6.5, "Harbor", { -90 })
	kit:RoadCover("X", 20, 64, 140, 26, 6.5, "Harbor", { 70 })
	kit:Mountains(HALF, HALF, { Margin = 50, SkipSide = "N", GroundY = -0.5 })
	kit:Boundary(HALF, HALF, 260)
	return kit
end

return Map
