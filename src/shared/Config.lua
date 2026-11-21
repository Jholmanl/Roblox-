-- Global game tuning. Change numbers here to rebalance the whole game.
local Config = {}

Config.GameName = "NEON STRIKE"
Config.ModeName = "TEAM DEATHMATCH" -- default; the live mode is ReplicatedStorage.Mode

-- Match flow
Config.IntermissionLength = 20 -- warmup before each match (seconds)
Config.MatchLength = 300 -- 5 minute matches
Config.ResultsLength = 10 -- podium / match summary
Config.VoteLength = 5 -- pre-match map + mode vote (seconds)
Config.KillsToWin = 30 -- (unused in team mode)
Config.TeamKillsToWin = 75 -- first team to this many kills wins
Config.MaxPlayers = 30 -- set the same number in Game Settings > Places

-- Bots fill the server up to this many combatants so it is never empty
Config.BotFill = 12 -- bots keep both teams filled up to this many fighters total
Config.BotDamageMultiplier = 0.45
Config.BotAccuracy = 0.38

-- Teams (spawns are at opposite ends of every map)
Config.Teams = {
	A = { Name = "ALPHA", Color = Color3.fromRGB(40, 140, 255), Brick = "Bright blue" },
	B = { Name = "BRAVO", Color = Color3.fromRGB(255, 70, 70), Brick = "Bright red" },
	C = { Name = "CHARLIE", Color = Color3.fromRGB(70, 220, 90), Brick = "Lime green" },
}

-- Game modes (players vote for the next mode on the results screen)
Config.Modes = {
	FFA = { Name = "FREE FOR ALL", Short = "FFA", Teams = {}, KillsToWin = 30, Desc = "Everyone for themselves. Spawns all over the map." },
	TDM = { Name = "TEAM DEATHMATCH", Short = "TDM", Teams = { "A", "B" }, KillsToWin = 75, Desc = "Alpha vs Bravo. Spawns at opposite ends." },
	TTDM = { Name = "TRIPLE TEAM DEATHMATCH", Short = "3TDM", Teams = { "A", "B", "C" }, KillsToWin = 60, Desc = "Alpha vs Bravo vs Charlie. Three bases." },
}
Config.ModeOrder = { "TDM", "FFA", "TTDM" }

-- Downed / revive: only players on a 5+ kill streak get knocked down instead of dying
Config.DownStreak = 5
Config.DownedHealth = 60 -- downed players bleed this much HP
Config.BleedRate = 3 -- HP per second (about 20 seconds to bleed out)
Config.ReviveTime = 2.5 -- seconds a teammate holds E
Config.SelfReviveTime = 4 -- seconds to hold F for a self revive (once per down)
Config.ReviveHealth = 0.5 -- share of max HP after a revive

-- Players
Config.BaseHealth = 100
Config.BaseWalkSpeed = 16
Config.SprintSpeed = 24
Config.AimWalkSpeed = 11
Config.RespawnTime = 4
Config.InstantRespawnTime = 0.5
Config.SpawnProtection = 2
Config.RegenDelay = 5
Config.RegenRate = 14 -- hp per second once regen starts

-- Movement abilities
Config.DashCooldown = 3
Config.DashSpeed = 95
Config.DashDuration = 0.18
Config.SlideDuration = 0.9
Config.SlideCooldown = 1.1
Config.SlideSpeed = 58
Config.AirJumps = 1 -- double jump for everyone, Triple Jump pass adds one
Config.AirJumpPower = 48
Config.SlamCooldown = 6
Config.SlamRadius = 14
Config.SlamDamage = 75
Config.SlamMinHeight = 8

-- Equipment
Config.Grenades = 2
Config.GrenadeRegen = 20 -- seconds per grenade
Config.GrenadeFuse = 2.2
Config.GrenadeRadius = 18
Config.GrenadeDamage = 120
Config.KnifeDamage = 100
Config.KnifeRange = 8
Config.KnifeCooldown = 0.7

-- Rewards
Config.KillScore = 100
Config.KillCash = 25
Config.KillXP = 100
Config.AssistScore = 50
Config.AssistCash = 10
Config.AssistXP = 40
Config.WinCash = 250
Config.WinXP = 1000
Config.Top3Cash = 100
Config.MatchPlayXP = 250
Config.MultiKillWindow = 4
Config.StartingCash = 500
Config.MaxLevel = 100
Config.DailyRewards = { 100, 150, 250, 400, 600, 900, 1500 }

function Config.XPForLevel(level: number): number
	return 500 + level * 250
end

-- Killstreaks are awarded automatically when the streak is reached.
Config.Killstreaks = {
	{ Id = "UAV", Kills = 3, Name = "UAV RADAR", Icon = "📡", Duration = 20 },
	{ Id = "Overdrive", Kills = 5, Name = "OVERDRIVE", Icon = "⚡", Duration = 15 },
	{ Id = "Airstrike", Kills = 7, Name = "AIRSTRIKE", Icon = "✈️" },
	{ Id = "InfiniteAmmo", Kills = 15, Name = "INFINITE AMMO", Icon = "♾️" },
	{ Id = "Nuke", Kills = 20, Name = "TACTICAL NUKE", Icon = "☢️" },
}
Config.AirstrikeRadius = 16
Config.AirstrikeDamage = 160
Config.NukeCountdown = 10

-- Map info for menus (the maps themselves live in ServerScriptService.Server.Maps)
Config.Maps = {
	Downtown = { Name = "DOWNTOWN", Icon = "🏙️", Desc = "City streets & rooftops" },
	Harbor = { Name = "HARBOR", Icon = "⚓", Desc = "Containers, cranes & a cargo ship" },
	Timberline = { Name = "TIMBERLINE", Icon = "🌲", Desc = "Forest river valley" },
	Arena = { Name = "NEON ARENA", Icon = "⚡", Desc = "Fast close-quarters arena" },
}

-- Set true to pretend you own every game pass while testing in Studio.
Config.StudioGrantAllPasses = false

Config.Colors = {
	Accent = Color3.fromRGB(255, 198, 26),
	Accent2 = Color3.fromRGB(0, 204, 255),
	Red = Color3.fromRGB(255, 64, 72),
	Green = Color3.fromRGB(70, 230, 120),
	Gold = Color3.fromRGB(255, 205, 60),
	Purple = Color3.fromRGB(170, 90, 255),
	Robux = Color3.fromRGB(0, 178, 110),
}

return Config
