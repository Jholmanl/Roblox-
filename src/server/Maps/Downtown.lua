-- DOWNTOWN: city blocks, roads, enterable buildings, a park with a pond, cars.
local MapKit = require(script.Parent.MapKit)
local M = Enum.Material
local P = MapKit.Palette
local rgb = Color3.fromRGB

local Map = {
	Id = "Downtown",
	Name = "DOWNTOWN",
	Desc = "City streets, rooftops and a park. Grab a car!",
	Icon = "🏙️",
	Lighting = {
		ClockTime = 17.8, Brightness = 2.2,
		Ambient = rgb(90, 80, 90), OutdoorAmbient = rgb(140, 120, 120),
		Atmosphere = { Density = 0.32, Haze = 1.6, Color = rgb(255, 200, 170), Decay = rgb(120, 90, 110) },
		Tint = rgb(255, 238, 225), Saturation = 0.12,
	},
}

local HALF = 160
local ROADS = { -100, 0, 100 }
local ROAD_W = 24

function Map.Build()
	local kit = MapKit.new(7)
	local rng = kit.Rng

	-- ground (the asphalt IS the road surface; blocks are raised sidewalks)
	kit:Part(Vector3.new(HALF * 2 + 40, 2, HALF * 2 + 40), CFrame.new(0, -1, 0), P.Asphalt, M.Asphalt)
	for _, c in ROADS do
		kit:Road("X", Vector3.new(0, 0, c), HALF * 2, ROAD_W, ROADS, true)
		kit:Road("Z", Vector3.new(c, 0, 0), HALF * 2, ROAD_W, ROADS, true)
	end
	for _, x in ROADS do
		for _, z in ROADS do
			kit:Crosswalk(Vector3.new(x, 0, z - ROAD_W / 2 - 3), "Z", ROAD_W)
			kit:Crosswalk(Vector3.new(x, 0, z + ROAD_W / 2 + 3), "Z", ROAD_W)
			kit:Crosswalk(Vector3.new(x - ROAD_W / 2 - 3, 0, z), "X", ROAD_W)
			kit:Crosswalk(Vector3.new(x + ROAD_W / 2 + 3, 0, z), "X", ROAD_W)
			kit:TrafficLight(Vector3.new(x + 14, 0.8, z + 14), Vector3.new(-1, 0, 0))
			kit:TrafficLight(Vector3.new(x - 14, 0.8, z - 14), Vector3.new(1, 0, 0))
		end
	end

	-- city blocks between roads: inner (±50) and edge strips (±136)
	local spans = { { -88, -12 }, { 12, 88 }, { -160, -112 }, { 112, 160 } }
	for _, sx in spans do
		for _, sz in spans do
			local cx, cz = (sx[1] + sx[2]) / 2, (sz[1] + sz[2]) / 2
			kit:Sidewalk(Vector3.new(cx, 0, cz), sx[2] - sx[1], sz[2] - sz[1])
			local edge = math.abs(cx) > 100 or math.abs(cz) > 100
			-- street lights along the curb
			if not edge then
				for d = sx[1] + 8, sx[2] - 8, 30 do
					kit:StreetLight(Vector3.new(d, 0.8, sz[1] + 1.5), Vector3.new(0, 0, -1))
					kit:StreetLight(Vector3.new(d, 0.8, sz[2] - 1.5), Vector3.new(0, 0, 1))
				end
			end
		end
	end

	-- SKYLINE: towers on the edge strips (form the map boundary)
	for _, sx in spans do
		for _, sz in spans do
			local cx, cz = (sx[1] + sx[2]) / 2, (sz[1] + sz[2]) / 2
			if math.abs(cx) > 100 or math.abs(cz) > 100 then
				local w, d = sx[2] - sx[1] - 8, sz[2] - sz[1] - 8
				local cols = w > 50 and 2 or 1
				local rows = d > 50 and 2 or 1
				for i = 1, cols do
					for j = 1, rows do
						local tx = sx[1] + 4 + (i - 0.5) * w / cols
						local tz = sz[1] + 4 + (j - 0.5) * d / rows
						local h = rng:NextNumber(36, 86)
						local tint = ({ rgb(120, 124, 130), rgb(150, 140, 120), rgb(90, 96, 110), rgb(170, 160, 150) })[rng:NextInteger(1, 4)]
						kit:Tower(CFrame.new(tx, 0.8, tz), w / cols - 4, d / rows - 4, h, tint, M.Concrete)
					end
				end
			end
		end
	end
	-- road ends blocked with barriers + a bus
	for _, c in ROADS do
		for _, s in { -1, 1 } do
			kit:Barrier(CFrame.new(c - 6, 0, s * 150) * CFrame.Angles(0, 0, 0))
			kit:Barrier(CFrame.new(c + 6, 0, s * 150))
			kit:Barrier(CFrame.new(s * 150, 0, c - 6) * CFrame.Angles(0, math.rad(90), 0))
			kit:Barrier(CFrame.new(s * 150, 0, c + 6) * CFrame.Angles(0, math.rad(90), 0))
		end
	end

	-- BLOCK A (+,+): CENTRAL PARK with grass, pond, trees
	kit:Fill(M.Grass, CFrame.new(50, 0, 50), Vector3.new(72, 1.6, 72))
	kit:Fill(M.Mud, CFrame.new(62, -1.2, 62), Vector3.new(26, 2, 20))
	kit:Water(CFrame.new(62, -0.2, 62), Vector3.new(24, 1.6, 18))
	for _, path in { { Vector3.new(50, 0.9, 50), Vector3.new(72, 0.2, 5) }, { Vector3.new(50, 0.9, 50), Vector3.new(5, 0.2, 72) } } do
		kit:Part(path[2], CFrame.new(path[1]), P.Sidewalk, M.Pavement)
	end
	-- fountain
	kit:Cylinder(1.6, 16, CFrame.new(50, 1.6, 50) * CFrame.Angles(0, 0, math.rad(90)), P.Concrete, M.Marble)
	local pool = kit:Cylinder(0.3, 14, CFrame.new(50, 2.45, 50) * CFrame.Angles(0, 0, math.rad(90)), rgb(60, 140, 200), M.Glass)
	pool.Transparency = 0.3
	kit:Pillar(Vector3.new(50, 2.4, 50), 5, 1.6, P.Concrete, M.Marble)
	kit:Ball(3, Vector3.new(50, 8, 50), P.Concrete, M.Marble)
	for _, t in { { 24, 24 }, { 24, 76 }, { 34, 64 }, { 40, 30 }, { 76, 26 }, { 82, 40 }, { 30, 44 }, { 66, 36 }, { 44, 80 }, { 80, 80 }, { 20, 58 } } do
		kit:Tree(Vector3.new(t[1], 0.8, t[2]), rng:NextNumber(0.9, 1.3), "Oak")
	end
	for _, b in { { 40, 56 }, { 60, 44 }, { 44, 40 } } do
		kit:Bench(CFrame.new(b[1], 0.8, b[2]))
		kit:Bush(Vector3.new(b[1] + 6, 0.8, b[2] + 4), 0.8)
	end

	-- BLOCK B (-,+): apartments + alley
	kit:Building({ Name = "Apartments", Origin = CFrame.new(-66, 0.8, 32), W = 36, D = 28, Floors = 3, Color = P.Brick, Material = M.Brick, Doors = { Front = true, Back = true }, Awning = rgb(30, 90, 140) })
	kit:Building({ Name = "Hotel", Origin = CFrame.new(-66, 0.8, 70), W = 36, D = 24, Floors = 2, Color = P.Plaster, Material = M.SmoothPlastic, Trim = P.BrickDark, Doors = { Front = true, Back = true }, Awning = rgb(150, 30, 40) })
	kit:Building({ Name = "Diner", Origin = CFrame.new(-26, 0.8, 54) * CFrame.Angles(0, math.rad(90), 0), W = 26, D = 20, Floors = 1, Color = rgb(200, 70, 60), Material = M.SmoothPlastic, Trim = P.White, Doors = { Front = true, Back = true }, Awning = P.White })
	kit:Dumpster(CFrame.new(-40, 0.8, 18))
	kit:Dumpster(CFrame.new(-42, 0.8, 84) * CFrame.Angles(0, math.rad(90), 0))
	for i = 1, 4 do
		kit:Crate(Vector3.new(-30 + i * 2, 0.8, 80 - i * 3), 3.5, i)
	end

	-- BLOCK C (-,-): parking lot + gas station
	kit:Part(Vector3.new(70, 0.1, 70), CFrame.new(-50, 0.85, -50), P.Asphalt, M.Asphalt)
	for i = 0, 6 do
		kit:Deco(Vector3.new(0.4, 0.05, 12), CFrame.new(-82 + i * 10, 0.93, -26), P.White, M.SmoothPlastic)
		kit:Deco(Vector3.new(0.4, 0.05, 12), CFrame.new(-82 + i * 10, 0.93, -74), P.White, M.SmoothPlastic)
	end
	-- gas station canopy
	for _, x in { -64, -36 } do
		for _, z in { -58, -42 } do
			kit:Pillar(Vector3.new(x, 0.8, z), 12, 1.4, P.White, M.SmoothPlastic)
		end
	end
	kit:Part(Vector3.new(34, 1.6, 22), CFrame.new(-50, 13.6, -50), P.White, M.SmoothPlastic)
	kit:Neon(Vector3.new(34.2, 0.6, 22.2), CFrame.new(-50, 12.9, -50), rgb(220, 40, 40))
	for _, x in { -56, -44 } do
		kit:Part(Vector3.new(2, 5, 3), CFrame.new(x, 3.3, -50), rgb(220, 40, 40), M.SmoothPlastic)
	end
	kit:Building({ Name = "Store", Origin = CFrame.new(-50, 0.8, -78) * CFrame.Angles(0, math.rad(180), 0), W = 30, D = 14, Floors = 1, Color = rgb(230, 230, 220), Material = M.SmoothPlastic, Trim = rgb(220, 40, 40), Doors = { Front = true }, Awning = rgb(220, 40, 40) })

	-- BLOCK D (+,-): office tower (4 floors) + plaza
	kit:Building({ Name = "Office", Origin = CFrame.new(58, 0.8, -58), W = 40, D = 40, Floors = 4, Color = rgb(170, 180, 190), Material = M.Concrete, Trim = rgb(60, 70, 90), Doors = { Front = true, Left = true }, Awning = rgb(60, 70, 90) })
	for i = 1, 3 do
		kit:Barrier(CFrame.new(20 + i * 9, 0.8, -20) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0))
	end
	kit:Tree(Vector3.new(22, 0.8, -40), 1, "Oak")
	kit:Tree(Vector3.new(24, 0.8, -84), 1, "Oak")

	-- street cover: wrecked / parked cars + barriers in the roads
	local parked = {
		{ -100, 40, 0, "Sedan" }, { -96, -60, 180, "Truck" }, { 4, 60, 0, "Sedan" }, { -4, -70, 180, "Sports" },
		{ 100, -30, 0, "Sedan" }, { 60, 4, 90, "Truck" }, { -60, -4, 270, "Sedan" }, { 40, 104, 90, "Sedan" },
	}
	for _, c in parked do
		local spot = kit:VehicleSpot(CFrame.new(c[1], 0, c[2]) * CFrame.Angles(0, math.rad(c[3]), 0), c[4])
		spot:SetAttribute("Parked", true)
	end
	for _, b in { { 0, 30, 15 }, { -30, 0, 80 }, { 100, 60, -10 }, { 30, -100, 95 }, { -100, -30, 5 } } do
		kit:Barrier(CFrame.new(b[1], 0, b[2]) * CFrame.Angles(0, math.rad(b[3]), 0))
	end
	-- drivable cars
	for _, c in { { -94, 70, 0, "Sports" }, { 6, -40, 180, "Sedan" }, { 94, 40, 0, "Jeep" }, { -40, 96, 90, "Sedan" }, { 40, -96, 270, "Truck" } } do
		kit:VehicleSpot(CFrame.new(c[1], 0, c[2]) * CFrame.Angles(0, math.rad(c[3]), 0), c[4])
	end

	-- pickups + spawns
	for _, p in { Vector3.new(20, 0.8, 20), Vector3.new(-20, 0.8, -20), Vector3.new(-20, 0.8, 20), Vector3.new(20, 0.8, -20) } do
		kit:HealthPack(p)
	end
	for _, c in ROADS do
		kit:Spawn(Vector3.new(c, 3, 140), Vector3.new(c, 3, 0))
		kit:Spawn(Vector3.new(c, 3, -140), Vector3.new(c, 3, 0))
		kit:Spawn(Vector3.new(140, 3, c), Vector3.new(0, 3, c))
		kit:Spawn(Vector3.new(-140, 3, c), Vector3.new(0, 3, c))
	end
	for _, s in { { 50, 14 }, { -50, 14 }, { 50, -14 }, { -50, -14 }, { 86, 50 }, { -86, -50 } } do
		kit:Spawn(Vector3.new(s[1], 3.8, s[2]))
	end
	kit:Boundary(HALF - 2, HALF - 2, 160)
	return kit
end

return Map
