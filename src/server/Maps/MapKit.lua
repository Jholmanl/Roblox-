-- MapKit: procedural building blocks for maps.
-- Everything is made of plain parts + Terrain, so maps need zero uploaded assets.
-- A map module calls kit:Building{...}, kit:Tree(...), kit:Road(...), etc.
local MapKit = {}
MapKit.__index = MapKit

local M = Enum.Material
local rgb = Color3.fromRGB

MapKit.Palette = {
	Asphalt = rgb(48, 50, 56),
	Concrete = rgb(150, 150, 146),
	ConcreteDark = rgb(105, 106, 108),
	Sidewalk = rgb(170, 168, 160),
	Brick = rgb(150, 80, 60),
	BrickDark = rgb(110, 60, 48),
	Plaster = rgb(214, 204, 186),
	Wood = rgb(124, 86, 54),
	WoodDark = rgb(84, 58, 38),
	WoodLight = rgb(170, 128, 84),
	Metal = rgb(92, 98, 108),
	MetalDark = rgb(52, 56, 64),
	Leaf = rgb(62, 124, 58),
	LeafDark = rgb(40, 92, 48),
	Pine = rgb(34, 86, 56),
	Trunk = rgb(96, 68, 44),
	Rock = rgb(118, 116, 112),
	Glass = rgb(150, 200, 230),
	Yellow = rgb(245, 200, 40),
	White = rgb(236, 236, 236),
	Red = rgb(200, 50, 50),
	Neon = rgb(0, 204, 255),
	NeonWarm = rgb(255, 198, 26),
}
local P = MapKit.Palette

function MapKit.new(seed: number?)
	local self = setmetatable({}, MapKit)
	local model = Instance.new("Model")
	model.Name = "Map"
	self.Model = model
	local function folder(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = model
		return f
	end
	self.Geo = folder("Geometry")
	self.Props = folder("Props")
	self.Spawns = folder("Spawns")
	self.VehicleSpots = folder("VehicleSpots")
	self.Terrain = workspace.Terrain
	self.Rng = Random.new(seed or 1)
	return self
end

-- PRIMITIVES ---------------------------------------------------------------------
function MapKit:Part(size: Vector3, cf: CFrame, color: Color3, material, parent, class)
	local p = Instance.new(class or "Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or self.Geo
	return p
end

-- Decorative part: no collisions, bullets pass through.
function MapKit:Deco(size, cf, color, material, parent)
	local p = self:Part(size, cf, color, material, parent or self.Props)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

function MapKit:Neon(size, cf, color, parent)
	local p = self:Deco(size, cf, color, M.Neon, parent)
	p.CastShadow = false
	return p
end

function MapKit:Wedge(size, cf, color, material, parent)
	return self:Part(size, cf, color, material, parent, "WedgePart")
end

-- Cylinder whose axis runs along the CFrame's X axis.
function MapKit:Cylinder(length: number, diameter: number, cf: CFrame, color, material, parent)
	local p = self:Part(Vector3.new(length, diameter, diameter), cf, color, material, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Vertical cylinder standing on `base` (bottom center).
function MapKit:Pillar(base: Vector3, height: number, diameter: number, color, material, parent)
	return self:Cylinder(height, diameter, CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, material, parent)
end

function MapKit:Ball(diameter: number, pos: Vector3, color, material, parent)
	local p = self:Part(Vector3.new(diameter, diameter, diameter), CFrame.new(pos), color, material, parent)
	p.Shape = Enum.PartType.Ball
	return p
end

-- See-through glass that stops players but lets bullets through.
function MapKit:Glass(size, cf, parent)
	local p = self:Part(size, cf, P.Glass, M.Glass, parent)
	p.Transparency = 0.6
	p.Reflectance = 0.15
	p.CanQuery = false
	p.CastShadow = false
	return p
end

-- Tilted slab from a low point to a high point; the top surface touches both points.
function MapKit:Ramp(low: Vector3, high: Vector3, width: number, color, material, parent)
	local length = (high - low).Magnitude
	local cf = CFrame.lookAt((low + high) / 2, high) * CFrame.new(0, -0.5, 0)
	return self:Part(Vector3.new(width, 1, length), cf, color or P.Concrete, material or M.Concrete, parent)
end

function MapKit:Light(part: BasePart, kind: string?, color: Color3?, range: number?, brightness: number?, face)
	local l = Instance.new(kind or "PointLight")
	l.Color = color or Color3.new(1, 0.95, 0.85)
	l.Range = range or 16
	l.Brightness = brightness or 1.5
	if face and l:IsA("SpotLight") then
		l.Face = face
		l.Angle = 100
	end
	l.Shadows = false
	l.Parent = part
	return l
end

-- GAMEPLAY MARKERS ---------------------------------------------------------------
function MapKit:Spawn(pos: Vector3, lookAt: Vector3?)
	local s = Instance.new("Part")
	s.Name = "Spawn"
	s.Anchored = true
	s.CanCollide = false
	s.CanQuery = false
	s.CanTouch = false
	s.Transparency = 1
	s.Size = Vector3.new(2, 1, 2)
	local target = lookAt or Vector3.new(0, pos.Y, 0)
	if (Vector3.new(target.X, pos.Y, target.Z) - pos).Magnitude < 0.1 then
		target = pos + Vector3.new(0, 0, -1)
	end
	s.CFrame = CFrame.lookAt(pos, Vector3.new(target.X, pos.Y, target.Z))
	s.Parent = self.Spawns
	return s
end

function MapKit:VehicleSpot(cf: CFrame, style: string?, color: Color3?)
	local s = Instance.new("Part")
	s.Name = "VehicleSpot"
	s.Anchored = true
	s.CanCollide = false
	s.CanQuery = false
	s.CanTouch = false
	s.Transparency = 1
	s.Size = Vector3.new(1, 1, 1)
	s.CFrame = cf
	s:SetAttribute("Style", style or "Sedan")
	if color then
		s:SetAttribute("Color", color)
	end
	s.Parent = self.VehicleSpots
	return s
end

function MapKit:HealthPack(pos: Vector3)
	local hp = self:Part(Vector3.new(2.5, 2.5, 2.5), CFrame.new(pos + Vector3.new(0, 1.5, 0)), rgb(70, 230, 120), M.Neon, self.Props)
	hp.Name = "HealthPack"
	hp.CanCollide = false
	hp:SetAttribute("HealthPack", true)
	self:Light(hp, "PointLight", rgb(70, 230, 120), 12, 1.5)
	self:Part(Vector3.new(4, 0.4, 4), CFrame.new(pos + Vector3.new(0, 0.2, 0)), P.MetalDark, M.DiamondPlate, self.Geo)
	return hp
end

function MapKit:JumpPad(pos: Vector3, power: number?)
	local pad = self:Cylinder(0.6, 8, CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(170, 90, 255), M.Neon, self.Geo)
	pad.Name = "JumpPad"
	pad:SetAttribute("JumpPad", power or 115)
	self:Light(pad, "PointLight", rgb(170, 90, 255), 16, 3)
	return pad
end

-- Invisible walls around the playable area.
function MapKit:Boundary(halfX: number, halfZ: number, height: number?)
	local h = height or 120
	for _, s in { { halfX, 0, 2, halfZ * 2 }, { -halfX, 0, 2, halfZ * 2 }, { 0, halfZ, halfX * 2, 2 }, { 0, -halfZ, halfX * 2, 2 } } do
		local w = self:Part(Vector3.new(s[3], h, s[4]), CFrame.new(s[1], h / 2 - 10, s[2]), Color3.new(), M.SmoothPlastic, self.Geo)
		w.Name = "Boundary"
		w.Transparency = 1
		w.CanQuery = false
		w.CastShadow = false
	end
end

-- TERRAIN -------------------------------------------------------------------------
function MapKit:Fill(material, cf: CFrame, size: Vector3)
	self.Terrain:FillBlock(cf, size, material)
end

function MapKit:FillBall(material, center: Vector3, radius: number)
	self.Terrain:FillBall(center, radius, material)
end

function MapKit:Water(cf: CFrame, size: Vector3)
	self.Terrain:FillBlock(cf, size, M.Water)
end

-- WALLS & BUILDINGS -----------------------------------------------------------------
-- Builds a wall running along local +X or +Z from `start`, with openings
-- { At = distance along wall (center), Width, Bottom, Top, Glass = bool }.
function MapKit:Wall(origin: CFrame, start: Vector3, axis: string, length: number, height: number, thick: number, openings, color, material, parent)
	local function place(a0, a1, y0, y1, glass)
		local len, h = a1 - a0, y1 - y0
		if len < 0.1 or h < 0.1 then
			return
		end
		local mid = (a0 + a1) / 2
		local t = glass and 0.3 or thick
		local pos, size
		if axis == "X" then
			pos = start + Vector3.new(mid, (y0 + y1) / 2, 0)
			size = Vector3.new(len, h, t)
		else
			pos = start + Vector3.new(0, (y0 + y1) / 2, mid)
			size = Vector3.new(t, h, len)
		end
		if glass then
			self:Glass(size, origin * CFrame.new(pos), parent)
		else
			self:Part(size, origin * CFrame.new(pos), color, material, parent)
		end
	end
	table.sort(openings, function(a, b)
		return a.At < b.At
	end)
	local cursor = 0
	for _, o in openings do
		local l, r = o.At - o.Width / 2, o.At + o.Width / 2
		place(cursor, l, 0, height)
		place(l, r, 0, o.Bottom)
		place(l, r, o.Top, height)
		if o.Glass then
			place(l, r, o.Bottom, o.Top, true)
		end
		cursor = r
	end
	place(cursor, length, 0, height)
end

-- Horizontal slab (top surface at local y) with an optional rectangular hole.
function MapKit:Slab(origin: CFrame, y: number, w: number, d: number, thick: number, hole, color, material, parent)
	local function rect(x0, x1, z0, z1)
		if x1 - x0 > 0.1 and z1 - z0 > 0.1 then
			self:Part(Vector3.new(x1 - x0, thick, z1 - z0), origin * CFrame.new((x0 + x1) / 2, y - thick / 2, (z0 + z1) / 2), color, material, parent)
		end
	end
	local hw, hd = w / 2, d / 2
	if not hole then
		rect(-hw, hw, -hd, hd)
		return
	end
	rect(-hw, hw, -hd, hole.Z0) -- front strip
	rect(-hw, hw, hole.Z1, hd) -- back strip
	rect(-hw, hole.X0, hole.Z0, hole.Z1)
	rect(hole.X1, hw, hole.Z0, hole.Z1)
end

local function windowOpenings(length: number, floorH: number, spacing: number, door)
	local list = {}
	local count = math.max(0, math.floor((length - 4) / spacing))
	local startAt = (length - (count - 1) * spacing) / 2
	for i = 0, count - 1 do
		local at = startAt + i * spacing
		if not door or math.abs(at - door) > 6 then
			table.insert(list, { At = at, Width = 4, Bottom = 3, Top = floorH - 2.5, Glass = true })
		end
	end
	if door then
		table.insert(list, { At = door, Width = 6, Bottom = 0, Top = 8.5, Glass = false })
	end
	return list
end

--[[ Enterable multi-storey building.
spec = {
	Origin = CFrame (ground center, rotation allowed), W, D, Floors, FloorH (12),
	Color, Trim, Material, Floor (interior floor color),
	Doors = { Front = true, Back = true, Left = false, Right = false },
	Roof = "Flat" | "Gable", RoofAccess = true, Props = true,
}
Front is the local -Z face. ]]
function MapKit:Building(spec)
	local o = spec.Origin
	local W, D = spec.W, spec.D
	local floors = spec.Floors or 2
	local H = spec.FloorH or 12
	local t = 1
	local color = spec.Color or P.Brick
	local mat = spec.Material or M.Brick
	local trim = spec.Trim or P.Concrete
	local floorColor = spec.Floor or rgb(120, 112, 100)
	local doors = spec.Doors or { Front = true }
	local model = Instance.new("Model")
	model.Name = spec.Name or "Building"
	model.Parent = self.Geo

	-- stairwell strip along the left wall
	local sx0, sx1 = -W / 2 + t, -W / 2 + t + 5
	local run = math.min(H * 1.7, D - 10)
	local sz0 = -D / 2 + 4
	local sz1 = sz0 + run
	local hole = { X0 = sx0, X1 = sx1, Z0 = sz0 - 0.5, Z1 = sz1 }

	for f = 0, floors - 1 do
		local y = f * H
		-- floor
		if f == 0 then
			self:Part(Vector3.new(W, 0.4, D), o * CFrame.new(0, 0.2, 0), floorColor, M.Concrete, model)
		else
			self:Slab(o, y, W, D, 1, hole, floorColor, M.Concrete, model)
		end
		local base = y + (f == 0 and 0.4 or 0)
		local wallH = H - (f == 0 and 0.4 or 0)
		local function door(side, len)
			return (f == 0 and doors[side]) and len / 2 or nil
		end
		self:Wall(o, Vector3.new(-W / 2, base, -D / 2 + t / 2), "X", W, wallH, t, windowOpenings(W, wallH, 8, door("Front", W)), color, mat, model)
		self:Wall(o, Vector3.new(-W / 2, base, D / 2 - t / 2), "X", W, wallH, t, windowOpenings(W, wallH, 8, door("Back", W)), color, mat, model)
		self:Wall(o, Vector3.new(-W / 2 + t / 2, base, -D / 2 + t), "Z", D - 2 * t, wallH, t, windowOpenings(D - 2 * t, wallH, 8, door("Left", D - 2 * t)), color, mat, model)
		self:Wall(o, Vector3.new(W / 2 - t / 2, base, -D / 2 + t), "Z", D - 2 * t, wallH, t, windowOpenings(D - 2 * t, wallH, 8, door("Right", D - 2 * t)), color, mat, model)
		-- ledge trim between floors
		if f > 0 then
			for _, s in { { 0, -D / 2 - 0.2, W + 0.8, 0.8 }, { 0, D / 2 + 0.2, W + 0.8, 0.8 }, { -W / 2 - 0.2, 0, 0.8, D }, { W / 2 + 0.2, 0, 0.8, D } } do
				self:Part(Vector3.new(s[3], 0.7, s[4]), o * CFrame.new(s[1], y, s[2]), trim, M.Concrete, model)
			end
		end
		-- stairs up to the next floor (or the roof)
		if f < floors - 1 or spec.RoofAccess ~= false then
			local cx = (sx0 + sx1) / 2
			local low = (o * CFrame.new(cx, y + (f == 0 and 0.4 or 0), sz0)).Position
			local high = (o * CFrame.new(cx, y + H, sz1)).Position
			self:Ramp(low, high, 5, rgb(90, 90, 96), M.DiamondPlate, model)
		end
		-- interior cover
		if spec.Props ~= false then
			local rng = self.Rng
			for _ = 1, math.floor(W * D / 300) do
				local px = rng:NextNumber(-W / 2 + 9, W / 2 - 4)
				local pz = rng:NextNumber(-D / 2 + 4, D / 2 - 4)
				if rng:NextNumber() < 0.5 then
					-- desk
					self:Part(Vector3.new(6, 0.4, 3), o * CFrame.new(px, base + 3, pz), P.WoodLight, M.Wood, model)
					self:Part(Vector3.new(5.6, 2.8, 0.3), o * CFrame.new(px, base + 1.4, pz + 1.3), P.WoodDark, M.Wood, model)
				else
					self:Part(Vector3.new(3.5, 3.5, 3.5), o * CFrame.new(px, base + 1.75, pz) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), rgb(170, 128, 70), M.WoodPlanks, model)
				end
			end
		end
	end

	-- roof
	local top = floors * H
	if spec.Roof == "Gable" then
		local rh = math.min(W, D) * 0.35
		self:Part(Vector3.new(W + 1, 0.6, D + 1), o * CFrame.new(0, top + 0.3, 0), trim, M.Wood, model)
		self:Wedge(Vector3.new(W + 2, rh, D / 2 + 1), o * CFrame.new(0, top + 0.6 + rh / 2, -D / 4 - 0.25), spec.RoofColor or P.WoodDark, M.WoodPlanks, model)
		self:Wedge(Vector3.new(W + 2, rh, D / 2 + 1), o * CFrame.new(0, top + 0.6 + rh / 2, D / 4 + 0.25) * CFrame.Angles(0, math.rad(180), 0), spec.RoofColor or P.WoodDark, M.WoodPlanks, model)
	else
		self:Slab(o, top, W, D, 1, spec.RoofAccess ~= false and hole or nil, P.ConcreteDark, M.Concrete, model)
		for _, s in { { 0, -D / 2 + 0.4, W, 0.8 }, { 0, D / 2 - 0.4, W, 0.8 }, { -W / 2 + 0.4, 0, 0.8, D }, { W / 2 - 0.4, 0, 0.8, D } } do
			self:Part(Vector3.new(s[3], 3, s[4]), o * CFrame.new(s[1], top + 1.5, s[2]), trim, M.Concrete, model)
		end
		-- rooftop clutter (cover for roof fights)
		local rng = self.Rng
		for _ = 1, 2 do
			local px, pz = rng:NextNumber(-W / 2 + 10, W / 2 - 5), rng:NextNumber(-D / 2 + 5, D / 2 - 5)
			self:Part(Vector3.new(5, 3.5, 4), o * CFrame.new(px, top + 1.75, pz), rgb(180, 182, 186), M.Metal, model)
			self:Deco(Vector3.new(3, 0.3, 2.5), o * CFrame.new(px, top + 3.6, pz), P.MetalDark, M.Metal, model)
		end
		if W > 24 then
			local tank = self:Cylinder(7, 6, o * CFrame.new(W / 2 - 6, top + 6.5, D / 2 - 6) * CFrame.Angles(0, 0, math.rad(90)), P.Wood, M.WoodPlanks, model)
			tank.Name = "WaterTank"
			for _, dx in { -2, 2 } do
				for _, dz in { -2, 2 } do
					self:Part(Vector3.new(0.5, 3, 0.5), o * CFrame.new(W / 2 - 6 + dx, top + 1.5, D / 2 - 6 + dz), P.MetalDark, M.Metal, model)
				end
			end
		end
	end
	-- awning over the front door
	if doors.Front then
		self:Part(Vector3.new(10, 0.4, 4), o * CFrame.new(0, 9.5, -D / 2 - 2), spec.Awning or P.Red, M.Fabric, model)
	end
	return model
end

-- Solid skyscraper (not enterable) used for skylines / map edges.
function MapKit:Tower(origin: CFrame, W: number, D: number, height: number, color, material, glassColor)
	local model = Instance.new("Model")
	model.Name = "Tower"
	model.Parent = self.Geo
	self:Part(Vector3.new(W, height, D), origin * CFrame.new(0, height / 2, 0), color or P.ConcreteDark, material or M.Concrete, model)
	local band = glassColor or rgb(70, 110, 140)
	for y = 6, height - 4, 10 do
		local g = self:Deco(Vector3.new(W + 0.3, 5, D + 0.3), origin * CFrame.new(0, y, 0), band, M.Glass, model)
		g.Reflectance = 0.25
	end
	self:Part(Vector3.new(W - 4, 4, D - 4), origin * CFrame.new(0, height + 2, 0), P.MetalDark, M.Metal, model)
	if height > 60 then
		local antenna = self:Deco(Vector3.new(0.6, 18, 0.6), origin * CFrame.new(W / 4, height + 13, D / 4), P.Metal, M.Metal, model)
		local blink = self:Neon(Vector3.new(1, 1, 1), origin * CFrame.new(W / 4, height + 22.5, D / 4), P.Red, model)
		self:Light(blink, "PointLight", P.Red, 20, 2)
		antenna.Name = "Antenna"
	end
	return model
end

-- ROADS -----------------------------------------------------------------------------
-- Road along X ("X") or Z ("Z") centered at `center`. Lane markings skip `skip` intersections.
function MapKit:Road(axis: string, center: Vector3, length: number, width: number, skip, noSurface: boolean?)
	local along = axis == "X" and Vector3.xAxis or Vector3.zAxis
	local across = axis == "X" and Vector3.zAxis or Vector3.xAxis
	local size = axis == "X" and Vector3.new(length, 0.3, width) or Vector3.new(width, 0.3, length)
	local markY = noSurface and 0.03 or 0.32
	if not noSurface then
		self:Part(size, CFrame.new(center + Vector3.new(0, 0.15, 0)), P.Asphalt, M.Asphalt, self.Geo)
	end
	local function inIntersection(d)
		for _, s in skip or {} do
			if math.abs(d - s) < width / 2 + 3 then
				return true
			end
		end
		return false
	end
	local start = (axis == "X" and center.X or center.Z) - length / 2
	local base = center - along * (axis == "X" and center.X or center.Z)
	for d = start + 3, start + length - 3, 12 do
		if not inIntersection(d + 3) then
			local pos = base + along * (d + 3) + Vector3.new(0, markY, 0)
			local s = axis == "X" and Vector3.new(6, 0.05, 0.4) or Vector3.new(0.4, 0.05, 6)
			self:Deco(s, CFrame.new(pos), P.Yellow, M.SmoothPlastic, self.Props)
		end
	end
	-- white edge lines (split around intersections)
	local segStart = start
	local cuts = {}
	for _, s in skip or {} do
		table.insert(cuts, s)
	end
	table.sort(cuts)
	table.insert(cuts, start + length + width)
	for _, cut in cuts do
		local segEnd = math.min(cut - width / 2 - 2, start + length)
		if segEnd - segStart > 2 then
			for _, side in { -1, 1 } do
				local mid = (segStart + segEnd) / 2
				local pos = base + along * mid + across * side * (width / 2 - 1.2) + Vector3.new(0, markY, 0)
				local s = axis == "X" and Vector3.new(segEnd - segStart, 0.05, 0.35) or Vector3.new(0.35, 0.05, segEnd - segStart)
				self:Deco(s, CFrame.new(pos), P.White, M.SmoothPlastic, self.Props)
			end
		end
		segStart = cut + width / 2 + 2
	end
end

-- Zebra crossing across a road at `pos`; stripes run along `axis` of travel.
function MapKit:Crosswalk(pos: Vector3, axis: string, width: number)
	for i = -width / 2 + 2, width / 2 - 2, 2.5 do
		local p = axis == "X" and Vector3.new(0, 0, i) or Vector3.new(i, 0, 0)
		local s = axis == "X" and Vector3.new(6, 0.05, 1.2) or Vector3.new(1.2, 0.05, 6)
		self:Deco(s, CFrame.new(pos + p + Vector3.new(0, 0.03, 0)), P.White, M.SmoothPlastic, self.Props)
	end
end

-- Raised sidewalk block (curb) covering a city block.
function MapKit:Sidewalk(center: Vector3, sx: number, sz: number)
	self:Part(Vector3.new(sx, 0.8, sz), CFrame.new(center + Vector3.new(0, 0.4, 0)), P.Sidewalk, M.Concrete, self.Geo)
	self:Part(Vector3.new(sx + 0.6, 0.6, sz + 0.6), CFrame.new(center + Vector3.new(0, 0.3, 0)), P.ConcreteDark, M.Concrete, self.Geo)
end

-- PROPS -----------------------------------------------------------------------------
function MapKit:StreetLight(pos: Vector3, facing: Vector3)
	local model = Instance.new("Model")
	model.Name = "StreetLight"
	model.Parent = self.Props
	self:Pillar(pos, 16, 0.6, P.MetalDark, M.Metal, model)
	local dir = Vector3.new(facing.X, 0, facing.Z).Unit
	local armMid = pos + Vector3.new(0, 16, 0) + dir * 2.5
	self:Part(Vector3.new(0.4, 0.4, 5), CFrame.lookAt(armMid, armMid + dir), P.MetalDark, M.Metal, model)
	local lamp = self:Neon(Vector3.new(1.4, 0.4, 2.4), CFrame.lookAt(armMid + dir * 2.4 - Vector3.new(0, 0.4, 0), armMid + dir * 4), rgb(255, 236, 190), model)
	self:Light(lamp, "SpotLight", rgb(255, 230, 180), 40, 2, Enum.NormalId.Bottom)
end

function MapKit:TrafficLight(pos: Vector3, facing: Vector3)
	local model = Instance.new("Model")
	model.Name = "TrafficLight"
	model.Parent = self.Props
	self:Pillar(pos, 13, 0.5, P.MetalDark, M.Metal, model)
	local dir = Vector3.new(facing.X, 0, facing.Z).Unit
	local box = pos + Vector3.new(0, 11.5, 0) + dir * 0.6
	self:Part(Vector3.new(1.2, 3.6, 1.2), CFrame.lookAt(box, box + dir), rgb(30, 30, 30), M.Metal, model)
	for i, c in { rgb(255, 50, 50), rgb(255, 190, 0), rgb(40, 230, 90) } do
		self:Neon(Vector3.new(0.7, 0.7, 0.2), CFrame.lookAt(box + dir * 0.65 + Vector3.new(0, 1.15 - (i - 1) * 1.15, 0), box + dir * 2), i == 3 and c or c:Lerp(Color3.new(), 0.7), model)
	end
end

function MapKit:Tree(pos: Vector3, scale: number?, kind: string?)
	local s = scale or 1
	local rng = self.Rng
	local model = Instance.new("Model")
	model.Name = "Tree"
	model.Parent = self.Props
	kind = kind or "Oak"
	if kind == "Pine" then
		local h = 9 * s
		self:Pillar(pos - Vector3.new(0, 1, 0), h + 1, 1.3 * s, P.Trunk, M.Wood, model)
		local layers = { 9, 7.2, 5.4, 3.4 }
		for i, d in layers do
			local disc = self:Cylinder(2.6 * s, d * s, CFrame.new(pos + Vector3.new(0, 3.5 * s + i * 2.6 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), math.rad(90)), i % 2 == 0 and P.Pine or P.LeafDark, M.LeafyGrass, model)
			disc.CanCollide = false
			disc.CanQuery = false
		end
	elseif kind == "Palm" then
		local lean = rng:NextNumber(-0.25, 0.25)
		local top = pos
		for i = 1, 4 do
			local seg = top + Vector3.new(lean * 2, 3 * s, 0)
			self:Part(Vector3.new(1.1 * s, 3.2 * s, 1.1 * s), CFrame.lookAt((top + seg) / 2, seg) * CFrame.Angles(math.rad(90), 0, 0), P.WoodLight, M.Wood, model)
			top = seg
			lean *= 1.3
			if i == 4 then
				break
			end
		end
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			local leafDir = Vector3.new(math.cos(a), -0.35, math.sin(a))
			local leaf = self:Deco(Vector3.new(1.8 * s, 0.25, 6 * s), CFrame.lookAt(top + leafDir * 3 * s, top + leafDir * 6 * s), P.Leaf, M.LeafyGrass, model)
			leaf.Parent = model
		end
	else
		local trunkH = 6 * s
		self:Pillar(pos - Vector3.new(0, 1, 0), trunkH + 1, 1.4 * s, P.Trunk, M.Wood, model)
		for _ = 1, 3 do
			local off = Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(0, 2.5), rng:NextNumber(-2, 2)) * s
			local leaf = self:Ball(rng:NextNumber(6, 8.5) * s, pos + Vector3.new(0, trunkH + 2 * s, 0) + off, rng:NextNumber() < 0.5 and P.Leaf or P.LeafDark, M.LeafyGrass, model)
			leaf.CanCollide = false
			leaf.CanQuery = false
		end
	end
	return model
end

function MapKit:Bush(pos: Vector3, scale: number?)
	local s = scale or 1
	for i = 1, 2 do
		local b = self:Ball((3 + i) * s, pos + Vector3.new(i * 0.8 * s, s, 0), P.LeafDark, M.LeafyGrass, self.Props)
		b.CanCollide = false
	end
end

function MapKit:Rock(pos: Vector3, scale: number?)
	local s = scale or 1
	local rng = self.Rng
	for _ = 1, 2 do
		self:Part(Vector3.new(rng:NextNumber(3, 6), rng:NextNumber(2.5, 4.5), rng:NextNumber(3, 6)) * s, CFrame.new(pos + Vector3.new(rng:NextNumber(-1, 1), 0.8 * s, rng:NextNumber(-1, 1))) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), P.Rock, M.Slate, self.Geo)
	end
end

function MapKit:Bench(cf: CFrame)
	self:Part(Vector3.new(6, 0.4, 1.8), cf * CFrame.new(0, 1.8, 0), P.WoodLight, M.Wood, self.Props)
	self:Part(Vector3.new(6, 1.6, 0.3), cf * CFrame.new(0, 2.8, 0.85), P.WoodLight, M.Wood, self.Props)
	for _, x in { -2.6, 2.6 } do
		self:Part(Vector3.new(0.3, 1.8, 1.6), cf * CFrame.new(x, 0.9, 0), P.MetalDark, M.Metal, self.Props)
	end
end

function MapKit:Dumpster(cf: CFrame)
	self:Part(Vector3.new(7, 4.5, 4), cf * CFrame.new(0, 2.25, 0), rgb(40, 100, 60), M.Metal, self.Geo)
	self:Part(Vector3.new(7.2, 0.3, 4.2), cf * CFrame.new(0, 4.6, 0) * CFrame.Angles(math.rad(-8), 0, 0), rgb(30, 30, 30), M.Plastic, self.Geo)
end

-- Concrete jersey barrier (great low cover)
function MapKit:Barrier(cf: CFrame)
	self:Part(Vector3.new(8, 1, 2.4), cf * CFrame.new(0, 0.5, 0), P.Concrete, M.Concrete, self.Geo)
	self:Part(Vector3.new(8, 2.6, 1.2), cf * CFrame.new(0, 2.3, 0), P.Concrete, M.Concrete, self.Geo)
	self:Deco(Vector3.new(8.05, 0.4, 1.25), cf * CFrame.new(0, 2.8, 0), rgb(220, 70, 40), M.SmoothPlastic)
end

function MapKit:Crate(pos: Vector3, size: number?, rot: number?)
	local s = size or 4
	return self:Part(Vector3.new(s, s, s), CFrame.new(pos + Vector3.new(0, s / 2, 0)) * CFrame.Angles(0, rot or 0, 0), rgb(176, 128, 66), M.WoodPlanks, self.Geo)
end

local CONTAINER_COLORS = { rgb(180, 60, 40), rgb(40, 90, 160), rgb(220, 150, 30), rgb(50, 130, 80), rgb(130, 130, 136), rgb(150, 50, 110) }
function MapKit:Container(cf: CFrame, color: Color3?, open: boolean?)
	local c = color or CONTAINER_COLORS[self.Rng:NextInteger(1, #CONTAINER_COLORS)]
	local model = Instance.new("Model")
	model.Name = "Container"
	model.Parent = self.Geo
	local W, H, L = 8, 8.5, 20
	if open then
		self:Part(Vector3.new(W, 0.4, L), cf * CFrame.new(0, 0.2, 0), c, M.CorrodedMetal, model)
		self:Part(Vector3.new(W, 0.4, L), cf * CFrame.new(0, H - 0.2, 0), c, M.CorrodedMetal, model)
		self:Part(Vector3.new(0.3, H, L), cf * CFrame.new(-W / 2 + 0.15, H / 2, 0), c, M.CorrodedMetal, model)
		self:Part(Vector3.new(0.3, H, L), cf * CFrame.new(W / 2 - 0.15, H / 2, 0), c, M.CorrodedMetal, model)
		self:Part(Vector3.new(W, H, 0.3), cf * CFrame.new(0, H / 2, L / 2 - 0.15), c, M.CorrodedMetal, model)
	else
		self:Part(Vector3.new(W, H, L), cf * CFrame.new(0, H / 2, 0), c, M.CorrodedMetal, model)
	end
	for _, z in { -L / 2 + 0.2, L / 2 - 0.2 } do
		self:Deco(Vector3.new(W + 0.1, H + 0.1, 0.4), cf * CFrame.new(0, H / 2, z), c:Lerp(Color3.new(), 0.3), M.Metal, model)
	end
	return model
end

function MapKit:Fence(a: Vector3, b: Vector3, height: number?, color: Color3?)
	local h = height or 4
	local dir = b - a
	local len = dir.Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	for d = 0, len, 6 do
		self:Part(Vector3.new(0.4, h, 0.4), CFrame.new(a + dir.Unit * d + Vector3.new(0, h / 2, 0)), color or P.WoodDark, M.Wood, self.Geo)
	end
	for _, y in { h * 0.4, h * 0.85 } do
		self:Part(Vector3.new(0.25, 0.4, len), cf * CFrame.new(0, y, 0), color or P.Wood, M.Wood, self.Geo)
	end
end

function MapKit:Tent(cf: CFrame, color: Color3?)
	local c = color or rgb(60, 110, 70)
	self:Wedge(Vector3.new(6, 4, 3), cf * CFrame.new(0, 2, -1.5), c, M.Fabric, self.Props)
	self:Wedge(Vector3.new(6, 4, 3), cf * CFrame.new(0, 2, 1.5) * CFrame.Angles(0, math.rad(180), 0), c, M.Fabric, self.Props)
end

function MapKit:Campfire(pos: Vector3)
	for i = 1, 4 do
		local a = i / 4 * math.pi
		self:Deco(Vector3.new(0.5, 0.5, 3), CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, a, 0), P.WoodDark, M.Wood)
	end
	local core = self:Neon(Vector3.new(1, 0.6, 1), CFrame.new(pos + Vector3.new(0, 0.5, 0)), rgb(255, 120, 30))
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Parent = core
	self:Light(core, "PointLight", rgb(255, 140, 60), 22, 2.5)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		self:Part(Vector3.new(1, 0.8, 1), CFrame.new(pos + Vector3.new(math.cos(a) * 2, 0.4, math.sin(a) * 2)), P.Rock, M.Slate, self.Geo)
	end
end

-- Wooden watchtower with a climbable truss ladder.
function MapKit:Watchtower(pos: Vector3, height: number?)
	local h = height or 22
	local model = Instance.new("Model")
	model.Name = "Watchtower"
	model.Parent = self.Geo
	for _, dx in { -4, 4 } do
		for _, dz in { -4, 4 } do
			self:Part(Vector3.new(1, h, 1), CFrame.new(pos + Vector3.new(dx, h / 2, dz)), P.WoodDark, M.Wood, model)
		end
	end
	self:Part(Vector3.new(11, 0.8, 11), CFrame.new(pos + Vector3.new(0, h, 0)), P.Wood, M.WoodPlanks, model)
	for _, s in { { 0, -5.3, 11, 0.4 }, { 0, 5.3, 11, 0.4 }, { -5.3, 0, 0.4, 11 }, { 5.3, 0, 0.4, 11 } } do
		self:Part(Vector3.new(s[3], 3, s[4]), CFrame.new(pos + Vector3.new(s[1], h + 1.9, s[2])), P.Wood, M.WoodPlanks, model)
	end
	self:Wedge(Vector3.new(12, 3, 6), CFrame.new(pos + Vector3.new(0, h + 8.5, -3)), P.WoodDark, M.WoodPlanks, model)
	self:Wedge(Vector3.new(12, 3, 6), CFrame.new(pos + Vector3.new(0, h + 8.5, 3)) * CFrame.Angles(0, math.rad(180), 0), P.WoodDark, M.WoodPlanks, model)
	for _, dx in { -4, 4 } do
		for _, dz in { -4, 4 } do
			self:Part(Vector3.new(0.5, 7, 0.5), CFrame.new(pos + Vector3.new(dx, h + 3.5, dz)), P.WoodDark, M.Wood, model)
		end
	end
	local ladder = self:Part(Vector3.new(2, h, 2), CFrame.new(pos + Vector3.new(0, h / 2, -5.6)), P.MetalDark, M.Metal, model, "TrussPart")
	ladder.Name = "Ladder"
	-- the ladder pokes through the railing; leave a gap there
	return model
end

-- Gantry crane straddling a container yard.
function MapKit:Crane(cf: CFrame, span: number, height: number)
	local model = Instance.new("Model")
	model.Name = "Crane"
	model.Parent = self.Geo
	local yellow = rgb(240, 180, 30)
	for _, x in { -span / 2, span / 2 } do
		for _, z in { -8, 8 } do
			self:Part(Vector3.new(2, height, 2), cf * CFrame.new(x, height / 2, z), yellow, M.Metal, model)
		end
		self:Part(Vector3.new(2.4, 2, 18), cf * CFrame.new(x, 1, 0), P.MetalDark, M.Metal, model)
	end
	for _, z in { -8, 8 } do
		self:Part(Vector3.new(span + 2, 2.5, 2), cf * CFrame.new(0, height, z), yellow, M.Metal, model)
	end
	self:Part(Vector3.new(8, 5, 18), cf * CFrame.new(span * 0.15, height + 3.5, 0), yellow, M.Metal, model)
	self:Deco(Vector3.new(0.3, height * 0.45, 0.3), cf * CFrame.new(span * 0.15, height * 0.75, 0), P.MetalDark, M.Metal, model)
	self:Part(Vector3.new(8, 1, 20), cf * CFrame.new(span * 0.15, height * 0.52, 0), P.MetalDark, M.Metal, model)
	return model
end

-- Cargo ship you can board via a gangway.
function MapKit:Ship(cf: CFrame, length: number, gangwayAt: number?)
	local model = Instance.new("Model")
	model.Name = "Ship"
	model.Parent = self.Geo
	local W = 30
	local hullH = 16
	local hull = rgb(150, 36, 36)
	local deckY = 12
	self:Part(Vector3.new(W, hullH, length), cf * CFrame.new(0, deckY - hullH / 2, 0), hull, M.Metal, model)
	self:Part(Vector3.new(W + 0.2, 1.2, length + 0.2), cf * CFrame.new(0, deckY - hullH + 3, 0), rgb(30, 30, 34), M.Metal, model)
	self:Wedge(Vector3.new(W, hullH, 20), cf * CFrame.new(0, deckY - hullH / 2, -length / 2 - 10), hull, M.Metal, model)
	self:Part(Vector3.new(W - 1, 0.6, length + 6), cf * CFrame.new(0, deckY + 0.3, -3), rgb(80, 90, 80), M.DiamondPlate, model)
	-- railings (with a gap for the gangway on the +X side)
	for _, x in { -W / 2 + 0.3, W / 2 - 0.3 } do
		local segments = { { -length / 2, length / 2 } }
		if gangwayAt and x > 0 then
			segments = { { -length / 2, gangwayAt - 4 }, { gangwayAt + 4, length / 2 } }
		end
		for _, seg in segments do
			self:Part(Vector3.new(0.4, 3, seg[2] - seg[1]), cf * CFrame.new(x, deckY + 2, (seg[1] + seg[2]) / 2), P.White, M.Metal, model)
		end
	end
	-- bridge tower at the stern
	local tower = cf * CFrame.new(0, deckY, length / 2 - 10)
	self:Building({ Origin = tower, W = 22, D = 14, Floors = 2, FloorH = 10, Color = P.White, Material = M.Metal, Trim = rgb(40, 40, 46), Doors = { Front = true }, Props = false, Awning = rgb(40, 40, 46) })
	-- containers on deck
	for i = 0, math.floor((length - 40) / 22) - 1 do
		for _, x in { -5, 5 } do
			self:Container(cf * CFrame.new(x, deckY + 0.6, -length / 2 + 14 + i * 22), nil, i % 2 == 1 and x > 0)
		end
	end
	return model
end

-- Wooden dock/pier on posts, deck top at `deckY`.
function MapKit:Pier(a: Vector3, b: Vector3, width: number, deckY: number)
	local dir = b - a
	local cf = CFrame.lookAt((a + b) / 2, b)
	local len = dir.Magnitude
	self:Part(Vector3.new(width, 0.8, len), CFrame.new(cf.Position.X, deckY - 0.4, cf.Position.Z) * cf.Rotation, P.WoodLight, M.WoodPlanks, self.Geo)
	for d = 0, len, 10 do
		for _, side in { -1, 1 } do
			local p = a + dir.Unit * d + cf.RightVector * side * (width / 2 - 0.5)
			self:Pillar(Vector3.new(p.X, deckY - 14, p.Z), 14, 1.2, P.WoodDark, M.Wood)
		end
	end
end

return MapKit
