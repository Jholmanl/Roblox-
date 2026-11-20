-- Every achievement is "Stat reaches Goal". Stats are tracked by AchievementService.
-- Category is used for the tabs in the achievements menu.
local Achievements = {}

local list = {
	-- Combat
	{ Id = "FirstKill", Name = "Fresh Meat", Desc = "Get your first elimination", Stat = "Kills", Goal = 1, Reward = 100, Icon = "🎯", Category = "Combat" },
	{ Id = "Kills50", Name = "Sharpshooter", Desc = "Get 50 eliminations", Stat = "Kills", Goal = 50, Reward = 500, Icon = "🎯", Category = "Combat" },
	{ Id = "Kills250", Name = "Veteran", Desc = "Get 250 eliminations", Stat = "Kills", Goal = 250, Reward = 1500, Icon = "🎖️", Category = "Combat" },
	{ Id = "Kills1000", Name = "War Machine", Desc = "Get 1,000 eliminations", Stat = "Kills", Goal = 1000, Reward = 5000, Icon = "🤖", Category = "Combat" },
	{ Id = "Kills5000", Name = "Living Legend", Desc = "Get 5,000 eliminations", Stat = "Kills", Goal = 5000, Reward = 20000, Icon = "👑", Category = "Combat" },
	{ Id = "Head10", Name = "Head Hunter", Desc = "Land 10 headshot kills", Stat = "Headshots", Goal = 10, Reward = 300, Icon = "💀", Category = "Combat" },
	{ Id = "Head100", Name = "Brain Surgeon", Desc = "Land 100 headshot kills", Stat = "Headshots", Goal = 100, Reward = 2000, Icon = "🧠", Category = "Combat" },
	{ Id = "Head500", Name = "Deadeye", Desc = "Land 500 headshot kills", Stat = "Headshots", Goal = 500, Reward = 8000, Icon = "👁️", Category = "Combat" },
	{ Id = "Assist25", Name = "Team Player", Desc = "Earn 25 assists", Stat = "Assists", Goal = 25, Reward = 400, Icon = "🤝", Category = "Combat" },
	{ Id = "Damage50k", Name = "Damage Dealer", Desc = "Deal 50,000 total damage", Stat = "Damage", Goal = 50000, Reward = 3000, Icon = "💥", Category = "Combat" },

	-- Streaks & multi kills
	{ Id = "Streak5", Name = "Killing Spree", Desc = "Get a 5 kill streak", Stat = "BestStreak", Goal = 5, Reward = 300, Icon = "🔥", Category = "Streaks" },
	{ Id = "Streak10", Name = "Dominating", Desc = "Get a 10 kill streak", Stat = "BestStreak", Goal = 10, Reward = 1000, Icon = "🔥", Category = "Streaks" },
	{ Id = "Streak15", Name = "Nuclear Option", Desc = "Get a 15 kill streak", Stat = "BestStreak", Goal = 15, Reward = 3000, Icon = "☢️", Category = "Streaks" },
	{ Id = "Streak25", Name = "Untouchable", Desc = "Get a 25 kill streak", Stat = "BestStreak", Goal = 25, Reward = 10000, Icon = "😇", Category = "Streaks" },
	{ Id = "Double", Name = "Double Trouble", Desc = "Get a Double Kill", Stat = "DoubleKills", Goal = 1, Reward = 150, Icon = "✌️", Category = "Streaks" },
	{ Id = "Triple", Name = "Hat Trick", Desc = "Get a Triple Kill", Stat = "TripleKills", Goal = 1, Reward = 400, Icon = "🎩", Category = "Streaks" },
	{ Id = "Quad", Name = "Fourth Horseman", Desc = "Get a Quad Kill", Stat = "QuadKills", Goal = 1, Reward = 1000, Icon = "🐎", Category = "Streaks" },
	{ Id = "Rampage", Name = "Rampage", Desc = "Get 5+ kills in rapid succession", Stat = "Rampages", Goal = 1, Reward = 2500, Icon = "🌪️", Category = "Streaks" },
	{ Id = "KO1", Name = "K.O!", Desc = "Get a K.O Streak (5 kills without dying)", Stat = "KOStreaks", Goal = 1, Reward = 300, Icon = "🔥", Category = "Streaks" },
	{ Id = "KO25", Name = "Knockout Artist", Desc = "Get 25 K.O Streaks", Stat = "KOStreaks", Goal = 25, Reward = 3000, Icon = "🥊", Category = "Streaks" },
	{ Id = "Infinite1", Name = "Bottomless Mag", Desc = "Earn Infinite Ammo (15 kills without dying)", Stat = "InfiniteAmmos", Goal = 1, Reward = 2500, Icon = "♾️", Category = "Streaks" },
	{ Id = "UAV1", Name = "Eyes in the Sky", Desc = "Call in a UAV", Stat = "UAVs", Goal = 1, Reward = 200, Icon = "📡", Category = "Streaks" },
	{ Id = "Overdrive1", Name = "Overclocked", Desc = "Activate Overdrive", Stat = "Overdrives", Goal = 1, Reward = 300, Icon = "⚡", Category = "Streaks" },
	{ Id = "Airstrike1", Name = "Danger Close", Desc = "Call in an Airstrike", Stat = "Airstrikes", Goal = 1, Reward = 500, Icon = "✈️", Category = "Streaks" },
	{ Id = "AirstrikeKills", Name = "Carpet Bomber", Desc = "Get 25 Airstrike kills", Stat = "AirstrikeKills", Goal = 25, Reward = 2500, Icon = "💣", Category = "Streaks" },
	{ Id = "Nuke1", Name = "Mutually Assured", Desc = "Drop a Tactical Nuke (20 kill streak)", Stat = "Nukes", Goal = 1, Reward = 5000, Icon = "☢️", Category = "Streaks" },

	-- Style (the stuff that makes Neon Strike different)
	{ Id = "Slide1", Name = "Slippery", Desc = "Get a kill while sliding", Stat = "SlideKills", Goal = 1, Reward = 200, Icon = "🛝", Category = "Style" },
	{ Id = "Slide50", Name = "Ice Skater", Desc = "Get 50 sliding kills", Stat = "SlideKills", Goal = 50, Reward = 2000, Icon = "⛸️", Category = "Style" },
	{ Id = "Air1", Name = "Sky High", Desc = "Get a kill while airborne", Stat = "AirKills", Goal = 1, Reward = 200, Icon = "🪂", Category = "Style" },
	{ Id = "Air100", Name = "Air Superiority", Desc = "Get 100 airborne kills", Stat = "AirKills", Goal = 100, Reward = 3000, Icon = "🦅", Category = "Style" },
	{ Id = "Dash1", Name = "Blink Strike", Desc = "Get a kill right after dashing", Stat = "DashKills", Goal = 1, Reward = 200, Icon = "💨", Category = "Style" },
	{ Id = "Dash50", Name = "Phase Shifter", Desc = "Get 50 dash kills", Stat = "DashKills", Goal = 50, Reward = 2000, Icon = "🌀", Category = "Style" },
	{ Id = "Slam1", Name = "Meteor", Desc = "Eliminate someone with a Ground Slam", Stat = "SlamKills", Goal = 1, Reward = 400, Icon = "☄️", Category = "Style" },
	{ Id = "Slam25", Name = "Earthshaker", Desc = "Get 25 Ground Slam kills", Stat = "SlamKills", Goal = 25, Reward = 3000, Icon = "🌋", Category = "Style" },
	{ Id = "Knife1", Name = "Up Close & Personal", Desc = "Get a knife kill", Stat = "KnifeKills", Goal = 1, Reward = 200, Icon = "🔪", Category = "Style" },
	{ Id = "Knife100", Name = "Butcher", Desc = "Get 100 knife kills", Stat = "KnifeKills", Goal = 100, Reward = 4000, Icon = "🗡️", Category = "Style" },
	{ Id = "Nade1", Name = "Fire in the Hole", Desc = "Get a grenade kill", Stat = "GrenadeKills", Goal = 1, Reward = 200, Icon = "💣", Category = "Style" },
	{ Id = "Nade50", Name = "Demolitionist", Desc = "Get 50 grenade kills", Stat = "GrenadeKills", Goal = 50, Reward = 2500, Icon = "🧨", Category = "Style" },
	{ Id = "LongShot", Name = "Long Distance Call", Desc = "Kill someone from 150+ studs", Stat = "LongShots", Goal = 1, Reward = 300, Icon = "🔭", Category = "Style" },
	{ Id = "LongShot50", Name = "Ghost Sniper", Desc = "Get 50 long shot kills", Stat = "LongShots", Goal = 50, Reward = 3000, Icon = "👻", Category = "Style" },
	{ Id = "NoScope", Name = "No Scope", Desc = "Get a sniper kill without aiming", Stat = "NoScopes", Goal = 1, Reward = 500, Icon = "🙈", Category = "Style" },
	{ Id = "NoScope25", Name = "Trickshot Artist", Desc = "Get 25 no-scope kills", Stat = "NoScopes", Goal = 25, Reward = 5000, Icon = "🎪", Category = "Style" },
	{ Id = "PointBlank", Name = "In Your Face", Desc = "Get a point-blank kill", Stat = "PointBlanks", Goal = 1, Reward = 150, Icon = "👊", Category = "Style" },
	{ Id = "Collateral", Name = "Two Birds", Desc = "Kill 2 enemies with one bullet", Stat = "Collaterals", Goal = 1, Reward = 1000, Icon = "🐦", Category = "Style" },
	{ Id = "Grave", Name = "From the Grave", Desc = "Get a kill after you've died", Stat = "GraveKills", Goal = 1, Reward = 750, Icon = "⚰️", Category = "Style" },
	{ Id = "Clutch", Name = "Clutch Factor", Desc = "Get a kill with 20 HP or less", Stat = "ClutchKills", Goal = 1, Reward = 250, Icon = "❤️‍🩹", Category = "Style" },
	{ Id = "Clutch50", Name = "Cockroach", Desc = "Get 50 clutch kills", Stat = "ClutchKills", Goal = 50, Reward = 3000, Icon = "🪳", Category = "Style" },
	{ Id = "Roadkill", Name = "Hit and Run", Desc = "Run someone over with a car", Stat = "Roadkills", Goal = 1, Reward = 300, Icon = "🚗", Category = "Vehicles" },
	{ Id = "Roadkill25", Name = "Road Rage", Desc = "Get 25 roadkills", Stat = "Roadkills", Goal = 25, Reward = 3000, Icon = "🏎️", Category = "Vehicles" },
	{ Id = "CarBoom", Name = "Car Bomb", Desc = "Blow up a vehicle", Stat = "CarsDestroyed", Goal = 1, Reward = 300, Icon = "💥", Category = "Vehicles" },
	{ Id = "CarBoom25", Name = "Scrapyard", Desc = "Blow up 25 vehicles", Stat = "CarsDestroyed", Goal = 25, Reward = 3000, Icon = "🔥", Category = "Vehicles" },
	{ Id = "Drive1", Name = "Learner's Permit", Desc = "Get behind the wheel", Stat = "Drives", Goal = 1, Reward = 100, Icon = "🔑", Category = "Vehicles" },
	{ Id = "Drive50", Name = "Getaway Driver", Desc = "Drive 50 times", Stat = "Drives", Goal = 50, Reward = 2000, Icon = "🚙", Category = "Vehicles" },
	{ Id = "Explosive50", Name = "Boom Squad", Desc = "Get 50 explosive kills", Stat = "ExplosiveKills", Goal = 50, Reward = 3000, Icon = "🧨", Category = "Vehicles" },
	{ Id = "JumpPad", Name = "Frequent Flyer", Desc = "Use jump pads 100 times", Stat = "JumpPads", Goal = 100, Reward = 500, Icon = "🚀", Category = "Style" },

	-- Rivalry
	{ Id = "Revenge", Name = "Payback", Desc = "Kill the player who last killed you", Stat = "Revenges", Goal = 1, Reward = 150, Icon = "😤", Category = "Rivalry" },
	{ Id = "Revenge50", Name = "Grudge Holder", Desc = "Get 50 revenge kills", Stat = "Revenges", Goal = 50, Reward = 2000, Icon = "📒", Category = "Rivalry" },
	{ Id = "Bounty", Name = "Bounty Hunter", Desc = "End an enemy's 5+ kill streak", Stat = "Bounties", Goal = 1, Reward = 300, Icon = "💰", Category = "Rivalry" },
	{ Id = "Bounty25", Name = "Most Wanted", Desc = "Claim 25 bounties", Stat = "Bounties", Goal = 25, Reward = 3000, Icon = "🤠", Category = "Rivalry" },
	{ Id = "FirstBlood", Name = "First Blood", Desc = "Get the first kill of a match", Stat = "FirstBloods", Goal = 1, Reward = 250, Icon = "🩸", Category = "Rivalry" },
	{ Id = "Comeback", Name = "Comeback Kid", Desc = "Get a kill after dying 3 times in a row", Stat = "Comebacks", Goal = 1, Reward = 200, Icon = "🔄", Category = "Rivalry" },

	-- Arsenal (weapon mastery achievements are generated below)
	{ Id = "Buy1", Name = "Window Shopper", Desc = "Buy a weapon from the Armory", Stat = "WeaponsBought", Goal = 1, Reward = 100, Icon = "🛒", Category = "Arsenal" },
	{ Id = "Own8", Name = "Collector", Desc = "Own 8 weapons", Stat = "WeaponsOwned", Goal = 8, Reward = 3000, Icon = "🗃️", Category = "Arsenal" },
	{ Id = "Own16", Name = "Arms Dealer", Desc = "Own 16 weapons", Stat = "WeaponsOwned", Goal = 16, Reward = 10000, Icon = "🏪", Category = "Arsenal" },

	-- Career
	{ Id = "Win1", Name = "Winner Winner", Desc = "Win a match", Stat = "Wins", Goal = 1, Reward = 500, Icon = "🏆", Category = "Career" },
	{ Id = "Win10", Name = "Champion", Desc = "Win 10 matches", Stat = "Wins", Goal = 10, Reward = 2500, Icon = "🏆", Category = "Career" },
	{ Id = "Win50", Name = "Dynasty", Desc = "Win 50 matches", Stat = "Wins", Goal = 50, Reward = 10000, Icon = "🏛️", Category = "Career" },
	{ Id = "Top3", Name = "On the Podium", Desc = "Finish top 3 in 10 matches", Stat = "Top3", Goal = 10, Reward = 1500, Icon = "🥉", Category = "Career" },
	{ Id = "Match1", Name = "Reporting for Duty", Desc = "Finish a match", Stat = "Matches", Goal = 1, Reward = 100, Icon = "🪖", Category = "Career" },
	{ Id = "Match100", Name = "Lifer", Desc = "Finish 100 matches", Stat = "Matches", Goal = 100, Reward = 5000, Icon = "📅", Category = "Career" },
	{ Id = "Level10", Name = "Rising Star", Desc = "Reach level 10", Stat = "Level", Goal = 10, Reward = 1000, Icon = "⭐", Category = "Career" },
	{ Id = "Level25", Name = "Elite", Desc = "Reach level 25", Stat = "Level", Goal = 25, Reward = 3000, Icon = "🌟", Category = "Career" },
	{ Id = "Level50", Name = "Commander", Desc = "Reach level 50", Stat = "Level", Goal = 50, Reward = 8000, Icon = "💫", Category = "Career" },
	{ Id = "Level100", Name = "Prestige Master", Desc = "Reach level 100", Stat = "Level", Goal = 100, Reward = 25000, Icon = "💎", Category = "Career" },
	{ Id = "Play60", Name = "Dedicated", Desc = "Play for 60 minutes", Stat = "Minutes", Goal = 60, Reward = 500, Icon = "⏱️", Category = "Career" },
	{ Id = "Play600", Name = "No Life", Desc = "Play for 10 hours", Stat = "Minutes", Goal = 600, Reward = 5000, Icon = "🛌", Category = "Career" },
	{ Id = "Daily7", Name = "Loyal Soldier", Desc = "Claim a 7-day login streak", Stat = "BestDaily", Goal = 7, Reward = 2000, Icon = "📆", Category = "Career" },
	{ Id = "Supporter", Name = "Supporter", Desc = "Buy anything from the Store", Stat = "RobuxPurchases", Goal = 1, Reward = 1000, Icon = "💚", Category = "Career" },
}

-- one mastery achievement per weapon + one "conquer" achievement per map
local Weapons = require(script.Parent.Weapons)
for _, id in Weapons.Order do
	local def = Weapons.Get(id)
	table.insert(list, {
		Id = "M" .. id, Name = def.Name .. " Mastery", Desc = "Get 100 kills with the " .. def.Name,
		Stat = "Kills_" .. id, Goal = 100, Reward = 1000 + (def.Level or 1) * 50, Icon = "🔫", Category = "Arsenal",
	})
end
for _, m in { { "Downtown", "🏙️" }, { "Harbor", "⚓" }, { "Timberline", "🌲" }, { "Arena", "⚡" } } do
	table.insert(list, {
		Id = "Win" .. m[1], Name = "Conquer " .. m[1], Desc = "Win a match on " .. m[1],
		Stat = "Wins_" .. m[1], Goal = 1, Reward = 750, Icon = m[2], Category = "Career",
	})
end

Achievements.List = list
Achievements.ById = {}
Achievements.ByStat = {}
Achievements.Categories = { "Combat", "Streaks", "Style", "Vehicles", "Rivalry", "Arsenal", "Career" }

for _, a in list do
	Achievements.ById[a.Id] = a
	Achievements.ByStat[a.Stat] = Achievements.ByStat[a.Stat] or {}
	table.insert(Achievements.ByStat[a.Stat], a)
end

return Achievements
