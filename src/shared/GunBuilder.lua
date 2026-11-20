-- Builds detailed gun models out of parts, modeled after real-world firearm
-- designs (plus a few sci-fi ones). No uploaded meshes needed.
--
-- Conventions: the Handle (receiver/frame) sits at the origin, the barrel points
-- down -Z, +Y is up and +X is the right-hand (ejection) side.
-- Attachments on the Handle: Muzzle, Sight, GripPoint, ForePoint, Eject.
-- Moving parts carry an "Anim" attribute that WeaponController animates:
--   Slide / Bolt   - snap back on every shot
--   Pump           - racks back after a shot (pump shotguns)
--   BoltAction     - lifts & pulls back after a shot (bolt-action rifles)
--   Recoil         - recoiling barrel (Barrett)
--   Cylinder       - rotates one chamber per shot around the model's CylinderPivot
--   Barrels        - spins continuously while firing around BarrelsPivot (minigun)
--   Break          - tips open around BreakPivot while reloading (double-barrel)
--   Mag            - drops out & returns while reloading
--   Payload        - hidden while the weapon is empty (RPG warhead)
--   Trigger / Hammer - small movement while firing
--   Glow           - flashes bright on each shot (sci-fi)
local Weapons = require(script.Parent.Weapons)

local GunBuilder = {}

local rgb = Color3.fromRGB
local M = Enum.Material
local GOLD = rgb(255, 196, 40)
local STEEL = rgb(78, 81, 88)
local DARK = rgb(44, 46, 50)
local BLACK = rgb(30, 31, 34)
local POLY = rgb(58, 60, 64)
local WOOD = rgb(128, 78, 42)
local WOOD_DARK = rgb(96, 58, 32)
local TAN = rgb(176, 150, 108)
local OD = rgb(84, 92, 62)
local CHROME = rgb(196, 198, 204)
local BRASS = rgb(200, 160, 70)
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- cylinders run along X; rotate onto Z

local STYLES = {
	Striker = "M4", Vanguard = "AK", Viper = "MP5", Tempest = "PDW", Hornet = "FAMAS", Warden = "SCAR",
	Ranger = "SVD", Inferno = "M249", Longbow = "AWM", Titan = "Barrett", Brute = "Pump", Razor = "AA12",
	Duke = "Double", Reaper = "Minigun", Havoc = "RPG", Thumper = "M32", Railgun = "Railgun",
	Sidekick = "Pistol", Stinger = "Uzi", HandCannon = "Deagle", Judge = "Revolver", Arc = "Energy",
	RayGun = "RayGun", PlasmaRifle = "Plasma", VoidCannon = "Void",
}

function GunBuilder.Build(weaponId: string, golden: boolean?)
	local def = Weapons.Get(weaponId)
	local look = def.Look
	local style = STYLES[weaponId] or "M4"
	local L = look.Length
	local accent = look.Accent
	local accentMat = look.Neon and M.Neon or M.SmoothPlastic

	local model = Instance.new("Model")
	model.Name = weaponId
	local parts = {}

	local function make(name, size, cf, color, material, shape, anim)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(math.max(size.X, 0.03), math.max(size.Y, 0.03), math.max(size.Z, 0.03))
		p.CFrame = cf
		p.Color = color or STEEL
		p.Material = material or M.Metal
		if shape then
			p.Shape = shape
		end
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if anim then
			p:SetAttribute("Anim", anim)
		end
		p.Parent = model
		table.insert(parts, p)
		return p
	end
	local function at(x, y, z)
		return CFrame.new(x, y, z)
	end
	local function box(name, size, cf, color, material, anim)
		return make(name, size, cf, color, material, nil, anim)
	end
	-- cylinder along the gun's Z axis
	local function cyl(name, length, d, cf, color, material, anim)
		return make(name, Vector3.new(length, d, d), cf * ALONG_Z, color, material, Enum.PartType.Cylinder, anim)
	end
	-- cylinder along the gun's X axis (sideways drums, knobs)
	local function cylX(name, length, d, cf, color, material, anim)
		return make(name, Vector3.new(length, d, d), cf, color, material, Enum.PartType.Cylinder, anim)
	end
	local function ball(name, d, cf, color, material, anim)
		return make(name, Vector3.new(d, d, d), cf, color, material, Enum.PartType.Ball, anim)
	end

	local handle = make("Handle", Vector3.new(0.3, 0.38, L * 0.34), at(0, 0, 0), STEEL, M.Metal)
	table.remove(parts) -- the handle is not welded to itself
	model.PrimaryPart = handle

	local info = {
		Grip = Vector3.new(0, -0.45, 0.3), Fore = Vector3.new(0, -0.2, -0.9),
		Muzzle = Vector3.new(0, 0.05, -L / 2 - look.Barrel), Sight = 0.42,
		Eject = Vector3.new(0.17, 0.06, 0), Shell = "Brass",
	}

	-------------------------------------------------------------- shared parts
	local function rail(z0, z1, y, x, sideways)
		local len = z1 - z0
		if sideways then
			box("SideRail", Vector3.new(0.05, 0.12, len), at(x, y, (z0 + z1) / 2), BLACK)
			return
		end
		box("Rail", Vector3.new(0.2, 0.06, len), at(x or 0, y, (z0 + z1) / 2), BLACK)
		local count = math.min(14, math.floor(len / 0.11))
		for i = 0, count - 1 do
			box("RailSlot", Vector3.new(0.23, 0.04, 0.04), at(x or 0, y + 0.04, z0 + 0.06 + i * (len / count)), BLACK)
		end
	end
	local function barrel(z0, length, d, y)
		cyl("Barrel", length, d, at(0, y, z0 - length / 2), DARK)
		info.Muzzle = Vector3.new(0, y, z0 - length)
	end
	local function birdcage(d)
		local z, y = info.Muzzle.Z, info.Muzzle.Y
		cyl("FlashHider", 0.26, d, at(0, y, z - 0.13), BLACK)
		for i = 1, 4 do
			local a = i / 4 * math.pi * 2
			box("FlashSlot", Vector3.new(0.03, 0.03, 0.18), at(math.cos(a) * d / 2, y + math.sin(a) * d / 2, z - 0.15), rgb(15, 15, 16))
		end
		info.Muzzle = Vector3.new(0, y, z - 0.26)
	end
	local function brake(d, len, wide)
		local z, y = info.Muzzle.Z, info.Muzzle.Y
		if wide then
			box("Brake", Vector3.new(d * 1.6, d, len), at(0, y, z - len / 2), BLACK)
			for i = 1, 2 do
				box("BrakePort", Vector3.new(d * 1.62, d * 0.55, len * 0.18), at(0, y, z - len * (i / 3)), rgb(12, 12, 12))
			end
		else
			cyl("Brake", len, d, at(0, y, z - len / 2), BLACK)
			for i = 1, 3 do
				box("BrakePort", Vector3.new(d + 0.03, 0.04, 0.05), at(0, y, z - len * (i / 4)), rgb(12, 12, 12))
			end
		end
		info.Muzzle = Vector3.new(0, y, z - len)
	end
	local function grip(z, angle, color, material)
		local a = math.rad(angle or -18)
		box("Grip", Vector3.new(0.22, 0.6, 0.3), at(0, -0.46, z) * CFrame.Angles(a, 0, 0), color or POLY, material or M.SmoothPlastic)
		box("GripBack", Vector3.new(0.2, 0.42, 0.06), at(0, -0.44, z + 0.17) * CFrame.Angles(a, 0, 0), color or POLY, material or M.SmoothPlastic)
		box("GripCap", Vector3.new(0.23, 0.05, 0.32), at(0, -0.77, z + 0.1) * CFrame.Angles(a, 0, 0), BLACK)
		info.Grip = Vector3.new(0, -0.46, z)
	end
	local function trigger(z)
		box("TriggerGuard", Vector3.new(0.05, 0.05, 0.45), at(0, -0.37, z - 0.2), BLACK)
		box("TriggerGuardFront", Vector3.new(0.05, 0.17, 0.05), at(0, -0.29, z - 0.42), BLACK)
		box("Trigger", Vector3.new(0.04, 0.16, 0.05), at(0, -0.27, z - 0.18) * CFrame.Angles(math.rad(14), 0, 0), CHROME, M.Metal, "Trigger")
	end
	local function ejectionPort(z, y)
		y = y or 0.06
		box("EjectionPort", Vector3.new(0.03, 0.12, 0.3), at(0.155, y, z), rgb(18, 18, 20))
		box("BoltCarrier", Vector3.new(0.03, 0.08, 0.24), at(0.165, y, z), CHROME, M.Metal, "Bolt")
		info.Eject = Vector3.new(0.18, y, z)
	end
	local function stanag(z, curve, steel)
		local c = steel and rgb(70, 70, 66) or POLY
		box("Magwell", Vector3.new(0.27, 0.2, 0.42), at(0, -0.29, z), STEEL)
		box("Mag", Vector3.new(0.19, 0.48, 0.33), at(0, -0.56, z - 0.04) * CFrame.Angles(math.rad(8 * curve), 0, 0), c, M.Metal, "Mag")
		box("Mag2", Vector3.new(0.19, 0.44, 0.32), at(0, -0.93, z - 0.04 - 0.1 * curve) * CFrame.Angles(math.rad(22 * curve), 0, 0), c, M.Metal, "Mag")
		if steel then
			for i = 1, 3 do
				box("MagRib", Vector3.new(0.2, 0.04, 0.24), at(0, -0.5 - i * 0.18, z - 0.02 - i * 0.04 * curve) * CFrame.Angles(math.rad(14 * curve), 0, 0), rgb(50, 50, 48), M.Metal, "Mag")
			end
		end
		box("MagBase", Vector3.new(0.22, 0.05, 0.35), at(0, -1.15, z - 0.06 - 0.22 * curve) * CFrame.Angles(math.rad(26 * curve), 0, 0), BLACK, M.Metal, "Mag")
	end
	local function straightMag(z, length, width, color)
		box("Magwell", Vector3.new(0.27, 0.2, 0.42), at(0, -0.29, z), STEEL)
		box("Mag", Vector3.new(width or 0.2, length, 0.34), at(0, -0.32 - length / 2, z - 0.03) * CFrame.Angles(math.rad(5), 0, 0), color or POLY, M.SmoothPlastic, "Mag")
		box("MagBase", Vector3.new((width or 0.2) + 0.03, 0.05, 0.36), at(0, -0.34 - length, z - 0.06) * CFrame.Angles(math.rad(5), 0, 0), BLACK, M.Metal, "Mag")
	end
	local function m4Stock(zRear, color)
		cyl("BufferTube", 0.62, 0.17, at(0, 0.02, zRear + 0.31), BLACK)
		box("Stock", Vector3.new(0.23, 0.36, 0.55), at(0, -0.05, zRear + 0.72), color or POLY, M.SmoothPlastic)
		box("StockTop", Vector3.new(0.21, 0.14, 0.5), at(0, 0.15, zRear + 0.7), color or POLY, M.SmoothPlastic)
		box("StockLatch", Vector3.new(0.1, 0.12, 0.2), at(0, -0.24, zRear + 0.58), BLACK)
		box("ButtPad", Vector3.new(0.25, 0.5, 0.07), at(0, -0.03, zRear + 1.01), BLACK, M.Rubber)
		box("SlingLoop", Vector3.new(0.05, 0.12, 0.12), at(0, -0.27, zRear + 0.95), BLACK)
	end
	local function fixedStock(zRear, length, color, material)
		box("Stock", Vector3.new(0.24, 0.34, length), at(0, -0.06, zRear + length / 2) * CFrame.Angles(math.rad(5), 0, 0), color, material)
		box("StockToe", Vector3.new(0.23, 0.3, length * 0.55), at(0, -0.27, zRear + length * 0.7) * CFrame.Angles(math.rad(-8), 0, 0), color, material)
		box("ButtPad", Vector3.new(0.26, 0.6, 0.07), at(0, -0.16, zRear + length + 0.02), BLACK, M.Rubber)
	end
	local function optic(kind, z, y)
		if kind == "RedDot" then
			box("OpticMount", Vector3.new(0.17, 0.08, 0.26), at(0, y + 0.08, z), BLACK)
			cyl("Optic", 0.34, 0.26, at(0, y + 0.27, z), BLACK)
			cylX("OpticKnob", 0.08, 0.1, at(0.15, y + 0.27, z), BLACK)
			local lens = cyl("Lens", 0.02, 0.2, at(0, y + 0.27, z - 0.17), rgb(120, 200, 255), M.Glass)
			lens.Transparency = 0.4
			box("Dot", Vector3.new(0.03, 0.03, 0.02), at(0, y + 0.27, z + 0.1), rgb(255, 40, 40), M.Neon)
			info.Sight = y + 0.27
		elseif kind == "Holo" then
			box("HoloBase", Vector3.new(0.24, 0.1, 0.44), at(0, y + 0.09, z), BLACK)
			box("HoloHood", Vector3.new(0.26, 0.04, 0.34), at(0, y + 0.43, z - 0.04), BLACK)
			box("HoloSideL", Vector3.new(0.03, 0.32, 0.3), at(-0.12, y + 0.27, z - 0.04), BLACK)
			box("HoloSideR", Vector3.new(0.03, 0.32, 0.3), at(0.12, y + 0.27, z - 0.04), BLACK)
			box("HoloButtons", Vector3.new(0.18, 0.06, 0.08), at(0, y + 0.16, z + 0.2), DARK)
			local g = box("HoloGlass", Vector3.new(0.2, 0.22, 0.02), at(0, y + 0.27, z - 0.16), rgb(150, 220, 255), M.Glass)
			g.Transparency = 0.5
			box("Reticle", Vector3.new(0.03, 0.03, 0.01), at(0, y + 0.27, z - 0.15), rgb(255, 60, 60), M.Neon)
			info.Sight = y + 0.27
		elseif kind == "PSO" then -- side-mounted scope (SVD)
			box("PSOMount", Vector3.new(0.12, 0.3, 0.5), at(-0.2, y - 0.05, z), BLACK)
			local sy = y + 0.2
			cyl("ScopeTube", 0.9, 0.17, at(-0.12, sy, z), BLACK)
			cyl("ScopeBell", 0.3, 0.26, at(-0.12, sy, z - 0.55), BLACK)
			cyl("EyeCup", 0.25, 0.24, at(-0.12, sy, z + 0.55), rgb(25, 25, 25), M.Rubber)
			box("Turret", Vector3.new(0.12, 0.12, 0.12), at(-0.12, sy + 0.13, z), BLACK)
			info.Sight = sy
		else -- "Scope"
			for _, dz in { -0.22, 0.22 } do
				box("ScopeRing", Vector3.new(0.08, 0.2, 0.08), at(0, y + 0.12, z + dz), BLACK)
			end
			local sy = y + 0.3
			cyl("ScopeTube", 0.95, 0.18, at(0, sy, z), BLACK)
			cyl("ScopeBellFront", 0.32, 0.3, at(0, sy, z - 0.6), BLACK)
			cyl("ScopeBellRear", 0.22, 0.26, at(0, sy, z + 0.55), BLACK)
			local lens = cyl("ScopeLens", 0.02, 0.26, at(0, sy, z - 0.77), rgb(80, 140, 200), M.Glass)
			lens.Transparency = 0.2
			box("TurretTop", Vector3.new(0.14, 0.12, 0.14), at(0, sy + 0.13, z), BLACK)
			box("TurretSide", Vector3.new(0.12, 0.14, 0.14), at(0.13, sy, z), BLACK)
			cylX("ParallaxKnob", 0.08, 0.12, at(-0.13, sy, z), BLACK)
			box("ScopeAccent", Vector3.new(0.19, 0.02, 0.04), at(0, sy, z - 0.42), accent, accentMat)
			info.Sight = sy
		end
	end
	local function bipod(z, y, folded)
		box("BipodMount", Vector3.new(0.16, 0.1, 0.16), at(0, y - 0.07, z), BLACK)
		for _, sx in { -1, 1 } do
			if folded then
				box("BipodLeg", Vector3.new(0.05, 0.05, 0.6), at(sx * 0.1, y - 0.12, z + 0.32), BLACK)
			else
				box("BipodLeg", Vector3.new(0.05, 0.55, 0.05), at(sx * 0.1, y - 0.36, z + 0.1) * CFrame.Angles(math.rad(-55), 0, math.rad(sx * 8)), BLACK)
				box("BipodFoot", Vector3.new(0.08, 0.05, 0.1), at(sx * 0.13, y - 0.55, z + 0.32), rgb(20, 20, 20), M.Rubber)
			end
		end
	end
	local function frontSightTower(z, y)
		box("FSBase", Vector3.new(0.16, 0.12, 0.14), at(0, y, z), BLACK)
		box("FSPostL", Vector3.new(0.03, 0.22, 0.06), at(-0.06, y + 0.15, z), BLACK)
		box("FSPostR", Vector3.new(0.03, 0.22, 0.06), at(0.06, y + 0.15, z), BLACK)
		box("FSPost", Vector3.new(0.025, 0.16, 0.025), at(0, y + 0.14, z), accent, accentMat)
	end

	-------------------------------------------------------------- styles
	local h = L * 0.17 -- half receiver length
	if style == "M4" then
		handle.Size = Vector3.new(0.3, 0.38, L * 0.34)
		box("LowerReceiver", Vector3.new(0.28, 0.2, L * 0.31), at(0, -0.26, 0.02), STEEL)
		box("MagRelease", Vector3.new(0.05, 0.06, 0.06), at(0.16, -0.24, -0.05), BLACK)
		box("Selector", Vector3.new(0.04, 0.05, 0.14), at(-0.16, -0.2, 0.22), accent, accentMat)
		box("BoltCatch", Vector3.new(0.04, 0.12, 0.08), at(-0.16, -0.16, -0.08), BLACK)
		box("ForwardAssist", Vector3.new(0.09, 0.09, 0.12), at(0.17, 0.1, h - 0.12), BLACK)
		box("DustCover", Vector3.new(0.02, 0.12, 0.3), at(0.2, -0.02, -0.02) * CFrame.Angles(0, 0, math.rad(-40)), STEEL)
		box("ChargingHandle", Vector3.new(0.24, 0.05, 0.12), at(0, 0.21, h - 0.04), BLACK)
		local hg = L * 0.32
		box("Handguard", Vector3.new(0.34, 0.34, hg), at(0, 0.01, -h - hg / 2), DARK, M.Metal)
		for i = 1, 5 do
			for _, sx in { -1, 1 } do
				box("MLok", Vector3.new(0.02, 0.07, 0.14), at(sx * 0.17, 0.0, -h - i * hg / 6), rgb(15, 15, 16))
			end
		end
		rail(-h - hg, h, 0.21)
		barrel(-h - hg, look.Barrel + 0.05, 0.12, 0.03)
		box("GasBlock", Vector3.new(0.15, 0.14, 0.1), at(0, 0.06, -h - hg - 0.05), BLACK)
		frontSightTower(-h - hg + 0.08, 0.26)
		birdcage(0.16)
		box("RearSight", Vector3.new(0.18, 0.18, 0.08), at(0, 0.32, h - 0.12), BLACK)
		grip(L * 0.08)
		trigger(L * 0.08)
		ejectionPort(-0.02)
		stanag(-L * 0.06, 1)
		m4Stock(h)
		optic("RedDot", -0.05, 0.21)
		info.Fore = Vector3.new(0, -0.18, -h - hg * 0.55)
	elseif style == "AK" then
		handle.Size = Vector3.new(0.28, 0.34, L * 0.36)
		box("DustCover", Vector3.new(0.26, 0.12, L * 0.34), at(0, 0.21, 0.02), STEEL)
		for i = 1, 3 do
			box("CoverRib", Vector3.new(0.27, 0.13, 0.04), at(0, 0.21, -0.1 + i * 0.14), DARK)
		end
		box("RearSightBlock", Vector3.new(0.2, 0.14, 0.24), at(0, 0.24, -h + 0.05), STEEL)
		box("RearSightLeaf", Vector3.new(0.12, 0.04, 0.3), at(0, 0.33, -h + 0.05), BLACK)
		box("Selector", Vector3.new(0.03, 0.08, 0.42), at(0.15, 0.04, 0.05), STEEL)
		box("ChargingHandle", Vector3.new(0.16, 0.06, 0.08), at(0.2, 0.08, -0.15), CHROME, M.Metal, "Bolt")
		ejectionPort(-0.05, 0.08)
		-- wooden furniture
		local hg = L * 0.26
		box("LowerHandguard", Vector3.new(0.32, 0.26, hg), at(0, -0.06, -h - hg / 2), WOOD, M.Wood)
		for i = 1, 3 do
			box("HandguardGroove", Vector3.new(0.33, 0.03, hg * 0.8), at(0, -0.06 + (i - 2) * 0.07, -h - hg / 2), WOOD_DARK, M.Wood)
		end
		box("UpperHandguard", Vector3.new(0.24, 0.14, hg * 0.85), at(0, 0.17, -h - hg * 0.45), WOOD, M.Wood)
		cyl("GasTube", hg * 0.3, 0.12, at(0, 0.17, -h - hg * 0.95), STEEL)
		barrel(-h - hg, look.Barrel + 0.35, 0.11, 0.03)
		box("GasBlock", Vector3.new(0.14, 0.24, 0.14), at(0, 0.09, -h - hg - 0.05), STEEL)
		box("FrontSightBase", Vector3.new(0.12, 0.2, 0.12), at(0, 0.12, info.Muzzle.Z + 0.12), STEEL)
		box("FrontSightHoodL", Vector3.new(0.03, 0.16, 0.1), at(-0.06, 0.26, info.Muzzle.Z + 0.12), STEEL)
		box("FrontSightHoodR", Vector3.new(0.03, 0.16, 0.1), at(0.06, 0.26, info.Muzzle.Z + 0.12), STEEL)
		box("FrontSightPost", Vector3.new(0.025, 0.12, 0.025), at(0, 0.26, info.Muzzle.Z + 0.12), BLACK)
		box("BayonetLug", Vector3.new(0.06, 0.08, 0.14), at(0, -0.06, info.Muzzle.Z + 0.25), STEEL)
		-- slant brake
		box("SlantBrake", Vector3.new(0.15, 0.15, 0.24), at(0, 0.03, info.Muzzle.Z - 0.12) * CFrame.Angles(math.rad(-12), 0, 0), STEEL)
		info.Muzzle = Vector3.new(0, 0.03, info.Muzzle.Z - 0.24)
		grip(L * 0.07, -20, rgb(70, 46, 30), M.Wood)
		trigger(L * 0.07)
		stanag(-L * 0.08, 1.6, true)
		box("Stock", Vector3.new(0.24, 0.36, 1.0), at(0, -0.12, h + 0.5) * CFrame.Angles(math.rad(9), 0, 0), WOOD, M.Wood)
		box("StockComb", Vector3.new(0.22, 0.14, 0.7), at(0, 0.06, h + 0.45) * CFrame.Angles(math.rad(6), 0, 0), WOOD, M.Wood)
		box("ButtPlate", Vector3.new(0.25, 0.48, 0.06), at(0, -0.26, h + 1.0), STEEL)
		info.Sight = 0.33
		info.Fore = Vector3.new(0, -0.2, -h - hg * 0.5)
	elseif style == "MP5" then
		handle.Size = Vector3.new(0.26, 0.4, L * 0.38)
		box("ReceiverTop", Vector3.new(0.2, 0.08, L * 0.38), at(0, 0.23, 0), STEEL)
		box("Trigger Group", Vector3.new(0.24, 0.2, L * 0.3), at(0, -0.26, 0.06), POLY, M.SmoothPlastic)
		local hgLen = L * 0.22
		box("Handguard", Vector3.new(0.3, 0.3, hgLen), at(0, -0.06, -h - hgLen / 2), POLY, M.SmoothPlastic)
		box("HandguardTip", Vector3.new(0.24, 0.24, 0.12), at(0, -0.04, -h - hgLen - 0.04), POLY, M.SmoothPlastic)
		cyl("CockingTube", hgLen + 0.25, 0.14, at(0, 0.16, -h - hgLen / 2 - 0.1), STEEL)
		box("CockingHandle", Vector3.new(0.18, 0.05, 0.05), at(-0.12, 0.16, -h - 0.12) * CFrame.Angles(0, math.rad(20), 0), BLACK, M.Metal, "Bolt")
		barrel(-h - hgLen, look.Barrel + 0.15, 0.11, 0.0)
		for i = 1, 3 do
			box("BarrelLug", Vector3.new(0.18, 0.04, 0.03), at(0, 0, info.Muzzle.Z + 0.04 + i * 0.05), STEEL)
		end
		cyl("FrontSightRing", 0.06, 0.22, at(0, 0.3, -h - hgLen - 0.05), STEEL)
		box("FrontSightPost", Vector3.new(0.02, 0.1, 0.02), at(0, 0.28, -h - hgLen - 0.05), BLACK)
		cylX("DrumSight", 0.14, 0.18, at(0, 0.33, h - 0.1), STEEL)
		ejectionPort(-0.08, 0.1)
		grip(L * 0.14)
		trigger(L * 0.14)
		-- thin curved mag
		box("Magwell", Vector3.new(0.22, 0.16, 0.3), at(0, -0.3, -L * 0.1), STEEL)
		box("Mag", Vector3.new(0.14, 0.5, 0.24), at(0, -0.58, -L * 0.1 - 0.06) * CFrame.Angles(math.rad(14), 0, 0), BLACK, M.Metal, "Mag")
		box("Mag2", Vector3.new(0.14, 0.3, 0.23), at(0, -0.9, -L * 0.1 - 0.17) * CFrame.Angles(math.rad(26), 0, 0), BLACK, M.Metal, "Mag")
		-- retractable stock
		for _, sx in { -0.09, 0.09 } do
			box("StockRod", Vector3.new(0.04, 0.04, 0.75), at(sx, 0.06, h + 0.37), STEEL)
		end
		box("ButtPlate", Vector3.new(0.24, 0.42, 0.08), at(0, -0.06, h + 0.76), BLACK, M.Rubber)
		info.Sight = 0.33
		info.Fore = Vector3.new(0, -0.2, -h - hgLen * 0.5)
	elseif style == "PDW" then
		handle.Size = Vector3.new(0.32, 0.46, L * 0.6)
		handle.Color = look.Body
		handle.Material = M.SmoothPlastic
		box("Shell", Vector3.new(0.3, 0.3, L * 0.55), at(0, -0.3, 0.05), look.Body, M.SmoothPlastic)
		-- thumbhole grip
		box("ThumbholeFront", Vector3.new(0.28, 0.5, 0.12), at(0, -0.62, -L * 0.12), look.Body, M.SmoothPlastic)
		box("Grip", Vector3.new(0.24, 0.5, 0.22), at(0, -0.62, L * 0.02), POLY, M.SmoothPlastic)
		box("ThumbholeBottom", Vector3.new(0.28, 0.08, 0.5), at(0, -0.88, -L * 0.04), look.Body, M.SmoothPlastic)
		info.Grip = Vector3.new(0, -0.62, L * 0.02)
		box("Trigger", Vector3.new(0.04, 0.12, 0.04), at(0, -0.5, -L * 0.07), BLACK, M.Metal, "Trigger")
		-- translucent top magazine with rounds
		local mag = box("TopMag", Vector3.new(0.28, 0.12, L * 0.55), at(0, 0.29, 0.02), rgb(160, 160, 150), M.Glass, "Mag")
		mag.Transparency = 0.4
		for i = 1, 8 do
			box("Round", Vector3.new(0.08, 0.06, 0.04), at((i % 2 == 0) and 0.05 or -0.05, 0.29, -L * 0.2 + i * 0.07), BRASS, M.Metal, "Mag")
		end
		cyl("SightRing", 0.08, 0.24, at(0, 0.48, -0.1), BLACK)
		box("SightBase", Vector3.new(0.14, 0.12, 0.3), at(0, 0.4, -0.1), BLACK)
		barrel(-L * 0.3, look.Barrel + 0.2, 0.1, -0.05)
		birdcage(0.14)
		box("ChargingHandle", Vector3.new(0.18, 0.05, 0.06), at(0.17, 0.0, -L * 0.22), BLACK, M.Metal, "Bolt")
		box("AccentStripe", Vector3.new(0.33, 0.04, L * 0.4), at(0, -0.12, 0), accent, accentMat)
		info.Eject = Vector3.new(0, -0.9, 0.1)
		info.Sight = 0.48
		info.Fore = Vector3.new(0, -0.62, -L * 0.12)
	elseif style == "FAMAS" then
		handle.Size = Vector3.new(0.3, 0.42, L * 0.5)
		handle.Color = look.Body
		box("Body", Vector3.new(0.3, 0.3, L * 0.62), at(0, -0.2, 0.25), look.Body, M.SmoothPlastic)
		-- full-length carry handle
		box("CarryHandle", Vector3.new(0.12, 0.08, L * 0.6), at(0, 0.5, 0.05), look.Body, M.SmoothPlastic)
		for _, dz in { -L * 0.28, L * 0.32 } do
			box("HandlePost", Vector3.new(0.12, 0.3, 0.14), at(0, 0.34, dz), look.Body, M.SmoothPlastic)
		end
		box("ChargingHandle", Vector3.new(0.14, 0.06, 0.08), at(0, 0.3, -0.05), BLACK, M.Metal, "Bolt")
		barrel(-L * 0.25, look.Barrel + 0.35, 0.11, 0.0)
		birdcage(0.15)
		bipod(-L * 0.3, -0.1, true)
		box("Grip", Vector3.new(0.22, 0.5, 0.26), at(0, -0.56, -L * 0.18) * CFrame.Angles(math.rad(-12), 0, 0), POLY, M.SmoothPlastic)
		box("HandGuard", Vector3.new(0.06, 0.36, 0.4), at(0, -0.48, -L * 0.28), look.Body, M.SmoothPlastic)
		info.Grip = Vector3.new(0, -0.56, -L * 0.18)
		box("Trigger", Vector3.new(0.04, 0.14, 0.04), at(0, -0.4, -L * 0.22), BLACK, M.Metal, "Trigger")
		straightMag(L * 0.12, 0.42, 0.18, BLACK)
		box("CheekRest", Vector3.new(0.2, 0.1, 0.5), at(0, 0.0, L * 0.45), BLACK, M.Rubber)
		box("ButtPad", Vector3.new(0.3, 0.5, 0.06), at(0, -0.18, L * 0.56), BLACK, M.Rubber)
		ejectionPort(L * 0.15, -0.1)
		box("Accent", Vector3.new(0.31, 0.03, L * 0.3), at(0, -0.05, 0.1), accent, accentMat)
		info.Sight = 0.5
		info.Fore = Vector3.new(0, -0.3, -L * 0.3)
	elseif style == "SCAR" then
		handle.Size = Vector3.new(0.32, 0.36, L * 0.4)
		handle.Color = TAN
		box("Lower", Vector3.new(0.28, 0.22, L * 0.28), at(0, -0.26, 0.05), BLACK)
		local front = L * 0.22
		box("UpperFront", Vector3.new(0.32, 0.3, front), at(0, 0.03, -L * 0.2 - front / 2), TAN, M.SmoothPlastic)
		rail(-L * 0.2 - front, L * 0.2, 0.2)
		rail(-L * 0.2 - front + 0.05, -L * 0.2 - 0.05, -0.02, 0.17, true)
		rail(-L * 0.2 - front + 0.05, -L * 0.2 - 0.05, -0.02, -0.17, true)
		box("ChargingHandle", Vector3.new(0.18, 0.08, 0.1), at(-0.2, 0.08, -L * 0.12), BLACK, M.Metal, "Bolt")
		barrel(-L * 0.2 - front, look.Barrel + 0.2, 0.13, 0.03)
		birdcage(0.18)
		grip(L * 0.1, -16, BLACK)
		trigger(L * 0.1)
		ejectionPort(-0.05)
		straightMag(-L * 0.05, 0.48, 0.22, BLACK)
		-- folding stock
		box("StockHinge", Vector3.new(0.18, 0.2, 0.12), at(0, 0.0, L * 0.2 + 0.06), BLACK)
		box("Stock", Vector3.new(0.22, 0.36, 0.75), at(0, -0.06, L * 0.2 + 0.5), TAN, M.SmoothPlastic)
		box("StockCheek", Vector3.new(0.2, 0.12, 0.45), at(0, 0.18, L * 0.2 + 0.5), BLACK)
		box("ButtPad", Vector3.new(0.24, 0.48, 0.07), at(0, -0.06, L * 0.2 + 0.9), BLACK, M.Rubber)
		optic("Holo", -0.05, 0.2)
		info.Fore = Vector3.new(0, -0.18, -L * 0.2 - front * 0.5)
	elseif style == "SVD" then
		handle.Size = Vector3.new(0.28, 0.34, L * 0.3)
		box("DustCover", Vector3.new(0.26, 0.1, L * 0.3), at(0, 0.21, 0), STEEL)
		box("ChargingHandle", Vector3.new(0.16, 0.06, 0.08), at(0.19, 0.08, -0.1), CHROME, M.Metal, "Bolt")
		ejectionPort(-0.05, 0.08)
		local hg = L * 0.24
		box("Handguard", Vector3.new(0.3, 0.3, hg), at(0, 0.0, -L * 0.15 - hg / 2), WOOD, M.Wood)
		for i = 1, 4 do
			box("Vent", Vector3.new(0.31, 0.04, 0.1), at(0, 0.05, -L * 0.15 - i * hg / 5), WOOD_DARK, M.Wood)
		end
		barrel(-L * 0.15 - hg, look.Barrel + L * 0.25, 0.1, 0.03)
		box("FrontSight", Vector3.new(0.06, 0.16, 0.08), at(0, 0.13, info.Muzzle.Z + 0.25), STEEL)
		brake(0.15, 0.3)
		-- skeleton thumbhole stock
		local zr = L * 0.15
		box("StockTop", Vector3.new(0.22, 0.14, 0.85), at(0, 0.08, zr + 0.42), WOOD, M.Wood)
		box("StockBottom", Vector3.new(0.22, 0.12, 0.6), at(0, -0.48, zr + 0.6) * CFrame.Angles(math.rad(10), 0, 0), WOOD, M.Wood)
		box("StockButt", Vector3.new(0.24, 0.6, 0.18), at(0, -0.2, zr + 0.85), WOOD, M.Wood)
		box("CheekPad", Vector3.new(0.2, 0.1, 0.35), at(0, 0.2, zr + 0.5), rgb(50, 40, 30), M.Fabric)
		box("Grip", Vector3.new(0.2, 0.5, 0.22), at(0, -0.3, zr + 0.18) * CFrame.Angles(math.rad(-20), 0, 0), WOOD, M.Wood)
		info.Grip = Vector3.new(0, -0.3, zr + 0.18)
		trigger(zr + 0.05)
		straightMag(-0.05, 0.4, 0.19, STEEL)
		optic("PSO", -0.05, 0.21)
		info.Fore = Vector3.new(0, -0.15, -L * 0.15 - hg * 0.5)
	elseif style == "M249" then
		handle.Size = Vector3.new(0.34, 0.4, L * 0.32)
		box("FeedCover", Vector3.new(0.32, 0.12, L * 0.28), at(0, 0.25, -0.02), BLACK)
		box("FeedCoverLatch", Vector3.new(0.16, 0.06, 0.08), at(0, 0.32, h - 0.08), BLACK)
		box("Lower", Vector3.new(0.3, 0.2, L * 0.26), at(0, -0.28, 0.04), BLACK)
		box("CarryHandle", Vector3.new(0.08, 0.06, 0.55), at(0.0, 0.62, -h - 0.2), BLACK)
		for _, dz in { -0.25, 0.22 } do
			box("CarryPost", Vector3.new(0.06, 0.28, 0.06), at(0, 0.48, -h - 0.2 + dz), BLACK)
		end
		local hg = L * 0.2
		box("Handguard", Vector3.new(0.34, 0.24, hg), at(0, -0.1, -h - hg / 2), POLY, M.SmoothPlastic)
		barrel(-h, look.Barrel + L * 0.32, 0.15, 0.06)
		box("HeatShield", Vector3.new(0.24, 0.06, L * 0.22), at(0, 0.18, -h - L * 0.12), BLACK)
		box("GasBlock", Vector3.new(0.18, 0.18, 0.12), at(0, 0.0, -h - hg - 0.12), BLACK)
		frontSightTower(info.Muzzle.Z + 0.2, 0.15)
		birdcage(0.2)
		bipod(-h - hg - 0.2, -0.05)
		box("ChargingHandle", Vector3.new(0.16, 0.08, 0.1), at(0.2, -0.02, -0.05), BLACK, M.Metal, "Bolt")
		info.Eject = Vector3.new(0, -0.45, 0.0)
		box("AmmoBag", Vector3.new(0.36, 0.5, 0.55), at(-0.05, -0.62, -0.12), OD, M.Fabric, "Mag")
		box("AmmoBagFlap", Vector3.new(0.38, 0.1, 0.57), at(-0.05, -0.36, -0.12), rgb(70, 78, 52), M.Fabric, "Mag")
		box("Belt", Vector3.new(0.3, 0.06, 0.14), at(-0.25, -0.05, -0.05), BRASS, M.Metal)
		grip(L * 0.07)
		trigger(L * 0.07)
		-- skeletal stock
		box("StockTop", Vector3.new(0.2, 0.1, 0.8), at(0, 0.04, h + 0.4), BLACK)
		box("StockBottom", Vector3.new(0.2, 0.1, 0.7), at(0, -0.3, h + 0.45) * CFrame.Angles(math.rad(-6), 0, 0), BLACK)
		box("ButtPad", Vector3.new(0.24, 0.5, 0.08), at(0, -0.12, h + 0.82), BLACK, M.Rubber)
		info.Sight = 0.42
		info.Fore = Vector3.new(0, -0.24, -h - hg * 0.5)
	elseif style == "AWM" then
		handle.Size = Vector3.new(0.28, 0.32, L * 0.3)
		box("Chassis", Vector3.new(0.3, 0.26, L * 0.62), at(0, -0.16, -L * 0.06), look.Body, M.SmoothPlastic)
		cyl("BoltBody", L * 0.24, 0.14, at(0, 0.16, 0.02), CHROME, M.Metal, "BoltAction")
		box("BoltHandle", Vector3.new(0.3, 0.05, 0.05), at(0.18, 0.12, h - 0.15), CHROME, M.Metal, "BoltAction")
		ball("BoltKnob", 0.13, at(0.35, 0.08, h - 0.15), BLACK, M.Metal, "BoltAction")
		info.Eject = Vector3.new(0.18, 0.16, 0.0)
		barrel(-h, look.Barrel + L * 0.35, 0.13, 0.04)
		for i = 1, 4 do
			box("Flute", Vector3.new(0.14, 0.02, L * 0.25), at(0, 0.04 + ((i % 2) * 2 - 1) * 0.06, -h - L * 0.2), DARK)
		end
		brake(0.2, 0.3)
		-- thumbhole stock (classic precision rifle shape)
		local zr = h
		box("StockTop", Vector3.new(0.26, 0.16, 0.9), at(0, 0.0, zr + 0.45), look.Body, M.SmoothPlastic)
		box("CheekRiser", Vector3.new(0.22, 0.12, 0.45), at(0, 0.14, zr + 0.5), look.Body, M.SmoothPlastic)
		box("StockButt", Vector3.new(0.26, 0.62, 0.2), at(0, -0.25, zr + 0.82), look.Body, M.SmoothPlastic)
		box("StockBottom", Vector3.new(0.24, 0.12, 0.5), at(0, -0.5, zr + 0.55), look.Body, M.SmoothPlastic)
		box("Grip", Vector3.new(0.22, 0.48, 0.2), at(0, -0.36, zr + 0.22) * CFrame.Angles(math.rad(-6), 0, 0), look.Body, M.SmoothPlastic)
		box("ButtPad", Vector3.new(0.27, 0.66, 0.06), at(0, -0.24, zr + 0.93), BLACK, M.Rubber)
		box("Monopod", Vector3.new(0.06, 0.25, 0.06), at(0, -0.6, zr + 0.72), BLACK)
		info.Grip = Vector3.new(0, -0.36, zr + 0.22)
		trigger(zr + 0.1)
		straightMag(-0.02, 0.26, 0.2, BLACK)
		rail(-h, h, 0.22)
		optic("Scope", -0.02, 0.22)
		bipod(-h - L * 0.25, -0.15)
		info.Fore = Vector3.new(0, -0.3, -L * 0.25)
	elseif style == "Barrett" then
		handle.Size = Vector3.new(0.36, 0.42, L * 0.36)
		box("LowerReceiver", Vector3.new(0.34, 0.28, L * 0.42), at(0, -0.33, 0.1), STEEL)
		for i = 1, 4 do
			box("ReceiverRib", Vector3.new(0.37, 0.04, 0.06), at(0, -0.1 + (i % 2) * 0.12, -0.5 + i * 0.25), DARK)
		end
		box("CarryHandle", Vector3.new(0.08, 0.06, 0.6), at(0, 0.62, -0.1), BLACK)
		for _, dz in { -0.25, 0.25 } do
			box("CarryPost", Vector3.new(0.06, 0.22, 0.06), at(0, 0.5, -0.1 + dz), BLACK)
		end
		-- recoiling barrel + big arrowhead brake
		cyl("Barrel", look.Barrel + L * 0.35, 0.17, at(0, 0.05, -h - (look.Barrel + L * 0.35) / 2), DARK, M.Metal, "Recoil")
		info.Muzzle = Vector3.new(0, 0.05, -h - look.Barrel - L * 0.35)
		local bz = info.Muzzle.Z
		box("Brake", Vector3.new(0.4, 0.22, 0.4), at(0, 0.05, bz - 0.2), BLACK, M.Metal, "Recoil")
		box("BrakeFront", Vector3.new(0.3, 0.18, 0.12), at(0, 0.05, bz - 0.45), BLACK, M.Metal, "Recoil")
		for _, sx in { -1, 1 } do
			box("BrakePort", Vector3.new(0.05, 0.16, 0.12), at(sx * 0.2, 0.05, bz - 0.2), rgb(10, 10, 10), M.Metal, "Recoil")
		end
		info.Muzzle = Vector3.new(0, 0.05, bz - 0.5)
		box("ChargingHandle", Vector3.new(0.16, 0.12, 0.12), at(0.24, 0.06, -0.2), BLACK, M.Metal, "Bolt")
		ejectionPort(0.0, 0.06)
		grip(L * 0.12, -10, BLACK)
		trigger(L * 0.12)
		straightMag(-0.05, 0.42, 0.26, STEEL)
		box("Stock", Vector3.new(0.3, 0.4, 0.7), at(0, -0.22, h + 0.35), STEEL)
		box("RecoilPad", Vector3.new(0.32, 0.62, 0.18), at(0, -0.2, h + 0.78), BLACK, M.Rubber)
		box("Monopod", Vector3.new(0.08, 0.3, 0.08), at(0, -0.55, h + 0.55), BLACK)
		rail(-h - 0.4, h, 0.24)
		optic("Scope", -0.1, 0.24)
		bipod(-h - 0.4, -0.12)
		info.Fore = Vector3.new(0, -0.32, -h - 0.4)
	elseif style == "Pump" then
		handle.Size = Vector3.new(0.3, 0.42, L * 0.32)
		box("ReceiverBottom", Vector3.new(0.28, 0.12, L * 0.3), at(0, -0.26, 0), STEEL)
		box("LoadingPort", Vector3.new(0.2, 0.03, L * 0.2), at(0, -0.33, -0.02), rgb(18, 18, 18))
		ejectionPort(-0.02, 0.06)
		info.Shell = "Shell"
		local bl = look.Barrel + L * 0.45
		barrel(-h, bl, 0.17, 0.09)
		box("VentRib", Vector3.new(0.06, 0.04, bl), at(0, 0.2, -h - bl / 2), BLACK)
		ball("Bead", 0.06, at(0, 0.24, info.Muzzle.Z + 0.05), CHROME)
		cyl("TubeMag", bl * 0.82, 0.15, at(0, -0.12, -h - bl * 0.41), DARK)
		cyl("MagCap", 0.1, 0.17, at(0, -0.12, -h - bl * 0.82 - 0.05), BLACK)
		-- pump forend + action bars (all move together)
		local pz = -h - L * 0.18
		box("Pump", Vector3.new(0.3, 0.26, L * 0.24), at(0, -0.1, pz), WOOD, M.Wood, "Pump")
		for i = 1, 6 do
			box("PumpGroove", Vector3.new(0.31, 0.025, 0.04), at(0, -0.1 + ((i % 2) * 2 - 1) * 0.06, pz - L * 0.1 + i * L * 0.03), WOOD_DARK, M.Wood, "Pump")
		end
		box("ActionBar", Vector3.new(0.02, 0.04, L * 0.25), at(0.12, -0.08, pz + L * 0.1), CHROME, M.Metal, "Pump")
		info.Fore = Vector3.new(0, -0.22, pz)
		-- straight wrist stock
		box("Wrist", Vector3.new(0.24, 0.3, 0.45), at(0, -0.14, h + 0.2) * CFrame.Angles(math.rad(-14), 0, 0), WOOD, M.Wood)
		info.Grip = Vector3.new(0, -0.24, h + 0.2)
		trigger(h - 0.05)
		box("Stock", Vector3.new(0.24, 0.36, 0.8), at(0, -0.24, h + 0.75) * CFrame.Angles(math.rad(6), 0, 0), WOOD, M.Wood)
		box("ButtPad", Vector3.new(0.26, 0.56, 0.08), at(0, -0.32, h + 1.15), BLACK, M.Rubber)
		info.Sight = 0.25
	elseif style == "AA12" then
		handle.Size = Vector3.new(0.34, 0.44, L * 0.5)
		handle.Color = look.Body
		box("UpperRib", Vector3.new(0.36, 0.08, L * 0.5), at(0, 0.26, 0), DARK)
		for i = 1, 6 do
			box("Rib", Vector3.new(0.37, 0.3, 0.05), at(0, 0.02, -L * 0.2 + i * L * 0.06), DARK)
		end
		box("CarryHandle", Vector3.new(0.1, 0.1, L * 0.4), at(0, 0.48, 0), BLACK)
		for _, dz in { -L * 0.18, L * 0.18 } do
			box("HandlePost", Vector3.new(0.1, 0.18, 0.1), at(0, 0.36, dz), BLACK)
		end
		barrel(-L * 0.25, look.Barrel + 0.35, 0.2, 0.04)
		cyl("Shroud", 0.6, 0.3, at(0, 0.04, -L * 0.25 - 0.3), BLACK)
		brake(0.26, 0.25)
		grip(L * 0.12, -14, BLACK)
		trigger(L * 0.12)
		box("Magwell", Vector3.new(0.3, 0.2, 0.46), at(0, -0.32, -L * 0.1), STEEL)
		cylX("Drum", 0.36, 0.9, at(0, -0.8, -L * 0.1), POLY, M.SmoothPlastic, "Mag")
		cylX("DrumCap", 0.38, 0.32, at(0, -0.8, -L * 0.1), accent, accentMat, "Mag")
		box("ChargingHandle", Vector3.new(0.12, 0.08, 0.08), at(0, 0.3, -0.05), BLACK, M.Metal, "Bolt")
		ejectionPort(0.05, 0.05)
		info.Shell = "Shell"
		fixedStock(L * 0.25, 0.8, BLACK, M.SmoothPlastic)
		box("ForeGrip", Vector3.new(0.14, 0.4, 0.16), at(0, -0.36, -L * 0.22), BLACK)
		info.Sight = 0.55
		info.Fore = Vector3.new(0, -0.36, -L * 0.22)
	elseif style == "Double" then
		handle.Size = Vector3.new(0.34, 0.34, L * 0.22)
		handle.Color = CHROME
		box("Engraving", Vector3.new(0.35, 0.18, L * 0.16), at(0, -0.02, 0), rgb(160, 150, 130), M.Metal)
		local bl = look.Barrel + L * 0.5
		local hinge = Vector3.new(0, -0.08, -L * 0.11)
		model:SetAttribute("BreakPivot", hinge)
		for _, sx in { -0.085, 0.085 } do
			cyl("Barrel", bl, 0.16, at(sx, 0.06, -L * 0.11 - bl / 2), DARK, M.Metal, "Break")
			cyl("Bore", 0.02, 0.1, at(sx, 0.06, -L * 0.11 - bl - 0.01), rgb(5, 5, 5), M.Metal, "Break")
		end
		box("Rib", Vector3.new(0.06, 0.04, bl), at(0, 0.15, -L * 0.11 - bl / 2), DARK, M.Metal, "Break")
		ball("Bead", 0.06, at(0, 0.19, -L * 0.11 - bl + 0.05), BRASS, M.Metal, "Break")
		box("Forend", Vector3.new(0.3, 0.2, L * 0.24), at(0, -0.1, -L * 0.11 - L * 0.16), WOOD, M.Wood, "Break")
		info.Muzzle = Vector3.new(0, 0.06, -L * 0.11 - bl)
		info.Fore = Vector3.new(0, -0.2, -L * 0.11 - L * 0.16)
		box("TopLever", Vector3.new(0.06, 0.04, 0.2), at(0.05, 0.19, L * 0.1), CHROME)
		for _, sx in { -0.08, 0.08 } do
			box("Hammer", Vector3.new(0.05, 0.14, 0.1), at(sx, 0.2, L * 0.1) * CFrame.Angles(math.rad(-30), 0, 0), DARK, M.Metal, "Hammer")
		end
		box("Wrist", Vector3.new(0.24, 0.3, 0.5), at(0, -0.12, L * 0.11 + 0.22) * CFrame.Angles(math.rad(-12), 0, 0), WOOD, M.Wood)
		info.Grip = Vector3.new(0, -0.3, L * 0.11 + 0.22)
		trigger(L * 0.11)
		box("Stock", Vector3.new(0.24, 0.36, 0.9), at(0, -0.2, L * 0.11 + 0.85) * CFrame.Angles(math.rad(6), 0, 0), WOOD, M.Wood)
		box("ButtPad", Vector3.new(0.26, 0.58, 0.08), at(0, -0.28, L * 0.11 + 1.3), BLACK, M.Rubber)
		info.Shell = "Shell"
		info.Eject = Vector3.new(0, 0.1, -L * 0.11)
		info.Sight = 0.22
	elseif style == "Minigun" then
		handle.Size = Vector3.new(0.6, 0.6, L * 0.3)
		handle.Color = look.Body
		local pivot = Vector3.new(0, 0.05, 0)
		model:SetAttribute("BarrelsPivot", pivot)
		local bl = look.Barrel + 1.0
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			cyl("Barrel" .. i, bl, 0.11, at(math.cos(a) * 0.17, 0.05 + math.sin(a) * 0.17, -h - bl / 2), DARK, M.Metal, "Barrels")
		end
		for _, dz in { 0.15, bl * 0.55, bl - 0.05 } do
			cyl("BarrelClamp", 0.08, 0.48, at(0, 0.05, -h - dz), STEEL, M.Metal, "Barrels")
		end
		cyl("Rotor", 0.5, 0.5, at(0, 0.05, -h + 0.05), accent, accentMat, "Barrels")
		info.Muzzle = Vector3.new(0, 0.05, -h - bl)
		box("Motor", Vector3.new(0.3, 0.3, 0.5), at(0, -0.3, 0.1), BLACK)
		box("AmmoBox", Vector3.new(0.5, 0.7, 0.9), at(0.6, -0.4, 0.1), OD, M.Metal, "Mag")
		box("FeedChute", Vector3.new(0.3, 0.12, 0.5), at(0.35, -0.05, 0), BRASS, M.Metal)
		box("RearHandle", Vector3.new(0.6, 0.08, 0.08), at(0, 0.0, h + 0.35), BLACK)
		for _, sx in { -0.25, 0.25 } do
			box("RearHandleArm", Vector3.new(0.06, 0.06, 0.4), at(sx, 0, h + 0.15), BLACK)
		end
		box("RearGrip", Vector3.new(0.12, 0.5, 0.14), at(0, -0.25, h + 0.35), POLY, M.Rubber)
		box("TopHandle", Vector3.new(0.08, 0.08, 0.7), at(0, 0.5, 0), BLACK)
		box("TopPost", Vector3.new(0.08, 0.22, 0.08), at(0, 0.38, 0.3), BLACK)
		box("TopPost2", Vector3.new(0.08, 0.22, 0.08), at(0, 0.38, -0.3), BLACK)
		info.Grip = Vector3.new(0, -0.25, h + 0.35)
		info.Fore = Vector3.new(0, 0.5, 0)
		info.Eject = Vector3.new(-0.35, -0.2, 0)
		info.Sight = 0.62
	elseif style == "RPG" then
		handle.Size = Vector3.new(0.3, 0.3, L * 0.3)
		local tubeY = 0.25
		cyl("Tube", L + 0.4, 0.42, at(0, tubeY, 0), STEEL)
		for _, z in { -L * 0.18, L * 0.08 } do
			cyl("HeatGuard", L * 0.22, 0.56, at(0, tubeY, z), WOOD, M.Wood)
		end
		-- flared venturi at the back
		for i, d in { 0.5, 0.62, 0.74 } do
			cyl("Venturi" .. i, 0.18, d, at(0, tubeY, L / 2 + 0.2 + (i - 1) * 0.16), DARK)
		end
		-- warhead (hidden while empty)
		local z = -L / 2 - 0.2
		for i, d in { 0.3, 0.55, 0.7, 0.66, 0.5, 0.32, 0.16 } do
			cyl("Warhead" .. i, 0.2, d, at(0, tubeY, z - (i - 1) * 0.18), i <= 3 and OD or rgb(70, 80, 54), M.Metal, "Payload")
		end
		cyl("WarheadBand", 0.05, 0.72, at(0, tubeY, z - 0.36), accent, accentMat, "Payload")
		info.Muzzle = Vector3.new(0, tubeY, -L / 2 - 0.2)
		grip(0.2, -8, BLACK)
		trigger(0.2)
		box("ForeGrip", Vector3.new(0.14, 0.44, 0.16), at(0, -0.24, -L * 0.25), BLACK)
		info.Fore = Vector3.new(0, -0.24, -L * 0.25)
		box("OpticArm", Vector3.new(0.2, 0.08, 0.24), at(-0.3, tubeY + 0.08, -0.2), BLACK)
		cyl("Optic", 0.55, 0.2, at(-0.42, tubeY + 0.18, -0.2), BLACK)
		cyl("OpticEye", 0.2, 0.24, at(-0.42, tubeY + 0.18, 0.12), rgb(25, 25, 25), M.Rubber)
		box("IronSight", Vector3.new(0.06, 0.18, 0.06), at(0, tubeY + 0.3, -L * 0.3), BLACK)
		info.Shell = "None"
		info.Sight = tubeY + 0.32
	elseif style == "M32" then
		handle.Size = Vector3.new(0.3, 0.4, L * 0.3)
		local pivot = Vector3.new(0, -0.08, -h - 0.3)
		model:SetAttribute("CylinderPivot", pivot)
		cyl("Cylinder", 0.6, 0.95, at(0, -0.08, -h - 0.3), look.Body, M.Metal, "Cylinder")
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			cyl("Chamber" .. i, 0.62, 0.22, at(math.cos(a) * 0.3, -0.08 + math.sin(a) * 0.3, -h - 0.3), rgb(20, 20, 22), M.Metal, "Cylinder")
		end
		cyl("Spindle", 0.66, 0.12, at(0, -0.08, -h - 0.3), accent, accentMat)
		box("Frame", Vector3.new(0.16, 0.12, 0.7), at(0, 0.48, -h - 0.3), BLACK)
		barrel(-h - 0.6, look.Barrel + 0.5, 0.36, 0.12)
		box("BarrelRail", Vector3.new(0.08, 0.06, look.Barrel + 0.5), at(0, 0.33, -h - 0.6 - (look.Barrel + 0.5) / 2), BLACK)
		box("ForeGrip", Vector3.new(0.14, 0.44, 0.16), at(0, -0.3, info.Muzzle.Z + 0.3), BLACK)
		info.Fore = Vector3.new(0, -0.3, info.Muzzle.Z + 0.3)
		grip(L * 0.1)
		trigger(L * 0.1)
		m4Stock(h)
		optic("Holo", -0.02, 0.2)
		rail(-h, h, 0.2)
		info.Shell = "None"
	elseif style == "Railgun" then
		handle.Size = Vector3.new(0.36, 0.44, L * 0.3)
		handle.Color = look.Body
		local rl = L * 0.55 + look.Barrel
		for _, sx in { -0.16, 0.16 } do
			box("Rail", Vector3.new(0.1, 0.2, rl), at(sx, 0.04, -h - rl / 2), DARK)
		end
		for i = 1, 6 do
			local z = -h - i * (rl / 7)
			box("Coil", Vector3.new(0.26, 0.05, 0.06), at(0, 0.04, z), accent, M.Neon, "Glow")
			cyl("CoilRing", 0.07, 0.44, at(0, 0.04, z), DARK)
		end
		info.Muzzle = Vector3.new(0, 0.04, -h - rl)
		box("Capacitor", Vector3.new(0.32, 0.24, 0.6), at(0, -0.3, -0.1), POLY, M.SmoothPlastic)
		box("CapacitorGlow", Vector3.new(0.34, 0.06, 0.5), at(0, -0.3, -0.1), accent, M.Neon, "Glow")
		grip(L * 0.1)
		trigger(L * 0.1)
		fixedStock(h, 1.0, POLY, M.SmoothPlastic)
		box("StockGlow", Vector3.new(0.26, 0.04, 0.8), at(0, 0.05, h + 0.5), accent, M.Neon, "Glow")
		rail(-h, h, 0.24)
		optic("Scope", -0.05, 0.24)
		info.Shell = "None"
		info.Fore = Vector3.new(0, -0.15, -h - 0.4)
	elseif style == "Plasma" then
		handle.Size = Vector3.new(0.34, 0.46, L * 0.4)
		handle.Color = look.Body
		handle.Material = M.SmoothPlastic
		box("TopShell", Vector3.new(0.3, 0.14, L * 0.5), at(0, 0.3, -0.1), rgb(210, 214, 222), M.SmoothPlastic)
		box("SideWindowL", Vector3.new(0.02, 0.2, L * 0.25), at(-0.18, 0.02, -0.05), rgb(10, 20, 30), M.Glass)
		box("SideWindowR", Vector3.new(0.02, 0.2, L * 0.25), at(0.18, 0.02, -0.05), rgb(10, 20, 30), M.Glass)
		for i = 1, 3 do
			cyl("PlasmaCell" .. i, 0.12, 0.16, at(0, 0.02, -0.25 + i * 0.13), accent, M.Neon, "Glow")
		end
		-- twin emitter prongs
		for _, sx in { -0.12, 0.12 } do
			box("Prong", Vector3.new(0.08, 0.26, L * 0.35), at(sx, 0.02, -L * 0.2 - L * 0.17), rgb(210, 214, 222), M.SmoothPlastic)
			box("ProngGlow", Vector3.new(0.02, 0.18, L * 0.3), at(sx * 0.6, 0.02, -L * 0.2 - L * 0.17), accent, M.Neon, "Glow")
		end
		info.Muzzle = Vector3.new(0, 0.02, -L * 0.2 - L * 0.36)
		for i = 1, 3 do
			box("HeatVent", Vector3.new(0.05, 0.16, 0.06), at(0.19, 0.02, 0.2 + i * 0.09), DARK, M.Metal, "Bolt")
		end
		grip(L * 0.12, -16, BLACK)
		trigger(L * 0.12)
		box("PowerCell", Vector3.new(0.2, 0.42, 0.3), at(0, -0.42, -0.2), DARK, M.Metal, "Mag")
		box("PowerCellGlow", Vector3.new(0.22, 0.06, 0.32), at(0, -0.3, -0.2), accent, M.Neon, "Mag")
		fixedStock(L * 0.2, 0.75, rgb(210, 214, 222), M.SmoothPlastic)
		cyl("SightRing", 0.06, 0.26, at(0, 0.55, -0.05), DARK)
		box("SightBase", Vector3.new(0.12, 0.14, 0.2), at(0, 0.44, -0.05), DARK)
		info.Shell = "None"
		info.Sight = 0.55
		info.Fore = Vector3.new(0, -0.15, -L * 0.25)
	elseif style == "Void" then
		handle.Size = Vector3.new(0.5, 0.5, L * 0.3)
		handle.Color = look.Body
		local orbZ = -L * 0.2
		local orbGlass = ball("OrbChamber", 0.9, at(0, 0.15, orbZ), rgb(120, 90, 160), M.Glass)
		orbGlass.Transparency = 0.5
		ball("Singularity", 0.42, at(0, 0.15, orbZ), accent, M.Neon, "Glow")
		for _, sx in { -1, 1 } do
			box("OrbCage", Vector3.new(0.06, 0.9, 0.06), at(sx * 0.42, 0.15, orbZ), DARK)
		end
		box("OrbCageTop", Vector3.new(0.9, 0.06, 0.06), at(0, 0.62, orbZ), DARK)
		local pivot = Vector3.new(0, 0.15, 0)
		model:SetAttribute("BarrelsPivot", pivot)
		for i = 1, 3 do
			local z = orbZ - 0.55 - i * 0.22
			cyl("EmitterRing" .. i, 0.08, 0.8 - i * 0.12, at(0, 0.15, z), DARK, M.Metal, "Barrels")
			for k = 1, 3 do
				local a = k / 3 * math.pi * 2 + i
				box("RingGlow", Vector3.new(0.06, 0.06, 0.09), at(math.cos(a) * (0.36 - i * 0.06), 0.15 + math.sin(a) * (0.36 - i * 0.06), z), accent, M.Neon, "Barrels")
			end
		end
		info.Muzzle = Vector3.new(0, 0.15, orbZ - 1.3)
		box("PowerCell", Vector3.new(0.36, 0.36, 0.6), at(0, 0.1, L * 0.2), DARK, M.Metal, "Mag")
		box("PowerCellGlow", Vector3.new(0.38, 0.08, 0.5), at(0, 0.1, L * 0.2), accent, M.Neon, "Mag")
		grip(L * 0.05, -12, BLACK)
		trigger(L * 0.05)
		box("ForeGrip", Vector3.new(0.14, 0.42, 0.16), at(0, -0.3, orbZ), BLACK)
		box("TopHandle", Vector3.new(0.08, 0.08, 0.7), at(0, 0.75, 0.1), DARK)
		info.Shell = "None"
		info.Sight = 0.8
		info.Fore = Vector3.new(0, -0.3, orbZ)
	elseif style == "RayGun" then
		handle.Size = Vector3.new(0.3, 0.3, 0.5)
		handle.Color = look.Body
		ball("Body", 0.6, at(0, 0.1, 0.05), look.Body, M.Metal)
		for i = 1, 4 do
			local d = 0.5 - i * 0.07
			cyl("Ring" .. i, 0.08, d, at(0, 0.1, -0.3 - i * 0.14), i % 2 == 0 and CHROME or rgb(200, 60, 60), M.Metal)
		end
		cyl("Emitter", 0.5, 0.12, at(0, 0.1, -0.55), CHROME)
		ball("EmitterTip", 0.2, at(0, 0.1, -0.85), accent, M.Neon, "Glow")
		info.Muzzle = Vector3.new(0, 0.1, -0.95)
		for k = 1, 3 do
			local a = k / 3 * math.pi * 2 + math.pi / 2
			box("Fin", Vector3.new(0.04, 0.3, 0.3), at(math.cos(a) * 0.32, 0.1 + math.sin(a) * 0.32, 0.25) * CFrame.Angles(0, 0, a), rgb(200, 60, 60), M.Metal)
		end
		cyl("Canister", 0.36, 0.16, at(0, 0.42, 0.05), accent, M.Neon, "Glow")
		box("CanisterClip", Vector3.new(0.2, 0.06, 0.06), at(0, 0.36, 0.05), CHROME)
		box("Grip", Vector3.new(0.2, 0.55, 0.28), at(0, -0.3, 0.25) * CFrame.Angles(math.rad(-22), 0, 0), rgb(120, 60, 40), M.Wood)
		info.Grip = Vector3.new(0, -0.3, 0.25)
		box("TriggerGuard", Vector3.new(0.05, 0.05, 0.3), at(0, -0.18, 0.05), CHROME)
		box("Trigger", Vector3.new(0.04, 0.12, 0.04), at(0, -0.12, 0.08), CHROME, M.Metal, "Trigger")
		info.Fore = Vector3.new(0, -0.38, 0.3)
		info.Shell = "None"
		info.Sight = 0.32
	elseif style == "Revolver" then
		local fat = true
		handle.Size = Vector3.new(0.24, 0.36, 0.55)
		model:SetAttribute("CylinderPivot", Vector3.new(0, 0.0, -0.22))
		cyl("Cylinder", 0.44, fat and 0.52 or 0.44, at(0, 0.0, -0.22), CHROME, M.Metal, "Cylinder")
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			box("Flute", Vector3.new(0.05, 0.05, 0.4), at(math.cos(a) * 0.25, math.sin(a) * 0.25, -0.22), DARK, M.Metal, "Cylinder")
		end
		local bl = look.Barrel + L * 0.35
		barrel(-0.44, bl, 0.2, 0.1)
		box("TopRib", Vector3.new(0.1, 0.08, bl), at(0, 0.22, -0.44 - bl / 2), STEEL)
		box("EjectorShroud", Vector3.new(0.12, 0.12, bl * 0.75), at(0, -0.06, -0.44 - bl * 0.37), STEEL)
		box("FrontSight", Vector3.new(0.04, 0.1, 0.08), at(0, 0.3, info.Muzzle.Z + 0.08), accent, accentMat)
		box("TopStrap", Vector3.new(0.18, 0.08, 0.5), at(0, 0.26, -0.15), STEEL)
		box("Hammer", Vector3.new(0.06, 0.18, 0.12), at(0, 0.22, 0.2) * CFrame.Angles(math.rad(-30), 0, 0), DARK, M.Metal, "Hammer")
		box("Grip", Vector3.new(0.22, 0.62, 0.3), at(0, -0.38, 0.32) * CFrame.Angles(math.rad(-22), 0, 0), WOOD, M.Wood)
		box("GripScrew", Vector3.new(0.24, 0.05, 0.05), at(0, -0.36, 0.32), BRASS)
		info.Grip = Vector3.new(0, -0.38, 0.32)
		trigger(0.15)
		info.Fore = Vector3.new(0, -0.42, 0.37)
		info.Shell = "None"
		info.Sight = 0.32
	else -- semi-auto pistols: Pistol, Uzi, Deagle, Energy
		local P = L
		handle.Size = Vector3.new(0.22, 0.16, P * 0.75)
		handle.Color = POLY
		handle.Material = M.SmoothPlastic
		local slideLen = P * 0.9
		local slideH = style == "Deagle" and 0.3 or 0.22
		local slideColor = style == "Energy" and look.Body or (style == "Deagle" and CHROME or STEEL)
		if style == "Uzi" then
			-- boxy stamped receiver, mag in the grip, top cocking knob
			handle.Size = Vector3.new(0.3, 0.36, P * 0.85)
			handle.Color = look.Body
			handle.Material = M.Metal
			box("TopCover", Vector3.new(0.28, 0.06, P * 0.8), at(0, 0.21, 0), DARK)
			box("CockingKnob", Vector3.new(0.12, 0.08, 0.1), at(0, 0.27, P * 0.2), BLACK, M.Metal, "Bolt")
			box("FrontSightEars", Vector3.new(0.16, 0.12, 0.06), at(0, 0.26, -P * 0.38), BLACK)
			box("RearSight", Vector3.new(0.14, 0.1, 0.06), at(0, 0.26, P * 0.38), BLACK)
			barrel(-P * 0.42, look.Barrel + 0.05, 0.12, 0.02)
			box("BarrelNut", Vector3.new(0.18, 0.18, 0.08), at(0, 0.02, -P * 0.44), BLACK)
			box("Grip", Vector3.new(0.24, 0.62, 0.3), at(0, -0.48, 0.05) * CFrame.Angles(math.rad(-6), 0, 0), POLY, M.SmoothPlastic)
			box("Mag", Vector3.new(0.16, 0.45, 0.2), at(0, -0.98, 0.1) * CFrame.Angles(math.rad(-6), 0, 0), BLACK, M.Metal, "Mag")
			box("GripSafety", Vector3.new(0.12, 0.3, 0.05), at(0, -0.42, 0.22), BLACK)
			info.Grip = Vector3.new(0, -0.48, 0.05)
			trigger(-0.08)
			box("ForeGrip", Vector3.new(0.12, 0.34, 0.14), at(0, -0.3, -P * 0.3), BLACK)
			for _, sx in { -0.12, 0.12 } do
				box("StockArm", Vector3.new(0.03, 0.03, 0.55), at(sx, 0.1, P * 0.4 + 0.27), STEEL)
			end
			box("StockPad", Vector3.new(0.26, 0.2, 0.05), at(0, 0.05, P * 0.4 + 0.55), STEEL)
			ejectionPort(0.0, 0.08)
			info.Fore = Vector3.new(0, -0.3, -P * 0.3)
			info.Sight = 0.32
		else
			-- slide (moves) + frame
			box("Slide", Vector3.new(0.24, slideH, slideLen), at(0, 0.15, -0.04), slideColor, style == "Energy" and M.SmoothPlastic or M.Metal, "Slide")
			for i = 1, 7 do
				box("Serration", Vector3.new(0.25, slideH * 0.6, 0.022), at(0, 0.16, slideLen / 2 - 0.1 - i * 0.05), DARK, M.Metal, "Slide")
			end
			box("FrontSight", Vector3.new(0.04, 0.06, 0.05), at(0, 0.15 + slideH / 2 + 0.03, -slideLen / 2 + 0.05), accent, accentMat, "Slide")
			box("RearSight", Vector3.new(0.17, 0.06, 0.05), at(0, 0.15 + slideH / 2 + 0.03, slideLen / 2 - 0.08), BLACK, M.Metal, "Slide")
			box("EjectionPort", Vector3.new(0.03, 0.09, 0.22), at(0.12, 0.18, -0.06), rgb(18, 18, 20), M.Metal, "Slide")
			info.Eject = Vector3.new(0.14, 0.2, -0.06)
			if style == "Deagle" then
				-- triangular-profile fixed barrel in front
				box("BarrelBlock", Vector3.new(0.26, 0.3, P * 0.45), at(0, 0.15, -slideLen / 2 - P * 0.2), CHROME, M.Metal)
				box("BarrelRib", Vector3.new(0.12, 0.06, P * 0.45), at(0, 0.32, -slideLen / 2 - P * 0.2), CHROME, M.Metal)
				box("BarrelBevelL", Vector3.new(0.05, 0.22, P * 0.45), at(-0.12, 0.24, -slideLen / 2 - P * 0.2) * CFrame.Angles(0, 0, math.rad(25)), STEEL)
				box("BarrelBevelR", Vector3.new(0.05, 0.22, P * 0.45), at(0.12, 0.24, -slideLen / 2 - P * 0.2) * CFrame.Angles(0, 0, math.rad(-25)), STEEL)
				info.Muzzle = Vector3.new(0, 0.16, -slideLen / 2 - P * 0.43)
				box("Hammer", Vector3.new(0.06, 0.14, 0.08), at(0, 0.28, slideLen / 2 + 0.02) * CFrame.Angles(math.rad(-30), 0, 0), DARK, M.Metal, "Hammer")
			else
				cyl("BarrelHood", 0.1, 0.12, at(0, 0.15, -slideLen / 2 - 0.08), DARK)
				info.Muzzle = Vector3.new(0, 0.15, -slideLen / 2 - 0.14)
			end
			box("Frame", Vector3.new(0.22, 0.14, slideLen * 0.85), at(0, -0.02, -0.08), POLY, M.SmoothPlastic)
			box("AccessoryRail", Vector3.new(0.18, 0.06, slideLen * 0.3), at(0, -0.1, -slideLen * 0.3), BLACK)
			box("Grip", Vector3.new(0.22, 0.6, 0.32), at(0, -0.36, slideLen * 0.28) * CFrame.Angles(math.rad(-16), 0, 0), style == "Deagle" and BLACK or POLY, M.SmoothPlastic)
			box("GripTexture", Vector3.new(0.23, 0.4, 0.26), at(0, -0.38, slideLen * 0.29) * CFrame.Angles(math.rad(-16), 0, 0), rgb(40, 40, 42), M.Fabric)
			box("MagBase", Vector3.new(0.24, 0.05, 0.32), at(0, -0.67, slideLen * 0.36) * CFrame.Angles(math.rad(-16), 0, 0), DARK, M.Metal, "Mag")
			box("Mag", Vector3.new(0.16, 0.4, 0.24), at(0, -0.5, slideLen * 0.32) * CFrame.Angles(math.rad(-16), 0, 0), DARK, M.Metal, "Mag")
			info.Grip = Vector3.new(0, -0.36, slideLen * 0.28)
			box("TriggerGuard", Vector3.new(0.05, 0.05, 0.36), at(0, -0.26, slideLen * 0.02), POLY, M.SmoothPlastic)
			box("Trigger", Vector3.new(0.04, 0.13, 0.04), at(0, -0.17, slideLen * 0.06), DARK, M.Metal, "Trigger")
			box("SlideStop", Vector3.new(0.03, 0.04, 0.12), at(-0.12, 0.04, 0.0), BLACK)
			if style == "Energy" then
				for i = 1, 3 do
					box("Coil", Vector3.new(0.26, 0.05, 0.05), at(0, 0.16, -slideLen / 2 + i * 0.14), accent, M.Neon, "Glow")
				end
				cyl("Emitter", 0.12, 0.2, at(0, 0.15, -slideLen / 2 - 0.08), accent, M.Neon, "Glow")
				info.Shell = "None"
			end
			info.Sight = 0.15 + slideH / 2 + 0.05
			info.Fore = Vector3.new(0, -0.42, slideLen * 0.28 + 0.05)
		end
	end

	if golden then
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") and p.Material ~= M.Neon and p.Material ~= M.Glass then
				p.Color = (p.Color == BLACK or p.Color == DARK or p.Color == POLY) and rgb(190, 140, 30) or GOLD
				p.Material = M.Metal
				p.Reflectance = 0.25
			end
		end
	end

	for _, p in parts do
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = p
		w.Parent = handle
	end
	local function attachment(name, pos)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = pos
		a.Parent = handle
	end
	attachment("Muzzle", info.Muzzle)
	attachment("Sight", Vector3.new(0, info.Sight, 0))
	attachment("GripPoint", info.Grip)
	attachment("ForePoint", info.Fore)
	attachment("Eject", info.Eject)
	model:SetAttribute("Shell", info.Shell)
	return model
end

-- Turns a built gun into a Tool the character can hold (third-person view).
function GunBuilder.BuildTool(weaponId: string, golden: boolean?)
	local def = Weapons.Get(weaponId)
	local model = GunBuilder.Build(weaponId, golden)
	local handle = model.PrimaryPart
	local grip = handle:FindFirstChild("GripPoint")
	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	tool:SetAttribute("WeaponId", weaponId)
	tool:SetAttribute("Slot", def.Slot)
	tool.Grip = grip and CFrame.new(grip.Position) or CFrame.new(0, -0.35, def.Look.Length * 0.22)
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()
	return tool
end

return GunBuilder
