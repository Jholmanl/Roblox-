-- Builds drivable cars out of parts. Styles: Sedan, Sports, Jeep, Truck.
-- Physics: 4 invisible low-friction balls carry the car (they ride up curbs),
-- the driver's client sets the velocity directly (arcade handling).
local CarBuilder = {}

local rgb = Color3.fromRGB
local M = Enum.Material

CarBuilder.Styles = {
	Sedan = { W = 7, L = 14, Body = 2.4, Cabin = 2.4, CabinL = 7, CabinZ = 0.6, Wheel = 2.8, Speed = 80, Health = 450, Colors = { rgb(30, 60, 140), rgb(200, 200, 205), rgb(25, 25, 28), rgb(150, 20, 30) } },
	Sports = { W = 7.2, L = 14, Body = 1.8, Cabin = 1.9, CabinL = 5.5, CabinZ = 1, Wheel = 2.6, Speed = 105, Health = 350, Spoiler = true, Colors = { rgb(230, 40, 40), rgb(255, 196, 26), rgb(20, 200, 120), rgb(240, 240, 240) } },
	Jeep = { W = 7.6, L = 13, Body = 3, Cabin = 0, CabinL = 6, CabinZ = 0.5, Wheel = 3.6, Speed = 75, Health = 600, Open = true, Colors = { rgb(80, 100, 60), rgb(140, 120, 80), rgb(60, 80, 100) } },
	Truck = { W = 8, L = 18, Body = 3, Cabin = 3.2, CabinL = 6, CabinZ = -4.5, Wheel = 3.4, Speed = 65, Health = 800, Bed = true, Colors = { rgb(160, 60, 40), rgb(230, 230, 225), rgb(40, 70, 120) } },
}

local function part(model, name, size, cf, color, material, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = collide == true
	p.Parent = model
	return p
end

function CarBuilder.Build(style: string, color: Color3?, anchored: boolean?)
	local s = CarBuilder.Styles[style] or CarBuilder.Styles.Sedan
	local seed = math.random(1, #s.Colors)
	local paint = color or s.Colors[seed]
	local W, L = s.W, s.L
	local model = Instance.new("Model")
	model.Name = style
	model:SetAttribute("Vehicle", style)
	model:SetAttribute("MaxHealth", s.Health)
	model:SetAttribute("Health", s.Health)
	model:SetAttribute("Speed", s.Speed)

	local floorY = 1.3
	local chassis = part(model, "Chassis", Vector3.new(W - 0.4, 1, L - 0.6), CFrame.new(0, floorY, 0), rgb(30, 30, 32), M.Metal, true)
	chassis.PivotOffset = CFrame.new(0, -floorY, 0)
	model.PrimaryPart = chassis

	local bodyY = floorY + 0.5 + s.Body / 2
	local body = part(model, "Body", Vector3.new(W, s.Body, L), CFrame.new(0, bodyY, 0), paint, M.SmoothPlastic, true)
	body.Reflectance = 0.08
	local top = floorY + 0.5 + s.Body
	-- bumpers + grill
	part(model, "BumperF", Vector3.new(W + 0.2, 0.8, 0.6), CFrame.new(0, floorY + 0.6, -L / 2 - 0.2), rgb(40, 40, 44), M.Metal)
	part(model, "BumperR", Vector3.new(W + 0.2, 0.8, 0.6), CFrame.new(0, floorY + 0.6, L / 2 + 0.2), rgb(40, 40, 44), M.Metal)
	part(model, "Grill", Vector3.new(W * 0.5, s.Body * 0.45, 0.2), CFrame.new(0, bodyY - 0.1, -L / 2 - 0.05), rgb(20, 20, 22), M.Metal)
	-- lights
	for _, x in { -W / 2 + 1, W / 2 - 1 } do
		local head = part(model, "Headlight", Vector3.new(1.4, 0.6, 0.2), CFrame.new(x, bodyY + s.Body * 0.2, -L / 2 - 0.05), rgb(255, 250, 230), M.Neon)
		if x < 0 then
			local spot = Instance.new("SpotLight")
			spot.Range = 45
			spot.Brightness = 3
			spot.Angle = 60
			spot.Face = Enum.NormalId.Front
			spot.Parent = head
		end
		part(model, "Taillight", Vector3.new(1.4, 0.5, 0.2), CFrame.new(x, bodyY + s.Body * 0.2, L / 2 + 0.05), rgb(255, 30, 30), M.Neon)
	end

	-- cabin
	if s.Open then
		-- roll bar + windshield frame
		for _, x in { -W / 2 + 0.4, W / 2 - 0.4 } do
			part(model, "RollBar", Vector3.new(0.4, 3.2, 0.4), CFrame.new(x, top + 1.6, 1.5), rgb(30, 30, 30), M.Metal)
		end
		part(model, "RollBarTop", Vector3.new(W - 0.4, 0.4, 0.4), CFrame.new(0, top + 3.2, 1.5), rgb(30, 30, 30), M.Metal)
		local ws = part(model, "Windshield", Vector3.new(W - 0.6, 2, 0.2), CFrame.new(0, top + 1, -1.8) * CFrame.Angles(math.rad(-15), 0, 0), rgb(150, 200, 230), M.Glass)
		ws.Transparency = 0.5
		part(model, "Spare", Vector3.new(0.8, s.Wheel, s.Wheel), CFrame.new(0, bodyY + 0.6, L / 2 + 0.7) * CFrame.Angles(0, math.rad(90), 0), rgb(25, 25, 25), M.Rubber).Shape = Enum.PartType.Cylinder
	else
		local cz = s.CabinZ
		local glass = part(model, "Cabin", Vector3.new(W - 0.7, s.Cabin, s.CabinL), CFrame.new(0, top + s.Cabin / 2, cz), rgb(120, 170, 210), M.Glass, true)
		glass.Transparency = 0.35
		glass.Reflectance = 0.2
		glass.CanQuery = false -- bullets pass through windows and hit the people inside
		part(model, "Roof", Vector3.new(W - 0.4, 0.35, s.CabinL - 0.6), CFrame.new(0, top + s.Cabin + 0.17, cz), paint, M.SmoothPlastic)
		for _, x in { -W / 2 + 0.35, W / 2 - 0.35 } do
			for _, z in { -s.CabinL / 2 + 0.2, s.CabinL / 2 - 0.2 } do
				part(model, "Pillar", Vector3.new(0.3, s.Cabin, 0.3), CFrame.new(x, top + s.Cabin / 2, cz + z), paint, M.SmoothPlastic)
			end
		end
	end
	if s.Spoiler then
		part(model, "Spoiler", Vector3.new(W - 0.6, 0.25, 1.4), CFrame.new(0, top + 1.2, L / 2 - 0.8), rgb(20, 20, 22), M.SmoothPlastic)
		for _, x in { -2.2, 2.2 } do
			part(model, "SpoilerLeg", Vector3.new(0.3, 1.1, 0.4), CFrame.new(x, top + 0.6, L / 2 - 0.8), rgb(20, 20, 22), M.SmoothPlastic)
		end
		part(model, "Stripe", Vector3.new(1.2, 0.05, L + 0.02), CFrame.new(0, top + 0.02, 0), rgb(255, 255, 255), M.SmoothPlastic)
	end
	if s.Bed then
		-- open cargo bed behind the cab
		for _, x in { -W / 2 + 0.2, W / 2 - 0.2 } do
			part(model, "BedWall", Vector3.new(0.4, 1.8, L - s.CabinL - 1.5), CFrame.new(x, top + 0.9, (s.CabinL + 1.5) / 2 - 0.2), paint, M.SmoothPlastic, true)
		end
		part(model, "Tailgate", Vector3.new(W, 1.8, 0.4), CFrame.new(0, top + 0.9, L / 2 - 0.2), paint, M.SmoothPlastic, true)
	end

	-- wheels (visual) + support balls (physics)
	local wz = L / 2 - s.Wheel * 0.75
	for _, x in { -W / 2 + 0.2, W / 2 - 0.2 } do
		for _, z in { -wz, wz } do
			local wheel = part(model, "Wheel", Vector3.new(1.3, s.Wheel, s.Wheel), CFrame.new(x, s.Wheel / 2, z), rgb(25, 25, 25), M.Rubber)
			wheel.Shape = Enum.PartType.Cylinder
			local rim = part(model, "Rim", Vector3.new(1.35, s.Wheel * 0.55, s.Wheel * 0.55), CFrame.new(x, s.Wheel / 2, z), rgb(190, 190, 196), M.Metal)
			rim.Shape = Enum.PartType.Cylinder
			local ball = part(model, "Support", Vector3.new(2.4, 2.4, 2.4), CFrame.new(x * 0.7, 1.2, z), rgb(0, 0, 0), M.SmoothPlastic, true)
			ball.Shape = Enum.PartType.Ball
			ball.Transparency = 1
			ball.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.02, 0, 100, 1)
		end
	end
	-- wheel arches
	for _, z in { -wz, wz } do
		part(model, "Arch", Vector3.new(W + 0.1, 0.4, s.Wheel + 0.6), CFrame.new(0, s.Wheel + 0.2, z), rgb(30, 30, 32), M.SmoothPlastic)
	end

	-- seats
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 0.6, 2)
	seat.CFrame = CFrame.new(-1.4, top - 0.4, s.CabinZ + 0.6)
	seat.Color = rgb(30, 30, 30)
	seat.HeadsUpDisplay = false
	seat.MaxSpeed = 0
	seat.Transparency = 0
	seat.Parent = model
	local passenger = Instance.new("Seat")
	passenger.Name = "PassengerSeat"
	passenger.Size = Vector3.new(2, 0.6, 2)
	passenger.CFrame = CFrame.new(1.4, top - 0.4, s.CabinZ + 0.6)
	passenger.Color = rgb(30, 30, 30)
	passenger.Parent = model

	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = anchored == true
			if p ~= chassis then
				local w = Instance.new("WeldConstraint")
				w.Part0 = chassis
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	return model
end

return CarBuilder
