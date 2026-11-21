-- ROBUX STORE
-- 1. Create each Game Pass / Developer Product on the Creator Dashboard
--    (create.roblox.com > your experience > Monetization).
-- 2. Paste the numeric ID into the "Id" field below. Price shown in the UI is
--    only a label; the real price is whatever you set on the dashboard.
local Monetization = {}

Monetization.GamePasses = {
	VIP = {
		Id = 0, Price = 499, Icon = "👑", Name = "VIP",
		Perks = { "2x Cash from everything", "+10 Max Health", "Gold name in killfeed & scoreboard", "VIP chat tag" },
		Color = Color3.fromRGB(255, 205, 60),
	},
	DoubleXP = {
		Id = 0, Price = 299, Icon = "⭐", Name = "2x XP",
		Perks = { "Permanent double XP", "Level up & unlock guns 2x faster" },
		Color = Color3.fromRGB(0, 204, 255),
	},
	Juggernaut = {
		Id = 0, Price = 399, Icon = "🛡️", Name = "Juggernaut Armor",
		Perks = { "+35 Max Health", "Take 10% less explosive damage" },
		Color = Color3.fromRGB(120, 140, 160),
	},
	SpeedDemon = {
		Id = 0, Price = 249, Icon = "👟", Name = "Speed Demon",
		Perks = { "+15% movement speed", "Dash cooldown cut in half" },
		Color = Color3.fromRGB(255, 120, 40),
	},
	FastHands = {
		Id = 0, Price = 199, Icon = "✋", Name = "Fast Hands",
		Perks = { "35% faster reloads" },
		Color = Color3.fromRGB(70, 230, 120),
	},
	ExtendedMags = {
		Id = 0, Price = 249, Icon = "📦", Name = "Extended Mags",
		Perks = { "+50% magazine size", "Double reserve ammo" },
		Color = Color3.fromRGB(200, 160, 90),
	},
	GoldenArsenal = {
		Id = 0, Price = 599, Icon = "🏅", Name = "Golden Arsenal",
		Perks = { "+10% damage with ALL guns", "Shiny gold weapon skins" },
		Color = Color3.fromRGB(255, 190, 30),
	},
	RadarPro = {
		Id = 0, Price = 349, Icon = "📡", Name = "Radar Pro",
		Perks = { "Killstreaks need 1 fewer kill", "UAV lasts twice as long" },
		Color = Color3.fromRGB(0, 230, 200),
	},
	InstantRespawn = {
		Id = 0, Price = 149, Icon = "⏩", Name = "Instant Respawn",
		Perks = { "Respawn in 0.5s instead of 4s" },
		Color = Color3.fromRGB(255, 80, 120),
	},
	TripleJump = {
		Id = 0, Price = 149, Icon = "🦘", Name = "Triple Jump",
		Perks = { "One extra mid-air jump" },
		Color = Color3.fromRGB(150, 220, 255),
	},
	Grenadier = {
		Id = 0, Price = 199, Icon = "💣", Name = "Grenadier",
		Perks = { "+2 grenades per life", "Grenades recharge 2x faster" },
		Color = Color3.fromRGB(110, 160, 60),
	},
	Vampire = {
		Id = 0, Price = 299, Icon = "🧛", Name = "Vampire Rounds",
		Perks = { "Heal 25 HP on every kill" },
		Color = Color3.fromRGB(200, 30, 60),
	},
	Phantom = {
		Id = 0, Price = 499, Icon = "👻", Name = "Phantom Vector",
		Perks = { "Exclusive Vector-style SMG", "18 rounds/sec with almost no recoil", "Moves fast, built for close fights" },
		Color = Color3.fromRGB(0, 230, 160),
	},
	Vortex = {
		Id = 0, Price = 349, Icon = "🌀", Name = "Vortex Auto Pistol",
		Perks = { "Full-auto machine pistol sidearm", "33-round extended mag", "Laser + mini red dot" },
		Color = Color3.fromRGB(255, 120, 30),
	},
	Hellcat = {
		Id = 0, Price = 449, Icon = "😈", Name = "Hellcat AR Pistol",
		Perks = { "A full-auto AR as your sidearm", "30-round mag, rifle-class range", "Holo sight + angled grip" },
		Color = Color3.fromRGB(255, 40, 60),
	},
	KnifeKarambit = {
		Id = 0, Price = 199, Icon = "🪝", Name = "Karambit",
		Perks = { "Curved claw knife skin", "Faster knife swings (0.5s)" },
		Color = Color3.fromRGB(255, 70, 90),
	},
	KnifeButterfly = {
		Id = 0, Price = 249, Icon = "🦋", Name = "Butterfly Knife",
		Perks = { "Anodized butterfly knife skin", "Quick swings + extra reach" },
		Color = Color3.fromRGB(160, 120, 255),
	},
	KnifeMachete = {
		Id = 0, Price = 299, Icon = "🗡️", Name = "Jungle Machete",
		Perks = { "Big machete skin", "Longer reach, hits harder" },
		Color = Color3.fromRGB(150, 155, 160),
	},
	KnifeKatana = {
		Id = 0, Price = 499, Icon = "🐉", Name = "Dragon Katana",
		Perks = { "Glowing energy katana", "Longest melee reach in the game" },
		Color = Color3.fromRGB(255, 60, 40),
	},
	Railgun = {
		Id = 0, Price = 799, Icon = "⚡", Name = "Railgun",
		Perks = { "Exclusive weapon", "Pierces through every enemy in a line", "110 damage per shot" },
		Color = Color3.fromRGB(170, 90, 255),
	},
}

Monetization.PassOrder = {
	"VIP", "DoubleXP", "GoldenArsenal", "Juggernaut", "Railgun", "RadarPro",
	"Vampire", "SpeedDemon", "ExtendedMags", "FastHands", "Grenadier", "InstantRespawn", "TripleJump",
	"Phantom", "Vortex", "Hellcat", "KnifeKatana", "KnifeMachete", "KnifeButterfly", "KnifeKarambit",
}

Monetization.Products = {
	Cash1 = { Id = 0, Price = 49, Icon = "💵", Name = "1,000 Cash", Desc = "Buy guns in the Armory", Cash = 1000 },
	Cash2 = { Id = 0, Price = 199, Icon = "💰", Name = "5,000 Cash", Desc = "Most popular!", Cash = 5000 },
	Cash3 = { Id = 0, Price = 799, Icon = "🏦", Name = "25,000 Cash", Desc = "Best value: unlock everything", Cash = 25000 },
	XPBoost = { Id = 0, Price = 99, Icon = "🚀", Name = "3x XP Boost (30 min)", Desc = "Stacks with 2x XP pass", BoostMinutes = 30 },
	Airstrike = { Id = 0, Price = 99, Icon = "✈️", Name = "Airstrike Call-In", Desc = "Call it in any time with [Z]", Token = "Airstrike" },
	Nuke = { Id = 0, Price = 499, Icon = "☢️", Name = "Tactical Nuke", Desc = "Win the match instantly with [X]", Token = "Nuke" },
}

Monetization.ProductOrder = { "Cash2", "Cash1", "Cash3", "XPBoost", "Airstrike", "Nuke" }

function Monetization.FindPassById(id: number)
	for key, pass in Monetization.GamePasses do
		if pass.Id == id and id ~= 0 then
			return key, pass
		end
	end
	return nil
end

function Monetization.FindProductById(id: number)
	for key, product in Monetization.Products do
		if product.Id == id and id ~= 0 then
			return key, product
		end
	end
	return nil
end

return Monetization
