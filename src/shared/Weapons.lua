-- Weapon definitions. Every gun in the game is data-driven from this table.
-- Price = in-game cash, Level = level needed to buy, Pass = Robux game pass needed.
local Weapons = {}

Weapons.Defs = {
	-- PRIMARIES ---------------------------------------------------------
	Striker = {
		Name = "STRIKER AR", Class = "Assault Rifle", Slot = "Primary",
		Damage = 24, HeadMult = 1.6, FireRate = 10, Auto = true,
		Mag = 30, Reserve = 150, Reload = 2.0,
		Spread = 2.2, AdsSpread = 0.4, Range = 600, FalloffStart = 120,
		Recoil = 0.9, ZoomFov = 55, Speed = 1.0,
		Price = 0, Level = 1,
		Look = { Body = Color3.fromRGB(45, 48, 56), Accent = Color3.fromRGB(255, 198, 26), Length = 2.6, Barrel = 1.0, Scope = false },
	},
	Viper = {
		Name = "VIPER SMG", Class = "SMG", Slot = "Primary",
		Damage = 17, HeadMult = 1.4, FireRate = 15, Auto = true,
		Mag = 35, Reserve = 175, Reload = 1.6,
		Spread = 3.0, AdsSpread = 1.0, Range = 300, FalloffStart = 60,
		Recoil = 0.6, ZoomFov = 60, Speed = 1.1,
		Price = 750, Level = 3,
		Look = { Body = Color3.fromRGB(30, 30, 34), Accent = Color3.fromRGB(0, 204, 255), Length = 1.9, Barrel = 0.6, Scope = false },
	},
	Brute = {
		Name = "BRUTE SHOTGUN", Class = "Shotgun", Slot = "Primary",
		Damage = 14, HeadMult = 1.3, FireRate = 1.3, Auto = false, Pellets = 9,
		Mag = 6, Reserve = 36, Reload = 2.6,
		Spread = 6.5, AdsSpread = 4.5, Range = 140, FalloffStart = 25,
		Recoil = 4.5, ZoomFov = 62, Speed = 1.0,
		Price = 1500, Level = 5,
		Look = { Body = Color3.fromRGB(90, 60, 40), Accent = Color3.fromRGB(255, 120, 40), Length = 2.8, Barrel = 1.2, Scope = false },
	},
	Hornet = {
		Name = "HORNET BURST", Class = "Burst Rifle", Slot = "Primary",
		Damage = 31, HeadMult = 1.7, FireRate = 4, Auto = false, Burst = 3, BurstDelay = 0.06,
		Mag = 24, Reserve = 120, Reload = 2.1,
		Spread = 1.6, AdsSpread = 0.2, Range = 700, FalloffStart = 160,
		Recoil = 1.2, ZoomFov = 50, Speed = 1.0,
		Price = 3000, Level = 10,
		Look = { Body = Color3.fromRGB(240, 240, 240), Accent = Color3.fromRGB(255, 200, 0), Length = 2.7, Barrel = 0.9, Scope = true },
	},
	Inferno = {
		Name = "INFERNO LMG", Class = "LMG", Slot = "Primary",
		Damage = 26, HeadMult = 1.5, FireRate = 11, Auto = true,
		Mag = 100, Reserve = 300, Reload = 4.2,
		Spread = 3.2, AdsSpread = 1.0, Range = 600, FalloffStart = 140,
		Recoil = 1.1, ZoomFov = 55, Speed = 0.85,
		Price = 6000, Level = 18,
		Look = { Body = Color3.fromRGB(70, 75, 50), Accent = Color3.fromRGB(255, 70, 30), Length = 3.2, Barrel = 1.3, Scope = false },
	},
	Longbow = {
		Name = "LONGBOW SNIPER", Class = "Sniper", Slot = "Primary",
		Damage = 95, HeadMult = 2.5, FireRate = 0.9, Auto = false, Penetrate = 1,
		Mag = 5, Reserve = 30, Reload = 3.0,
		Spread = 8, AdsSpread = 0, Range = 1500, FalloffStart = 1500,
		Recoil = 6, ZoomFov = 18, Speed = 0.9, Scoped = true,
		Price = 8000, Level = 25,
		Look = { Body = Color3.fromRGB(40, 55, 45), Accent = Color3.fromRGB(120, 255, 120), Length = 3.6, Barrel = 1.6, Scope = true },
	},
	Railgun = {
		Name = "RAILGUN", Class = "Exotic", Slot = "Primary",
		Damage = 110, HeadMult = 2, FireRate = 1.2, Auto = false, Penetrate = 99,
		Mag = 6, Reserve = 48, Reload = 2.4,
		Spread = 1, AdsSpread = 0, Range = 2000, FalloffStart = 2000,
		Recoil = 5, ZoomFov = 30, Speed = 1.0, Scoped = true,
		Price = 0, Level = 1, Pass = "Railgun",
		Look = { Body = Color3.fromRGB(20, 20, 30), Accent = Color3.fromRGB(170, 90, 255), Length = 3.4, Barrel = 1.4, Scope = true, Neon = true },
	},

	-- SECONDARIES ------------------------------------------------------
	Sidekick = {
		Name = "SIDEKICK PISTOL", Class = "Pistol", Slot = "Secondary",
		Damage = 28, HeadMult = 1.8, FireRate = 6, Auto = false,
		Mag = 12, Reserve = 72, Reload = 1.3,
		Spread = 1.6, AdsSpread = 0.4, Range = 300, FalloffStart = 60,
		Recoil = 1.4, ZoomFov = 62, Speed = 1.1,
		Price = 0, Level = 1,
		Look = { Body = Color3.fromRGB(40, 40, 44), Accent = Color3.fromRGB(200, 200, 200), Length = 1.1, Barrel = 0.2, Scope = false },
	},
	Stinger = {
		Name = "STINGER MACHINE PISTOL", Class = "Pistol", Slot = "Secondary",
		Damage = 16, HeadMult = 1.4, FireRate = 14, Auto = true,
		Mag = 20, Reserve = 120, Reload = 1.4,
		Spread = 3.0, AdsSpread = 1.4, Range = 200, FalloffStart = 40,
		Recoil = 0.7, ZoomFov = 64, Speed = 1.1,
		Price = 1200, Level = 7,
		Look = { Body = Color3.fromRGB(25, 25, 30), Accent = Color3.fromRGB(255, 60, 160), Length = 1.3, Barrel = 0.3, Scope = false },
	},
	HandCannon = {
		Name = "HAND CANNON", Class = "Revolver", Slot = "Secondary",
		Damage = 58, HeadMult = 2.0, FireRate = 2.2, Auto = false,
		Mag = 6, Reserve = 36, Reload = 2.2,
		Spread = 1.8, AdsSpread = 0.2, Range = 400, FalloffStart = 100,
		Recoil = 4, ZoomFov = 58, Speed = 1.05,
		Price = 4000, Level = 14,
		Look = { Body = Color3.fromRGB(160, 160, 170), Accent = Color3.fromRGB(255, 198, 26), Length = 1.4, Barrel = 0.5, Scope = false },
	},
}

Weapons.Order = { "Striker", "Viper", "Brute", "Hornet", "Inferno", "Longbow", "Railgun", "Sidekick", "Stinger", "HandCannon" }

function Weapons.Get(id: string)
	return Weapons.Defs[id]
end

-- Mag/reserve sizes include the Extended Mags pass bonus.
function Weapons.MagSize(def, extended: boolean): number
	return extended and math.floor(def.Mag * 1.5) or def.Mag
end

function Weapons.ReserveSize(def, extended: boolean): number
	return extended and def.Reserve * 2 or def.Reserve
end

return Weapons
