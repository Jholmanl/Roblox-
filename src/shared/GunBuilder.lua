-- Builds detailed gun models out of parts (no uploaded meshes needed).
-- Every weapon gets a realistic silhouette for its type: receivers, rails,
-- handguards, curved mags, optics, stocks, muzzle devices, bipods...
-- The barrel points down the Handle's -Z axis.
-- Attachments on the Handle: Muzzle, Sight (ADS height), GripPoint (right hand), ForePoint (left hand).
local Weapons = require(script.Parent.Weapons)

local GunBuilder = {}

local rgb = Color3.fromRGB
local M = Enum.Material
local GOLD = rgb(255, 196, 40)
local STEEL = rgb(78, 81, 88)
local DARKSTEEL = rgb(44, 46, 50)
local POLY = rgb(58, 60, 64)
local WOOD = rgb(122, 76, 42)
local CHROME = rgb(190, 192, 198)
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- cylinders run along X; rotate onto Z

-- weapon id -> style + options
local STYLES = {
	Striker = { "Rifle", Optic = "RedDot" },
	Vanguard = { "Rifle", Short = true, Optic = "Holo" },
	Hornet = { "Rifle", Optic = "Scope" },
	Warden = { "Battle", Optic = "Holo" },
	Ranger = { "DMR", Optic = "Scope" },
	Viper = { "SMG", Optic = "RedDot" },
	Tempest = { "SMG", Optic = "Holo", Long = true },
	Inferno = { "LMG" },
	Longbow = { "Sniper" },
	Titan = { "Sniper", Heavy = true },
	Brute = { "Pump", Wood = true },
	Razor = { "AutoShotgun" },
	Duke = { "DoubleBarrel" },
	Reaper = { "Minigun" },
	Havoc = { "RPG" },
	Thumper = { "GL" },
	Railgun = { "Railgun" },
	Sidekick = { "Pistol" },
	Stinger = { "MachinePistol" },
	HandCannon = { "Revolver" },
	Judge = { "Revolver", Fat = true },
	Arc = { "EnergyPistol" },
}

local function newPart(model, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
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
	p.Parent = model
	return p
end

function GunBuilder.Build(weaponId: string, golden: boolean?)
	local def = Weapons.Get(weaponId)
	local look = def.Look
	local style = STYLES[weaponId] or { "Rifle" }
	local kind = style[1]
	local L = look.Length
	local B = look.Barrel

	local model = Instance.new("Model")
	model.Name = weaponId

	local furniture = style.Wood and WOOD or look.Body -- stock / handguard / grip color
	local accent = look.Accent
	local accentMat = look.Neon and M.Neon or M.SmoothPlastic
	local parts = {}

	local function box(name, size, cf, color, material)
		local p = newPart(model, name, size, cf, color or STEEL, material or M.Metal)
		table.insert(parts, p)
		return p
	end
	local function cyl(name, length, diameter, cf, color, material)
		local p = newPart(model, name, Vector3.new(length, diameter, diameter), cf * ALONG_Z, color or STEEL, material or M.Metal, Enum.PartType.Cylinder)
		table.insert(parts, p)
		return p
	end
	local function at(x, y, z)
		return CFrame.new(x, y, z)
	end

	-- the Handle is always the receiver / main body
	local recLen = L * 0.34
	local handle = newPart(model, "Handle", Vector3.new(0.3, 0.4, recLen), at(0, 0, 0), STEEL, M.Metal)
	model.PrimaryPart = handle

	local info = { Grip = Vector3.new(0, -0.42, recLen * 0.25), Fore = Vector3.new(0, -0.22, -recLen * 0.9), Muzzle = Vector3.new(0, 0.05, -L / 2 - B), Sight = 0.42 }

	----------------------------------------------------------------- shared pieces
	local function topRail(z0, z1, y)
		local len = z1 - z0
		box("Rail", Vector3.new(0.2, 0.06, len), at(0, y, (z0 + z1) / 2), DARKSTEEL)
		local count = math.floor(len / 0.11)
		for i = 0, math.min(count, 14) - 1 do
			box("RailSlot", Vector3.new(0.24, 0.045, 0.045), at(0, y + 0.04, z0 + 0.06 + i * (len / math.max(1, count))), DARKSTEEL)
		end
	end
	local function pistolGrip(z, angle, color)
		box("Grip", Vector3.new(0.22, 0.62, 0.3), at(0, -0.46, z) * CFrame.Angles(math.rad(angle or -16), 0, 0), color or POLY, M.SmoothPlastic)
		box("GripCap", Vector3.new(0.24, 0.06, 0.32), at(0, -0.78, z + 0.1) * CFrame.Angles(math.rad(angle or -16), 0, 0), color or POLY, M.SmoothPlastic)
		info.Grip = Vector3.new(0, -0.46, z)
	end
	local function triggerGuard(z)
		box("TriggerGuard", Vector3.new(0.06, 0.05, 0.46), at(0, -0.36, z - 0.18), DARKSTEEL)
		box("TriggerGuardFront", Vector3.new(0.06, 0.18, 0.05), at(0, -0.28, z - 0.4), DARKSTEEL)
		box("Trigger", Vector3.new(0.04, 0.17, 0.05), at(0, -0.27, z - 0.17) * CFrame.Angles(math.rad(12), 0, 0), CHROME)
	end
	local function ejectionPort(z)
		box("EjectionPort", Vector3.new(0.03, 0.12, 0.3), at(0.155, 0.06, z), DARKSTEEL)
		box("ForwardAssist", Vector3.new(0.08, 0.08, 0.1), at(0.17, 0.1, z + 0.28), DARKSTEEL)
	end
	local function muzzleBrake(z, d, len)
		cyl("Muzzle", len, d, at(0, info.Muzzle.Y, z - len / 2), DARKSTEEL)
		for i = 1, 3 do
			box("Port", Vector3.new(d + 0.02, 0.04, 0.05), at(0, info.Muzzle.Y, z - len * (i / 4)), rgb(15, 15, 16))
		end
		info.Muzzle = Vector3.new(0, info.Muzzle.Y, z - len)
	end
	local function barrel(zStart, length, d, y)
		cyl("Barrel", length, d, at(0, y, zStart - length / 2), DARKSTEEL)
		info.Muzzle = Vector3.new(0, y, zStart - length)
	end
	local function curvedMag(z, scale)
		local s = scale or 1
		box("Magwell", Vector3.new(0.26, 0.2, 0.42), at(0, -0.28, z), STEEL)
		box("Mag", Vector3.new(0.19, 0.48 * s, 0.34), at(0, -0.56, z - 0.05) * CFrame.Angles(math.rad(10), 0, 0), POLY, M.SmoothPlastic)
		box("Mag2", Vector3.new(0.19, 0.42 * s, 0.33), at(0, -0.92 * s, z - 0.17) * CFrame.Angles(math.rad(24), 0, 0), POLY, M.SmoothPlastic)
		box("MagBase", Vector3.new(0.22, 0.06, 0.36), at(0, -1.13 * s, z - 0.27) * CFrame.Angles(math.rad(24), 0, 0), DARKSTEEL)
	end
	local function boxMag(z, length, width)
		box("Magwell", Vector3.new(0.26, 0.2, 0.42), at(0, -0.28, z), STEEL)
		box("Mag", Vector3.new(width or 0.2, length, 0.36), at(0, -0.3 - length / 2, z - 0.04) * CFrame.Angles(math.rad(6), 0, 0), POLY, M.SmoothPlastic)
		box("MagBase", Vector3.new((width or 0.2) + 0.03, 0.06, 0.38), at(0, -0.32 - length, z - 0.08) * CFrame.Angles(math.rad(6), 0, 0), DARKSTEEL)
	end
	local function adjustableStock(zRear)
		cyl("BufferTube", 0.55, 0.18, at(0, 0.02, zRear + 0.27), DARKSTEEL)
		box("Stock", Vector3.new(0.24, 0.42, 0.62), at(0, -0.06, zRear + 0.7), furniture, M.SmoothPlastic)
		box("StockCheek", Vector3.new(0.22, 0.14, 0.5), at(0, 0.18, zRear + 0.68), furniture, M.SmoothPlastic)
		box("ButtPad", Vector3.new(0.26, 0.52, 0.08), at(0, -0.08, zRear + 1.03), DARKSTEEL, M.Rubber)
	end
	local function fixedStock(zRear, length, wood)
		local c = wood and WOOD or furniture
		local mat = wood and M.Wood or M.SmoothPlastic
		box("Stock", Vector3.new(0.24, 0.36, length), at(0, -0.04, zRear + length / 2) * CFrame.Angles(math.rad(4), 0, 0), c, mat)
		box("StockToe", Vector3.new(0.23, 0.32, length * 0.55), at(0, -0.26, zRear + length * 0.68) * CFrame.Angles(math.rad(-8), 0, 0), c, mat)
		box("ButtPad", Vector3.new(0.26, 0.62, 0.08), at(0, -0.14, zRear + length + 0.02), DARKSTEEL, M.Rubber)
	end
	local function handguard(z0, length, color, vents)
		box("Handguard", Vector3.new(0.34, 0.36, length), at(0, 0.02, z0 - length / 2), color or furniture, M.SmoothPlastic)
		if vents then
			for i = 1, math.min(5, math.floor(length / 0.18)) do
				for _, sx in { -1, 1 } do
					box("Vent", Vector3.new(0.02, 0.08, 0.12), at(sx * 0.17, 0.04, z0 - i * (length / 6)), DARKSTEEL)
				end
			end
		end
		info.Fore = Vector3.new(0, -0.18, z0 - length * 0.55)
	end
	local function frontSight(z, y)
		box("FrontSightBase", Vector3.new(0.12, 0.14, 0.08), at(0, y, z), DARKSTEEL)
		box("FrontSightPost", Vector3.new(0.03, 0.12, 0.03), at(0, y + 0.12, z), accent, accentMat)
	end
	local function optic(kind2, z, railY)
		if kind2 == "RedDot" then
			box("OpticMount", Vector3.new(0.18, 0.08, 0.26), at(0, railY + 0.08, z), DARKSTEEL)
			cyl("Optic", 0.32, 0.26, at(0, railY + 0.27, z), DARKSTEEL)
			cyl("Lens", 0.02, 0.2, at(0, railY + 0.27, z - 0.17), rgb(120, 200, 255), M.Glass).Transparency = 0.4
			box("Dot", Vector3.new(0.03, 0.03, 0.02), at(0, railY + 0.27, z + 0.1), rgb(255, 40, 40), M.Neon)
			info.Sight = railY + 0.27
		elseif kind2 == "Holo" then
			box("HoloBase", Vector3.new(0.24, 0.1, 0.42), at(0, railY + 0.09, z), DARKSTEEL)
			box("HoloHood", Vector3.new(0.26, 0.04, 0.34), at(0, railY + 0.42, z - 0.04), DARKSTEEL)
			box("HoloSideL", Vector3.new(0.03, 0.32, 0.3), at(-0.12, railY + 0.27, z - 0.04), DARKSTEEL)
			box("HoloSideR", Vector3.new(0.03, 0.32, 0.3), at(0.12, railY + 0.27, z - 0.04), DARKSTEEL)
			local glass = box("HoloGlass", Vector3.new(0.2, 0.22, 0.02), at(0, railY + 0.27, z - 0.16), rgb(150, 220, 255), M.Glass)
			glass.Transparency = 0.5
			box("Reticle", Vector3.new(0.03, 0.03, 0.01), at(0, railY + 0.27, z - 0.15), rgb(255, 60, 60), M.Neon)
			info.Sight = railY + 0.27
		else -- Scope
			for _, dz in { -0.2, 0.2 } do
				box("ScopeRing", Vector3.new(0.08, 0.2, 0.08), at(0, railY + 0.12, z + dz), DARKSTEEL)
			end
			local y = railY + 0.3
			cyl("ScopeTube", 0.9, 0.18, at(0, y, z), DARKSTEEL)
			cyl("ScopeBellFront", 0.3, 0.3, at(0, y, z - 0.55), DARKSTEEL)
			cyl("ScopeBellRear", 0.22, 0.26, at(0, y, z + 0.5), DARKSTEEL)
			cyl("ScopeLens", 0.02, 0.26, at(0, y, z - 0.71), rgb(80, 140, 200), M.Glass).Transparency = 0.2
			box("TurretTop", Vector3.new(0.14, 0.12, 0.14), at(0, y + 0.13, z), DARKSTEEL)
			box("TurretSide", Vector3.new(0.12, 0.14, 0.14), at(0.13, y, z), DARKSTEEL)
			box("ScopeAccent", Vector3.new(0.19, 0.02, 0.04), at(0, y, z - 0.38), accent, accentMat)
			info.Sight = y
		end
	end
	local function bipod(z, y)
		box("BipodMount", Vector3.new(0.16, 0.1, 0.16), at(0, y - 0.08, z), DARKSTEEL)
		for _, sx in { -1, 1 } do
			box("BipodLeg", Vector3.new(0.05, 0.55, 0.05), at(sx * 0.1, y - 0.36, z + 0.1) * CFrame.Angles(math.rad(-55), 0, math.rad(sx * 8)), DARKSTEEL)
		end
	end
	local function chargingHandle(zRear)
		box("ChargingHandle", Vector3.new(0.22, 0.05, 0.1), at(0, 0.21, zRear - 0.04), DARKSTEEL)
	end

	----------------------------------------------------------------- styles
	local h = recLen / 2
	if kind == "Rifle" or kind == "Battle" or kind == "DMR" or kind == "AutoShotgun" or kind == "LMG" then
		local hgLen = kind == "DMR" and L * 0.38 or (style.Short and L * 0.24 or L * 0.3)
		handle.Size = Vector3.new(0.3, 0.42, recLen)
		box("Lower", Vector3.new(0.28, 0.16, recLen * 0.9), at(0, -0.26, recLen * 0.03), STEEL)
		topRail(-h - hgLen, h, 0.24)
		handguard(-h, hgLen, kind == "Battle" and furniture or POLY, true)
		local barrelD = kind == "AutoShotgun" and 0.2 or (kind == "LMG" and 0.17 or 0.12)
		barrel(-h - hgLen, B + 0.1, barrelD, 0.04)
		box("GasBlock", Vector3.new(0.16, 0.14, 0.1), at(0, 0.07, -h - hgLen - 0.06), DARKSTEEL)
		muzzleBrake(info.Muzzle.Z, barrelD + 0.06, kind == "DMR" and 0.32 or 0.24)
		pistolGrip(recLen * 0.28)
		triggerGuard(recLen * 0.28)
		ejectionPort(-recLen * 0.05)
		chargingHandle(h)
		if kind == "AutoShotgun" then
			box("Magwell", Vector3.new(0.28, 0.2, 0.46), at(0, -0.28, -recLen * 0.12), STEEL)
			cyl("Drum", 0.34, 0.85, at(0, -0.72, -recLen * 0.14) * CFrame.Angles(0, math.rad(90), 0), POLY, M.SmoothPlastic)
			cyl("DrumCap", 0.36, 0.3, at(0, -0.72, -recLen * 0.14) * CFrame.Angles(0, math.rad(90), 0), accent, accentMat)
		elseif kind == "LMG" then
			box("AmmoBox", Vector3.new(0.4, 0.55, 0.62), at(0, -0.5, -recLen * 0.12), rgb(70, 78, 52), M.Metal)
			box("AmmoBelt", Vector3.new(0.12, 0.1, 0.2), at(0.2, -0.16, -recLen * 0.12), CHROME, M.Metal)
			box("CarryHandle", Vector3.new(0.08, 0.06, 0.6), at(0, 0.48, -recLen * 0.1), DARKSTEEL)
			for _, dz in { -0.25, 0.25 } do
				box("CarryPost", Vector3.new(0.08, 0.22, 0.06), at(0, 0.37, -recLen * 0.1 + dz), DARKSTEEL)
			end
			cyl("BarrelShroud", hgLen * 0.6, 0.26, at(0, 0.04, -h - hgLen - hgLen * 0.3), DARKSTEEL)
			bipod(-h - hgLen + 0.1, -0.12)
			info.Sight = 0.4
			frontSight(-h - hgLen, 0.24)
		elseif kind == "Battle" or kind == "DMR" then
			boxMag(-recLen * 0.1, kind == "DMR" and 0.44 or 0.5, 0.22)
		else
			curvedMag(-recLen * 0.12)
		end
		if kind == "DMR" or kind == "Battle" then
			fixedStock(h, 1.05, false)
		elseif kind ~= "LMG" then
			adjustableStock(h)
		else
			fixedStock(h, 0.95, false)
		end
		if kind == "DMR" then
			bipod(-h - hgLen + 0.15, -0.12)
		end
		if kind ~= "LMG" then
			optic(style.Optic or "RedDot", -recLen * 0.05, 0.24)
		end
		if style.Short then
			box("ForeGrip", Vector3.new(0.14, 0.4, 0.16), at(0, -0.36, -h - hgLen * 0.5), POLY, M.SmoothPlastic)
		end
	elseif kind == "SMG" then
		handle.Size = Vector3.new(0.3, 0.4, recLen)
		box("Lower", Vector3.new(0.28, 0.14, recLen * 0.9), at(0, -0.25, 0), POLY, M.SmoothPlastic)
		topRail(-h, h, 0.23)
		handguard(-h, L * 0.16, POLY, true)
		barrel(-h - L * 0.16, B + 0.15, 0.1, 0.04)
		cyl("Suppressor", 0.6, 0.2, at(0, 0.04, info.Muzzle.Z - 0.25), DARKSTEEL)
		info.Muzzle = Vector3.new(0, 0.04, info.Muzzle.Z - 0.55)
		pistolGrip(recLen * 0.25)
		triggerGuard(recLen * 0.25)
		boxMag(-recLen * 0.18, style.Long and 0.75 or 0.62, 0.17)
		box("ForeGrip", Vector3.new(0.14, 0.42, 0.16), at(0, -0.36, -h - L * 0.08), POLY, M.SmoothPlastic)
		-- folding wire stock
		for _, sx in { -0.1, 0.1 } do
			box("StockArm", Vector3.new(0.04, 0.04, 0.8), at(sx, 0.0, h + 0.4), DARKSTEEL)
		end
		box("StockPad", Vector3.new(0.26, 0.4, 0.06), at(0, -0.1, h + 0.82), DARKSTEEL, M.Rubber)
		ejectionPort(-recLen * 0.05)
		box("AccentStripe", Vector3.new(0.31, 0.04, recLen * 0.6), at(0, -0.12, 0), accent, accentMat)
		optic(style.Optic or "RedDot", -recLen * 0.05, 0.23)
	elseif kind == "Sniper" then
		local heavy = style.Heavy
		handle.Size = Vector3.new(0.3, 0.38, recLen)
		box("Chassis", Vector3.new(0.3, 0.2, recLen + 0.6), at(0, -0.24, -0.15), furniture, M.SmoothPlastic)
		local bLen = B + L * 0.42
		barrel(-h, bLen, heavy and 0.17 or 0.13, 0.05)
		cyl("BarrelBase", 0.5, heavy and 0.22 or 0.18, at(0, 0.05, -h - 0.25), DARKSTEEL)
		muzzleBrake(info.Muzzle.Z, heavy and 0.3 or 0.2, heavy and 0.42 or 0.28)
		box("Forend", Vector3.new(0.3, 0.26, L * 0.28), at(0, -0.12, -h - L * 0.14), furniture, M.SmoothPlastic)
		info.Fore = Vector3.new(0, -0.24, -h - L * 0.14)
		pistolGrip(recLen * 0.45, -10, furniture)
		triggerGuard(recLen * 0.45)
		boxMag(-recLen * 0.05, heavy and 0.38 or 0.3, 0.2)
		-- bolt handle
		box("BoltShaft", Vector3.new(0.3, 0.05, 0.05), at(0.22, 0.1, recLen * 0.25), CHROME)
		box("BoltKnob", Vector3.new(0.12, 0.12, 0.12), at(0.38, 0.06, recLen * 0.25), DARKSTEEL)
		fixedStock(h + 0.25, 1.1, false)
		box("CheekRiser", Vector3.new(0.22, 0.16, 0.5), at(0, 0.22, h + 0.65), furniture, M.SmoothPlastic)
		topRail(-h, h, 0.22)
		optic("Scope", -recLen * 0.05, 0.22)
		bipod(-h - L * 0.24, -0.1)
	elseif kind == "Pump" then
		handle.Size = Vector3.new(0.3, 0.42, recLen)
		barrel(-h, B + L * 0.45, 0.17, 0.08)
		cyl("TubeMag", B + L * 0.35, 0.15, at(0, -0.12, -h - (B + L * 0.35) / 2), DARKSTEEL)
		box("Pump", Vector3.new(0.3, 0.26, L * 0.22), at(0, -0.1, -h - L * 0.18), style.Wood and WOOD or POLY, style.Wood and M.Wood or M.SmoothPlastic)
		for i = 1, 5 do
			box("PumpRib", Vector3.new(0.32, 0.03, 0.03), at(0, -0.1 + ((i % 2) * 2 - 1) * 0.06, -h - L * 0.1 - i * 0.06), DARKSTEEL)
		end
		info.Fore = Vector3.new(0, -0.22, -h - L * 0.18)
		box("Bead", Vector3.new(0.05, 0.05, 0.05), at(0, 0.19, info.Muzzle.Z + 0.05), CHROME)
		box("LoadingGate", Vector3.new(0.2, 0.04, 0.3), at(0, -0.21, -recLen * 0.05), DARKSTEEL)
		ejectionPort(-recLen * 0.1)
		pistolGrip(recLen * 0.3, -20, style.Wood and WOOD or POLY)
		triggerGuard(recLen * 0.3)
		fixedStock(h, 1.0, style.Wood)
		info.Sight = 0.22
	elseif kind == "DoubleBarrel" then
		handle.Size = Vector3.new(0.34, 0.34, recLen * 0.7)
		handle.Color = CHROME
		local bLen = B + L * 0.5
		for _, sx in { -0.085, 0.085 } do
			cyl("Barrel", bLen, 0.16, at(sx, 0.06, -recLen * 0.35 - bLen / 2), DARKSTEEL)
		end
		box("Rib", Vector3.new(0.06, 0.04, bLen), at(0, 0.15, -recLen * 0.35 - bLen / 2), DARKSTEEL)
		box("Forend", Vector3.new(0.3, 0.2, L * 0.24), at(0, -0.1, -recLen * 0.35 - L * 0.14), WOOD, M.Wood)
		info.Fore = Vector3.new(0, -0.2, -recLen * 0.35 - L * 0.14)
		info.Muzzle = Vector3.new(0, 0.06, -recLen * 0.35 - bLen)
		box("Hammer", Vector3.new(0.05, 0.14, 0.1), at(0.08, 0.2, recLen * 0.3), DARKSTEEL)
		box("Hammer2", Vector3.new(0.05, 0.14, 0.1), at(-0.08, 0.2, recLen * 0.3), DARKSTEEL)
		box("Wrist", Vector3.new(0.24, 0.3, 0.5), at(0, -0.12, recLen * 0.35 + 0.22) * CFrame.Angles(math.rad(-12), 0, 0), WOOD, M.Wood)
		info.Grip = Vector3.new(0, -0.3, recLen * 0.35 + 0.22)
		triggerGuard(recLen * 0.35)
		fixedStock(recLen * 0.35 + 0.45, 1.05, true)
		info.Sight = 0.2
	elseif kind == "Minigun" then
		handle.Size = Vector3.new(0.6, 0.6, recLen)
		handle.Color = look.Body
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			cyl("Barrel" .. i, B + 1.0, 0.11, at(math.cos(a) * 0.17, 0.05 + math.sin(a) * 0.17, -h - (B + 1.0) / 2), DARKSTEEL)
		end
		for _, dz in { 0.15, B * 0.6 + 0.4, B + 0.85 } do
			cyl("BarrelClamp", 0.08, 0.48, at(0, 0.05, -h - dz), STEEL)
		end
		cyl("Motor", 0.5, 0.5, at(0, 0.05, -h + 0.05), accent, accentMat)
		info.Muzzle = Vector3.new(0, 0.05, -h - B - 1.0)
		box("AmmoBox", Vector3.new(0.5, 0.7, 0.9), at(0.55, -0.4, 0.1), rgb(70, 78, 52), M.Metal)
		box("Feed", Vector3.new(0.3, 0.12, 0.5), at(0.32, -0.05, 0), CHROME)
		box("RearHandle", Vector3.new(0.6, 0.08, 0.08), at(0, 0.0, h + 0.35), DARKSTEEL)
		box("RearGrip", Vector3.new(0.12, 0.5, 0.14), at(0, -0.25, h + 0.35), POLY, M.SmoothPlastic)
		box("TopHandle", Vector3.new(0.08, 0.08, 0.7), at(0, 0.5, 0), DARKSTEEL)
		box("TopPost", Vector3.new(0.08, 0.22, 0.08), at(0, 0.38, 0.3), DARKSTEEL)
		box("TopPost2", Vector3.new(0.08, 0.22, 0.08), at(0, 0.38, -0.3), DARKSTEEL)
		info.Grip = Vector3.new(0, -0.25, h + 0.35)
		info.Fore = Vector3.new(0, 0.5, 0)
		info.Sight = 0.62
	elseif kind == "RPG" then
		handle.Size = Vector3.new(0.3, 0.3, recLen)
		cyl("Tube", L + 0.6, 0.6, at(0, 0.2, -0.1), look.Body, M.Metal)
		cyl("TubeRear", 0.5, 0.75, at(0, 0.2, L / 2 + 0.1), DARKSTEEL)
		cyl("Venturi", 0.3, 0.55, at(0, 0.2, L / 2 + 0.45), DARKSTEEL)
		-- warhead: stacked cylinders tapering to a point
		local z = -L / 2 - 0.4
		for i, d in { 0.62, 0.72, 0.62, 0.45, 0.25 } do
			cyl("Warhead" .. i, 0.22, d, at(0, 0.2, z - (i - 1) * 0.2), i <= 2 and rgb(80, 92, 62) or rgb(70, 80, 54))
		end
		cyl("WarheadRing", 0.06, 0.74, at(0, 0.2, z - 0.1), accent, accentMat)
		info.Muzzle = Vector3.new(0, 0.2, -L / 2 - 0.4)
		pistolGrip(0.2, -10)
		triggerGuard(0.2)
		box("ForeGrip", Vector3.new(0.16, 0.42, 0.18), at(0, -0.3, -0.9), POLY, M.SmoothPlastic)
		info.Fore = Vector3.new(0, -0.3, -0.9)
		box("OpticArm", Vector3.new(0.18, 0.08, 0.2), at(-0.36, 0.25, -0.2), DARKSTEEL)
		cyl("Optic", 0.5, 0.18, at(-0.45, 0.42, -0.2), DARKSTEEL)
		box("ShoulderPad", Vector3.new(0.5, 0.15, 0.6), at(0, -0.12, 0.8), POLY, M.Fabric)
		info.Sight = 0.6
	elseif kind == "GL" then
		handle.Size = Vector3.new(0.3, 0.4, recLen)
		cyl("Cylinder", 0.55, 0.95, at(0, -0.05, -h - 0.28), look.Body, M.Metal)
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			cyl("Chamber" .. i, 0.57, 0.2, at(math.cos(a) * 0.3, -0.05 + math.sin(a) * 0.3, -h - 0.28), rgb(20, 20, 22))
		end
		cyl("Spindle", 0.6, 0.12, at(0, -0.05, -h - 0.28), accent, accentMat)
		barrel(-h - 0.56, B + 0.5, 0.36, 0.1)
		box("BarrelRail", Vector3.new(0.08, 0.06, B + 0.5), at(0, 0.31, -h - 0.56 - (B + 0.5) / 2), DARKSTEEL)
		box("ForeGrip", Vector3.new(0.14, 0.44, 0.16), at(0, -0.3, info.Muzzle.Z + 0.35), POLY, M.SmoothPlastic)
		info.Fore = Vector3.new(0, -0.3, info.Muzzle.Z + 0.35)
		pistolGrip(recLen * 0.2)
		triggerGuard(recLen * 0.2)
		adjustableStock(h)
		optic("Holo", 0, 0.22)
		topRail(-h, h, 0.22)
	elseif kind == "Railgun" then
		handle.Size = Vector3.new(0.36, 0.44, recLen)
		handle.Color = look.Body
		for _, sx in { -0.16, 0.16 } do
			box("Rail", Vector3.new(0.1, 0.18, L * 0.55 + B), at(sx, 0.04, -h - (L * 0.55 + B) / 2), DARKSTEEL)
		end
		for i = 1, 6 do
			local z = -h - i * ((L * 0.55 + B) / 7)
			box("Coil", Vector3.new(0.26, 0.04, 0.06), at(0, 0.04, z), accent, M.Neon)
			cyl("CoilRing", 0.06, 0.42, at(0, 0.04, z), DARKSTEEL)
		end
		info.Muzzle = Vector3.new(0, 0.04, -h - L * 0.55 - B)
		box("Capacitor", Vector3.new(0.32, 0.24, 0.6), at(0, -0.3, -recLen * 0.1), POLY, M.SmoothPlastic)
		box("CapacitorGlow", Vector3.new(0.34, 0.06, 0.5), at(0, -0.3, -recLen * 0.1), accent, M.Neon)
		pistolGrip(recLen * 0.3)
		triggerGuard(recLen * 0.3)
		fixedStock(h, 1.0, false)
		box("StockGlow", Vector3.new(0.26, 0.04, 0.8), at(0, 0.05, h + 0.5), accent, M.Neon)
		topRail(-h, h, 0.24)
		optic("Scope", -recLen * 0.05, 0.24)
		info.Fore = Vector3.new(0, -0.15, -h - 0.4)
	else -- pistols & revolvers
		local P = L
		if kind == "Revolver" then
			handle.Size = Vector3.new(0.24, 0.32, P * 0.35)
			local fat = style.Fat
			cyl("Cylinder", 0.42, fat and 0.5 or 0.42, at(0, 0.0, -P * 0.06), CHROME)
			for i = 1, 6 do
				local a = i / 6 * math.pi * 2
				box("Flute", Vector3.new(0.05, 0.05, 0.38), at(math.cos(a) * (fat and 0.24 or 0.2), math.sin(a) * (fat and 0.24 or 0.2), -P * 0.06), DARKSTEEL)
			end
			barrel(-P * 0.06 - 0.21, B + P * 0.35, fat and 0.2 or 0.16, 0.08)
			box("TopRib", Vector3.new(0.08, 0.08, B + P * 0.35), at(0, 0.2, -P * 0.06 - 0.21 - (B + P * 0.35) / 2), STEEL)
			box("Ejector", Vector3.new(0.08, 0.08, B + P * 0.25), at(0, -0.06, -P * 0.06 - 0.21 - (B + P * 0.25) / 2), STEEL)
			box("FrontSight", Vector3.new(0.04, 0.1, 0.08), at(0, 0.28, info.Muzzle.Z + 0.08), accent, accentMat)
			box("Hammer", Vector3.new(0.06, 0.16, 0.12), at(0, 0.18, P * 0.18) * CFrame.Angles(math.rad(-30), 0, 0), DARKSTEEL)
			box("Grip", Vector3.new(0.22, 0.62, 0.3), at(0, -0.36, P * 0.2) * CFrame.Angles(math.rad(-22), 0, 0), WOOD, M.Wood)
			info.Grip = Vector3.new(0, -0.36, P * 0.2)
			triggerGuard(P * 0.12)
			info.Sight = 0.3
		else
			-- slide + frame
			local slideLen = P * 0.9
			handle.Size = Vector3.new(0.22, 0.2, slideLen * 0.8)
			handle.CFrame = at(0, -0.1, 0)
			box("Slide", Vector3.new(0.24, 0.22, slideLen), at(0, 0.1, -0.05), kind == "EnergyPistol" and look.Body or STEEL, kind == "EnergyPistol" and M.SmoothPlastic or M.Metal)
			for i = 1, 6 do
				box("Serration", Vector3.new(0.25, 0.14, 0.025), at(0, 0.11, slideLen / 2 - 0.12 - i * 0.06), DARKSTEEL)
			end
			box("EjectionPort", Vector3.new(0.03, 0.1, 0.24), at(0.12, 0.13, -0.05), DARKSTEEL)
			box("Frame", Vector3.new(0.22, 0.14, slideLen * 0.85), at(0, -0.06, -0.08), POLY, M.SmoothPlastic)
			box("Grip", Vector3.new(0.22, 0.6, 0.32), at(0, -0.38, slideLen * 0.28) * CFrame.Angles(math.rad(-16), 0, 0), POLY, M.SmoothPlastic)
			info.Grip = Vector3.new(0, -0.38, slideLen * 0.28)
			box("TriggerGuard", Vector3.new(0.05, 0.05, 0.36), at(0, -0.28, slideLen * 0.02), POLY, M.SmoothPlastic)
			box("Trigger", Vector3.new(0.04, 0.14, 0.04), at(0, -0.19, slideLen * 0.06), DARKSTEEL)
			cyl("Barrel", 0.12, 0.12, at(0, 0.1, -slideLen / 2 - 0.08), DARKSTEEL)
			info.Muzzle = Vector3.new(0, 0.1, -slideLen / 2 - 0.15)
			box("FrontSight", Vector3.new(0.04, 0.06, 0.05), at(0, 0.24, -slideLen / 2 + 0.06), accent, accentMat)
			box("RearSight", Vector3.new(0.16, 0.06, 0.05), at(0, 0.24, slideLen / 2 - 0.06), DARKSTEEL)
			info.Sight = 0.26
			if kind == "MachinePistol" then
				box("ExtMag", Vector3.new(0.18, 0.55, 0.26), at(0, -0.86, slideLen * 0.36) * CFrame.Angles(math.rad(-16), 0, 0), POLY, M.SmoothPlastic)
				cyl("Compensator", 0.22, 0.2, at(0, 0.1, -slideLen / 2 - 0.15), DARKSTEEL)
				box("ForeGrip", Vector3.new(0.12, 0.36, 0.14), at(0, -0.3, -slideLen * 0.35), POLY, M.SmoothPlastic)
				info.Muzzle = Vector3.new(0, 0.1, -slideLen / 2 - 0.27)
				info.Fore = Vector3.new(0, -0.3, -slideLen * 0.35)
			elseif kind == "EnergyPistol" then
				for i = 1, 3 do
					box("Coil", Vector3.new(0.26, 0.05, 0.05), at(0, 0.1, -slideLen / 2 + i * 0.14), accent, M.Neon)
				end
				cyl("Emitter", 0.12, 0.2, at(0, 0.1, -slideLen / 2 - 0.08), accent, M.Neon)
			else
				box("MagBase", Vector3.new(0.24, 0.06, 0.32), at(0, -0.68, slideLen * 0.35) * CFrame.Angles(math.rad(-16), 0, 0), DARKSTEEL)
			end
		end
		info.Fore = info.Fore.Z < 0 and info.Fore or Vector3.new(0, -0.38, P * 0.05)
		if kind ~= "MachinePistol" then
			info.Fore = Vector3.new(0, -0.42, P * 0.2 + 0.05) -- two-handed pistol grip
		end
	end

	if golden then
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") and p.Material ~= M.Neon and p.Material ~= M.Glass then
				p.Color = (p.Color == DARKSTEEL or p.Color == POLY) and rgb(190, 140, 30) or GOLD
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
		a.Position = handle.CFrame:PointToObjectSpace(pos)
		a.Parent = handle
	end
	attachment("Muzzle", info.Muzzle)
	attachment("Sight", Vector3.new(0, info.Sight, 0))
	attachment("GripPoint", info.Grip)
	attachment("ForePoint", info.Fore)
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
