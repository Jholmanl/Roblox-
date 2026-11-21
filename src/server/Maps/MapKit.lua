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
function MapKit:Spawn(pos: Vector3, lookAt: Vector3?, team: string?)
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
	if team then
		s:SetAttribute("Team", team)
	end
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
	-- walls overlap at the corners so there's no seam to squeeze through
	for _, s in { { halfX, 0, 2, halfZ * 2 + 6 }, { -halfX, 0, 2, halfZ * 2 + 6 }, { 0, halfZ, halfX * 2 + 6, 2 }, { 0, -halfZ, halfX * 2 + 6, 2 } } do
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
function MapKit:Wall(origin: CFrame, start: Vector3, axis: string, length: number, height: number, thick: number, openings, color, material, parent, trim)
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
			-- some windows glow warm from inside (lit rooms at dusk / night)
			if trim and y0 > 1 and self.Rng:NextNumber() < (self.LitWindows or 0.3) then
				local inward = -trim.Outward * (thick / 2 + 0.05)
				local glowPos = axis == "X" and pos + Vector3.new(0, 0, inward) or pos + Vector3.new(inward, 0, 0)
				local glowSize = axis == "X" and Vector3.new(len - 0.4, h - 0.4, 0.1) or Vector3.new(0.1, h - 0.4, len - 0.4)
				local warm = ({ rgb(255, 214, 150), rgb(255, 236, 200), rgb(255, 196, 120), rgb(220, 235, 255) })[self.Rng:NextInteger(1, 4)]
				local glow = self:Neon(glowSize, origin * CFrame.new(glowPos), warm, parent)
				glow.Transparency = 0.45
				glow.Name = "LitWindow"
			end
			-- window mullions: a cross of thin frame bars over the pane
			if trim and len > 2.5 and h > 2.5 then
				local mc = trim.Color:Lerp(Color3.new(), 0.35)
				local d = 0.42
				if axis == "X" then
					self:Deco(Vector3.new(0.14, h, d), origin * CFrame.new(pos), mc, M.Metal, parent).CastShadow = false
					self:Deco(Vector3.new(len, 0.14, d), origin * CFrame.new(pos + Vector3.new(0, h * 0.12, 0)), mc, M.Metal, parent).CastShadow = false
				else
					self:Deco(Vector3.new(d, h, 0.14), origin * CFrame.new(pos), mc, M.Metal, parent).CastShadow = false
					self:Deco(Vector3.new(d, 0.14, len), origin * CFrame.new(pos + Vector3.new(0, h * 0.12, 0)), mc, M.Metal, parent).CastShadow = false
				end
			end
		else
			self:Part(size, origin * CFrame.new(pos), color, material, parent)
		end
	end
	-- window sill + head trim sticking out of the wall face
	local function frame(a0, a1, y, depth, h)
		if not trim then
			return
		end
		local mid = (a0 + a1) / 2
		local out = trim.Outward * (thick / 2 + depth / 2)
		local pos, size
		if axis == "X" then
			pos = start + Vector3.new(mid, y, out)
			size = Vector3.new(a1 - a0 + 0.6, h, depth)
		else
			pos = start + Vector3.new(out, y, mid)
			size = Vector3.new(depth, h, a1 - a0 + 0.6)
		end
		local p = self:Part(size, origin * CFrame.new(pos), trim.Color, M.Concrete, parent)
		p.CanQuery = false
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
		if o.Frame then
			frame(l, r, o.Bottom - 0.15, 0.7, 0.3) -- sill
			frame(l, r, o.Top + 0.2, 0.35, 0.4) -- head
			if trim and o.Bottom > 2 and self.Rng:NextNumber() < (self.FlowerBoxes or 0.14) then
				local mid = (l + r) / 2
				local out = trim.Outward * (thick / 2 + 0.55)
				local y = o.Bottom - 0.75
				local bpos = axis == "X" and start + Vector3.new(mid, y, out) or start + Vector3.new(out, y, mid)
				local bsize = axis == "X" and Vector3.new(o.Width - 0.4, 0.8, 0.9) or Vector3.new(0.9, 0.8, o.Width - 0.4)
				self:Deco(bsize, origin * CFrame.new(bpos), rgb(110, 70, 50), M.Wood, parent)
				for k = -1, 1 do
					local fp = axis == "X" and bpos + Vector3.new(k * (o.Width / 3.4), 0.6, 0) or bpos + Vector3.new(0, 0.6, k * (o.Width / 3.4))
					local leaf = self:Ball(0.9, (origin * CFrame.new(fp)).Position, P.Leaf, M.LeafyGrass, parent)
					leaf.CanCollide, leaf.CanQuery, leaf.CastShadow = false, false, false
					local flower = self:Ball(0.45, (origin * CFrame.new(fp + Vector3.new(0, 0.4, 0))).Position, ({ rgb(240, 70, 90), rgb(255, 200, 60), rgb(250, 250, 250), rgb(190, 90, 230) })[self.Rng:NextInteger(1, 4)], M.SmoothPlastic, parent)
					flower.CanCollide, flower.CanQuery, flower.CastShadow = false, false, false
				end
			end
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
	rect(-hw, hw, -hd, hole.Z0)
	rect(-hw, hw, hole.Z1, hd)
	rect(-hw, hole.X0, hole.Z0, hole.Z1)
	rect(hole.X1, hw, hole.Z0, hole.Z1)
end

-- Windows along a wall. `openChance` = share of windows left open (no glass)
-- so players can climb in and out.
local function windowOpenings(length: number, floorH: number, spacing: number, door, rng, openChance: number, sill: number?)
	local list = {}
	local count = math.max(0, math.floor((length - 4) / spacing))
	local startAt = (length - (count - 1) * spacing) / 2
	local bottom = sill or 3
	for i = 0, count - 1 do
		local at = startAt + i * spacing
		if not door or math.abs(at - door) > 6 then
			local open = rng:NextNumber() < (openChance or 0)
			table.insert(list, { At = at, Width = 4, Bottom = bottom, Top = floorH - 2.5, Glass = not open, Frame = true })
		end
	end
	if door then
		table.insert(list, { At = door, Width = 6, Bottom = 0, Top = 8.5, Glass = false })
	end
	return list
end

local SIDES = {
	Front = { N = Vector3.new(0, 0, -1), T = Vector3.new(1, 0, 0), Rot = CFrame.identity },
	Back = { N = Vector3.new(0, 0, 1), T = Vector3.new(1, 0, 0), Rot = CFrame.identity },
	Left = { N = Vector3.new(-1, 0, 0), T = Vector3.new(0, 0, 1), Rot = CFrame.Angles(0, math.rad(90), 0) },
	Right = { N = Vector3.new(1, 0, 0), T = Vector3.new(0, 0, 1), Rot = CFrame.Angles(0, math.rad(90), 0) },
}

--[[ Enterable multi-storey building.
spec = {
	Origin = CFrame (ground center), W, D, Floors, FloorH (12),
	Color, Trim, Material, Floor, Name, Awning,
	Doors = { Front = true, Back = true, Left = false, Right = false },
	Roof = "Flat" | "Gable", RoofAccess = true, Props = true,
	OpenWindows = 0..1   share of windows left open (climb in/out)
	OpenSides = { Right = true }   every window on these sides is open
	Storefront = Color3  big shop windows + sign band on the ground floor front
	FireEscape = "Right" | "Left" | "Back"   balconies + ladder to the roof
	Ladder = "Right" | ...   plain roof ladder
	Balconies = true   small balconies on the front
	AC = true   wall air-conditioner units
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
	local rng = self.Rng
	local model = Instance.new("Model")
	model.Name = spec.Name or "Building"
	model.Parent = self.Geo
	local openSides = spec.OpenSides or {}
	if spec.FireEscape then
		openSides[spec.FireEscape] = true
	end

	-- stairwell strip along the left wall
	local sx0, sx1 = -W / 2 + t, -W / 2 + t + 5
	local run = math.min(H * 1.7, D - 10)
	local sz0 = -D / 2 + 4
	local sz1 = sz0 + run
	local hole = { X0 = sx0, X1 = sx1, Z0 = sz0 - 0.5, Z1 = sz1 }

	local function sidePos(side, along, out, y)
		local s = SIDES[side]
		local half = (side == "Front" or side == "Back") and D / 2 or W / 2
		return o * CFrame.new(s.N * (half + out) + s.T * along + Vector3.new(0, y, 0)) * s.Rot
	end

	for f = 0, floors - 1 do
		local y = f * H
		if f == 0 then
			self:Part(Vector3.new(W, 0.4, D), o * CFrame.new(0, 0.2, 0), floorColor, M.Concrete, model)
		else
			self:Slab(o, y, W, D, 1, hole, floorColor, M.Concrete, model)
		end
		local base = y + (f == 0 and 0.4 or 0)
		local wallH = H - (f == 0 and 0.4 or 0)
		local function openings(side, len)
			local door = (f == 0 and doors[side]) and len / 2 or nil
			if f == 0 and side == "Front" and spec.Storefront then
				-- shop windows either side of the door
				local paneW = len / 2 - 5
				return {
					{ At = paneW / 2 + 1, Width = paneW, Bottom = 1.2, Top = 8.5, Glass = true },
					{ At = len - paneW / 2 - 1, Width = paneW, Bottom = 1.2, Top = 8.5, Glass = true },
					{ At = len / 2, Width = 6, Bottom = 0, Top = 8.5, Glass = false },
				}
			end
			local chance = openSides[side] and 1 or (spec.OpenWindows or 0)
			return windowOpenings(len, wallH, 8, door, rng, chance, f == 0 and 2.6 or 3)
		end
		self:Wall(o, Vector3.new(-W / 2, base, -D / 2 + t / 2), "X", W, wallH, t, openings("Front", W), color, mat, model, { Outward = -1, Color = trim })
		self:Wall(o, Vector3.new(-W / 2, base, D / 2 - t / 2), "X", W, wallH, t, openings("Back", W), color, mat, model, { Outward = 1, Color = trim })
		self:Wall(o, Vector3.new(-W / 2 + t / 2, base, -D / 2 + t), "Z", D - 2 * t, wallH, t, openings("Left", D - 2 * t), color, mat, model, { Outward = -1, Color = trim })
		self:Wall(o, Vector3.new(W / 2 - t / 2, base, -D / 2 + t), "Z", D - 2 * t, wallH, t, openings("Right", D - 2 * t), color, mat, model, { Outward = 1, Color = trim })
		if f > 0 then
			for _, s in { { 0, -D / 2 - 0.2, W + 0.8, 0.8 }, { 0, D / 2 + 0.2, W + 0.8, 0.8 }, { -W / 2 - 0.2, 0, 0.8, D }, { W / 2 + 0.2, 0, 0.8, D } } do
				self:Part(Vector3.new(s[3], 0.7, s[4]), o * CFrame.new(s[1], y, s[2]), trim, M.Concrete, model)
			end
		end
		if f < floors - 1 or spec.RoofAccess ~= false then
			local cx = (sx0 + sx1) / 2
			local low = (o * CFrame.new(cx, y + (f == 0 and 0.4 or 0), sz0)).Position
			local high = (o * CFrame.new(cx, y + H, sz1)).Position
			self:Ramp(low, high, 5, rgb(90, 90, 96), M.DiamondPlate, model)
			self:Part(Vector3.new(0.3, 3, run), o * CFrame.new(sx1 + 0.2, y + H + 1.5, (sz0 + sz1) / 2), P.MetalDark, M.Metal, model)
		end
		-- ceiling light fixture so interiors aren't pitch black
		if spec.InteriorLights ~= false then
			local fx = o * CFrame.new(W * 0.12, y + H - 0.35, 0)
			local fixture = self:Neon(Vector3.new(4, 0.2, 1.2), fx, rgb(255, 240, 215), model)
			self:Deco(Vector3.new(4.4, 0.25, 1.6), fx * CFrame.new(0, 0.2, 0), P.MetalDark, M.Metal, model)
			self:Light(fixture, "PointLight", rgb(255, 228, 190), math.max(W, D) * 0.75, 0.9)
		end
		if spec.Props ~= false then
			for _ = 1, math.floor(W * D / 300) do
				local px = rng:NextNumber(-W / 2 + 9, W / 2 - 4)
				local pz = rng:NextNumber(-D / 2 + 4, D / 2 - 4)
				local roll = rng:NextNumber()
				if roll < 0.35 then
					self:Part(Vector3.new(6, 0.4, 3), o * CFrame.new(px, base + 3, pz), P.WoodLight, M.Wood, model)
					self:Part(Vector3.new(5.6, 2.8, 0.3), o * CFrame.new(px, base + 1.4, pz + 1.3), P.WoodDark, M.Wood, model)
				elseif roll < 0.6 then
					-- couch
					self:Part(Vector3.new(6, 1.6, 2.6), o * CFrame.new(px, base + 0.8, pz), rgb(90, 70, 60), M.Fabric, model)
					self:Part(Vector3.new(6, 2.4, 0.8), o * CFrame.new(px, base + 1.6, pz + 1.3), rgb(90, 70, 60), M.Fabric, model)
				elseif roll < 0.8 then
					-- shelf
					self:Part(Vector3.new(5, 6, 1.4), o * CFrame.new(px, base + 3, pz), P.WoodDark, M.Wood, model)
				else
					self:Part(Vector3.new(3.5, 3.5, 3.5), o * CFrame.new(px, base + 1.75, pz) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), rgb(170, 128, 70), M.WoodPlanks, model)
				end
			end
		end
	end

	local top = floors * H
	-- plinth + corner pilasters
	for _, s in { { 0, -D / 2 - 0.15, W + 0.5, 0.5 }, { 0, D / 2 + 0.15, W + 0.5, 0.5 }, { -W / 2 - 0.15, 0, 0.5, D + 0.5 }, { W / 2 + 0.15, 0, 0.5, D + 0.5 } } do
		self:Part(Vector3.new(s[3], 1.4, s[4]), o * CFrame.new(s[1], 0.7, s[2]), trim:Lerp(Color3.new(), 0.25), M.Concrete, model)
	end
	if spec.Pilasters ~= false then
		for _, cx in { -W / 2, W / 2 } do
			for _, cz in { -D / 2, D / 2 } do
				self:Part(Vector3.new(1.4, top, 1.4), o * CFrame.new(cx, top / 2, cz), trim, M.Concrete, model)
			end
		end
	end

	if spec.Roof == "Gable" then
		local rh = math.min(W, D) * 0.35
		self:Part(Vector3.new(W + 1, 0.6, D + 1), o * CFrame.new(0, top + 0.3, 0), trim, M.Wood, model)
		self:Wedge(Vector3.new(W + 2, rh, D / 2 + 1), o * CFrame.new(0, top + 0.6 + rh / 2, -D / 4 - 0.25), spec.RoofColor or P.WoodDark, M.WoodPlanks, model)
		self:Wedge(Vector3.new(W + 2, rh, D / 2 + 1), o * CFrame.new(0, top + 0.6 + rh / 2, D / 4 + 0.25) * CFrame.Angles(0, math.rad(180), 0), spec.RoofColor or P.WoodDark, M.WoodPlanks, model)
		self:Part(Vector3.new(2, rh * 0.8, 2), o * CFrame.new(W / 4, top + rh * 0.6, D / 4), P.Brick, M.Brick, model) -- chimney
	else
		local roofHole = spec.RoofAccess ~= false and hole or nil
		self:Slab(o, top, W, D, 1, roofHole, P.ConcreteDark, M.Concrete, model)
		-- parapet + cornice
		for _, s in { { 0, -D / 2 + 0.4, W, 0.8 }, { 0, D / 2 - 0.4, W, 0.8 }, { -W / 2 + 0.4, 0, 0.8, D }, { W / 2 - 0.4, 0, 0.8, D } } do
			self:Part(Vector3.new(s[3], 3, s[4]), o * CFrame.new(s[1], top + 1.5, s[2]), trim, M.Concrete, model)
		end
		for _, s in { { 0, -D / 2 - 0.3, W + 2, 1.4 }, { 0, D / 2 + 0.3, W + 2, 1.4 }, { -W / 2 - 0.3, 0, 1.4, D + 2 }, { W / 2 + 0.3, 0, 1.4, D + 2 } } do
			self:Part(Vector3.new(s[3], 1.1, s[4]), o * CFrame.new(s[1], top - 0.2, s[2]), trim, M.Concrete, model)
		end
		-- stair bulkhead (door faces +Z where the ramp arrives)
		if roofHole then
			local bh = 8
			local bx0, bx1 = -W / 2 + 0.8, sx1 + 1
			local bz0, bz1 = hole.Z0 - 1, hole.Z1
			self:Part(Vector3.new(bx1 - bx0, bh, 0.8), o * CFrame.new((bx0 + bx1) / 2, top + bh / 2, bz0), trim, M.Concrete, model)
			self:Part(Vector3.new(0.8, bh, bz1 - bz0), o * CFrame.new(bx1, top + bh / 2, (bz0 + bz1) / 2), trim, M.Concrete, model)
			self:Part(Vector3.new(0.8, bh - 3, bz1 - bz0), o * CFrame.new(bx0, top + 3 + (bh - 3) / 2, (bz0 + bz1) / 2), trim, M.Concrete, model)
			self:Part(Vector3.new(bx1 - bx0 + 1, 0.6, bz1 - bz0 + 1), o * CFrame.new((bx0 + bx1) / 2, top + bh + 0.3, (bz0 + bz1) / 2), P.MetalDark, M.Metal, model)
			local lamp = self:Neon(Vector3.new(0.6, 0.3, 0.6), o * CFrame.new((bx0 + bx1) / 2, top + bh - 0.6, bz1 + 0.2), rgb(255, 230, 180), model)
			self:Light(lamp, "PointLight", rgb(255, 220, 170), 14, 1.2)
		end
		-- rooftop clutter (cover for roof fights)
		for _ = 1, 3 do
			local px, pz = rng:NextNumber(-W / 2 + 10, W / 2 - 5), rng:NextNumber(-D / 2 + 5, D / 2 - 5)
			self:Part(Vector3.new(5, 3.5, 4), o * CFrame.new(px, top + 1.75, pz), rgb(180, 182, 186), M.Metal, model)
			self:Deco(Vector3.new(3.2, 0.3, 3), o * CFrame.new(px, top + 3.6, pz), P.MetalDark, M.Metal, model)
			for i = -1, 1 do
				self:Deco(Vector3.new(0.1, 2.6, 3.2), o * CFrame.new(px + i * 1.5 + 0.8, top + 1.9, pz), P.MetalDark, M.Metal, model)
			end
		end
		self:Pillar((o * CFrame.new(W / 2 - 3, top, -D / 2 + 3)).Position, 9, 0.3, P.MetalDark, M.Metal, model) -- antenna
		if W > 24 then
			local tank = self:Cylinder(7, 6, o * CFrame.new(W / 2 - 6, top + 6.5, D / 2 - 6) * CFrame.Angles(0, 0, math.rad(90)), P.Wood, M.WoodPlanks, model)
			tank.Name = "WaterTank"
			self:Wedge(Vector3.new(6, 1.5, 3), o * CFrame.new(W / 2 - 6, top + 10.75, D / 2 - 7.5), P.WoodDark, M.WoodPlanks, model)
			self:Wedge(Vector3.new(6, 1.5, 3), o * CFrame.new(W / 2 - 6, top + 10.75, D / 2 - 4.5) * CFrame.Angles(0, math.rad(180), 0), P.WoodDark, M.WoodPlanks, model)
			for _, dx in { -2, 2 } do
				for _, dz in { -2, 2 } do
					self:Part(Vector3.new(0.5, 3, 0.5), o * CFrame.new(W / 2 - 6 + dx, top + 1.5, D / 2 - 6 + dz), P.MetalDark, M.Metal, model)
				end
			end
		end
	end

	-- storefront sign band
	if spec.Storefront then
		local sign = self:Part(Vector3.new(W * 0.85, 1.8, 0.5), o * CFrame.new(0, 10.3, -D / 2 - 0.4), spec.Storefront, M.SmoothPlastic, model)
		sign.Name = "ShopSign"
		self:Light(sign, "SurfaceLight", spec.Storefront:Lerp(Color3.new(1, 1, 1), 0.5), 14, 1.2, Enum.NormalId.Front)
		local shopGlow = self:Neon(Vector3.new(W * 0.7, 0.2, 2), o * CFrame.new(0, 8.6, -D / 2 + 3), rgb(255, 245, 225), model)
		self:Light(shopGlow, "PointLight", rgb(255, 235, 200), 22, 1.4)
		self:Neon(Vector3.new(W * 0.85, 0.2, 0.55), o * CFrame.new(0, 9.35, -D / 2 - 0.4), rgb(255, 240, 210), model)
		for i = -2, 2 do
			self:Neon(Vector3.new(1.2, 0.9, 0.1), o * CFrame.new(i * 2.2, 10.3, -D / 2 - 0.7), rgb(255, 255, 255), model)
		end
	end
	if doors.Front then
		self:Part(Vector3.new(10, 0.4, 4), o * CFrame.new(0, 9.5, -D / 2 - 2), spec.Awning or P.Red, M.Fabric, model)
		for _, x in { -4.8, 4.8 } do
			self:Part(Vector3.new(0.2, 1.2, 4), o * CFrame.new(x, 8.9, -D / 2 - 2), spec.Awning or P.Red, M.Fabric, model)
		end
	end

	-- fire escape: balcony on every floor + ladder all the way to the roof
	if spec.FireEscape then
		local side = spec.FireEscape
		local along = (side == "Front" or side == "Back") and W * 0.15 or D * 0.15
		for f = 1, floors - 1 do
			local y = f * H
			self:Part(Vector3.new(11, 0.3, 3.6), sidePos(side, along, 1.8, y + 0.15), P.MetalDark, M.DiamondPlate, model)
			self:Part(Vector3.new(11, 3, 0.2), sidePos(side, along, 3.5, y + 1.65), P.MetalDark, M.Metal, model).Transparency = 0.3
			self:Part(Vector3.new(0.2, 3, 3.6), sidePos(side, along - 5.4, 1.8, y + 1.65), P.MetalDark, M.Metal, model)
		end
		local lad = self:Ladder(sidePos(side, along + 6.5, 1.0, 0).Position, top + 3.5, nil)
		lad.Parent = model
	elseif spec.Ladder then
		local lad = self:Ladder(sidePos(spec.Ladder, 0, 1.0, 0).Position, top + 3.5, nil)
		lad.Parent = model
	end
	-- balconies on the front
	if spec.Balconies then
		for f = 1, floors - 1 do
			for i = -1, 1, 2 do
				local x = i * W * 0.25
				self:Part(Vector3.new(6, 0.4, 3), o * CFrame.new(x, f * H + 0.2, -D / 2 - 1.5), trim, M.Concrete, model)
				self:Part(Vector3.new(6, 2.6, 0.25), o * CFrame.new(x, f * H + 1.7, -D / 2 - 2.9), P.MetalDark, M.Metal, model)
			end
		end
	end
	-- drainpipes down two corners (with brackets)
	for _, c in { { W / 2 + 0.55, D / 2 - 1.2 }, { -W / 2 - 0.55, D / 2 - 1.2 } } do
		local pipe = self:Cylinder(top + 0.5, 0.45, o * CFrame.new(c[1], top / 2, c[2]) * CFrame.Angles(0, 0, math.rad(90)), P.MetalDark, M.Metal, model)
		pipe.CanCollide, pipe.CanQuery = false, false
		for y = H * 0.5, top, H do
			self:Deco(Vector3.new(0.7, 0.18, 0.6), o * CFrame.new(c[1] - math.sign(c[1]) * 0.25, y, c[2]), P.MetalDark, M.Metal, model)
		end
		self:Deco(Vector3.new(0.6, 0.3, 1.0), o * CFrame.new(c[1], 0.4, c[2] - 0.4), P.MetalDark, M.Metal, model)
	end
	-- door frames around every ground-floor doorway
	for side, on in doors do
		if on and SIDES[side] and not (side == "Front" and spec.Storefront) then
			for _, a in { -3.25, 3.25 } do
				self:Deco(Vector3.new(0.5, 8.9, 0.5), sidePos(side, a, 0.3, 4.65), trim:Lerp(Color3.new(), 0.2), M.Concrete, model)
			end
			self:Deco(Vector3.new(7, 0.6, 0.6), sidePos(side, 0, 0.3, 9.1), trim:Lerp(Color3.new(), 0.2), M.Concrete, model)
			local lamp = self:Neon(Vector3.new(0.5, 0.35, 0.3), sidePos(side, 0, 0.75, 9.8), rgb(255, 225, 170), model)
			self:Light(lamp, "PointLight", rgb(255, 210, 150), 12, 0.9)
		end
	end
	-- rooftop gear + the odd lit billboard (flat roofs only)
	if spec.Roof ~= "Gable" then
		local dishPos = (o * CFrame.new(-W / 4, top, D / 4)).Position
		self:Pillar(dishPos, 2.2, 0.3, P.MetalDark, M.Metal, model)
		local dish = self:Cylinder(0.3, 2.6, CFrame.new(dishPos + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(60)), rgb(220, 222, 226), M.SmoothPlastic, model)
		dish.CanQuery = false
		for i = 1, 2 do
			local v = (o * CFrame.new(W / 4 - i * 3, top, -D / 4)).Position
			self:Pillar(v, 1.6, 1.1, rgb(170, 172, 176), M.Metal, model)
			self:Cylinder(0.3, 1.5, CFrame.new(v + Vector3.new(0, 1.75, 0)) * CFrame.Angles(0, 0, math.rad(90)), P.MetalDark, M.Metal, model)
		end
		if W >= 20 and rng:NextNumber() < (self.Billboards or 0.25) then
			local bc = o * CFrame.new(0, top + 9, D / 2 - 2)
			for _, x in { -5, 5 } do
				self:Part(Vector3.new(0.5, 9, 0.5), o * CFrame.new(x, top + 4.5, D / 2 - 2), P.MetalDark, M.Metal, model)
			end
			self:Part(Vector3.new(14, 6, 0.5), bc, P.MetalDark, M.Metal, model)
			local adColor = ({ rgb(255, 80, 60), rgb(0, 190, 255), rgb(255, 200, 30), rgb(120, 230, 90), rgb(230, 90, 220) })[rng:NextInteger(1, 5)]
			local panel = self:Deco(Vector3.new(13, 5, 0.1), bc * CFrame.new(0, 0, -0.3), adColor, M.SmoothPlastic, model)
			self:Light(panel, "SurfaceLight", adColor:Lerp(Color3.new(1, 1, 1), 0.4), 18, 1.4, Enum.NormalId.Front)
			self:Neon(Vector3.new(9, 0.8, 0.12), bc * CFrame.new(-1, 0.9, -0.36), Color3.new(1, 1, 1))
			self:Neon(Vector3.new(6, 0.5, 0.12), bc * CFrame.new(-2.4, -0.6, -0.36), adColor:Lerp(Color3.new(1, 1, 1), 0.6))
			self:Neon(Vector3.new(14.2, 0.2, 0.2), bc * CFrame.new(0, -3.1, -0.4), rgb(255, 245, 220))
		end
	end
	-- wall AC units
	if spec.AC ~= false then
		for _ = 1, floors do
			local side = ({ "Back", "Left", "Right" })[rng:NextInteger(1, 3)]
			local len = (side == "Back") and W or D
			local y = rng:NextInteger(1, floors) * H - H * 0.35
			self:Part(Vector3.new(2.6, 1.8, 1.4), sidePos(side, rng:NextNumber(-len / 2 + 4, len / 2 - 4), 0.7, y), rgb(200, 202, 205), M.Metal, model)
		end
	end
	return model
end

-- Skyscraper used for skylines / map edges: podium, banded glass shaft, crown.
function MapKit:Tower(origin: CFrame, W: number, D: number, height: number, color, material, glassColor)
	local model = Instance.new("Model")
	model.Name = "Tower"
	model.Parent = self.Geo
	local c = color or P.ConcreteDark
	-- podium with a glass shop band
	self:Part(Vector3.new(W + 2, 10, D + 2), origin * CFrame.new(0, 5, 0), c:Lerp(Color3.new(), 0.15), material or M.Concrete, model)
	local shop = self:Deco(Vector3.new(W + 2.2, 5, D + 2.2), origin * CFrame.new(0, 4, 0), rgb(40, 60, 80), M.Glass, model)
	shop.Reflectance = 0.3
	self:Part(Vector3.new(W, height - 10, D), origin * CFrame.new(0, 10 + (height - 10) / 2, 0), c, material or M.Concrete, model)
	local band = glassColor or rgb(70, 110, 140)
	for y = 14, height - 4, 9 do
		local g = self:Deco(Vector3.new(W + 0.3, 5, D + 0.3), origin * CFrame.new(0, y, 0), band, M.Glass, model)
		g.Reflectance = 0.25
		-- random lit offices on each face
		for _, face in { { 0, 1, W }, { 0, -1, W }, { 1, 0, D }, { -1, 0, D } } do
			local cols = math.max(1, math.floor(face[3] / 5))
			for k = 0, cols - 1 do
				if self.Rng:NextNumber() < (self.LitWindows or 0.3) * 0.9 then
					local along = -face[3] / 2 + (k + 0.5) * face[3] / cols
					local out = (face[1] ~= 0 and W or D) / 2 + 0.2
					local cf = face[1] ~= 0 and CFrame.new(face[1] * out, y, along) or CFrame.new(along, y, face[2] * out)
					local size = face[1] ~= 0 and Vector3.new(0.1, 4.2, face[3] / cols - 0.8) or Vector3.new(face[3] / cols - 0.8, 4.2, 0.1)
					local lit = self:Neon(size, origin * cf, rgb(255, 222, 160), model)
					lit.Transparency = 0.35
				end
			end
		end
	end
	-- vertical mullions
	for i = -2, 2 do
		for _, s in { 1, -1 } do
			self:Deco(Vector3.new(0.6, height - 10, 0.5), origin * CFrame.new(i * W / 5, 10 + (height - 10) / 2, s * (D / 2 + 0.2)), c, material or M.Concrete, model)
			self:Deco(Vector3.new(0.5, height - 10, 0.6), origin * CFrame.new(s * (W / 2 + 0.2), 10 + (height - 10) / 2, i * D / 5), c, material or M.Concrete, model)
		end
	end
	-- crown
	self:Part(Vector3.new(W + 1, 1.5, D + 1), origin * CFrame.new(0, height + 0.75, 0), c:Lerp(Color3.new(1, 1, 1), 0.2), M.Concrete, model)
	self:Part(Vector3.new(W - 4, 5, D - 4), origin * CFrame.new(0, height + 4, 0), P.MetalDark, M.Metal, model)
	if height > 60 then
		self:Deco(Vector3.new(0.6, 18, 0.6), origin * CFrame.new(W / 4, height + 15, D / 4), P.Metal, M.Metal, model)
		local blink = self:Neon(Vector3.new(1, 1, 1), origin * CFrame.new(W / 4, height + 24.5, D / 4), P.Red, model)
		self:Light(blink, "PointLight", P.Red, 20, 2)
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
	-- surface wear: puddles, cracks, oil stains and curb drains
	if not self.NoRoadDetail then
		for d = start + 8, start + length - 8, 14 do
			if not inIntersection(d) then
				local lateral = self.Rng:NextNumber(-width / 2 + 2, width / 2 - 2)
				local pos = base + along * (d + self.Rng:NextNumber(-3, 3)) + across * lateral
				local roll = self.Rng:NextNumber()
				if roll < 0.28 then
					local puddle = self:Deco(Vector3.new(0.04, self.Rng:NextNumber(3, 6), self.Rng:NextNumber(2.5, 5)), CFrame.new(pos + Vector3.new(0, markY - 0.01, 0)) * CFrame.Angles(0, self.Rng:NextNumber(0, 3), math.rad(90)), rgb(40, 46, 56), M.Glass, self.Props)
					puddle.Shape = Enum.PartType.Cylinder
					puddle.Reflectance = 0.45
					puddle.Transparency = 0.15
					puddle.CastShadow = false
					puddle.Name = "Puddle"
				elseif roll < 0.62 then
					for k = 0, 2 do
						local c = self:Deco(Vector3.new(self.Rng:NextNumber(1.5, 3.2), 0.03, 0.12), CFrame.new(pos + Vector3.new(k * 1.1, markY - 0.015, k * 0.7)) * CFrame.Angles(0, self.Rng:NextNumber(0, 3), 0), rgb(26, 27, 30), M.SmoothPlastic, self.Props)
						c.CastShadow = false
					end
				elseif roll < 0.82 then
					local stain = self:Deco(Vector3.new(0.03, self.Rng:NextNumber(2, 3.5), self.Rng:NextNumber(2, 3.5)), CFrame.new(pos + Vector3.new(0, markY - 0.015, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(30, 31, 34), M.SmoothPlastic, self.Props)
					stain.Shape = Enum.PartType.Cylinder
					stain.Transparency = 0.25
					stain.CastShadow = false
				else
					local drain = base + along * d + across * (width / 2 - 0.9) * (self.Rng:NextNumber() < 0.5 and 1 or -1)
					local g = self:Deco(axis == "X" and Vector3.new(2.4, 0.05, 1.2) or Vector3.new(1.2, 0.05, 2.4), CFrame.new(drain + Vector3.new(0, markY, 0)), rgb(30, 30, 32), M.DiamondPlate, self.Props)
					g.CastShadow = false
				end
			end
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
	self.Surfaces = self.Surfaces or {}
	table.insert(self.Surfaces, { center.X - sx / 2, center.X + sx / 2, center.Z - sz / 2, center.Z + sz / 2, center.Y + 0.8 })
	self:Part(Vector3.new(sx, 0.8, sz), CFrame.new(center + Vector3.new(0, 0.4, 0)), P.Sidewalk, M.Concrete, self.Geo)
	self:Part(Vector3.new(sx + 0.6, 0.6, sz + 0.6), CFrame.new(center + Vector3.new(0, 0.3, 0)), P.ConcreteDark, M.Concrete, self.Geo)
	-- curb stones around the edge + paving seams near the curb
	local topY = center.Y + 0.81
	for _, e in { { 0, -sz / 2 + 0.5, sx, 1 }, { 0, sz / 2 - 0.5, sx, 1 }, { -sx / 2 + 0.5, 0, 1, sz }, { sx / 2 - 0.5, 0, 1, sz } } do
		self:Deco(Vector3.new(e[3], 0.04, e[4]), CFrame.new(center.X + e[1], topY, center.Z + e[2]), P.Sidewalk:Lerp(Color3.new(1, 1, 1), 0.25), M.Concrete).CastShadow = false
	end
	local seam = P.Sidewalk:Lerp(Color3.new(), 0.18)
	for x = -sx / 2 + 6, sx / 2 - 6, 6 do
		for _, zEdge in { -sz / 2 + 3.5, sz / 2 - 3.5 } do
			self:Deco(Vector3.new(0.12, 0.03, 5), CFrame.new(center.X + x, topY, center.Z + zEdge), seam, M.SmoothPlastic).CastShadow = false
		end
	end
	for z = -sz / 2 + 6, sz / 2 - 6, 6 do
		for _, xEdge in { -sx / 2 + 3.5, sx / 2 - 3.5 } do
			self:Deco(Vector3.new(5, 0.03, 0.12), CFrame.new(center.X + xEdge, topY, center.Z + z), seam, M.SmoothPlastic).CastShadow = false
		end
	end
	-- a little litter: paper scraps and leaves
	for _ = 1, math.floor(sx * sz / 900) do
		local lp = Vector3.new(center.X + self.Rng:NextNumber(-sx / 2 + 1, sx / 2 - 1), topY + 0.01, center.Z + self.Rng:NextNumber(-sz / 2 + 1, sz / 2 - 1))
		local bit = self:Deco(Vector3.new(0.5, 0.02, 0.4), CFrame.new(lp) * CFrame.Angles(0, self.Rng:NextNumber(0, 6), 0), self.Rng:NextNumber() < 0.5 and rgb(235, 232, 220) or rgb(150, 110, 60), M.SmoothPlastic)
		bit.CastShadow = false
	end
end

-- PROPS -----------------------------------------------------------------------------
function MapKit:StreetLight(pos: Vector3, facing: Vector3)
	local model = Instance.new("Model")
	model.Name = "StreetLight"
	model.Parent = self.Props
	-- tapered pole on a round footing
	self:Pillar(pos, 0.8, 1.6, P.MetalDark, M.Metal, model)
	self:Pillar(pos, 9, 0.75, P.MetalDark, M.Metal, model)
	self:Pillar(pos + Vector3.new(0, 9, 0), 7, 0.55, P.MetalDark, M.Metal, model)
	self:Ball(0.8, pos + Vector3.new(0, 16, 0), P.MetalDark, M.Metal, model)
	local dir = Vector3.new(facing.X, 0, facing.Z).Unit
	-- curved arm: three short segments bending out over the road
	local p0 = pos + Vector3.new(0, 15.6, 0)
	local pts = { p0, p0 + dir * 1.4 + Vector3.new(0, 1.0, 0), p0 + dir * 3.0 + Vector3.new(0, 1.4, 0), p0 + dir * 4.8 + Vector3.new(0, 1.2, 0) }
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local seg = self:Cylinder((b - a).Magnitude + 0.3, 0.35, CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), P.MetalDark, M.Metal, model)
		seg.CanQuery = false
	end
	-- cobra-head lamp housing
	local head = pts[#pts] + dir * 0.6
	local housing = self:Part(Vector3.new(1.5, 0.6, 2.6), CFrame.lookAt(head, head + dir), P.MetalDark, M.Metal, model)
	housing.CanQuery = false
	local lamp = self:Neon(Vector3.new(1.1, 0.15, 2.1), CFrame.lookAt(head - Vector3.new(0, 0.35, 0), head - Vector3.new(0, 0.35, 0) + dir), rgb(255, 228, 170), model)
	self:Light(lamp, "SpotLight", rgb(255, 222, 170), 46, 3, Enum.NormalId.Bottom)
	self:Light(lamp, "PointLight", rgb(255, 214, 160), 14, 0.8)
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
		-- root flare + a branch fork so the trunk isn't a plain stick
		for k = 1, 4 do
			local a = k / 4 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local root = self:Cylinder(2 * s, 0.7 * s, CFrame.lookAt(pos + dir * 0.7 * s + Vector3.new(0, 0.25, 0), pos + dir * 2 * s - Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.rad(90), 0), P.Trunk:Lerp(Color3.new(), 0.1), M.Wood, model)
			root.CanCollide, root.CanQuery = false, false
		end
		for _, side in { -1, 1 } do
			local b0 = pos + Vector3.new(0, trunkH * 0.7, 0)
			local b1 = b0 + Vector3.new(side * 2 * s, 2.2 * s, rng:NextNumber(-1, 1) * s)
			local branch = self:Cylinder((b1 - b0).Magnitude, 0.55 * s, CFrame.lookAt((b0 + b1) / 2, b1) * CFrame.Angles(0, math.rad(90), 0), P.Trunk, M.Wood, model)
			branch.CanCollide, branch.CanQuery = false, false
		end
		-- fuller, rounder canopy: a big core plus smaller clumps around it
		local crown = pos + Vector3.new(0, trunkH + 2 * s, 0)
		local core = self:Ball(8 * s, crown, P.Leaf, M.LeafyGrass, model)
		core.CanCollide = false
		core.CanQuery = false
		for k = 1, 5 do
			local ang = k / 5 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
			local clump = self:Ball(rng:NextNumber(4, 5.5) * s, crown + Vector3.new(math.cos(ang) * 3.4, rng:NextNumber(-1.2, 1.6), math.sin(ang) * 3.4) * s, rng:NextNumber() < 0.5 and P.Leaf:Lerp(P.LeafDark, 0.3) or P.LeafDark, M.LeafyGrass, model)
			clump.CanCollide = false
			clump.CanQuery = false
		end
		for _ = 1, 2 do
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
		local size = Vector3.new(rng:NextNumber(3, 6), rng:NextNumber(2.5, 4.5), rng:NextNumber(3, 6)) * s
		local cf = CFrame.new(pos + Vector3.new(rng:NextNumber(-1, 1), 0.8 * s, rng:NextNumber(-1, 1))) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3))
		self:Part(size, cf, P.Rock:Lerp(rgb(90, 88, 84), rng:NextNumber()), M.Slate, self.Geo)
		-- moss cap on top
		local moss = self:Deco(Vector3.new(size.X * 0.85, 0.25, size.Z * 0.85), cf * CFrame.new(0, size.Y / 2, 0), rgb(70, 110, 55), M.Grass)
		moss.CastShadow = false
	end
	for _ = 1, 3 do
		local pebble = self:Part(Vector3.one * rng:NextNumber(0.6, 1.2) * s, CFrame.new(pos + Vector3.new(rng:NextNumber(-4, 4), 0.3, rng:NextNumber(-4, 4)) * Vector3.new(s, 1, s)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), P.Rock, M.Slate, self.Props)
		pebble.CanCollide, pebble.CanQuery = false, false
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
	-- corrugated side ribs, rust streaks and locking bars on the doors
	local rib = c:Lerp(Color3.new(), 0.18)
	for z = -L / 2 + 1.6, L / 2 - 1.6, 2.4 do
		for _, x in { -W / 2 - 0.08, W / 2 + 0.08 } do
			self:Deco(Vector3.new(0.16, H - 0.6, 0.7), cf * CFrame.new(x, H / 2, z), rib, M.CorrodedMetal, model).CastShadow = false
		end
	end
	for _ = 1, 2 do
		local x = (self.Rng:NextNumber() < 0.5 and -1 or 1) * (W / 2 + 0.17)
		self:Deco(Vector3.new(0.05, self.Rng:NextNumber(2, 5), self.Rng:NextNumber(0.6, 1.4)), cf * CFrame.new(x, H - 2.5, self.Rng:NextNumber(-L / 2 + 2, L / 2 - 2)), rgb(120, 70, 40), M.CorrodedMetal, model).CastShadow = false
	end
	for i = -1.5, 1.5 do
		local bar = self:Cylinder(H - 0.8, 0.18, cf * CFrame.new(i * 1.7, H / 2, L / 2 + 0.05) * CFrame.Angles(0, 0, math.rad(90)), rgb(60, 62, 66), M.Metal, model)
		bar.CanCollide, bar.CanQuery, bar.CastShadow = false, false, false
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

-- Wall / post lantern with a warm flicker-free glow.
function MapKit:Lantern(cf: CFrame, parent)
	local cage = self:Deco(Vector3.new(0.9, 1.3, 0.9), cf, P.MetalDark, M.Metal, parent)
	cage.Transparency = 0.2
	local bulb = self:Neon(Vector3.new(0.55, 0.8, 0.55), cf, rgb(255, 190, 110), parent)
	self:Deco(Vector3.new(1.2, 0.25, 1.2), cf * CFrame.new(0, 0.75, 0), P.MetalDark, M.Metal, parent)
	self:Light(bulb, "PointLight", rgb(255, 180, 100), 18, 1.3)
	return bulb
end

-- Stadium-style floodlight head aimed at `target`.
function MapKit:Floodlight(pos: Vector3, target: Vector3, parent)
	local cf = CFrame.lookAt(pos, target)
	self:Deco(Vector3.new(3.2, 2, 0.8), cf, P.MetalDark, M.Metal, parent)
	local face = self:Neon(Vector3.new(2.8, 1.6, 0.1), cf * CFrame.new(0, 0, -0.45), rgb(240, 245, 255), parent)
	self:Light(face, "SpotLight", rgb(235, 240, 255), 60, 3, Enum.NormalId.Front)
	return face
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
	-- floodlights under the girders light the yard below
	for _, x in { -span / 2 + 3, span / 2 - 3 } do
		local p = (cf * CFrame.new(x, height - 2.2, 0)).Position
		self:Floodlight(p, p + Vector3.new(-x * 0.6, -height, 0), model)
	end
	local warn = self:Neon(Vector3.new(0.8, 0.8, 0.8), cf * CFrame.new(span * 0.15, height + 6.4, 0), P.Red, model)
	self:Light(warn, "PointLight", P.Red, 14, 1.5)
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
	-- plank seams, bollards, tyre fenders and rope coils
	for d = 1, len - 1, 2 do
		local p = a + dir.Unit * d
		self:Deco(Vector3.new(width - 0.2, 0.03, 0.08), CFrame.new(p.X, deckY + 0.01, p.Z) * cf.Rotation, P.WoodDark, M.Wood).CastShadow = false
	end
	for d = 6, len - 4, 14 do
		for _, side in { -1, 1 } do
			local p = a + dir.Unit * d + cf.RightVector * side * (width / 2 - 0.8)
			self:Pillar(Vector3.new(p.X, deckY, p.Z), 1.4, 0.9, rgb(40, 42, 46), M.Metal)
			self:Ball(1.1, Vector3.new(p.X, deckY + 1.45, p.Z), rgb(40, 42, 46), M.Metal).CanQuery = false
			local f = a + dir.Unit * (d + 4) + cf.RightVector * side * (width / 2 + 0.5)
			local tyre = self:Cylinder(0.8, 2.2, CFrame.new(f.X, deckY - 1.2, f.Z) * cf.Rotation * CFrame.Angles(0, math.rad(90), 0), rgb(25, 25, 27), M.Rubber)
			tyre.CanCollide, tyre.CanQuery = false, false
		end
		local rp = a + dir.Unit * (d + 2)
		local coil = self:Cylinder(0.35, 1.6, CFrame.new(rp.X, deckY + 0.18, rp.Z) * CFrame.Angles(0, 0, math.rad(90)), rgb(200, 180, 130), M.Fabric)
		coil.CanCollide, coil.CanQuery = false, false
	end
end

-- BATTLE ROYALE PIECES -----------------------------------------------------------------

-- Flat ground (top surface at `top`) covering x0..x1 / z0..z1 with rectangular holes
-- cut out (tunnel entrances). holes = { { X0, X1, Z0, Z1 }, ... }
function MapKit:Ground(top: number, x0: number, x1: number, z0: number, z1: number, thickness: number, holes, color, material)
	local rects = { { x0, x1, z0, z1 } }
	for _, h in holes or {} do
		local out = {}
		for _, r in rects do
			if h.X1 <= r[1] or h.X0 >= r[2] or h.Z1 <= r[3] or h.Z0 >= r[4] then
				table.insert(out, r)
			else
				if h.X0 > r[1] then
					table.insert(out, { r[1], h.X0, r[3], r[4] })
				end
				if h.X1 < r[2] then
					table.insert(out, { h.X1, r[2], r[3], r[4] })
				end
				local mx0, mx1 = math.max(r[1], h.X0), math.min(r[2], h.X1)
				if h.Z0 > r[3] then
					table.insert(out, { mx0, mx1, r[3], h.Z0 })
				end
				if h.Z1 < r[4] then
					table.insert(out, { mx0, mx1, h.Z1, r[4] })
				end
			end
		end
		rects = out
	end
	for _, r in rects do
		if r[2] - r[1] > 0.1 and r[4] - r[3] > 0.1 then
			self:Part(Vector3.new(r[2] - r[1], thickness, r[4] - r[3]), CFrame.new((r[1] + r[2]) / 2, top - thickness / 2, (r[3] + r[4]) / 2), color, material)
		end
	end
end

-- Climbable ladder (TrussPart) standing at `base` going up `height` studs.
function MapKit:Ladder(base: Vector3, height: number, _normal)
	local h = math.max(2, math.floor(height / 2 + 0.5) * 2)
	local truss = self:Part(Vector3.new(2, h, 2), CFrame.new(base + Vector3.new(0, h / 2, 0)), rgb(70, 74, 80), M.Metal, self.Geo, "TrussPart")
	truss.Name = "Ladder"
	return truss
end

--[[ Underground tunnel with stair entrances. Returns the ground holes for the entrances.
spec = { Axis = "Z"|"X", Cross = number, From, To, Floor = -14, Width = 14, Height = 9,
	Entrances = { { At = number, Dir = 1 | -1 }, ... }, Style = "Subway" | "Sewer" | "Mine", Terrain = bool } ]]
function MapKit:Tunnel(spec)
	local axisZ = spec.Axis ~= "X"
	local c = spec.Cross or 0
	local floorY = spec.Floor or -14
	local W = spec.Width or 14
	local H = spec.Height or 9
	local style = spec.Style or "Subway"
	local model = Instance.new("Model")
	model.Name = style .. "Tunnel"
	model.Parent = self.Geo
	local function at(along, across, y)
		return axisZ and Vector3.new(c + across, y, along) or Vector3.new(along, y, c + across)
	end
	local function size(lenAlong, h, lenAcross)
		return axisZ and Vector3.new(lenAcross, h, lenAlong) or Vector3.new(lenAlong, h, lenAcross)
	end
	local wallColor, wallMat, floorColor, floorMat
	if style == "Mine" then
		wallColor, wallMat, floorColor, floorMat = rgb(96, 74, 52), M.Ground, rgb(80, 64, 48), M.Ground
	elseif style == "Sewer" then
		wallColor, wallMat, floorColor, floorMat = rgb(92, 96, 92), M.Concrete, rgb(70, 74, 72), M.Concrete
	else
		wallColor, wallMat, floorColor, floorMat = rgb(214, 216, 210), M.SmoothPlastic, rgb(120, 120, 124), M.Concrete
	end
	local a0, a1 = math.min(spec.From, spec.To), math.max(spec.From, spec.To)
	local len = a1 - a0
	local mid = (a0 + a1) / 2
	local depth = -floorY
	local run = depth * 1.45
	if spec.Terrain then
		self:Fill(M.Air, CFrame.new(at(mid, 0, floorY + H / 2)), size(len + 4, H + 2, W + 2))
	end
	-- floor, walls, end caps
	self:Part(size(len + 2, 1, W + 2), CFrame.new(at(mid, 0, floorY - 0.5)), floorColor, floorMat, model)
	for _, s in { -1, 1 } do
		self:Part(size(len + 2, H + 1, 1), CFrame.new(at(mid, s * (W / 2 + 0.5), floorY + (H + 1) / 2)), wallColor, wallMat, model)
	end
	for _, e in { a0 - 1, a1 + 1 } do
		self:Part(size(1, H + 1, W + 2), CFrame.new(at(e, 0, floorY + (H + 1) / 2)), wallColor, wallMat, model)
	end
	-- ceiling with gaps over the entrance ramps
	local gaps = {}
	for _, e in spec.Entrances or {} do
		local g0, g1 = e.At, e.At + e.Dir * run
		table.insert(gaps, { math.min(g0, g1) - 0.5, math.max(g0, g1) + 0.5 })
	end
	table.sort(gaps, function(x, y)
		return x[1] < y[1]
	end)
	local cursor = a0 - 1
	local ceilY = floorY + H + 0.5
	local function ceiling(z0, z1)
		if z1 - z0 > 0.1 then
			self:Part(size(z1 - z0, 1, W + 2), CFrame.new(at((z0 + z1) / 2, 0, ceilY)), wallColor:Lerp(Color3.new(), 0.2), wallMat, model)
		end
	end
	for _, g in gaps do
		ceiling(cursor, g[1])
		cursor = g[2]
	end
	ceiling(cursor, a1 + 1)

	-- style dressing + lights
	for d = a0 + 6, a1 - 6, 16 do
		local lamp = self:Neon(size(4, 0.3, 1), CFrame.new(at(d, 0, ceilY - 0.65)), style == "Mine" and rgb(255, 190, 110) or rgb(235, 245, 255), model)
		self:Light(lamp, "PointLight", style == "Mine" and rgb(255, 180, 100) or rgb(220, 235, 255), 26, 1.4)
	end
	if style == "Subway" then
		for _, s in { -1, 1 } do
			self:Deco(size(len, 1, 0.1), CFrame.new(at(mid, s * (W / 2 - 0.05), floorY + 3.5)), rgb(30, 110, 60), M.SmoothPlastic, model)
			self:Deco(size(len, 0.15, 0.3), CFrame.new(at(mid, s * 1.6, floorY + 0.08)), rgb(150, 150, 156), M.Metal, model)
		end
		for d = a0 + 4, a1 - 4, 3 do
			self:Deco(size(0.6, 0.12, 4.4), CFrame.new(at(d, 0, floorY + 0.03)), rgb(80, 62, 48), M.Wood, model)
		end
		for d = a0 + 20, a1 - 20, 32 do
			for _, s in { -1, 1 } do
				self:Part(size(1.4, H, 1.4), CFrame.new(at(d, s * (W / 2 - 2), floorY + H / 2)), rgb(60, 110, 70), M.Metal, model)
			end
		end
	elseif style == "Sewer" then
		local water = self:Deco(size(len, 0.2, 3.5), CFrame.new(at(mid, 0, floorY + 0.12)), rgb(60, 90, 70), M.Glass, model)
		water.Transparency = 0.2
		for _, s in { -1, 1 } do
			local pipe = self:Cylinder(len, 1.2, CFrame.new(at(mid, s * (W / 2 - 0.8), floorY + H - 1.5)) * (axisZ and CFrame.Angles(0, math.rad(90), 0) or CFrame.identity), rgb(110, 80, 60), M.CorrodedMetal, model)
			pipe.CanCollide = false
		end
	else -- Mine
		for d = a0 + 4, a1 - 4, 8 do
			for _, s in { -1, 1 } do
				self:Part(size(1, H, 1), CFrame.new(at(d, s * (W / 2 - 0.6), floorY + H / 2)), P.WoodDark, M.Wood, model)
			end
			self:Part(size(1, 1, W), CFrame.new(at(d, 0, floorY + H - 0.5)), P.WoodDark, M.Wood, model)
		end
		for _, s in { -1, 1 } do
			self:Deco(size(len, 0.15, 0.3), CFrame.new(at(mid, s * 1.4, floorY + 0.08)), rgb(110, 100, 90), M.Metal, model)
		end
	end
	-- cover inside: crates / barrels every so often
	local rng = self.Rng
	for d = a0 + 12, a1 - 12, 26 do
		local side = rng:NextNumber() < 0.5 and -1 or 1
		self:Part(Vector3.new(3.5, 3.5, 3.5), CFrame.new(at(d, side * (W / 2 - 2.5), floorY + 1.75)), rgb(150, 112, 60), M.WoodPlanks, model)
	end

	-- entrances: ramp down from the surface, enclosed shaft, railings on top
	local holes = {}
	for _, e in spec.Entrances or {} do
		local top = at(e.At, 0, 0)
		local bottom = at(e.At + e.Dir * run, 0, floorY)
		self:Ramp(bottom, top, 6, rgb(110, 110, 114), M.DiamondPlate, model)
		local z0, z1 = math.min(e.At, e.At + e.Dir * run), math.max(e.At, e.At + e.Dir * run)
		for _, s in { -1, 1 } do
			self:Part(size(z1 - z0, depth, 0.8), CFrame.new(at((z0 + z1) / 2, s * 3.4, floorY + depth / 2)), wallColor, wallMat, model)
			-- surface railing
			self:Part(size(z1 - z0, 3.2, 0.3), CFrame.new(at((z0 + z1) / 2, s * 3.6, 1.6)), rgb(40, 110, 60), M.Metal, model)
		end
		self:Part(size(0.8, depth, 7.6), CFrame.new(at(e.At - e.Dir * 0.4, 0, floorY + depth / 2)), wallColor, wallMat, model)
		self:Part(size(0.3, 3.2, 7.4), CFrame.new(at(e.At + e.Dir * run, 0, 1.6)), rgb(40, 110, 60), M.Metal, model)
		if style == "Subway" then
			for _, s in { -1, 1 } do
				local post = at(e.At, s * 3.6, 0)
				self:Pillar(post, 6, 0.3, rgb(40, 110, 60), M.Metal, model)
				local globe = self:Ball(1, post + Vector3.new(0, 6.4, 0), rgb(120, 255, 140), M.Neon, model)
				globe.CanCollide = false
			end
		end
		if spec.Terrain then
			local mz = (z0 + z1) / 2
			self:Fill(M.Air, CFrame.new(at(mz, 0, floorY / 2 + 2)), size(z1 - z0 + 1, depth + 6, 7))
		end
		local p0, p1 = at(z0, -3.2, 0), at(z1, 3.2, 0)
		table.insert(holes, { X0 = math.min(p0.X, p1.X), X1 = math.max(p0.X, p1.X), Z0 = math.min(p0.Z, p1.Z), Z1 = math.max(p0.Z, p1.Z) })
	end
	return holes
end

-- Stacked sandbag wall (great cover). rows = 3 is chest height, 4 is full cover.
function MapKit:Sandbags(cf: CFrame, length: number, rows: number?)
	local r = rows or 3
	local tan = rgb(168, 146, 102)
	for row = 0, r - 1 do
		local offset = (row % 2) * 1.1
		for x = -length / 2 + 1.1 + offset, length / 2 - 1.1, 2.2 do
			local bag = self:Part(Vector3.new(2.2, 1.05, 1.4), cf * CFrame.new(x, 0.52 + row * 1.0, 0) * CFrame.Angles(0, self.Rng:NextNumber(-0.08, 0.08), 0), tan:Lerp(rgb(130, 112, 80), self.Rng:NextNumber()), M.Fabric)
			bag.Name = "Sandbag"
		end
	end
end

-- Dense bush you can hide inside (no collision, bullets go through).
function MapKit:HideBush(pos: Vector3, scale: number?)
	local s = scale or 1
	local rng = self.Rng
	for i = 1, 4 do
		local b = self:Ball(rng:NextNumber(5, 7) * s, pos + Vector3.new(rng:NextNumber(-2, 2) * s, (2 + i * 0.4) * s, rng:NextNumber(-2, 2) * s), i % 2 == 0 and P.LeafDark or P.Leaf, M.LeafyGrass, self.Props)
		b.CanCollide = false
		b.CanQuery = false
		b.Name = "HideBush"
	end
end

-- STREET FURNITURE ---------------------------------------------------------------------
function MapKit:Hydrant(pos: Vector3)
	self:Pillar(pos, 2.2, 0.8, rgb(200, 40, 30), M.Metal, self.Props)
	self:Ball(0.9, pos + Vector3.new(0, 2.3, 0), rgb(200, 40, 30), M.Metal, self.Props)
	self:Cylinder(1.2, 0.35, CFrame.new(pos + Vector3.new(0, 1.5, 0)), rgb(220, 200, 60), M.Metal, self.Props)
end

function MapKit:TrashCan(pos: Vector3)
	self:Pillar(pos, 3, 1.8, rgb(40, 70, 50), M.Metal, self.Props)
	self:Cylinder(0.3, 2, CFrame.new(pos + Vector3.new(0, 3.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(30, 50, 36), M.Metal, self.Props)
end

function MapKit:Manhole(pos: Vector3)
	local m = self:Cylinder(0.06, 3, CFrame.new(pos + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(50, 50, 52), M.DiamondPlate, self.Props)
	m.CanCollide = false
end

function MapKit:Cone(pos: Vector3)
	self:Part(Vector3.new(1.4, 0.2, 1.4), CFrame.new(pos + Vector3.new(0, 0.1, 0)), rgb(30, 30, 30), M.Plastic, self.Props)
	self:Pillar(pos + Vector3.new(0, 0.2, 0), 1.8, 0.7, rgb(255, 120, 20), M.Plastic, self.Props)
	self:Cylinder(0.3, 0.75, CFrame.new(pos + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(240, 240, 240), M.Plastic, self.Props)
end

function MapKit:Planter(pos: Vector3)
	self:Part(Vector3.new(5, 2, 5), CFrame.new(pos + Vector3.new(0, 1, 0)), P.ConcreteDark, M.Concrete, self.Geo)
	self:Bush(pos + Vector3.new(0, 1.6, 0), 0.8)
end

function MapKit:BusStop(cf: CFrame)
	self:Part(Vector3.new(10, 0.3, 4), cf * CFrame.new(0, 8, 0), P.MetalDark, M.Metal, self.Props)
	for _, x in { -4.8, 4.8 } do
		self:Part(Vector3.new(0.3, 8, 0.3), cf * CFrame.new(x, 4, 1.6), P.MetalDark, M.Metal, self.Props)
	end
	self:Glass(Vector3.new(10, 6.5, 0.2), cf * CFrame.new(0, 4.5, 1.8))
	local ad = self:Neon(Vector3.new(0.2, 5, 3), cf * CFrame.new(4.9, 4.2, 0), rgb(255, 200, 80), self.Props)
	ad.Name = "BusAd"
	self:Bench(cf * CFrame.new(0, 0, 0.8))
end

function MapKit:NewsBox(cf: CFrame)
	self:Part(Vector3.new(1.8, 3, 1.6), cf * CFrame.new(0, 1.5, 0), rgb(30, 80, 160), M.Metal, self.Props)
	self:Glass(Vector3.new(1.4, 0.9, 0.1), cf * CFrame.new(0, 2.3, -0.82))
end

function MapKit:StreetSign(pos: Vector3, rot: number?)
	self:Pillar(pos, 10, 0.3, P.MetalDark, M.Metal, self.Props)
	self:Part(Vector3.new(4, 0.9, 0.1), CFrame.new(pos + Vector3.new(0, 9.2, 0)) * CFrame.Angles(0, rot or 0, 0), rgb(20, 110, 60), M.SmoothPlastic, self.Props)
	self:Part(Vector3.new(0.1, 0.9, 4), CFrame.new(pos + Vector3.new(0, 8.2, 0)) * CFrame.Angles(0, rot or 0, 0), rgb(20, 110, 60), M.SmoothPlastic, self.Props)
end

function MapKit:PowerBox(cf: CFrame)
	self:Part(Vector3.new(3, 4, 1.8), cf * CFrame.new(0, 2, 0), rgb(120, 126, 110), M.Metal, self.Geo)
	self:Deco(Vector3.new(2.6, 0.5, 0.1), cf * CFrame.new(0, 3.2, -0.92), rgb(240, 200, 30), M.SmoothPlastic)
end

-- Team spawn base at one end of the map: spawn markers behind a line of cover.
function MapKit:SpawnBase(center: Vector3, toward: Vector3, team: string, width: number?)
	local w = width or 60
	local dir = Vector3.new(toward.X - center.X, 0, toward.Z - center.Z).Unit
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local color = ({ A = rgb(40, 120, 255), B = rgb(255, 60, 60), C = rgb(60, 220, 110) })[team] or rgb(255, 198, 26)
	for i = -4, 4 do
		if i ~= 0 then -- the middle is kept free (tunnel entrances / roads)
			self:Spawn(center + right * (i * w / 9) + Vector3.new(0, 3, 0), center + dir * 100, team)
		end
	end
	-- cover line in front of the spawn
	local front = center + dir * 14
	for i = -2, 2 do
		if i ~= 0 then
			local cf = CFrame.lookAt(front + right * (i * w / 5), front + right * (i * w / 5) + dir)
			self:Sandbags(cf, w / 6, 3)
		end
	end
	-- team flag
	local pole = center - dir * 6
	self:Pillar(pole, 16, 0.5, P.MetalDark, M.Metal, self.Props)
	local flag = self:Part(Vector3.new(0.2, 3.5, 5.5), CFrame.lookAt(pole + Vector3.new(0, 14, 0) + right * 2.9, pole + Vector3.new(0, 14, 0) + right * 3.9), color, M.Fabric, self.Props)
	flag.CanCollide = false
	local glow = self:Neon(Vector3.new(1.2, 0.08, w * 0.9), CFrame.lookAt(center + Vector3.new(0, 0.06, 0) + dir * 4, center + Vector3.new(0, 0.06, 0) + dir * 4 + right), color, self.Props)
	glow.Name = "SpawnLine"
end

-- Free-for-all spawn points scattered around the map. Points closer than
-- `minGap` studs to an earlier point are dropped so nobody spawns on top of someone.
function MapKit:FFASpawns(points, minGap: number?)
	local gap = minGap or 36
	local kept = {}
	for _, p in points do
		local ok = true
		for _, q in kept do
			if (Vector3.new(p.X - q.X, 0, p.Z - q.Z)).Magnitude < gap then
				ok = false
				break
			end
		end
		if ok then
			table.insert(kept, p)
			self:Spawn(Vector3.new(p.X, (p.Y ~= 0 and p.Y or 3), p.Z), Vector3.new(0, 3, 0), "FFA")
		end
	end
end

--[[ Big terrain mountains all around the map (outside the invisible boundary walls,
so they look real but can't be reached). Also lays a grass plain out to the horizon.
opts = { Margin = 40, SkipSide = "N" (water side, +Z), GroundY = -0.5 } ]]
function MapKit:Mountains(halfX: number, halfZ: number, opts)
	opts = opts or {}
	local rng = self.Rng
	local margin = opts.Margin or 40
	local gy = opts.GroundY or -0.5
	local ext = 650
	local inX, inZ = halfX + 12, halfZ + 12
	-- grass plains from just outside the map to the horizon
	local plains = {
		S = { CFrame.new(0, gy - 4, -inZ - ext / 2), Vector3.new((inX + ext) * 2, 8, ext) },
		N = { CFrame.new(0, gy - 4, inZ + ext / 2), Vector3.new((inX + ext) * 2, 8, ext) },
		W = { CFrame.new(-inX - ext / 2, gy - 4, 0), Vector3.new(ext, 8, inZ * 2) },
		E = { CFrame.new(inX + ext / 2, gy - 4, 0), Vector3.new(ext, 8, inZ * 2) },
	}
	for side, pl in plains do
		if side ~= opts.SkipSide then
			self:Fill(M.Grass, pl[1], pl[2])
		end
	end
	-- two rows of peaks per side; snow caps on the tall ones
	local function peak(center: Vector3, r: number)
		self:FillBall(M.Rock, center, r)
		self:FillBall(M.Grass, center + Vector3.new(0, -r * 0.22, 0), r * 1.0) -- green lower slopes, rocky peaks
		if r > 95 then
			self:FillBall(M.Snow, center + Vector3.new(0, r * 0.62, 0), r * 0.32)
		end
	end
	local sides = {
		{ "S", Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), halfX, halfZ },
		{ "N", Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), halfX, halfZ },
		{ "W", Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), halfZ, halfX },
		{ "E", Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), halfZ, halfX },
	}
	for _, sd in sides do
		if sd[1] ~= opts.SkipSide then
			local along, out, len, edge = sd[2], sd[3], sd[4], sd[5]
			for row = 1, 2 do
				local spacing = row == 1 and 80 or 120
				for d = -len - 120, len + 120, spacing do
					local r = row == 1 and rng:NextNumber(60, 95) or rng:NextNumber(95, 140)
					local dist = edge + margin + r * 0.95 + (row - 1) * 70
					local center = along * (d + rng:NextNumber(-20, 20)) + out * dist + Vector3.new(0, -r * 0.35, 0)
					peak(center, r)
				end
			end
		end
	end
end

-- COVER -------------------------------------------------------------------------------
-- Height of the terrain under (x, z); 0 when there's nothing to hit (or outside Roblox).
function MapKit:GroundY(x: number, z: number): (number, boolean)
	-- raised surfaces (sidewalk blocks) built by this kit
	local best = nil
	for _, r in self.Surfaces or {} do
		if x >= r[1] and x <= r[2] and z >= r[3] and z <= r[4] then
			best = math.max(best or -math.huge, r[5])
		end
	end
	if best then
		return best, false
	end
	local ok, result = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { workspace.Terrain }
		return workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -90, 0), params)
	end)
	if ok and result then
		return result.Position.Y, result.Material == Enum.Material.Water
	end
	return 0, false
end

-- Decorative ground cover: grass tufts, wildflowers, ferns, stumps and mushrooms.
-- Nothing here collides or blocks bullets; it just makes the ground feel alive.
function MapKit:Scatter(x0: number, x1: number, z0: number, z1: number, count: number, avoid)
	local rng = self.Rng
	local grass = { rgb(76, 140, 60), rgb(96, 158, 66), rgb(60, 118, 52) }
	local petals = { rgb(250, 240, 120), rgb(255, 255, 255), rgb(200, 120, 255), rgb(255, 120, 150), rgb(120, 170, 255) }
	local placed = 0
	for _ = 1, count * 3 do
		if placed >= count then
			break
		end
		local x, z = rng:NextNumber(x0, x1), rng:NextNumber(z0, z1)
		local blocked = avoid and avoid(x, z)
		local y, water = self:GroundY(x, z)
		if not blocked and not water then
			placed += 1
			local base = CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			local roll = rng:NextNumber()
			if roll < 0.5 then
				for k = 1, 4 do
					local blade = self:Deco(Vector3.new(0.15, rng:NextNumber(0.9, 1.6), 0.5), base * CFrame.new(rng:NextNumber(-0.5, 0.5), 0.5, rng:NextNumber(-0.5, 0.5)) * CFrame.Angles(rng:NextNumber(-0.35, 0.35), k, rng:NextNumber(-0.35, 0.35)), grass[rng:NextInteger(1, 3)], M.Grass)
					blade.CastShadow = false
				end
			elseif roll < 0.75 then
				local col = petals[rng:NextInteger(1, #petals)]
				for _ = 1, 3 do
					local off = Vector3.new(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8))
					local h = rng:NextNumber(0.8, 1.4)
					self:Deco(Vector3.new(0.08, h, 0.08), base * CFrame.new(off + Vector3.new(0, h / 2, 0)), rgb(70, 120, 50), M.Grass).CastShadow = false
					local bloom = self:Ball(0.42, (base * CFrame.new(off + Vector3.new(0, h, 0))).Position, col, M.SmoothPlastic, self.Props)
					bloom.CanCollide, bloom.CanQuery, bloom.CastShadow = false, false, false
				end
			elseif roll < 0.9 then
				for k = 1, 6 do
					local frond = self:Deco(Vector3.new(0.6, 0.08, 2.2), base * CFrame.Angles(0, k * 1.05, 0) * CFrame.new(0, 0.55, -1) * CFrame.Angles(math.rad(25), 0, 0), rgb(56, 120, 50), M.LeafyGrass)
					frond.CastShadow = false
				end
			elseif roll < 0.96 then
				local stump = self:Cylinder(1.2, 1.8, base * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), P.Trunk, M.Wood, self.Props)
				stump.CanQuery = false
				self:Deco(Vector3.new(0.05, 1.7, 1.7), base * CFrame.new(0, 1.21, 0) * CFrame.Angles(0, 0, math.rad(90)), P.WoodLight, M.Wood).Shape = Enum.PartType.Cylinder
			else
				for k = 1, 3 do
					local m0 = base * CFrame.new(k * 0.5 - 1, 0, rng:NextNumber(-0.4, 0.4))
					self:Deco(Vector3.new(0.15, 0.4, 0.15), m0 * CFrame.new(0, 0.2, 0), rgb(235, 225, 205), M.SmoothPlastic).CastShadow = false
					local cap = self:Ball(0.5, (m0 * CFrame.new(0, 0.42, 0)).Position, rgb(200, 60, 40), M.SmoothPlastic, self.Props)
					cap.CanCollide, cap.CanQuery, cap.CastShadow = false, false, false
					cap.Size = Vector3.new(0.5, 0.3, 0.5)
				end
			end
		end
	end
end

function MapKit:Barrel(pos: Vector3, color: Color3?, tipped: boolean?)
	local c = color or rgb(40, 90, 160)
	local cf = tipped and (CFrame.new(pos + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, self.Rng:NextNumber(0, 3), 0)) or (CFrame.new(pos + Vector3.new(0, 1.9, 0)) * CFrame.Angles(0, 0, math.rad(90)))
	local b = self:Cylinder(3.8, 2.6, cf, c, M.Metal)
	b.Name = "Barrel"
	for _, off in { -1.1, 1.1 } do
		self:Deco(Vector3.new(0.25, 2.72, 2.72), cf * CFrame.new(off, 0, 0), c:Lerp(Color3.new(), 0.35), M.Metal).Shape = Enum.PartType.Cylinder
	end
	return b
end

function MapKit:Pallet(cf: CFrame, height: number?)
	for layer = 0, (height or 1) - 1 do
		local y = layer * 0.7
		for i = -1, 1 do
			self:Part(Vector3.new(4.6, 0.35, 0.6), cf * CFrame.new(0, y + 0.18, i * 1.8), P.WoodLight, M.WoodPlanks)
		end
		for i = -2, 2 do
			self:Deco(Vector3.new(0.8, 0.12, 4.4), cf * CFrame.new(i * 1.05, y + 0.42, 0), P.WoodLight:Lerp(P.Wood, 0.3), M.WoodPlanks)
		end
	end
end

-- Burnt-out car shell: solid, waist-high-plus cover.
function MapKit:Wreck(cf: CFrame, color: Color3?)
	local body = (color or rgb(90, 70, 60)):Lerp(rgb(40, 34, 30), 0.45)
	local model = Instance.new("Model")
	model.Name = "Wreck"
	model.Parent = self.Geo
	self:Part(Vector3.new(6.2, 2.2, 13), cf * CFrame.new(0, 1.9, 0), body, M.CorrodedMetal, model)
	-- rounded bumpers
	for _, z in { -6.5, 6.5 } do
		self:Cylinder(6.2, 1.6, cf * CFrame.new(0, 1.6, z), body:Lerp(Color3.new(), 0.2), M.CorrodedMetal, model)
	end
	-- crushed cabin with broken-out windows
	self:Part(Vector3.new(5.6, 1.6, 6), cf * CFrame.new(0, 3.75, 0.6) * CFrame.Angles(math.rad(4), 0, math.rad(3)), body, M.CorrodedMetal, model)
	self:Deco(Vector3.new(5.7, 0.9, 6.1), cf * CFrame.new(0, 3.8, 0.6) * CFrame.Angles(math.rad(4), 0, math.rad(3)), rgb(20, 20, 22), M.SmoothPlastic, model)
	for _, x in { -2.9, 2.9 } do
		for _, z in { -4.2, 4.2 } do
			local w = self:Cylinder(1.1, 2.4, cf * CFrame.new(x, 1.0, z), rgb(28, 28, 30), M.Slate, model)
			w.CanQuery = false
		end
	end
	local smoke = self:Deco(Vector3.new(1, 1, 1), cf * CFrame.new(0, 4.6, -3), body, M.CorrodedMetal, model)
	smoke.Transparency = 1
	local pe = Instance.new("Smoke")
	pe.Color = rgb(60, 60, 60)
	pe.Opacity = 0.08
	pe.RiseVelocity = 3
	pe.Size = 4
	pe.Parent = smoke
	return model
end

function MapKit:LogPile(cf: CFrame)
	for row = 0, 2 do
		for i = 0, 2 - row do
			local log = self:Cylinder(9, 1.5, cf * CFrame.new(0, 0.75 + row * 1.25, (i - (2 - row) / 2) * 1.55) * CFrame.Angles(0, self.Rng:NextNumber(-0.05, 0.05), 0), P.Trunk:Lerp(P.WoodLight, self.Rng:NextNumber(0, 0.3)), M.Wood)
			log.Name = "Log"
		end
	end
end

function MapKit:FallenTree(cf: CFrame)
	local trunk = self:Cylinder(16, 2, cf * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(4)), P.Trunk, M.Wood)
	trunk.Name = "FallenTree"
	self:Cylinder(2.2, 2.6, cf * CFrame.new(-8, 1.3, 0), P.Trunk:Lerp(Color3.new(), 0.2), M.Wood) -- root end
	for i = 1, 3 do
		local leaf = self:Ball(self.Rng:NextNumber(4, 6), (cf * CFrame.new(6 + i, 1.8, self.Rng:NextNumber(-1.5, 1.5))).Position, P.LeafDark, M.LeafyGrass)
		leaf.CanCollide = false
	end
end

-- Low concrete wall chunk with exposed rebar (broken edge).
function MapKit:BrokenWall(cf: CFrame, length: number, color: Color3?)
	local c = color or P.ConcreteDark
	self:Part(Vector3.new(length, 4.6, 1.4), cf * CFrame.new(0, 2.3, 0), c, M.Concrete)
	self:Part(Vector3.new(length * 0.35, 1.6, 1.4), cf * CFrame.new(length * 0.2, 5.4, 0) * CFrame.Angles(0, 0, math.rad(-6)), c, M.Concrete)
	for i = 0, 2 do
		self:Deco(Vector3.new(0.15, 1.6, 0.15), cf * CFrame.new(-length / 2 + 0.4 + i * 0.5, 5.2, 0) * CFrame.Angles(0, 0, math.rad(-12 + i * 10)), rgb(90, 60, 45), M.CorrodedMetal)
	end
	for _ = 1, 3 do
		local rubble = self:Part(Vector3.one * self.Rng:NextNumber(0.8, 1.6), cf * CFrame.new(self.Rng:NextNumber(-length / 2, length / 2), 0.4, self.Rng:NextNumber(1.2, 2.6)) * CFrame.Angles(self.Rng:NextNumber(0, 3), self.Rng:NextNumber(0, 3), 0), c, M.Concrete)
		rubble.CanQuery = false
	end
end

local COVER_STYLES = {
	City = { "BarrierL", "Wreck", "Crates", "Sandbags", "Planter", "BrokenWall" },
	Harbor = { "Crates", "Barrels", "Pallets", "Sandbags", "BarrierL", "Wreck" },
	Forest = { "Logs", "Rocks", "FallenTree", "Sandbags", "Crates" },
	Arena = { "NeonWall", "NeonPillar", "NeonCrates" },
}

-- One cover cluster at `pos` (a little set piece you can hide behind / peek around).
function MapKit:CoverCluster(pos: Vector3, theme: string, style: string?)
	local rng = self.Rng
	local styles = COVER_STYLES[theme] or COVER_STYLES.City
	style = style or styles[rng:NextInteger(1, #styles)]
	local groundY = self:GroundY(pos.X, pos.Z)
	local y = math.max(pos.Y, groundY)
	local base = CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	if style == "BarrierL" then
		self:Barrier(base * CFrame.new(-2, 0, 0))
		self:Barrier(base * CFrame.new(3.4, 0, 4.4) * CFrame.Angles(0, math.rad(90), 0))
		self:Cone((base * CFrame.new(-7.5, 0, 2)).Position)
	elseif style == "Wreck" then
		self:Wreck(base * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-3, 3))))
	elseif style == "Crates" then
		self:Crate((base * CFrame.new(0, 0, 0)).Position, 5, rng:NextNumber(0, 0.3))
		self:Crate((base * CFrame.new(5.2, 0, 0.4)).Position, 4.5, rng:NextNumber(0, 0.3))
		self:Crate((base * CFrame.new(2.4, 5, 0.2)).Position, 4, rng:NextNumber(0, 0.6))
		self:Pallet(base * CFrame.new(-5, 0, 3), 2)
	elseif style == "Sandbags" then
		self:Sandbags(base, 10, 3)
		self:Sandbags(base * CFrame.new(5.6, 0, 3.6) * CFrame.Angles(0, math.rad(-60), 0), 6, 3)
		self:Sandbags(base * CFrame.new(-5.6, 0, 3.6) * CFrame.Angles(0, math.rad(60), 0), 6, 3)
	elseif style == "Planter" then
		local planter = self:Part(Vector3.new(12, 3.2, 4), base * CFrame.new(0, 1.6, 0), P.Concrete, M.Concrete)
		planter.Name = "BigPlanter"
		self:Deco(Vector3.new(11.4, 0.4, 3.4), base * CFrame.new(0, 3.1, 0), rgb(70, 50, 36), M.Ground)
		for i = -1, 1 do
			local b = self:Ball(3.4, (base * CFrame.new(i * 3.6, 4.2, 0)).Position, P.LeafDark, M.LeafyGrass)
			b.CanCollide = false
		end
		self:Bench(base * CFrame.new(0, 0, 4.2) * CFrame.Angles(0, math.rad(180), 0))
	elseif style == "BrokenWall" then
		self:BrokenWall(base, 11)
	elseif style == "Barrels" then
		local colors = { rgb(40, 90, 160), rgb(200, 70, 40), rgb(230, 170, 30), rgb(60, 120, 70) }
		for i = 0, 3 do
			self:Barrel((base * CFrame.new((i % 2) * 2.9 - 1.4, 0, math.floor(i / 2) * 2.9 - 1.4)).Position, colors[rng:NextInteger(1, 4)])
		end
		self:Barrel((base * CFrame.new(4.6, 0, 1)).Position, colors[rng:NextInteger(1, 4)], true)
		self:Pallet(base * CFrame.new(-4.8, 0, 0), 3)
	elseif style == "Pallets" then
		self:Pallet(base, 5)
		self:Pallet(base * CFrame.new(5.2, 0, 0.6) * CFrame.Angles(0, 0.2, 0), 3)
		self:Crate((base * CFrame.new(-4.6, 0, 1)).Position, 4)
	elseif style == "Logs" then
		self:LogPile(base)
		self:Rock((base * CFrame.new(6, 0, 3)).Position, 0.8)
	elseif style == "Rocks" then
		self:Rock(base.Position, 1.6)
		self:Rock((base * CFrame.new(5, 0, 2)).Position, 1.1)
		self:Bush((base * CFrame.new(-4, 0, 3)).Position, 1)
	elseif style == "FallenTree" then
		self:FallenTree(base)
	elseif style == "NeonWall" or style == "NeonPillar" or style == "NeonCrates" then
		local trim = rng:NextNumber() < 0.5 and P.NeonWarm or P.Neon
		if style == "NeonWall" then
			self:Part(Vector3.new(12, 4.5, 1.5), base * CFrame.new(0, 2.25, 0), P.MetalDark, M.Metal)
			self:Neon(Vector3.new(12.1, 0.25, 1.6), base * CFrame.new(0, 4.5, 0), trim)
			self:Part(Vector3.new(1.5, 4.5, 6), base * CFrame.new(6.75, 2.25, 2.25), P.MetalDark, M.Metal)
			self:Neon(Vector3.new(1.6, 0.25, 6.1), base * CFrame.new(6.75, 4.5, 2.25), trim)
		elseif style == "NeonPillar" then
			self:Pillar(base.Position, 10, 4, P.Metal, M.Metal)
			self:Neon(Vector3.new(0.3, 4.1, 4.1), CFrame.new(base.Position + Vector3.new(0, 10, 0)) * CFrame.Angles(0, 0, math.rad(90)), trim).Shape = Enum.PartType.Cylinder
			self:Part(Vector3.new(8, 3, 1.4), base * CFrame.new(0, 1.5, 3.2), P.MetalDark, M.Metal)
		else
			for i, off in { Vector3.new(0, 0, 0), Vector3.new(4.6, 0, 0.5), Vector3.new(2.2, 4, 0.2) } do
				local sz = i == 3 and 3.6 or 4.4
				local cf = base * CFrame.new(off + Vector3.new(0, sz / 2, 0))
				self:Part(Vector3.one * sz, cf, P.Metal, M.DiamondPlate)
				self:Neon(Vector3.new(sz + 0.05, 0.2, sz + 0.05), cf * CFrame.new(0, sz / 2 - 0.4, 0), trim)
			end
		end
	end
end

-- Scatter cover clusters over a list of { x, z } open spots.
function MapKit:CoverField(spots, theme: string)
	for _, p in spots do
		self:CoverCluster(Vector3.new(p[1], 0, p[2]), theme)
	end
end

-- Roadside cover along a straight road: alternating clusters near the curbs that
-- leave the driving lanes open.
function MapKit:RoadCover(axis: string, center: number, from: number, to: number, step: number, curb: number, _theme: string, skip)
	local side = 1
	for a = from, to, step do
		local blocked = false
		for _, s in skip or {} do
			if math.abs(a - s) < 16 then
				blocked = true
			end
		end
		if not blocked then
			local pos = axis == "X" and Vector3.new(a, 0, center + side * curb) or Vector3.new(center + side * curb, 0, a)
			local rot = axis == "X" and 0 or 90
			local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(rot + self.Rng:NextNumber(-12, 12)), 0)
			local roll = self.Rng:NextNumber()
			if roll < 0.4 then
				self:Wreck(cf * CFrame.Angles(0, math.rad(90), 0))
			elseif roll < 0.75 then
				self:Barrier(cf)
				self:Barrier(cf * CFrame.new(8.2, 0, 0.6) * CFrame.Angles(0, math.rad(14), 0))
			else
				self:Sandbags(cf, 8, 3)
			end
			side = -side
		end
	end
end

return MapKit
