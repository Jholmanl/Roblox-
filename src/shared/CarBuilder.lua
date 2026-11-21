-- Builds detailed, drivable cars out of parts. Styles: Sedan, Sports, Jeep, Truck.
-- Front of the car is the -Z side. The model pivot is on the ground under the car.
-- Physics: 4 invisible low-friction balls carry the car (they ride up curbs);
-- the driver's client sets the velocity directly (see VehicleController).
local CarBuilder = {}

local rgb = Color3.fromRGB
local M = Enum.Material

local BLACK = rgb(22, 22, 24)
local TRIM = rgb(36, 37, 40)
local CHROME = rgb(196, 198, 204)
local TIRE = rgb(26, 26, 27)
local GLASS = rgb(70, 92, 110)
local INTERIOR = rgb(40, 38, 36)

CarBuilder.Styles = {
	Sedan = {
		W = 7.2, L = 15, Wheel = 2.9, Clear = 0.9, Belt = 3.6, HoodFront = 3.05, Roof = 5.7,
		WsBase = -1.9, RoofFront = 0.2, RoofRear = 3.1, RearBase = 4.6, TrunkTop = 3.6,
		Speed = 80, Health = 450, Colors = { rgb(30, 60, 140), rgb(200, 200, 205), rgb(25, 25, 28), rgb(140, 22, 32), rgb(90, 100, 110) },
	},
	Sports = {
		W = 7.6, L = 14.6, Wheel = 2.7, Clear = 0.55, Belt = 2.95, HoodFront = 2.8, Roof = 4.5,
		WsBase = -1.4, RoofFront = 0.9, RoofRear = 2.1, RearBase = 5.4, TrunkTop = 3.0,
		Speed = 105, Health = 350, Spoiler = true, Colors = { rgb(220, 30, 30), rgb(255, 190, 20), rgb(20, 190, 120), rgb(240, 240, 240), rgb(20, 20, 24) },
	},
	Jeep = {
		W = 7.6, L = 13.2, Wheel = 3.7, Clear = 1.7, Belt = 4.5, HoodFront = 4.5, Roof = 7.6,
		WsBase = -0.9, RoofFront = -0.6, RoofRear = 4.6, RearBase = 6.6, TrunkTop = 4.5,
		Speed = 75, Health = 600, Open = true, Colors = { rgb(80, 100, 60), rgb(150, 128, 86), rgb(60, 80, 100), rgb(30, 32, 30) },
	},
	Truck = {
		W = 8, L = 18.5, Wheel = 3.5, Clear = 1.5, Belt = 4.6, HoodFront = 4.4, Roof = 7.4,
		WsBase = -3.0, RoofFront = -1.6, RoofRear = 1.4, RearBase = 1.9, TrunkTop = 4.6,
		Speed = 65, Health = 800, Bed = true, Colors = { rgb(160, 50, 36), rgb(232, 232, 228), rgb(40, 70, 120), rgb(30, 30, 32) },
	},
}

function CarBuilder.Build(style: string, color: Color3?, anchored: boolean?)
	local s = CarBuilder.Styles[style] or CarBuilder.Styles.Sedan
	local paint = color or s.Colors[math.random(1, #s.Colors)]
	local W, L, D = s.W, s.L, s.Wheel
	local r = D / 2
	local zF = -L / 2 + D * 1.02
	local zR = L / 2 - D * 1.1
	local Wc = W - 0.7 -- cabin width

	local model = Instance.new("Model")
	model.Name = style
	model:SetAttribute("Vehicle", style)
	model:SetAttribute("MaxHealth", s.Health)
	model:SetAttribute("Health", s.Health)
	model:SetAttribute("Speed", s.Speed)

	local function part(name, size, cf, col, material, collide, class)
		local p = Instance.new(class or "Part")
		p.Name = name
		p.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
		p.CFrame = cf
		p.Color = col
		p.Material = material or M.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = collide == true
		p.Parent = model
		return p
	end
	local function painted(name, size, cf, collide)
		local p = part(name, size, cf, paint, M.SmoothPlastic, collide)
		p.Reflectance = 0.12
		return p
	end
	local function cylX(name, length, diameter, pos, col, material)
		local p = part(name, Vector3.new(length, diameter, diameter), CFrame.new(pos), col, material)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function beam(name, a, b, thick, col, material)
		local len = (b - a).Magnitude
		return part(name, Vector3.new(thick, thick, len), CFrame.lookAt((a + b) / 2, b), col, material or M.SmoothPlastic)
	end
	local function glass(name, size, cf, class)
		local g = part(name, size, cf, GLASS, M.Glass, true, class)
		g.Transparency = 0.45
		g.Reflectance = 0.25
		g.CanQuery = false -- bullets pass through windows and hit the people inside
		return g
	end

	-- CHASSIS (physics root) -------------------------------------------------------
	local chassisY = s.Clear + 0.5
	local chassis = part("Chassis", Vector3.new(W - 0.6, 1, L - 1), CFrame.new(0, chassisY, 0), BLACK, M.Metal, true)
	chassis.PivotOffset = CFrame.new(0, -chassisY, 0)
	model.PrimaryPart = chassis

	-- LOWER BODY in segments so the wheel wells are open ----------------------------
	local archF0, archF1 = zF - r - 0.25, zF + r + 0.25
	local archR0, archR1 = zR - r - 0.25, zR + r + 0.25
	local bottom = s.Clear + 0.2
	local archBottom = math.max(D + 0.12, bottom)
	local frontTop = s.HoodFront
	local segments = {
		{ "FrontOverhang", -L / 2, archF0, bottom, frontTop },
		{ "FrontFender", archF0, archF1, archBottom, frontTop },
		{ "Rocker", archF1, archR0, bottom, s.Belt },
		{ "RearFender", archR0, archR1, archBottom, s.Bed and s.Belt or s.TrunkTop },
		{ "RearOverhang", archR1, L / 2, bottom, s.Bed and s.Belt or s.TrunkTop },
	}
	for _, seg in segments do
		local z0, z1, y0, y1 = seg[2], seg[3], seg[4], seg[5]
		-- the front-of-cabin area between the hood and windshield sits at belt height
		painted(seg[1], Vector3.new(W, y1 - y0, z1 - z0), CFrame.new(0, (y0 + y1) / 2, (z0 + z1) / 2), true)
	end
	-- hood: rises from the nose to the windshield base (wedge = high side at +Z)
	if s.Belt > frontTop + 0.05 then
		local hz0, hz1 = -L / 2, s.WsBase
		local wedge = part("Hood", Vector3.new(W, s.Belt - frontTop, hz1 - hz0), CFrame.new(0, frontTop + (s.Belt - frontTop) / 2, (hz0 + hz1) / 2), paint, M.SmoothPlastic, true, "WedgePart")
		wedge.Reflectance = 0.12
	end
	-- cowl between the hood and the cabin
	painted("Cowl", Vector3.new(W, s.Belt - frontTop + 0.01, math.max(0.1, archF1 - s.WsBase)), CFrame.new(0, (frontTop + s.Belt) / 2, s.WsBase + math.max(0.1, archF1 - s.WsBase) / 2), true)

	-- hood details
	beam("HoodLine", Vector3.new(-W * 0.22, frontTop + 0.02, -L / 2 + 0.3), Vector3.new(-W * 0.22, s.Belt + 0.02, s.WsBase - 0.1), 0.05, paint:Lerp(BLACK, 0.4))
	beam("HoodLine2", Vector3.new(W * 0.22, frontTop + 0.02, -L / 2 + 0.3), Vector3.new(W * 0.22, s.Belt + 0.02, s.WsBase - 0.1), 0.05, paint:Lerp(BLACK, 0.4))
	if s.Spoiler then
		for _, x in { -1.1, 1.1 } do
			part("HoodVent", Vector3.new(1.1, 0.06, 1.0), CFrame.new(x, s.Belt - 0.05, s.WsBase - 1.4) * CFrame.Angles(math.rad(-4), 0, 0), BLACK)
		end
	end

	-- GREENHOUSE ----------------------------------------------------------------------
	local cabinH = s.Roof - s.Belt
	if s.Open then
		-- jeep: upright windshield frame + roll cage
		local wsTop = s.Belt + 2.6
		glass("Windshield", Vector3.new(Wc, 2.4, 0.15), CFrame.new(0, s.Belt + 1.3, s.WsBase) * CFrame.Angles(math.rad(-10), 0, 0))
		part("WindshieldFrame", Vector3.new(Wc + 0.2, 0.2, 0.25), CFrame.new(0, wsTop, s.WsBase + 0.22), TRIM, M.Metal)
		for _, x in { -Wc / 2, Wc / 2 } do
			part("WindshieldPost", Vector3.new(0.2, 2.6, 0.25), CFrame.new(x, s.Belt + 1.3, s.WsBase + 0.1) * CFrame.Angles(math.rad(-10), 0, 0), TRIM, M.Metal)
			beam("CageSide", Vector3.new(x, wsTop, s.WsBase + 0.25), Vector3.new(x, s.Roof, 1.6), 0.24, TRIM, M.Metal)
			beam("CageTop", Vector3.new(x, s.Roof, 1.6), Vector3.new(x, s.Roof, s.RoofRear), 0.24, TRIM, M.Metal)
			beam("CageRear", Vector3.new(x, s.Roof, s.RoofRear), Vector3.new(x, s.Belt, s.RoofRear + 0.3), 0.24, TRIM, M.Metal)
			beam("CageMid", Vector3.new(x, s.Roof, 1.6), Vector3.new(x, s.Belt, 1.6), 0.24, TRIM, M.Metal)
		end
		beam("CageCross", Vector3.new(-Wc / 2, s.Roof, 1.6), Vector3.new(Wc / 2, s.Roof, 1.6), 0.24, TRIM, M.Metal)
		beam("CageCross2", Vector3.new(-Wc / 2, s.Roof, s.RoofRear), Vector3.new(Wc / 2, s.Roof, s.RoofRear), 0.24, TRIM, M.Metal)
		local bar = part("LightBar", Vector3.new(Wc * 0.8, 0.3, 0.4), CFrame.new(0, s.Roof + 0.25, 1.6), BLACK, M.Metal)
		for i = -2, 2 do
			part("RoofLight", Vector3.new(0.5, 0.22, 0.05), CFrame.new(i * 1.1, s.Roof + 0.25, 1.38), rgb(255, 250, 230), M.Neon)
		end
		bar.Name = "LightBar"
	else
		-- windshield: glass wedge from the cowl up to the roof (sides become the front side windows)
		local wsLen = s.RoofFront - s.WsBase
		glass("Windshield", Vector3.new(Wc, cabinH, wsLen), CFrame.new(0, s.Belt + cabinH / 2, s.WsBase + wsLen / 2), "WedgePart")
		local midLen = s.RoofRear - s.RoofFront
		glass("SideGlass", Vector3.new(Wc, cabinH, midLen), CFrame.new(0, s.Belt + cabinH / 2, s.RoofFront + midLen / 2))
		local rearLen = s.RearBase - s.RoofRear
		local rearDrop = s.Roof - (s.Bed and s.Belt or s.TrunkTop)
		glass("RearWindow", Vector3.new(Wc, rearDrop, rearLen), CFrame.new(0, s.Roof - rearDrop / 2, s.RoofRear + rearLen / 2) * CFrame.Angles(0, math.rad(180), 0), "WedgePart")
		painted("Roof", Vector3.new(Wc + 0.12, 0.25, midLen + 0.4), CFrame.new(0, s.Roof + 0.1, s.RoofFront + midLen / 2), true)
		-- pillars
		for _, x in { -Wc / 2, Wc / 2 } do
			beam("APillar", Vector3.new(x, s.Belt, s.WsBase), Vector3.new(x, s.Roof, s.RoofFront), 0.24, paint)
			beam("CPillar", Vector3.new(x, s.Roof, s.RoofRear), Vector3.new(x, s.Bed and s.Belt or s.TrunkTop, s.RearBase), 0.3, paint)
			part("BPillar", Vector3.new(0.22, cabinH, 0.4), CFrame.new(x, s.Belt + cabinH / 2, s.RoofFront + midLen * 0.45), TRIM)
			-- rounded roof edge
			local rail = part("RoofRail", Vector3.new(midLen + 0.3, 0.32, 0.32), CFrame.new(x, s.Roof + 0.02, s.RoofFront + midLen / 2) * CFrame.Angles(0, math.rad(90), 0), paint)
			rail.Shape = Enum.PartType.Cylinder
			rail.Reflectance = 0.12
		end
		-- wipers
		for _, x in { -1.3, 1.0 } do
			beam("Wiper", Vector3.new(x, s.Belt + 0.05, s.WsBase + 0.15), Vector3.new(x - 1.3, s.Belt + 0.35, s.WsBase + 0.5), 0.06, BLACK)
		end
	end
	-- trunk lid / fastback deck
	if not s.Bed and not s.Open then
		local deckZ0 = s.RearBase
		if L / 2 - deckZ0 > 0.2 then
			painted("TrunkLid", Vector3.new(W, 0.15, L / 2 - deckZ0), CFrame.new(0, s.TrunkTop + 0.07, (deckZ0 + L / 2) / 2), false)
		end
	end
	-- side mirrors
	for _, sx in { -1, 1 } do
		local base = Vector3.new(sx * (W / 2 + 0.05), s.Belt + 0.3, s.WsBase + 0.6)
		part("MirrorArm", Vector3.new(0.5, 0.12, 0.2), CFrame.new(base + Vector3.new(sx * 0.2, 0, 0)), TRIM)
		painted("Mirror", Vector3.new(0.25, 0.5, 0.75), CFrame.new(base + Vector3.new(sx * 0.5, 0.15, 0)), false)
		part("MirrorGlass", Vector3.new(0.27, 0.4, 0.05), CFrame.new(base + Vector3.new(sx * 0.5, 0.15, 0.39)), rgb(160, 190, 210), M.Glass)
	end

	-- SIDES: door seams, handles, skirts ---------------------------------------------
	local doorFront = s.Open and s.WsBase - 0.2 or s.WsBase + 0.3
	local doorSplit = s.Open and 1.4 or s.RoofFront + (s.RoofRear - s.RoofFront) * 0.45
	local doorRear = s.Bed and s.RoofRear + 0.3 or math.min(archR0 - 0.2, s.RoofRear + 0.6)
	for _, sx in { -1, 1 } do
		local x = sx * (W / 2 + 0.02)
		local seamH = s.Belt - bottom - 0.2
		for _, z in { doorFront, doorSplit, doorRear } do
			part("DoorSeam", Vector3.new(0.05, seamH, 0.06), CFrame.new(x, bottom + 0.1 + seamH / 2, z), BLACK)
		end
		for _, z in { doorSplit - 0.6, doorRear - 0.6 } do
			if not (s.Spoiler and z > doorSplit) then
				part("Handle", Vector3.new(0.08, 0.14, 0.55), CFrame.new(x + sx * 0.03, s.Belt - 0.55, z), CHROME, M.Metal)
			end
		end
		part("BeltTrim", Vector3.new(0.06, 0.1, archR0 - archF1), CFrame.new(x, s.Belt - 0.05, (archF1 + archR0) / 2), s.Open and paint or CHROME, M.Metal)
		part("SideSkirt", Vector3.new(0.12, 0.4, archR0 - archF1), CFrame.new(x, bottom + 0.2, (archF1 + archR0) / 2), TRIM)
		-- fender flares on off-road / sports styles
		if s.Open or s.Bed or s.Spoiler then
			for _, z in { zF, zR } do
				part("FenderFlare", Vector3.new(0.35, 0.35, D + 0.8), CFrame.new(sx * (W / 2 + 0.15), archBottom + 0.12, z), s.Spoiler and paint or TRIM)
			end
		end
	end

	-- FRONT --------------------------------------------------------------------------
	local nose = -L / 2
	part("Grille", Vector3.new(W * 0.48, frontTop - bottom - 0.7, 0.12), CFrame.new(0, bottom + 0.45 + (frontTop - bottom - 0.7) / 2, nose - 0.04), BLACK, M.Metal)
	for i = 1, 3 do
		part("GrilleBar", Vector3.new(W * 0.48, 0.07, 0.06), CFrame.new(0, bottom + 0.45 + i * (frontTop - bottom - 0.7) / 4, nose - 0.1), s.Spoiler and BLACK or CHROME, M.Metal)
	end
	part("BumperF", Vector3.new(W + 0.15, 0.7, 0.45), CFrame.new(0, bottom + 0.35, nose - 0.12), s.Open and BLACK or paint:Lerp(BLACK, 0.15), M.SmoothPlastic, true)
	-- rounded bumper face + rounded body corners (so the car isn't a box)
	local bumperCol = s.Open and BLACK or paint:Lerp(BLACK, 0.15)
	cylX("BumperFRound", W - 0.2, 0.7, Vector3.new(0, bottom + 0.35, nose - 0.32), bumperCol, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		local h = frontTop - bottom
		local corner = part("CornerF", Vector3.new(h, 0.8, 0.8), CFrame.new(sx * (W / 2 - 0.3), bottom + h / 2, nose + 0.1) * CFrame.Angles(0, 0, math.rad(90)), paint)
		corner.Shape = Enum.PartType.Cylinder
		corner.Reflectance = 0.12
	end
	part("PlateF", Vector3.new(1.6, 0.5, 0.05), CFrame.new(0, bottom + 0.4, nose - 0.36), rgb(240, 240, 240))
	for _, sx in { -1, 1 } do
		local hx = sx * (W / 2 - 0.95)
		local hy = frontTop - 0.42
		if s.Open then
			cylX("HeadlightRing", 0.2, 0.95, Vector3.new(0, 0, 0), CHROME, M.Metal).CFrame = CFrame.new(hx, hy, nose - 0.08) * CFrame.Angles(0, math.rad(90), 0)
			cylX("Headlight", 0.22, 0.75, Vector3.new(0, 0, 0), rgb(255, 250, 230), M.Neon).CFrame = CFrame.new(hx, hy, nose - 0.1) * CFrame.Angles(0, math.rad(90), 0)
		else
			part("HeadlightHousing", Vector3.new(1.5, 0.55, 0.22), CFrame.new(hx, hy, nose - 0.06), rgb(200, 210, 220), M.Glass).Transparency = 0.3
			part("Headlight", Vector3.new(0.6, 0.32, 0.12), CFrame.new(hx - sx * 0.3, hy, nose - 0.02), rgb(255, 250, 230), M.Neon)
			part("DRL", Vector3.new(1.3, 0.07, 0.1), CFrame.new(hx, hy - 0.22, nose - 0.05), rgb(255, 255, 255), M.Neon)
		end
		part("FogLight", Vector3.new(0.4, 0.22, 0.08), CFrame.new(sx * (W / 2 - 1.1), bottom + 0.35, nose - 0.36), rgb(255, 240, 200), M.Neon)
	end
	local lightPart = model:FindFirstChild("Headlight")
	if lightPart then
		local spot = Instance.new("SpotLight")
		spot.Range = 50
		spot.Brightness = 3
		spot.Angle = 60
		spot.Face = s.Open and Enum.NormalId.Right or Enum.NormalId.Front
		spot.Parent = lightPart
	end
	if s.Open or s.Bed then
		-- bull bar
		for _, sx in { -1.4, 1.4 } do
			part("BullBarPost", Vector3.new(0.2, 1.8, 0.2), CFrame.new(sx, bottom + 1.1, nose - 0.6), BLACK, M.Metal)
		end
		part("BullBar", Vector3.new(3.4, 0.2, 0.2), CFrame.new(0, bottom + 2, nose - 0.6), BLACK, M.Metal)
	end

	-- REAR -----------------------------------------------------------------------------
	local tail = L / 2
	local tailTop = s.Bed and s.Belt or s.TrunkTop
	part("BumperR", Vector3.new(W + 0.15, 0.7, 0.45), CFrame.new(0, bottom + 0.35, tail + 0.12), s.Open and BLACK or paint:Lerp(BLACK, 0.15), M.SmoothPlastic, true)
	cylX("BumperRRound", W - 0.2, 0.7, Vector3.new(0, bottom + 0.35, tail + 0.32), s.Open and BLACK or paint:Lerp(BLACK, 0.15), M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		local h = tailTop - bottom
		local corner = part("CornerR", Vector3.new(h, 0.8, 0.8), CFrame.new(sx * (W / 2 - 0.3), bottom + h / 2, tail - 0.1) * CFrame.Angles(0, 0, math.rad(90)), paint)
		corner.Shape = Enum.PartType.Cylinder
		corner.Reflectance = 0.12
	end
	part("PlateR", Vector3.new(1.6, 0.5, 0.05), CFrame.new(0, bottom + 1.0, tail + 0.03), rgb(240, 240, 240))
	part("PlateStripe", Vector3.new(1.6, 0.1, 0.06), CFrame.new(0, bottom + 1.2, tail + 0.04), rgb(30, 60, 150))
	for _, sx in { -1, 1 } do
		local tx = sx * (W / 2 - 0.8)
		part("Taillight", Vector3.new(1.4, 0.5, 0.1), CFrame.new(tx, tailTop - 0.45, tail + 0.03), rgb(255, 30, 30), M.Neon)
		part("ReverseLight", Vector3.new(0.4, 0.2, 0.1), CFrame.new(tx - sx * 0.4, tailTop - 0.85, tail + 0.03), rgb(240, 240, 240), M.Neon)
		cylX("Exhaust", 0.6, 0.32, Vector3.new(0, 0, 0), CHROME, M.Metal).CFrame = CFrame.new(sx * (W / 2 - 1.6), bottom + 0.1, tail + 0.25) * CFrame.Angles(0, math.rad(90), 0)
	end
	if s.Spoiler then
		painted("Spoiler", Vector3.new(W - 0.6, 0.2, 1.3), CFrame.new(0, tailTop + 1.1, tail - 0.8), false)
		for _, x in { -2.3, 2.3 } do
			part("SpoilerLeg", Vector3.new(0.25, 1.0, 0.4), CFrame.new(x, tailTop + 0.55, tail - 0.8), BLACK)
		end
		for x = -2, 2 do
			part("Diffuser", Vector3.new(0.08, 0.35, 0.8), CFrame.new(x * 0.8, bottom + 0.1, tail - 0.1), BLACK)
		end
		part("Stripe", Vector3.new(0.7, 0.03, L * 0.62), CFrame.new(-0.55, s.Belt + 0.02, -L * 0.18), rgb(245, 245, 245))
		part("Stripe2", Vector3.new(0.7, 0.03, L * 0.62), CFrame.new(0.55, s.Belt + 0.02, -L * 0.18), rgb(245, 245, 245))
	end
	if s.Open then
		-- spare wheel on the tailgate
		cylX("Spare", 1.0, D * 0.9, Vector3.new(0, 0, 0), TIRE, M.Rubber).CFrame = CFrame.new(0, s.Belt - 0.3, tail + 0.55) * CFrame.Angles(0, math.rad(90), 0)
		cylX("SpareRim", 1.04, D * 0.5, Vector3.new(0, 0, 0), CHROME, M.Metal).CFrame = CFrame.new(0, s.Belt - 0.3, tail + 0.56) * CFrame.Angles(0, math.rad(90), 0)
		-- snorkel
		local sx = W / 2 + 0.2
		part("Snorkel", Vector3.new(0.35, 2.6, 0.35), CFrame.new(sx, s.Belt + 1.1, s.WsBase + 0.1), BLACK)
	end

	-- PICKUP BED -----------------------------------------------------------------------
	if s.Bed then
		local z0 = s.RearBase + 0.2
		local len = L / 2 - z0
		part("BedFloor", Vector3.new(W - 0.6, 0.2, len), CFrame.new(0, s.Belt - 1.6, z0 + len / 2), rgb(40, 40, 42), M.DiamondPlate)
		for _, sx in { -1, 1 } do
			part("BedRail", Vector3.new(0.18, 0.12, len), CFrame.new(sx * (W / 2 - 0.1), s.Belt + 0.08, z0 + len / 2), CHROME, M.Metal)
		end
		painted("Tailgate", Vector3.new(W, 1.7, 0.25), CFrame.new(0, s.Belt - 0.85, L / 2 - 0.12), true)
		part("TowHitch", Vector3.new(0.4, 0.4, 0.9), CFrame.new(0, bottom + 0.1, tail + 0.6), BLACK, M.Metal)
		for i = -2, 2 do
			part("CabLight", Vector3.new(0.4, 0.15, 0.25), CFrame.new(i * 0.9, s.Roof + 0.28, s.RoofFront + 0.2), rgb(255, 170, 30), M.Neon)
		end
	end

	-- INTERIOR -------------------------------------------------------------------------
	local seatZ = (s.Open and 1.6 or s.RoofFront + (s.RoofRear - s.RoofFront) * 0.55)
	local seatY = s.Belt - 1.55
	part("Dashboard", Vector3.new(Wc - 0.2, 0.9, 1.1), CFrame.new(0, s.Belt - 0.25, s.WsBase + 0.75), INTERIOR)
	part("Floor", Vector3.new(Wc - 0.2, 0.2, (s.RearBase - s.WsBase) * 0.8), CFrame.new(0, s.Clear + 1.05, (s.WsBase + s.RearBase) / 2), INTERIOR)
	for _, sx in { -1, 1 } do
		part("SeatBack", Vector3.new(1.7, 2.2, 0.4), CFrame.new(sx * Wc * 0.24, seatY + 1.3, seatZ + 1.0) * CFrame.Angles(math.rad(-12), 0, 0), INTERIOR, M.Fabric)
		part("Headrest", Vector3.new(1.0, 0.6, 0.35), CFrame.new(sx * Wc * 0.24, seatY + 2.65, seatZ + 1.25), INTERIOR, M.Fabric)
	end
	local wheel = part("SteeringWheel", Vector3.new(0.12, 1.1, 1.1), CFrame.new(-Wc * 0.24, s.Belt + 0.15, s.WsBase + 1.45) * CFrame.Angles(math.rad(-25), math.rad(90), 0), BLACK)
	wheel.Shape = Enum.PartType.Cylinder

	-- WHEELS ---------------------------------------------------------------------------
	local tireW = s.Open and 1.5 or (s.Bed and 1.4 or 1.25)
	for _, sx in { -1, 1 } do
		for _, z in { zF, zR } do
			local cx = sx * (W / 2 - tireW / 2 + 0.25)
			local center = Vector3.new(cx, r, z)
			cylX("Tire", tireW, D, center, TIRE, M.Rubber)
			cylX("Sidewall", tireW + 0.02, D * 0.8, center, rgb(36, 36, 38), M.Rubber)
			cylX("Rim", tireW + 0.04, D * 0.62, center, s.Spoiler and rgb(40, 40, 44) or (s.Open and rgb(70, 70, 74) or CHROME), M.Metal)
			cylX("Hub", tireW + 0.1, D * 0.18, center, rgb(60, 60, 64), M.Metal)
			local face = cx + sx * (tireW / 2 + 0.04)
			for k = 0, 4 do
				part("Spoke", Vector3.new(0.06, D * 0.24, 0.16), CFrame.new(face, r, z) * CFrame.Angles(math.rad(k * 72), 0, 0) * CFrame.new(0, D * 0.17, 0), s.Spoiler and rgb(25, 25, 28) or rgb(150, 152, 158), M.Metal)
			end
			if s.Spoiler then
				part("Caliper", Vector3.new(0.1, D * 0.2, D * 0.18), CFrame.new(face - sx * 0.05, r + D * 0.18, z - D * 0.12), rgb(220, 30, 30))
			end
			-- physics support (invisible)
			local ball = part("Support", Vector3.new(2.4, 2.4, 2.4), CFrame.new(sx * W * 0.32, 1.2, z), BLACK, M.SmoothPlastic, true)
			ball.Shape = Enum.PartType.Ball
			ball.Transparency = 1
			ball.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.02, 0, 100, 1)
		end
		-- wheel well liners (dark, behind the tires)
		for _, z in { zF, zR } do
			part("WellLiner", Vector3.new(0.1, 0.5, D + 0.4), CFrame.new(sx * (W / 2 - tireW - 0.1), archBottom - 0.1, z), BLACK)
		end
	end

	-- SEATS (functional) -----------------------------------------------------------
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(1.7, 0.5, 1.8)
	seat.CFrame = CFrame.new(-Wc * 0.24, seatY, seatZ)
	seat.Color = INTERIOR
	seat.Material = M.Fabric
	seat.HeadsUpDisplay = false
	seat.MaxSpeed = 0
	seat.Parent = model
	local passenger = Instance.new("Seat")
	passenger.Name = "PassengerSeat"
	passenger.Size = Vector3.new(1.7, 0.5, 1.8)
	passenger.CFrame = CFrame.new(Wc * 0.24, seatY, seatZ)
	passenger.Color = INTERIOR
	passenger.Material = M.Fabric
	passenger.Parent = model

	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = anchored == true
			if p ~= chassis then
				p.Massless = not p.CanCollide
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
