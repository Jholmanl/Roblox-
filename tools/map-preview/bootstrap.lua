-- Minimal Roblox API mock so the game's map code can run outside Roblox.
-- Usage: rbxmock bootstrap.lua <repoRoot> <mapModulePath> <out.json>
local ROOT, MAP, OUT = ARGS[2], ARGS[3], ARGS[4]

-- Vector3 --------------------------------------------------------------------
local V3 = {}
local V3mt = {}
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3mt)
end
V3mt.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3mt.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3mt.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3mt.__mul = function(a, b)
	if type(a) == "number" then return v3(b.X * a, b.Y * a, b.Z * a) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3mt.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3mt.__tostring = function(a) return string.format("%g, %g, %g", a.X, a.Y, a.Z) end
local V3methods = {
	Dot = function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end,
	Cross = function(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end,
	Abs = function(a) return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z)) end,
	Lerp = function(a, b, t) return a + (b - a) * t end,
	Min = function(a, b) return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end,
	Max = function(a, b) return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end,
}
V3mt.__index = function(a, k)
	if k == "Magnitude" then return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z) end
	if k == "Unit" then
		local m = math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
		if m == 0 then return v3(0, 0, 0) end
		return v3(a.X / m, a.Y / m, a.Z / m)
	end
	return V3methods[k]
end
V3.new = v3
V3.zero = v3(0, 0, 0)
V3.one = v3(1, 1, 1)
V3.xAxis = v3(1, 0, 0)
V3.yAxis = v3(0, 1, 0)
V3.zAxis = v3(0, 0, 1)
Vector3 = V3
Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0 } end, zero = { X = 0, Y = 0 } }

-- CFrame (position + 3x3 rotation, row-major) ---------------------------------
local CF = {}
local CFmt = {}
local function cf(p, r)
	return setmetatable({ p = p, r = r }, CFmt)
end
local I = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function matmul(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return r
end
local function matvec(m, v)
	return v3(m[1] * v.X + m[2] * v.Y + m[3] * v.Z, m[4] * v.X + m[5] * v.Y + m[6] * v.Z, m[7] * v.X + m[8] * v.Y + m[9] * v.Z)
end
local function transpose(m)
	return { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
end
local function fromCols(right, up, back)
	return { right.X, up.X, back.X, right.Y, up.Y, back.Y, right.Z, up.Z, back.Z }
end
function CF.new(a, b, c, ...)
	if a == nil then return cf(v3(0, 0, 0), I) end
	if type(a) == "number" then
		local rest = { ... }
		if #rest >= 9 then
			return cf(v3(a, b, c), { rest[1], rest[2], rest[3], rest[4], rest[5], rest[6], rest[7], rest[8], rest[9] })
		end
		return cf(v3(a, b, c), I)
	end
	if b then return CF.lookAt(a, b) end
	return cf(a, I)
end
function CF.lookAt(pos, target, up)
	up = up or V3.yAxis
	local back = (pos - target).Unit
	if back.Magnitude == 0 then return cf(pos, I) end
	local right = up:Cross(back)
	if right.Magnitude < 1e-6 then right = V3.xAxis end
	right = right.Unit
	local up2 = back:Cross(right).Unit
	return cf(pos, fromCols(right, up2, back))
end
function CF.Angles(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local Rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cf(v3(0, 0, 0), matmul(matmul(Rx, Ry), Rz))
end
CF.fromEulerAnglesXYZ = CF.Angles
CF.identity = cf(v3(0, 0, 0), I)
CFmt.__mul = function(a, b)
	if getmetatable(b) == CFmt then
		return cf(a.p + matvec(a.r, b.p), matmul(a.r, b.r))
	end
	return a.p + matvec(a.r, b)
end
CFmt.__add = function(a, v) return cf(a.p + v, a.r) end
CFmt.__sub = function(a, v) return cf(a.p - v, a.r) end
local CFmethods = {
	Inverse = function(a)
		local rt = transpose(a.r)
		return cf(-matvec(rt, a.p), rt)
	end,
	Lerp = function(a, b, t) return cf(a.p:Lerp(b.p, t), t < 0.5 and a.r or b.r) end,
	PointToWorldSpace = function(a, v) return a * v end,
	ToWorldSpace = function(a, b) return a * b end,
	VectorToWorldSpace = function(a, v) return matvec(a.r, v) end,
}
CFmt.__index = function(a, k)
	if k == "Position" then return a.p end
	if k == "X" then return a.p.X end
	if k == "Y" then return a.p.Y end
	if k == "Z" then return a.p.Z end
	if k == "RightVector" then return v3(a.r[1], a.r[4], a.r[7]) end
	if k == "UpVector" then return v3(a.r[2], a.r[5], a.r[8]) end
	if k == "LookVector" then return v3(-a.r[3], -a.r[6], -a.r[9]) end
	if k == "Rotation" then return cf(v3(0, 0, 0), a.r) end
	return CFmethods[k]
end
CFrame = CF

-- Color3 ---------------------------------------------------------------------
local C3mt = {}
local function c3(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3mt) end
C3mt.__index = { Lerp = function(a, b, t) return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end }
C3mt.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
Color3 = {
	new = function(r, g, b) return c3(r or 0, g or 0, b or 0) end,
	fromRGB = function(r, g, b) return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end,
	fromHSV = function(h, s, v)
		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		local m = { { v, t, p }, { q, v, p }, { p, v, t }, { p, q, v }, { t, p, v }, { v, p, q } }
		local c = m[(i % 6) + 1]
		return c3(c[1], c[2], c[3])
	end,
}
BrickColor = { new = function() return {} end }
UDim2 = { new = function() return {} end, fromScale = function() return {} end, fromOffset = function() return {} end }
UDim = { new = function() return {} end }
NumberSequence = { new = function() return {} end }
NumberRange = { new = function() return {} end }
ColorSequence = { new = function() return {} end }
PhysicalProperties = { new = function() return {} end }
TweenInfo = { new = function() return {} end }

-- Enum -------------------------------------------------------------------------
local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, typeName)
		if not enumCache[typeName] then
			enumCache[typeName] = setmetatable({}, {
				__index = function(t, item)
					local e = { Name = item, EnumType = typeName }
					rawset(t, item, e)
					return e
				end,
			})
		end
		return enumCache[typeName]
	end,
})

-- Random / math.noise -----------------------------------------------------------
Random = {
	new = function(seed)
		local state = (seed or 1) * 2654435761 % 4294967296
		local r = {}
		local function nxt()
			state = (state * 1664525 + 1013904223) % 4294967296
			return state / 4294967296
		end
		function r:NextNumber(a, b)
			if a == nil then return nxt() end
			return a + (b - a) * nxt()
		end
		function r:NextInteger(a, b) return math.floor(a + (b - a + 1) * nxt()) end
		return r
	end,
}

-- Instances ------------------------------------------------------------------------
local PART_CLASSES = { Part = true, WedgePart = true, TrussPart = true, Seat = true, VehicleSeat = true, SpawnLocation = true, CornerWedgePart = true }
local Instance = {}
local InstMethods = {}
function InstMethods:SetAttribute(k, v) rawget(self, "_attrs")[k] = v end
function InstMethods:GetAttribute(k) return rawget(self, "_attrs")[k] end
function InstMethods:GetChildren()
	local t = {}
	for _, c in rawget(self, "_children") do table.insert(t, c) end
	return t
end
function InstMethods:GetDescendants()
	local out = {}
	local function walk(x)
		for _, c in rawget(x, "_children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function InstMethods:FindFirstChild(name)
	for _, c in rawget(self, "_children") do
		if c.Name == name then return c end
	end
	return nil
end
InstMethods.WaitForChild = InstMethods.FindFirstChild
function InstMethods:FindFirstChildOfClass(cls)
	for _, c in rawget(self, "_children") do
		if c.ClassName == cls then return c end
	end
	return nil
end
function InstMethods:IsA(cls)
	local me = self.ClassName
	if cls == me or cls == "Instance" then return true end
	if cls == "BasePart" then return PART_CLASSES[me] == true end
	if cls == "Light" then return me == "PointLight" or me == "SpotLight" or me == "SurfaceLight" end
	if cls == "Seat" then return me == "Seat" end
	return false
end
function InstMethods:Destroy() self.Parent = nil end
function InstMethods:ClearAllChildren()
	for _, c in self:GetChildren() do c.Parent = nil end
end
function InstMethods:GetPivot()
	if self.ClassName == "Model" then
		local pp = self.PrimaryPart
		if pp then return pp.CFrame * (pp.PivotOffset or CF.new()) end
		for _, d in self:GetDescendants() do
			if d:IsA("BasePart") then return d.CFrame end
		end
		return CF.new()
	end
	return self.CFrame
end
function InstMethods:PivotTo(target)
	local current = self:GetPivot()
	local delta = target * current:Inverse()
	if self.ClassName == "Model" then
		for _, d in self:GetDescendants() do
			if d:IsA("BasePart") then d.CFrame = delta * d.CFrame end
		end
	else
		self.CFrame = target
	end
end
function InstMethods:Clone()
	local c = Instance.new(self.ClassName)
	for k, v in rawget(self, "_props") do
		if k ~= "Parent" then c[k] = v end
	end
	for k, v in rawget(self, "_attrs") do c:SetAttribute(k, v) end
	for _, ch in rawget(self, "_children") do ch:Clone().Parent = c end
	return c
end
function InstMethods:SetNetworkOwner() end
function InstMethods:GetPropertyChangedSignal() return { Connect = function() return {} end } end
local signal = { Connect = function() return { Disconnect = function() end } end, Once = function() end, Wait = function() end }

local Instmt = {}
Instmt.__index = function(self, k)
	local props = rawget(self, "_props")
	if props[k] ~= nil then return props[k] end
	if InstMethods[k] then return InstMethods[k] end
	if k == "Position" and props.CFrame then return props.CFrame.Position end
	if k == "Touched" or k == "ChildAdded" or k == "Changed" or k == "Triggered" or k == "Destroying" or k == "AncestryChanged" then return signal end
	local kid = self:FindFirstChild(k)
	if kid then return kid end
	return nil
end
Instmt.__newindex = function(self, k, v)
	local props = rawget(self, "_props")
	if k == "Parent" then
		local old = props.Parent
		if old then
			local kids = rawget(old, "_children")
			for i, c in kids do
				if c == self then table.remove(kids, i) break end
			end
		end
		props.Parent = v
		if v then table.insert(rawget(v, "_children"), self) end
		return
	end
	if k == "Position" then
		local cur = props.CFrame or CF.new()
		props.CFrame = cf(v, cur.r)
		return
	end
	props[k] = v
end
function Instance.new(class)
	local self = setmetatable({ _props = { ClassName = class, Name = class }, _children = {}, _attrs = {} }, Instmt)
	if PART_CLASSES[class] then
		local p = rawget(self, "_props")
		p.Size = v3(4, 1, 2)
		p.CFrame = CF.new()
		p.Color = c3(0.64, 0.64, 0.64)
		p.Transparency = 0
		p.Anchored = false
		p.CanCollide = true
	end
	return self
end
rawset(_G, "Instance", Instance)

-- Terrain + services -------------------------------------------------------------------
local terrainOps = {}
local terrain = Instance.new("Terrain")
rawget(terrain, "_props").Name = "Terrain"
function terrain:FillBlock(cfr, size, mat) table.insert(terrainOps, { "block", cfr, size, mat.Name }) end
function terrain:FillBall(center, radius, mat) table.insert(terrainOps, { "ball", center, radius, mat.Name }) end
function terrain:FillCylinder(cfr, height, radius, mat) table.insert(terrainOps, { "cyl", cfr, height, radius, mat.Name }) end
function terrain:FillWedge(cfr, size, mat) table.insert(terrainOps, { "block", cfr, size, mat.Name }) end
function terrain:Clear() terrainOps = {} end
-- methods on the terrain object need to bypass the instance metatable
for _, k in { "FillBlock", "FillBall", "FillCylinder", "FillWedge", "Clear" } do
	InstMethods[k] = terrain[k]
end
workspace = Instance.new("Workspace")
rawget(workspace, "_props").Terrain = terrain
terrain.Parent = workspace

local services = {}
game = {
	GetService = function(_, name)
		if name == "Workspace" then return workspace end
		services[name] = services[name] or Instance.new(name)
		return services[name]
	end,
}
task = { wait = function() return 0 end, spawn = function(f, ...) f(...) end, delay = function() end, defer = function() end }
warn = function(...) print("WARN", ...) end
typeof = function(v)
	local mt = getmetatable(v)
	if mt == V3mt then return "Vector3" end
	if mt == CFmt then return "CFrame" end
	if mt == C3mt then return "Color3" end
	if mt == Instmt then return "Instance" end
	return type(v)
end

-- require / script mock ------------------------------------------------------------------
local function exists(path)
	local ok = pcall(readfile, path)
	return ok
end
local moduleCache = {}
local dirRef
local function moduleRef(path)
	return { __module = path }
end
dirRef = function(dir)
	return setmetatable({ __dir = dir }, {
		__index = function(t, k)
			if k == "WaitForChild" or k == "FindFirstChild" then
				return function(_, name) return t[name] end
			end
			if exists(dir .. "/" .. k .. ".lua") then return moduleRef(dir .. "/" .. k .. ".lua") end
			return dirRef(dir .. "/" .. k)
		end,
	})
end
local function parentDir(path)
	return path:match("^(.*)/[^/]+$")
end
local currentScript
function require(ref)
	local path = ref.__module
	if moduleCache[path] ~= nil then return moduleCache[path] end
	local fn = compile(readfile(path), "@" .. path)
	local prev = currentScript
	currentScript = { Parent = dirRef(parentDir(path)), Name = path }
	script = currentScript
	local result = fn()
	currentScript = prev
	script = prev
	moduleCache[path] = result
	return result
end
-- ReplicatedStorage.Shared
rawget(services, "x")
services.ReplicatedStorage = setmetatable({}, { __index = function(_, k)
	if k == "WaitForChild" or k == "FindFirstChild" then
		return function(_, name)
			if name == "Shared" then return dirRef(ROOT .. "/src/shared") end
			return nil
		end
	end
	return nil
end })

-- RUN ------------------------------------------------------------------------------------
local map = require(moduleRef(MAP))
local kit = map.Build()
local CarBuilder = require(moduleRef(ROOT .. "/src/shared/CarBuilder.lua"))
kit.Extra = {}
for _, spot in kit.VehicleSpots:GetChildren() do
	local car = CarBuilder.Build(spot:GetAttribute("Style"), spot:GetAttribute("Color"), true)
	car:PivotTo(spot.CFrame)
	table.insert(kit.Extra, car)
end

-- EXPORT ----------------------------------------------------------------------------------
local out = {}
local function num(x) return string.format("%.3f", x) end
local function col(c) return string.format("[%d,%d,%d]", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
local count = 0
local roots = { kit.Model }
if kit.Extra then
	for _, e in kit.Extra do table.insert(roots, e) end
end
for _, root in roots do
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.99 then
			local c = d.CFrame
			local r = c.r
			local shape = d.Shape and d.Shape.Name or "Block"
			if d.ClassName == "WedgePart" then shape = "Wedge" end
			if d.ClassName == "TrussPart" then shape = "Truss" end
			local mat = d.Material and d.Material.Name or "Plastic"
			local light = 0
			for _, ch in d:GetChildren() do
				if ch:IsA("Light") then light = 1 end
			end
			count += 1
			table.insert(out, string.format('{"s":"%s","z":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"c":%s,"m":"%s","t":%s,"l":%d}',
				shape, num(d.Size.X), num(d.Size.Y), num(d.Size.Z), num(c.p.X), num(c.p.Y), num(c.p.Z),
				num(r[1]), num(r[2]), num(r[3]), num(r[4]), num(r[5]), num(r[6]), num(r[7]), num(r[8]), num(r[9]),
				col(d.Color), mat, num(d.Transparency or 0), light))
		end
	end
end
local terr = {}
for _, op in terrainOps do
	if op[1] == "block" then
		local c, s = op[2], op[3]
		local r = c.r
		table.insert(terr, string.format('{"k":"block","p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"z":[%s,%s,%s],"m":"%s"}', num(c.p.X), num(c.p.Y), num(c.p.Z), num(r[1]), num(r[2]), num(r[3]), num(r[4]), num(r[5]), num(r[6]), num(r[7]), num(r[8]), num(r[9]), num(s.X), num(s.Y), num(s.Z), op[4]))
	elseif op[1] == "ball" then
		table.insert(terr, string.format('{"k":"ball","p":[%s,%s,%s],"rad":%s,"m":"%s"}', num(op[2].X), num(op[2].Y), num(op[2].Z), num(op[3]), op[4]))
	end
end
local spawns = {}
for _, s in kit.Spawns:GetChildren() do
	table.insert(spawns, string.format("[%s,%s,%s]", num(s.CFrame.p.X), num(s.CFrame.p.Y), num(s.CFrame.p.Z)))
end
local L = map.Lighting or {}
local lighting = string.format('{"clock":%s}', num(L.ClockTime or 14))
writefile(OUT, '{"name":"' .. map.Name .. '","lighting":' .. lighting .. ',"parts":[' .. table.concat(out, ",") .. '],"terrain":[' .. table.concat(terr, ",") .. '],"spawns":[' .. table.concat(spawns, ",") .. ']}')
print(map.Name .. ": " .. count .. " parts, " .. #terrainOps .. " terrain fills, " .. #spawns .. " spawns")
