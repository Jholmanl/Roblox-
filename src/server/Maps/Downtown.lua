-- DOWNTOWN: city blocks, subway tunnel, fire escapes, open-window buildings,
-- barricaded intersections. Team ALPHA spawns south, BRAVO north.
local MapKit = require(script.Parent.MapKit)
local M = Enum.Material
local P = MapKit.Palette
local rgb = Color3.fromRGB

local Map = {
	Id = "Downtown",
	Name = "DOWNTOWN",
	Desc = "City streets, rooftops and a subway under the avenue.",
	Icon = "🏙️",
	Lighting = {
		ClockTime = 18.1, Brightness = 2, Exposure = 0.15,
		Ambient = rgb(90, 80, 90), OutdoorAmbient = rgb(140, 120, 120),
		Atmosphere = { Density = 0.32, Haze = 1.6, Color = rgb(255, 200, 170), Decay = rgb(120, 90, 110) },
		Tint = rgb(255, 236, 222), Saturation = 0.14, Contrast = 0.24, SunRays = 0.16, CloudColor = rgb(255, 205, 185),
	},
}

local HALF = 160
local ROADS = { -100, 0, 100 }
local ROAD_W = 24

function Map.Build()
	local kit = MapKit.new(7)
	local rng = kit.Rng

	-- SUBWAY under the main avenue (x = 0), entrances at both spawns + mid-blocks
	local holes = kit:Tunnel({
		Axis = "Z", Cross = 0, From = -152, To = 152, Floor = -14, Width = 14, Height = 9, Style = "Subway",
		Entrances = {
			{ At = -150, Dir = 1 }, { At = -80, Dir = 1 }, { At = -20, Dir = -1 },
			{ At = 20, Dir = 1 }, { At = 80, Dir = -1 }, { At = 150, Dir = -1 },
		},
	})

	-- ground (the asphalt IS the road surface; blocks are raised sidewalks)
	kit:Ground(0, -HALF - 20, HALF + 20, -HALF - 20, HALF + 20, 2, holes, P.Asphalt, M.Asphalt)
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
			kit:StreetSign(Vector3.new(x - 14, 0.8, z + 14), math.rad(45))
			kit:Manhole(Vector3.new(x + 5, 0, z - 5))
			-- barricaded intersection: sandbag nests on two corners
			if not (x == 0 and math.abs(z) > 50) then
				kit:Sandbags(CFrame.new(x - 6, 0, z + 6) * CFrame.Angles(0, math.rad(45), 0), 8, 3)
				kit:Sandbags(CFrame.new(x + 6, 0, z - 6) * CFrame.Angles(0, math.rad(45), 0), 8, 3)
			end
		end
	end

	-- city blocks between roads: inner (±50) and edge strips (±136)
	local spans = { { -88, -12 }, { 12, 88 }, { -160, -112 }, { 112, 160 } }
	for _, sx in spans do
		for _, sz in spans do
			local cx, cz = (sx[1] + sx[2]) / 2, (sz[1] + sz[2]) / 2
			kit:Sidewalk(Vector3.new(cx, 0, cz), sx[2] - sx[1], sz[2] - sz[1])
			local edge = math.abs(cx) > 100 or math.abs(cz) > 100
			if not edge then
				for d = sx[1] + 8, sx[2] - 8, 30 do
					kit:StreetLight(Vector3.new(d, 0.8, sz[1] + 1.5), Vector3.new(0, 0, -1))
					kit:StreetLight(Vector3.new(d, 0.8, sz[2] - 1.5), Vector3.new(0, 0, 1))
				end
				-- street furniture along the curbs
				kit:Hydrant(Vector3.new(sx[1] + 3, 0.8, sz[1] + 22))
				kit:TrashCan(Vector3.new(sx[2] - 3, 0.8, sz[1] + 30))
				kit:TrashCan(Vector3.new(sx[1] + 3, 0.8, sz[2] - 30))
				kit:NewsBox(CFrame.new(sx[2] - 2.5, 0.8, sz[2] - 20) * CFrame.Angles(0, math.rad(-90), 0))
				kit:Planter(Vector3.new(sx[1] + 22, 0.8, sz[2] - 3))
				kit:Planter(Vector3.new(sx[2] - 22, 0.8, sz[1] + 3))
				kit:PowerBox(CFrame.new(sx[2] - 3, 0.8, (sz[1] + sz[2]) / 2) * CFrame.Angles(0, math.rad(90), 0))
			end
		end
	end
	kit:BusStop(CFrame.new(-14.5, 0.8, -50) * CFrame.Angles(0, math.rad(-90), 0))
	kit:BusStop(CFrame.new(14.5, 0.8, 50) * CFrame.Angles(0, math.rad(90), 0))

	-- SKYLINE: towers on the east/west edge strips (the north/south ends are spawns)
	for _, sx in spans do
		for _, sz in spans do
			local cx, cz = (sx[1] + sx[2]) / 2, (sz[1] + sz[2]) / 2
			local spawnStrip = (math.abs(cz) > 100 and math.abs(cx) < 100) or (cx < -100 and math.abs(cz) < 100)
			if (math.abs(cx) > 100 or math.abs(cz) > 100) and not spawnStrip then
				local w, d = sx[2] - sx[1] - 8, sz[2] - sz[1] - 8
				local cols = w > 50 and 2 or 1
				local rows = d > 50 and 2 or 1
				for i = 1, cols do
					for j = 1, rows do
						local tx = sx[1] + 4 + (i - 0.5) * w / cols
						local tz = sz[1] + 4 + (j - 0.5) * d / rows
						local h = rng:NextNumber(40, 80)
						local tint = ({ rgb(120, 124, 130), rgb(150, 140, 120), rgb(90, 96, 110), rgb(170, 160, 150) })[rng:NextInteger(1, 4)]
						kit:Tower(CFrame.new(tx, 0.8, tz), w / cols - 4, d / rows - 4, h, tint, M.Concrete)
					end
				end
			end
		end
	end

	-- TEAM SPAWNS at both ends
	kit:SpawnBase(Vector3.new(0, 0, -138), Vector3.new(0, 0, 0), "A", 150)
	kit:SpawnBase(Vector3.new(0, 0, 138), Vector3.new(0, 0, 0), "B", 150)
	for _, c in { -100, 100 } do
		for _, s in { -1, 1 } do
			kit:Barrier(CFrame.new(c - 6, 0, s * 152))
			kit:Barrier(CFrame.new(c + 6, 0, s * 152))
		end
	end
	for _, s in { -1, 1 } do
		for _, c in ROADS do
			kit:Barrier(CFrame.new(s * 150, 0, c - 6) * CFrame.Angles(0, math.rad(90), 0))
			kit:Barrier(CFrame.new(s * 150, 0, c + 6) * CFrame.Angles(0, math.rad(90), 0))
		end
	end

	-- BLOCK A (+,+): CENTRAL PARK with grass, pond, trees and hiding bushes
	kit:Fill(M.Grass, CFrame.new(50, 0, 50), Vector3.new(72, 1.6, 72))
	kit:Fill(M.Mud, CFrame.new(62, -1.2, 62), Vector3.new(26, 2, 20))
	kit:Water(CFrame.new(62, -0.2, 62), Vector3.new(24, 1.6, 18))
	for _, path in { { Vector3.new(50, 0.9, 50), Vector3.new(72, 0.2, 5) }, { Vector3.new(50, 0.9, 50), Vector3.new(5, 0.2, 72) } } do
		kit:Part(path[2], CFrame.new(path[1]), P.Sidewalk, M.Pavement)
	end
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
	end
	for _, b in { { 22, 34 }, { 34, 22 }, { 78, 70 }, { 70, 82 }, { 26, 70 }, { 82, 26 } } do
		kit:HideBush(Vector3.new(b[1], 0.8, b[2]), 1)
	end
	kit:Sandbags(CFrame.new(50, 0.8, 30), 10, 3)

	-- BLOCK B (-,+): apartments with fire escape, hotel, diner + alley
	kit:Building({ Name = "Apartments", Origin = CFrame.new(-66, 0.8, 32), W = 36, D = 28, Floors = 3, Color = P.Brick, Material = M.Brick, Trim = rgb(200, 190, 170), Doors = { Front = true, Back = true }, Awning = rgb(30, 90, 140), FireEscape = "Right", OpenWindows = 0.35, Balconies = true })
	kit:Building({ Name = "Hotel", Origin = CFrame.new(-66, 0.8, 72), W = 36, D = 22, Floors = 3, FloorH = 11, Color = P.Plaster, Material = M.SmoothPlastic, Trim = P.BrickDark, Doors = { Front = true, Back = true }, Awning = rgb(150, 30, 40), Ladder = "Back", OpenWindows = 0.3 })
	kit:Building({ Name = "Diner", Origin = CFrame.new(-26, 0.8, 54) * CFrame.Angles(0, math.rad(90), 0), W = 26, D = 20, Floors = 1, Color = rgb(200, 70, 60), Material = M.SmoothPlastic, Trim = P.White, Doors = { Front = true, Back = true }, Awning = P.White, Storefront = rgb(220, 40, 40), Ladder = "Back" })
	kit:Dumpster(CFrame.new(-40, 0.8, 18))
	kit:Dumpster(CFrame.new(-42, 0.8, 86) * CFrame.Angles(0, math.rad(90), 0))
	kit:HideBush(Vector3.new(-44, 0.8, 50), 0.8)
	for i = 1, 4 do
		kit:Crate(Vector3.new(-32 + i * 2, 0.8, 80 - i * 3), 3.5, i)
	end
	kit:Sandbags(CFrame.new(-40, 0.8, 34) * CFrame.Angles(0, math.rad(90), 0), 8, 4)

	-- BLOCK C (-,-): parking lot + gas station + corner store
	kit:Part(Vector3.new(70, 0.1, 70), CFrame.new(-50, 0.85, -50), P.Asphalt, M.Asphalt)
	for i = 0, 6 do
		kit:Deco(Vector3.new(0.4, 0.05, 12), CFrame.new(-82 + i * 10, 0.93, -26), P.White, M.SmoothPlastic)
		kit:Deco(Vector3.new(0.4, 0.05, 12), CFrame.new(-82 + i * 10, 0.93, -74), P.White, M.SmoothPlastic)
	end
	for _, x in { -64, -36 } do
		for _, z in { -58, -42 } do
			kit:Pillar(Vector3.new(x, 0.8, z), 12, 1.4, P.White, M.SmoothPlastic)
		end
	end
	kit:Part(Vector3.new(34, 1.6, 22), CFrame.new(-50, 13.6, -50), P.White, M.SmoothPlastic)
	kit:Neon(Vector3.new(34.2, 0.6, 22.2), CFrame.new(-50, 12.9, -50), rgb(220, 40, 40))
	kit:Ladder(Vector3.new(-66.5, 0.8, -50), 14, nil)
	for _, x in { -56, -44 } do
		kit:Part(Vector3.new(2, 5, 3), CFrame.new(x, 3.3, -50), rgb(220, 40, 40), M.SmoothPlastic)
	end
	kit:Building({ Name = "Store", Origin = CFrame.new(-50, 0.8, -80) * CFrame.Angles(0, math.rad(180), 0), W = 30, D = 12, Floors = 1, Color = rgb(230, 230, 220), Material = M.SmoothPlastic, Trim = rgb(220, 40, 40), Doors = { Front = true }, Awning = rgb(220, 40, 40), Storefront = rgb(30, 120, 200), Props = false })
	kit:Sandbags(CFrame.new(-30, 0.8, -30) * CFrame.Angles(0, math.rad(45), 0), 10, 3)

	-- BLOCK D (+,-): office tower + pharmacy + plaza
	kit:Building({ Name = "Office", Origin = CFrame.new(62, 0.8, -60), W = 36, D = 36, Floors = 4, Color = rgb(170, 180, 190), Material = M.Concrete, Trim = rgb(60, 70, 90), Doors = { Front = true, Left = true }, Awning = rgb(60, 70, 90), FireEscape = "Right", OpenWindows = 0.2 })
	kit:Building({ Name = "Pharmacy", Origin = CFrame.new(28, 0.8, -78) * CFrame.Angles(0, math.rad(180), 0), W = 22, D = 16, Floors = 1, Color = rgb(235, 235, 235), Material = M.SmoothPlastic, Trim = rgb(30, 150, 80), Doors = { Front = true }, Awning = rgb(30, 150, 80), Storefront = rgb(30, 160, 90), Ladder = "Left", Props = false })
	for i = 1, 3 do
		kit:Barrier(CFrame.new(20 + i * 9, 0.8, -22) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0))
	end
	kit:Tree(Vector3.new(22, 0.8, -40), 1, "Oak")
	kit:HideBush(Vector3.new(36, 0.8, -40), 0.9)

	-- street cover: wrecked / parked cars, barriers, cones
	local parked = {
		{ -100, 40, 0, "Sedan" }, { -96, -60, 180, "Truck" }, { 6, 62, 0, "Sedan" }, { -6, -62, 180, "Sports" },
		{ 100, -30, 0, "Sedan" }, { 60, 4, 90, "Truck" }, { -60, -4, 270, "Sedan" }, { 40, 104, 90, "Sedan" }, { -40, -104, 270, "Truck" },
	}
	for _, c in parked do
		local spot = kit:VehicleSpot(CFrame.new(c[1], 0, c[2]) * CFrame.Angles(0, math.rad(c[3]), 0), c[4])
		spot:SetAttribute("Parked", true)
	end
	for _, b in { { -30, 0, 80 }, { 100, 60, -10 }, { 30, -100, 95 }, { -100, -30, 5 }, { 70, 100, 85 } } do
		kit:Barrier(CFrame.new(b[1], 0, b[2]) * CFrame.Angles(0, math.rad(b[3]), 0))
	end
	for _, c in { { 96, 8 }, { 92, 10 }, { -96, -8 }, { 8, 96 }, { -8, -96 } } do
		kit:Cone(Vector3.new(c[1], 0, c[2]))
	end
	for _, c in { { -94, 70, 0, "Sports" }, { 94, 40, 0, "Jeep" }, { -40, 96, 90, "Sedan" }, { 40, -96, 270, "Truck" } } do
		kit:VehicleSpot(CFrame.new(c[1], 0, c[2]) * CFrame.Angles(0, math.rad(c[3]), 0), c[4])
	end

	for _, p in { Vector3.new(20, 0.8, 20), Vector3.new(-20, 0.8, -20), Vector3.new(-20, 0.8, 20), Vector3.new(20, 0.8, -20) } do
		kit:HealthPack(p)
	end
	-- TRIPLE TEAM base (west road end) + FREE FOR ALL spawns all over the city
	kit:SpawnBase(Vector3.new(-138, 0.8, 0), Vector3.new(0, 0, 0), "C", 150)
	-- CHARLIE plaza on the west strip: lamps, planters and cover instead of towers
	for _, z in { -80, -50, -20, 20, 50, 80 } do
		kit:StreetLight(Vector3.new(-113.5, 0.8, z), Vector3.new(1, 0, 0))
	end
	for _, p in { { -126, -70 }, { -150, -40 }, { -126, 40 }, { -150, 72 } } do
		kit:CoverCluster(Vector3.new(p[1], 0.8, p[2]), "City", "Planter")
	end
	kit:CoverCluster(Vector3.new(-128, 0.8, -28), "City", "BrokenWall")
	kit:CoverCluster(Vector3.new(-128, 0.8, 28), "City", "Crates")
	-- MORE COVER: open lots + both sides of every street (driving lanes stay clear)
	kit:CoverField({ { -51, -31 }, { 67, -27 }, { 29, -57 }, { -25, -65 }, { -51, -61 }, { -29, 29 }, { -77, -35 }, { -77, -73 } }, "City")
	for _, c in ROADS do
		-- keep the avenue's subway stairs and the spawn ends clear
		local ends = c == 0 and { -100, 0, 100, -138, 138, -80, -20, 20, 80 } or { -100, 0, 100 }
		kit:RoadCover("X", c, -146, 146, 30, 8, "City", c == 0 and { -100, 0, 100, -138 } or { -100, 0, 100 })
		kit:RoadCover("Z", c, -146, 146, 30, 8, "City", ends)
	end
	local ffa = {}
	for _, x in ROADS do
		for _, z in { -50, 50 } do
			table.insert(ffa, Vector3.new(x, 0, z))
		end
	end
	for _, z in ROADS do
		for _, x in { -40, 40 } do
			table.insert(ffa, Vector3.new(x, 0, z))
		end
	end
	for _, p in { { 0, -118 }, { 0, 118 }, { -40, -135 }, { 40, -135 }, { -40, 135 }, { 40, 135 }, { 60, 72 }, { -84, -40 }, { 84, 30 } } do
		table.insert(ffa, Vector3.new(p[1], 0, p[2]))
	end
	kit:FFASpawns(ffa)

	-- mountains all around (beyond the boundary, can't be reached)
	kit:Mountains(HALF, HALF, { Margin = 60, GroundY = -0.5 })
	kit:Boundary(HALF - 2, HALF - 2, 260)
	return kit
end

return Map
