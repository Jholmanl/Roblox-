-- HARBOR: container maze, cranes, warehouses and a cargo ship you can board.
local MapKit = require(script.Parent.MapKit)
local M = Enum.Material
local P = MapKit.Palette
local rgb = Color3.fromRGB

local Map = {
	Id = "Harbor",
	Name = "HARBOR",
	Desc = "Shipping docks at sunset. Fight through the container maze.",
	Icon = "⚓",
	Lighting = {
		ClockTime = 17.4, Brightness = 2.4,
		Ambient = rgb(100, 80, 80), OutdoorAmbient = rgb(150, 120, 110),
		Atmosphere = { Density = 0.3, Haze = 2, Color = rgb(255, 190, 150), Decay = rgb(150, 90, 100) },
		Tint = rgb(255, 230, 210), Saturation = 0.15,
	},
}

local HALF = 180

function Map.Build()
	local kit = MapKit.new(33)
	local rng = kit.Rng

	-- land + sea
	kit:Part(Vector3.new(HALF * 2 + 20, 4, 230), CFrame.new(0, -2, -75), P.ConcreteDark, M.Concrete)
	kit:Part(Vector3.new(HALF * 2 + 20, 0.3, 1.5), CFrame.new(0, 0.15, 39.2), P.Yellow, M.SmoothPlastic)
	kit:Part(Vector3.new(HALF * 2 + 20, 6, 2), CFrame.new(0, -3, 40.5), P.ConcreteDark, M.Concrete)
	kit:Fill(M.Sand, CFrame.new(0, -14, 140), Vector3.new(HALF * 2 + 80, 6, 220))
	kit:Water(CFrame.new(0, -6, 140), Vector3.new(HALF * 2 + 80, 10, 220))
	for x = -HALF + 10, HALF - 10, 20 do
		kit:Pillar(Vector3.new(x, 0, 37.5), 1.5, 1.4, rgb(40, 40, 44), M.Metal)
	end
	kit:Road("X", Vector3.new(0, 0, 20), HALF * 2, 20, {})

	-- CONTAINER YARD (west) with a lane through the middle for the crane
	local cols = { -165, -153, -141, -117, -105, -93, -69, -57, -45 }
	local rows = { -140, -116, -92, -56, -32, -8 }
	for _, x in cols do
		for _, z in rows do
			if rng:NextNumber() > 0.14 then
				local stack = rng:NextInteger(1, 3)
				for level = 0, stack - 1 do
					kit:Container(CFrame.new(x, level * 8.5, z), nil, level == 0 and rng:NextNumber() < 0.25)
				end
			end
		end
	end
	kit:Crane(CFrame.new(-105, 0, -74), 92, 42)
	-- quay crane over the ship
	kit:Crane(CFrame.new(50, 0, 30) * CFrame.Angles(0, math.rad(90), 0), 34, 50)

	-- WAREHOUSES (east)
	kit:Building({
		Name = "Warehouse", Origin = CFrame.new(85, 0, -112), W = 60, D = 44, Floors = 1, FloorH = 18,
		Color = rgb(90, 110, 130), Material = M.CorrodedMetal, Trim = rgb(50, 60, 70), Floor = rgb(110, 110, 110),
		Doors = { Front = true, Back = true, Left = true, Right = true }, Awning = rgb(240, 180, 30),
	})
	kit:Building({
		Name = "PortOffice", Origin = CFrame.new(85, 0, -42), W = 50, D = 28, Floors = 2, FloorH = 12,
		Color = rgb(220, 214, 200), Material = M.Concrete, Trim = rgb(40, 90, 140),
		Doors = { Front = true, Back = true }, Awning = rgb(40, 90, 140),
	})
	-- fuel tanks
	for _, z in { -140, -95 } do
		kit:Pillar(Vector3.new(152, 0, z), 26, 26, rgb(225, 225, 220), M.Metal)
		kit:Cylinder(0.8, 26.5, CFrame.new(152, 18, z) * CFrame.Angles(0, 0, math.rad(90)), rgb(200, 60, 50), M.Metal)
	end
	kit:Fence(Vector3.new(130, 0, -165), Vector3.new(130, 0, -70), 6, P.MetalDark)

	-- CARGO SHIP + gangway
	kit:Ship(CFrame.new(0, 0, 77) * CFrame.Angles(0, math.rad(90), 0), 130, -20)
	kit:Ramp(Vector3.new(-20, 0, 36), Vector3.new(-20, 12.6, 62.5), 6, P.MetalDark, M.DiamondPlate)

	-- PIERS + boats
	for _, x in { -145, 145 } do
		kit:Pier(Vector3.new(x, 0, 41), Vector3.new(x, 0, 130), 10, 0.6)
		for _, side in { -1, 1 } do
			local bx, bz = x + side * 12, 95 + side * 10
			kit:Part(Vector3.new(8, 4, 20), CFrame.new(bx, -1.5, bz), side > 0 and P.White or rgb(40, 80, 140), M.SmoothPlastic)
			kit:Wedge(Vector3.new(8, 4, 6), CFrame.new(bx, -1.5, bz - 13), side > 0 and P.White or rgb(40, 80, 140), M.SmoothPlastic)
			kit:Part(Vector3.new(6, 4, 7), CFrame.new(bx, 2.5, bz + 3), P.White, M.SmoothPlastic)
			kit:Glass(Vector3.new(6.2, 1.5, 7.2), CFrame.new(bx, 3.2, bz + 3))
		end
	end

	-- LIGHTHOUSE island
	kit:FillBall(M.Rock, Vector3.new(135, -16, 165), 26)
	kit:Pillar(Vector3.new(135, 6, 165), 36, 8, P.White, M.SmoothPlastic)
	for y = 12, 36, 10 do
		kit:Cylinder(3, 8.2, CFrame.new(135, y, 165) * CFrame.Angles(0, 0, math.rad(90)), P.Red, M.SmoothPlastic)
	end
	local lamp = kit:Neon(Vector3.new(5, 5, 5), CFrame.new(135, 44.5, 165), rgb(255, 240, 180))
	kit:Light(lamp, "PointLight", rgb(255, 230, 170), 60, 3)

	-- dockside dressing
	for x = -170, 170, 34 do
		kit:Tree(Vector3.new(x, 0, 30), rng:NextNumber(0.9, 1.2), "Palm")
		kit:StreetLight(Vector3.new(x + 17, 0, 30), Vector3.new(0, 0, -1))
	end
	for i = 1, 14 do
		local x, z = rng:NextNumber(-25, 125), rng:NextNumber(-165, 5)
		if not (x > 50 and x < 120 and z > -140 and z < -24) then
			if i % 2 == 0 then
				kit:Crate(Vector3.new(x, 0, z), 4, rng:NextNumber(0, 1))
				kit:Crate(Vector3.new(x + 4.2, 0, z), 4, rng:NextNumber(0, 1))
			else
				for b = 0, 2 do
					kit:Pillar(Vector3.new(x + b * 2.3, 0, z), 3.6, 2.2, ({ rgb(30, 80, 160), rgb(200, 60, 40), rgb(60, 140, 70) })[b + 1], M.Metal)
				end
			end
		end
	end
	for _, b in { { -20, -60, 0 }, { 10, -100, 90 }, { -10, -140, 30 }, { 30, -10, 60 } } do
		kit:Barrier(CFrame.new(b[1], 0, b[2]) * CFrame.Angles(0, math.rad(b[3]), 0))
	end

	-- pickups, vehicles, spawns
	for _, p in { Vector3.new(-80, 0, -74), Vector3.new(30, 0, -74), Vector3.new(0, 0, 10), Vector3.new(160, 0, -40) } do
		kit:HealthPack(p)
	end
	kit:VehicleSpot(CFrame.new(-100, 0.5, 20) * CFrame.Angles(0, math.rad(-90), 0), "Truck")
	kit:VehicleSpot(CFrame.new(70, 0.5, 16) * CFrame.Angles(0, math.rad(90), 0), "Sedan")
	kit:VehicleSpot(CFrame.new(150, 0.5, -10), "Jeep")
	kit:VehicleSpot(CFrame.new(-20, 0.5, -165) * CFrame.Angles(0, math.rad(90), 0), "Sports")
	local parked = kit:VehicleSpot(CFrame.new(20, 0.5, -120), "Truck")
	parked:SetAttribute("Parked", true)
	for x = -150, 150, 50 do
		kit:Spawn(Vector3.new(x, 3, -168), Vector3.new(x, 3, 0))
	end
	for _, z in { -120, -60, 0 } do
		kit:Spawn(Vector3.new(-174, 3, z))
		kit:Spawn(Vector3.new(172, 3, z + 10))
	end
	kit:Spawn(Vector3.new(30, 16, 77), Vector3.new(-40, 16, 77))
	kit:Spawn(Vector3.new(-50, 16, 70), Vector3.new(40, 16, 70))
	kit:Boundary(HALF, HALF, 200)
	return kit
end

return Map
