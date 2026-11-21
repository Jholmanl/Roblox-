-- Server-authoritative combat: hitscan validation, damage, kills, medals,
-- grenades, knife, ground slam, health regen and pickups.
--
-- An "entity" is anything that can fight: a real player or a bot.
--   entity.Holder is an Instance whose attributes (Kills, Deaths, Score, Streak)
--   drive the scoreboard. For players it's the Player, for bots a Configuration.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Weapons = require(Shared.Weapons)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)
local GunBuilder = require(Shared.GunBuilder)
local DataService = require(script.Parent.DataService)
local AchievementService = require(script.Parent.AchievementService)
local TeamService = require(script.Parent.TeamService)

local Combat = {}
Combat.Entities = {} -- [character Model] = entity (alive or recently dead)
Combat.ByPlayer = {} -- [Player] = entity
Combat.Hooks = {
	Round = nil, -- RoundService (IsCounting, TakeFirstBlood, OnKill, OnDeath)
	Killstreaks = nil, -- KillstreakService (OnStreak)
	Vehicles = nil, -- VehicleService (CarFromPart, DamageCar, AreaDamage)
}

-- HELPERS --------------------------------------------------------------------
local function hasPass(entity, passKey: string): boolean
	return entity.Player ~= nil and entity.Player:GetAttribute("Pass_" .. passKey) == true
end
Combat.HasPass = hasPass

local function addAttr(holder: Instance, name: string, amount: number)
	holder:SetAttribute(name, (holder:GetAttribute(name) or 0) + amount)
end

local function counting(): boolean
	return Combat.Hooks.Round ~= nil and Combat.Hooks.Round.IsCounting()
end

local function notify(entity, kind, payload)
	if entity and entity.Player then
		Remotes.Notify:FireClient(entity.Player, kind, payload)
	end
end

function Combat.IsAlive(entity): boolean
	return entity ~= nil
		and not entity.Dead
		and entity.Humanoid ~= nil
		and entity.Root ~= nil
		and entity.Humanoid.Health > 0
		and entity.Character ~= nil
		and entity.Character.Parent ~= nil
end

function Combat.MaxHealth(entity): number
	local hp = Config.BaseHealth
	if hasPass(entity, "VIP") then
		hp += 10
	end
	if hasPass(entity, "Juggernaut") then
		hp += 35
	end
	return hp
end

function Combat.MaxGrenades(entity): number
	return Config.Grenades + (hasPass(entity, "Grenadier") and 2 or 0)
end

local function grenadeInterval(entity): number
	return Config.GrenadeRegen / (hasPass(entity, "Grenadier") and 2 or 1)
end

local function setGrenades(entity, count: number)
	entity.Grenades = count
	if entity.Player then
		entity.Player:SetAttribute("Grenades", count)
	end
end

function Combat.NewEntity(name: string, holder: Instance, player: Player?)
	local entity = {
		Name = name,
		Holder = holder,
		Player = player,
		IsBot = player == nil,
		Dead = true,
		Streak = 0,
		DeathsSinceKill = 0,
		LastKiller = nil,
		Multi = 0,
		LastKillTime = 0,
		Ammo = {},
		Reload = {},
		LastFire = {},
		Grenades = 0,
		NextGrenade = 0,
		LastGrenade = 0,
		LastKnife = 0,
		LastSlam = 0,
		LastDamaged = 0,
		DamageLog = {},
		OverdriveUntil = 0,
	}
	if player then
		Combat.ByPlayer[player] = entity
	end
	TeamService.Register(entity)
	return entity
end

function Combat.RemoveEntity(entity)
	if entity.Character then
		Combat.Entities[entity.Character] = nil
	end
	if entity.Player then
		Combat.ByPlayer[entity.Player] = nil
	end
	TeamService.Unregister(entity)
	entity.Dead = true
end

function Combat.ResetAmmo(entity, weaponId: string)
	local def = Weapons.Get(weaponId)
	if not def then
		return
	end
	local ext = hasPass(entity, "ExtendedMags")
	entity.Ammo[weaponId] = { Mag = Weapons.MagSize(def, ext), Reserve = Weapons.ReserveSize(def, ext) }
	entity.Reload[weaponId] = nil
end

-- Registers a freshly spawned character for an entity.
function Combat.AttachCharacter(entity, character: Model, weaponIds: { string })
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	entity.Character = character
	entity.Humanoid = humanoid
	entity.Root = root
	entity.Dead = false
	entity.InfiniteAmmo = false
	entity.Downed = false
	entity.DownedBy = nil
	character:SetAttribute("Team", entity.Team)
	character:SetAttribute("Downed", false)
	if entity.Player then
		entity.Player:SetAttribute("InfiniteAmmo", false)
		entity.Player:SetAttribute("Downed", false)
		entity.Player:SetAttribute("SelfReviveUsed", false)
	end
	entity.DamageLog = {}
	entity.LastDamaged = 0
	entity.Ammo = {}
	entity.Reload = {}
	entity.LastFire = {}
	for _, id in weaponIds do
		Combat.ResetAmmo(entity, id)
	end
	setGrenades(entity, Combat.MaxGrenades(entity))
	entity.NextGrenade = os.clock() + grenadeInterval(entity)

	local maxHp = Combat.MaxHealth(entity)
	humanoid.MaxHealth = maxHp
	humanoid.Health = maxHp
	humanoid.BreakJointsOnDeath = true
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local ff = Instance.new("ForceField")
	ff.Visible = true
	ff.Parent = character
	Debris:AddItem(ff, Config.SpawnProtection)

	Combat.Entities[character] = entity
	humanoid.Died:Connect(function()
		if not entity.Dead and entity.Character == character then
			entity.Dead = true
			Combat.HandleDeath(nil, entity, { Weapon = "Environment", WeaponName = "THE VOID" })
		end
	end)
	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil and Combat.Entities[character] == entity then
			Combat.Entities[character] = nil
		end
	end)
end

-- Gives a player their loadout as Tools.
function Combat.GiveLoadout(player: Player, loadout)
	local entity = Combat.ByPlayer[player]
	local character = player.Character
	if not entity or not character then
		return
	end
	local backpack = player:WaitForChild("Backpack")
	backpack:ClearAllChildren()
	local golden = hasPass(entity, "GoldenArsenal")
	local first
	for _, slot in { "Primary", "Secondary" } do
		local id = loadout[slot]
		if id and Weapons.Get(id) then
			local tool = GunBuilder.BuildTool(id, golden)
			tool.Parent = backpack
			first = first or tool
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if first and humanoid then
		humanoid:EquipTool(first)
	end
end

local function removeSpawnProtection(entity)
	if entity.Character then
		local ff = entity.Character:FindFirstChildOfClass("ForceField")
		if ff then
			ff:Destroy()
		end
	end
end

-- DAMAGE -----------------------------------------------------------------------
function Combat.Damage(attacker, victim, amount: number, info): boolean
	if not Combat.IsAlive(victim) then
		return false
	end
	if attacker == victim then
		return false
	end
	if attacker and not TeamService.Enemies(attacker, victim) then
		return false -- no friendly fire
	end
	if Combat.Hooks.Round and Combat.Hooks.Round.State == "Results" then
		return false
	end
	if victim.Character:FindFirstChildOfClass("ForceField") then
		return false
	end
	if info.Explosive and hasPass(victim, "Juggernaut") then
		amount *= 0.9
	end
	amount = math.max(1, math.floor(amount + 0.5))

	local humanoid = victim.Humanoid
	local before = humanoid.Health
	local after = math.max(0, before - amount)
	local dealt = before - after
	victim.LastDamaged = os.clock()

	if attacker then
		victim.DamageLog[attacker] = (victim.DamageLog[attacker] or 0) + dealt
		if attacker.Player then
			AchievementService.Add(attacker.Player, "Damage", dealt)
			Remotes.HitConfirm:FireClient(attacker.Player, {
				Damage = dealt,
				Headshot = info.Headshot == true,
				Killed = after <= 0,
				Position = info.Position or victim.Root.Position,
			})
		end
	end
	if victim.Player then
		local from = attacker and attacker.Root and attacker.Root.Position or nil
		Remotes.Damaged:FireClient(victim.Player, from, dealt)
	end

	if after <= 0 then
		-- players on a big streak get knocked down instead of dying
		if victim.Player and not victim.Downed and victim.Streak >= Config.DownStreak and info.Kind ~= "Nuke" then
			Combat.Down(attacker, victim, info)
			return false
		end
		if victim.Downed and not attacker then
			attacker = victim.DownedBy -- bled out: credit whoever knocked them
			info = victim.DownedInfo or info
		end
		victim.Dead = true -- set before Health so the Died handler doesn't double count
		humanoid.Health = 0
		Combat.HandleDeath(attacker, victim, info)
		return true
	end
	humanoid.Health = after
	return false
end

-- DOWNED / REVIVE -----------------------------------------------------------------
local function clearDowned(entity)
	entity.Downed = false
	entity.DownedBy = nil
	entity.DownedInfo = nil
	if entity.Character then
		entity.Character:SetAttribute("Downed", false)
		local root = entity.Character:FindFirstChild("HumanoidRootPart")
		local prompt = root and root:FindFirstChild("RevivePrompt")
		if prompt then
			prompt:Destroy()
		end
	end
	if entity.Player then
		entity.Player:SetAttribute("Downed", false)
	end
end
Combat.ClearDowned = clearDowned

function Combat.Down(attacker, victim, info)
	victim.Downed = true
	victim.DownedBy = attacker
	victim.DownedInfo = info
	victim.DownedAt = os.clock()
	victim.Humanoid.Health = Config.DownedHealth
	victim.Character:SetAttribute("Downed", true)
	victim.Player:SetAttribute("Downed", true)
	-- teammates hold E on the downed player to revive them
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Revive"
	prompt.ObjectText = victim.Name
	prompt.HoldDuration = Config.ReviveTime
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("Team", victim.Team)
	prompt.Enabled = victim.Team ~= nil
	prompt.Parent = victim.Root
	prompt.Triggered:Connect(function(player)
		local reviver = Combat.ByPlayer[player]
		if reviver and reviver ~= victim and reviver.Team ~= nil and reviver.Team == victim.Team and Combat.IsAlive(reviver) and not reviver.Downed and victim.Downed and Combat.IsAlive(victim) then
			Combat.Revive(victim, reviver)
		end
	end)
	if attacker then
		AchievementService.Add(attacker.Player, "Knockdowns", 1)
		notify(attacker, "Medal", { Medals = { { Text = "KNOCKED DOWN", Bonus = 50 } } })
		if counting() then
			addAttr(attacker.Holder, "Score", 50)
		end
	end
	Remotes.KillFeed:FireAllClients({
		Killer = attacker and attacker.Name, KillerTeam = attacker and attacker.Team,
		Victim = victim.Name, VictimTeam = victim.Team, Weapon = info.WeaponName or "?", Knock = true,
	})
	notify(victim, "Downed", { By = attacker and attacker.Name or "?", Bleed = Config.DownedHealth / Config.BleedRate })
end

function Combat.Revive(victim, reviver)
	if not victim.Downed then
		return
	end
	clearDowned(victim)
	victim.Humanoid.Health = victim.Humanoid.MaxHealth * Config.ReviveHealth
	victim.LastDamaged = os.clock()
	notify(victim, "Revived", { By = reviver and reviver.Name or nil })
	if reviver then
		AchievementService.Add(reviver.Player, "Revives", 1)
		notify(reviver, "Medal", { Medals = { { Text = "REVIVE", Bonus = 100 } } })
		if counting() then
			addAttr(reviver.Holder, "Score", 100)
		end
		if reviver.Player then
			DataService.AddCash(reviver.Player, 25, true)
			DataService.AddXP(reviver.Player, 100)
		end
	else
		AchievementService.Add(victim.Player, "SelfRevives", 1)
	end
end

Remotes.SelfRevive.OnServerEvent:Connect(function(player)
	local entity = Combat.ByPlayer[player]
	if not entity or not entity.Downed or not Combat.IsAlive(entity) then
		return
	end
	if player:GetAttribute("SelfReviveUsed") then
		return
	end
	if os.clock() - (entity.DownedAt or 0) < Config.SelfReviveTime - 0.3 then
		return
	end
	player:SetAttribute("SelfReviveUsed", true)
	Combat.Revive(entity, nil)
end)

local MULTI_NAMES = { [2] = "DOUBLE KILL", [3] = "TRIPLE KILL", [4] = "QUAD KILL", [5] = "RAMPAGE" }
local MULTI_STATS = { [2] = "DoubleKills", [3] = "TripleKills", [4] = "QuadKills", [5] = "Rampages" }
local STREAK_NAMES = { [5] = "K.O STREAK 🔥", [10] = "DOMINATING", [15] = "UNSTOPPABLE", [20] = "GODLIKE", [25] = "LEGENDARY" }

function Combat.HandleDeath(killer, victim, info)
	local round = Combat.Hooks.Round
	local victimStreak = victim.Streak
	clearDowned(victim)
	victim.Streak = 0
	victim.InfiniteAmmo = false
	if victim.Player then
		victim.Player:SetAttribute("InfiniteAmmo", false)
	end
	victim.DeathsSinceKill += 1
	victim.Holder:SetAttribute("Streak", 0)
	if counting() then
		addAttr(victim.Holder, "Deaths", 1)
	end
	AchievementService.Add(victim.Player, "Deaths", 1)
	local damageLog = victim.DamageLog
	victim.DamageLog = {}

	local weaponName = info.WeaponName or "?"

	if not killer or killer == victim then
		Remotes.KillFeed:FireAllClients({ Victim = victim.Name, VictimTeam = victim.Team, Weapon = weaponName })
		if victim.Player then
			Remotes.KillInfo:FireClient(victim.Player, { Killer = nil, Weapon = weaponName })
		end
		if round then
			round.OnDeath(victim)
		end
		return
	end

	victim.LastKiller = killer.Name
	local kp = killer.Player
	local medals = {}
	local bonus = 0
	local function medal(text: string, points: number, stat: string?)
		table.insert(medals, { Text = text, Bonus = points })
		bonus += points
		if stat then
			AchievementService.Add(kp, stat, 1)
		end
	end

	-- streak + multi kill
	killer.Streak += 1
	local now = os.clock()
	if now - killer.LastKillTime <= Config.MultiKillWindow then
		killer.Multi += 1
	else
		killer.Multi = 1
	end
	killer.LastKillTime = now
	local multi = math.min(killer.Multi, 5)
	if killer.Multi >= 2 then
		medal(MULTI_NAMES[multi], 50 * multi, MULTI_STATS[multi])
	end
	if STREAK_NAMES[killer.Streak] then
		medal(STREAK_NAMES[killer.Streak], killer.Streak * 20)
	end
	if killer.Streak == 5 then
		AchievementService.Add(kp, "KOStreaks", 1)
		notify(killer, "KOStreak", { Streak = 5 })
		for _, p in Players:GetPlayers() do
			if p ~= kp then
				Remotes.Notify:FireClient(p, "Message", { Text = killer.Name .. " is on a K.O STREAK 🔥", Color = Color3.fromRGB(255, 120, 40) })
			end
		end
	end

	-- style medals
	if info.Headshot then
		medal("HEADSHOT", 50, "Headshots")
	end
	if round and round.TakeFirstBlood() then
		medal("FIRST BLOOD", 100, "FirstBloods")
	end
	if killer.LastKiller == victim.Name then
		medal("REVENGE", 75, "Revenges")
		killer.LastKiller = nil
	end
	if victimStreak >= 5 then
		medal("BOUNTY CLAIMED", victimStreak * 25, "Bounties")
	elseif victimStreak >= 3 then
		medal("BUZZKILL", 50)
	end
	if killer.DeathsSinceKill >= 3 then
		medal("COMEBACK", 75, "Comebacks")
	end
	killer.DeathsSinceKill = 0

	local distance = info.Distance or 0
	if info.Kind == "Knife" then
		medal("SLICED", 50, "KnifeKills")
	elseif info.Kind == "Grenade" then
		medal("FRAGGED", 50, "GrenadeKills")
	elseif info.Kind == "Slam" then
		medal("METEOR STRIKE", 100, "SlamKills")
	elseif info.Kind == "Airstrike" then
		AchievementService.Add(kp, "AirstrikeKills", 1)
	elseif info.Kind == "Roadkill" then
		medal("ROADKILL", 100)
	elseif info.Kind == "Vehicle" then
		medal("CAR BOMB", 75)
	elseif info.Kind == nil then
		if distance >= 150 then
			medal("LONG SHOT", 75, "LongShots")
		elseif distance <= 5 then
			medal("POINT BLANK", 25, "PointBlanks")
		end
		if info.Class == "Sniper" and not info.Ads then
			medal("NO SCOPE", 150, "NoScopes")
		end
		if info.Weapon then
			AchievementService.Add(kp, "Kills_" .. info.Weapon, 1)
		end
	end
	if info.Slide then
		medal("SLIDE KILL", 50, "SlideKills")
	end
	if info.Air then
		medal("AIRBORNE", 50, "AirKills")
	end
	if info.Dash then
		medal("BLINK KILL", 50, "DashKills")
	end
	if not Combat.IsAlive(killer) then
		medal("FROM THE GRAVE", 150, "GraveKills")
	elseif killer.Humanoid.Health <= 20 then
		medal("CLUTCH", 75, "ClutchKills")
	end

	if info.Explosive then
		AchievementService.Add(kp, "ExplosiveKills", 1)
		if info.Projectile then
			medal(info.Direct and "DIRECT HIT" or "BOOM", info.Direct and 75 or 25)
		end
	end
	AchievementService.Add(kp, "Kills", 1)
	AchievementService.SetMax(kp, "BestStreak", killer.Streak)

	-- score & rewards
	local score = Config.KillScore + bonus
	killer.Holder:SetAttribute("Streak", killer.Streak)
	if counting() then
		addAttr(killer.Holder, "Kills", 1)
		addAttr(killer.Holder, "Score", score)
		TeamService.AddScore(killer.Team, 1)
	end
	if kp then
		DataService.AddCash(kp, Config.KillCash + bonus // 5, true)
		DataService.AddXP(kp, Config.KillXP + bonus)
		if hasPass(killer, "Vampire") and Combat.IsAlive(killer) then
			killer.Humanoid.Health = math.min(killer.Humanoid.MaxHealth, killer.Humanoid.Health + 25)
		end
	end

	-- assists
	for helper, dmg in damageLog do
		if helper ~= killer and dmg >= 25 then
			if counting() then
				addAttr(helper.Holder, "Score", Config.AssistScore)
			end
			if helper.Player then
				DataService.AddCash(helper.Player, Config.AssistCash, true)
				DataService.AddXP(helper.Player, Config.AssistXP)
				AchievementService.Add(helper.Player, "Assists", 1)
				notify(helper, "Medal", { Medals = { { Text = "ASSIST", Bonus = Config.AssistScore } } })
			end
		end
	end

	Remotes.KillFeed:FireAllClients({
		Killer = killer.Name,
		KillerVIP = hasPass(killer, "VIP"),
		KillerTeam = killer.Team,
		Victim = victim.Name,
		VictimVIP = hasPass(victim, "VIP"),
		VictimTeam = victim.Team,
		Weapon = weaponName,
		Headshot = info.Headshot == true,
	})
	notify(killer, "Kill", { Victim = victim.Name, Medals = medals, Score = score, Headshot = info.Headshot == true })
	if victim.Player then
		Remotes.KillInfo:FireClient(victim.Player, {
			Killer = killer.Name,
			Weapon = weaponName,
			Headshot = info.Headshot == true,
			Distance = math.floor(distance),
			KillerHealth = Combat.IsAlive(killer) and math.ceil(killer.Humanoid.Health) or 0,
			KillerMax = killer.Humanoid and killer.Humanoid.MaxHealth or 100,
			KillerCharacter = killer.Character,
		})
	end

	if Combat.Hooks.Killstreaks then
		Combat.Hooks.Killstreaks.OnStreak(killer, killer.Streak)
	end
	if round then
		round.OnDeath(victim)
		round.OnKill(killer)
	end
end

-- Area damage (grenades, slams, airstrikes). Returns number of kills.
function Combat.AreaDamage(attacker, position: Vector3, radius: number, maxDamage: number, info, effect: string?)
	Remotes.Effect:FireAllClients(effect or "Explosion", position, radius)
	if Combat.Hooks.Vehicles and info.Explosive then
		Combat.Hooks.Vehicles.AreaDamage(attacker, position, radius, maxDamage)
	end
	local kills = 0
	local victims = {}
	for _, victim in Combat.Entities do
		table.insert(victims, victim)
	end
	for _, victim in victims do
		if victim ~= attacker and TeamService.Enemies(attacker, victim) and Combat.IsAlive(victim) then
			local d = (victim.Root.Position - position).Magnitude
			if d <= radius then
				local hitInfo = table.clone(info)
				hitInfo.Position = victim.Root.Position
				hitInfo.Distance = (attacker and attacker.Root) and (attacker.Root.Position - victim.Root.Position).Magnitude or 0
				if Combat.Damage(attacker, victim, maxDamage * (1 - (d / radius) * 0.6), hitInfo) then
					kills += 1
				end
			end
		end
	end
	return kills
end

-- GUNFIRE --------------------------------------------------------------------
local function completeReload(entity, weaponId: string)
	local def = Weapons.Get(weaponId)
	local ammo = entity.Ammo[weaponId]
	entity.Reload[weaponId] = nil
	if not def or not ammo then
		return
	end
	local need = Weapons.MagSize(def, hasPass(entity, "ExtendedMags")) - ammo.Mag
	local take = math.min(need, ammo.Reserve)
	ammo.Mag += take
	ammo.Reserve -= take
end

function Combat.ReloadTime(entity, def): number
	return def.Reload * (hasPass(entity, "FastHands") and 0.65 or 1)
end

local function validVector(v): boolean
	return typeof(v) == "Vector3" and v == v and v.Magnitude > 0.01 and v.Magnitude < 1e5
end

-- Fires a set of rays for an entity. Used by players (from the remote) and bots.
-- dirs: list of unit directions (pellets / burst rounds).
function Combat.Shoot(entity, weaponId: string, origin: Vector3, dirs, flags)
	local def = Weapons.Get(weaponId)
	local dmgMult = hasPass(entity, "GoldenArsenal") and 1.1 or 1
	if entity.IsBot then
		dmgMult = Config.BotDamageMultiplier
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local effectsFolder = workspace:FindFirstChild("Effects")

	local totals = {}
	local carTotals = {}
	local vehicles = Combat.Hooks.Vehicles
	local ends = {}
	-- passengers shooting out of a car shouldn't hit their own car
	local ownCar = nil
	local seatPart = entity.Humanoid and entity.Humanoid.SeatPart
	if seatPart and vehicles then
		ownCar = vehicles.CarFromPart(seatPart)
	end
	for i, dir in dirs do
		local exclude = { entity.Character, effectsFolder, ownCar }
		local start = origin
		local remaining = def.Range
		local pierce = def.Penetrate or 0
		local endPos = origin + dir * def.Range
		local guard = 0
		while remaining > 1 and guard < 12 do
			guard += 1
			params.FilterDescendantsInstances = exclude
			local result = workspace:Raycast(start, dir * remaining, params)
			if not result then
				break
			end
			local _, model = Util.HumanoidFromPart(result.Instance)
			local victim = model and Combat.Entities[model]
			local car = (not model and vehicles) and vehicles.CarFromPart(result.Instance) or nil
			if car then
				carTotals[car] = (carTotals[car] or 0) + def.Damage * dmgMult * 0.7
				endPos = result.Position
				break
			end
			if victim and Combat.IsAlive(victim) and not TeamService.Enemies(entity, victim) then
				-- bullets pass through teammates
				table.insert(exclude, model)
				remaining -= (result.Position - start).Magnitude
				start = result.Position
				continue
			end
			if victim and Combat.IsAlive(victim) then
				local hitPart = result.Instance
				local headshot = hitPart.Name == "Head" or (hitPart.Parent ~= nil and hitPart.Parent:IsA("Accessory"))
				local dist = (result.Position - origin).Magnitude
				local falloff = 1
				if dist > def.FalloffStart then
					falloff = math.clamp(1 - (dist - def.FalloffStart) / math.max(1, def.Range - def.FalloffStart) * 0.5, 0.5, 1)
				end
				local acc = totals[victim] or { Damage = 0, Headshot = false, Position = result.Position, Distance = dist }
				acc.Damage += def.Damage * (headshot and def.HeadMult or 1) * falloff * dmgMult
				acc.Headshot = acc.Headshot or headshot
				totals[victim] = acc
				if pierce > 0 then
					pierce -= 1
					table.insert(exclude, model)
					remaining -= (result.Position - start).Magnitude
					start = result.Position
					continue
				end
				endPos = result.Position
				break
			elseif model then
				-- dead body or non-combatant: shoot through it
				table.insert(exclude, model)
				remaining -= (result.Position - start).Magnitude
				start = result.Position
				continue
			end
			endPos = result.Position
			break
		end
		ends[i] = endPos
	end

	local kills = 0
	for victim, acc in totals do
		local killed = Combat.Damage(entity, victim, acc.Damage, {
			Weapon = weaponId,
			WeaponName = def.Name,
			Class = def.Class,
			Headshot = acc.Headshot,
			Position = acc.Position,
			Distance = acc.Distance,
			Ads = flags.Ads == true,
			Slide = flags.Slide == true,
			Air = flags.Air == true,
			Dash = flags.Dash == true,
		})
		if killed then
			kills += 1
		end
	end
	if vehicles then
		for car, dmg in carTotals do
			vehicles.DamageCar(car, entity, dmg)
		end
	end
	if kills >= 2 then
		AchievementService.Add(entity.Player, "Collaterals", 1)
		if counting() then
			addAttr(entity.Holder, "Score", 100)
		end
		notify(entity, "Medal", { Medals = { { Text = "COLLATERAL", Bonus = 100 } } })
	end
	Remotes.Effect:FireAllClients("Shot", entity.Character, weaponId, ends)
end


-- PROJECTILES (rockets, grenade launcher) --------------------------------------
-- Simulated on the server with stepped raycasts; the visual part is moved each frame.
function Combat.FireProjectile(entity, weaponId: string, origin: Vector3, dir: Vector3)
	local def = Weapons.Get(weaponId)
	local spec = def.Projectile
	local effects = workspace:FindFirstChild("Effects") or workspace
	local rocket = Instance.new("Part")
	rocket.Name = "Projectile"
	rocket.Anchored = true
	rocket.CanCollide = false
	rocket.CanQuery = false
	rocket.CanTouch = false
	rocket.Size = Vector3.new(spec.Size, spec.Size, spec.Size * 3)
	rocket.Material = Enum.Material.Neon
	rocket.Color = def.Look.Accent
	rocket.CFrame = CFrame.lookAt(origin + dir * 3, origin + dir * 4)
	local light = Instance.new("PointLight")
	light.Color = def.Look.Accent
	light.Range = 14
	light.Brightness = 3
	light.Parent = rocket
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.2, spec.Size * 1.5)
	a1.Position = Vector3.new(0, -0.2, spec.Size * 1.5)
	a0.Parent, a1.Parent = rocket, rocket
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.4
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 200, 120), Color3.fromRGB(120, 120, 120))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.WidthScale = NumberSequence.new(1, 3)
	trail.Parent = rocket
	rocket.Parent = effects
	Remotes.Effect:FireAllClients("Launch", entity.Character, weaponId)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.Character, effects }
	local pos = origin + dir * 2
	local vel = dir * spec.Speed
	local life = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		life += dt
		local nextVel = vel - Vector3.new(0, spec.Gravity * dt, 0)
		local step = (vel + nextVel) / 2 * dt
		local result = workspace:Raycast(pos, step, params)
		vel = nextVel
		if result or life > 5 then
			conn:Disconnect()
			local hitPos = result and result.Position or pos
			rocket:Destroy()
			local direct = nil
			if result then
				local _, model = Util.HumanoidFromPart(result.Instance)
				direct = model and Combat.Entities[model]
			end
			if direct and Combat.IsAlive(direct) then
				Combat.Damage(entity, direct, spec.Direct, {
					Weapon = weaponId, WeaponName = def.Name, Class = def.Class, Explosive = true, Projectile = true, Direct = true,
					Position = hitPos, Distance = (hitPos - origin).Magnitude,
				})
			end
			Combat.AreaDamage(entity, hitPos, spec.Radius, def.Damage, {
				Weapon = weaponId, WeaponName = def.Name, Class = def.Class, Explosive = true, Projectile = true,
			}, spec.Effect)
			return
		end
		pos += step
		rocket.CFrame = CFrame.lookAt(pos, pos + vel)
	end)
end

Remotes.Fire.OnServerEvent:Connect(function(player, weaponId, origin, dirs, flags)
	local entity = Combat.ByPlayer[player]
	if not Combat.IsAlive(entity) or entity.Downed then
		return
	end
	if typeof(weaponId) ~= "string" or typeof(origin) ~= "Vector3" or typeof(dirs) ~= "table" then
		return
	end
	local def = Weapons.Get(weaponId)
	if not def then
		return
	end
	local tool = entity.Character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute("WeaponId") ~= weaponId then
		return
	end
	local ammo = entity.Ammo[weaponId]
	if not ammo then
		return
	end
	local now = os.clock()
	local rate = def.FireRate * (entity.OverdriveUntil > now and 1.5 or 1)
	if now - (entity.LastFire[weaponId] or 0) < (1 / rate) * 0.75 then
		return
	end
	local unlimited = entity.InfiniteAmmo == true
	local reloadEnd = entity.Reload[weaponId]
	if reloadEnd and not unlimited then
		if now >= reloadEnd - 0.3 then
			completeReload(entity, weaponId)
		else
			return
		end
	end
	if ammo.Mag <= 0 and not unlimited then
		return
	end

	local maxRays = def.Pellets or def.Burst or 1
	local clean = {}
	for i = 1, math.min(#dirs, maxRays) do
		if validVector(dirs[i]) then
			table.insert(clean, dirs[i].Unit)
		end
	end
	if #clean == 0 then
		return
	end
	local cost = def.Burst and #clean or 1
	if not unlimited then
		ammo.Mag = math.max(0, ammo.Mag - cost)
	end
	entity.LastFire[weaponId] = now
	removeSpawnProtection(entity)

	local head = entity.Character:FindFirstChild("Head")
	if not validVector(origin) or not head or (origin - head.Position).Magnitude > 12 then
		origin = head and head.Position or entity.Root.Position
	end
	if def.Projectile then
		Combat.FireProjectile(entity, weaponId, origin, clean[1])
		return
	end
	Combat.Shoot(entity, weaponId, origin, clean, typeof(flags) == "table" and flags or {})
end)

Remotes.Reload.OnServerEvent:Connect(function(player, weaponId)
	local entity = Combat.ByPlayer[player]
	if not Combat.IsAlive(entity) or typeof(weaponId) ~= "string" then
		return
	end
	local def = Weapons.Get(weaponId)
	local ammo = entity.Ammo[weaponId]
	if not def or not ammo or entity.Reload[weaponId] then
		return
	end
	if ammo.Mag >= Weapons.MagSize(def, hasPass(entity, "ExtendedMags")) or ammo.Reserve <= 0 then
		return
	end
	local t = Combat.ReloadTime(entity, def)
	local finish = os.clock() + t
	entity.Reload[weaponId] = finish
	task.delay(t, function()
		if entity.Reload[weaponId] == finish then
			completeReload(entity, weaponId)
		end
	end)
end)

-- EQUIPMENT ------------------------------------------------------------------
Remotes.Knife.OnServerEvent:Connect(function(player)
	local entity = Combat.ByPlayer[player]
	if not Combat.IsAlive(entity) or entity.Downed then
		return
	end
	local now = os.clock()
	if now - entity.LastKnife < Config.KnifeCooldown then
		return
	end
	entity.LastKnife = now
	removeSpawnProtection(entity)
	Remotes.Effect:FireAllClients("Knife", entity.Character)
	local look = entity.Root.CFrame.LookVector
	local best, bestDist = nil, Config.KnifeRange
	for _, other in Combat.Entities do
		if other ~= entity and TeamService.Enemies(entity, other) and Combat.IsAlive(other) then
			local offset = other.Root.Position - entity.Root.Position
			local d = offset.Magnitude
			if d <= bestDist and d > 0 and look:Dot(offset.Unit) > 0.3 then
				best, bestDist = other, d
			end
		end
	end
	if best then
		Combat.Damage(entity, best, Config.KnifeDamage, {
			Weapon = "Knife", WeaponName = "KNIFE", Kind = "Knife",
			Distance = bestDist, Position = best.Root.Position,
		})
	end
end)

function Combat.ThrowGrenade(entity, position: Vector3, velocity: Vector3)
	local g = Instance.new("Part")
	g.Name = "Grenade"
	g.Shape = Enum.PartType.Ball
	g.Size = Vector3.new(0.9, 0.9, 0.9)
	g.Color = Color3.fromRGB(50, 70, 40)
	g.Material = Enum.Material.Metal
	g.CFrame = CFrame.new(position)
	g.CanCollide = true
	g.CanQuery = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 60, 40)
	light.Range = 6
	light.Brightness = 3
	light.Parent = g
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = g
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = g
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.25
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 140, 60))
	trail.LightEmission = 1
	trail.Parent = g
	g.Parent = workspace:FindFirstChild("Effects") or workspace
	g:SetNetworkOwner(nil)
	g.AssemblyLinearVelocity = velocity
	task.delay(Config.GrenadeFuse, function()
		local pos = g.Position
		g:Destroy()
		Combat.AreaDamage(entity, pos, Config.GrenadeRadius, Config.GrenadeDamage, {
			Weapon = "Grenade", WeaponName = "FRAG GRENADE", Kind = "Grenade", Explosive = true,
		})
	end)
end

Remotes.Grenade.OnServerEvent:Connect(function(player, dir)
	local entity = Combat.ByPlayer[player]
	if not Combat.IsAlive(entity) or entity.Downed or not validVector(dir) then
		return
	end
	local now = os.clock()
	if entity.Grenades <= 0 or now - entity.LastGrenade < 0.8 then
		return
	end
	entity.LastGrenade = now
	setGrenades(entity, entity.Grenades - 1)
	removeSpawnProtection(entity)
	local head = entity.Character:FindFirstChild("Head") or entity.Root
	dir = dir.Unit
	Combat.ThrowGrenade(entity, head.Position + dir * 2.5, dir * 80 + Vector3.new(0, 20, 0))
end)

Remotes.Slam.OnServerEvent:Connect(function(player, position)
	local entity = Combat.ByPlayer[player]
	if not Combat.IsAlive(entity) or entity.Downed or not validVector(position) then
		return
	end
	local now = os.clock()
	if now - entity.LastSlam < Config.SlamCooldown - 0.5 then
		return
	end
	if (position - entity.Root.Position).Magnitude > 15 then
		return
	end
	entity.LastSlam = now
	Combat.AreaDamage(entity, position, Config.SlamRadius, Config.SlamDamage, {
		Weapon = "Slam", WeaponName = "GROUND SLAM", Kind = "Slam",
	}, "Slam")
end)

local lastPad = {}
Remotes.JumpPad.OnServerEvent:Connect(function(player)
	if os.clock() - (lastPad[player] or 0) > 1 then
		lastPad[player] = os.clock()
		AchievementService.Add(player, "JumpPads", 1)
	end
end)
Players.PlayerRemoving:Connect(function(player)
	lastPad[player] = nil
end)

-- PICKUPS --------------------------------------------------------------------
function Combat.SetupPickups(folder: Instance)
	for _, pad in folder:GetDescendants() do
		if pad:IsA("BasePart") and pad:GetAttribute("HealthPack") then
			local ready = true
			pad.Touched:Connect(function(hit)
				if not ready then
					return
				end
				local _, model = Util.HumanoidFromPart(hit)
				local entity = model and Combat.Entities[model]
				if not Combat.IsAlive(entity) or entity.Downed then
					return
				end
				ready = false
				entity.Humanoid.Health = entity.Humanoid.MaxHealth
				for id in entity.Ammo do
					local def = Weapons.Get(id)
					entity.Ammo[id].Reserve = Weapons.ReserveSize(def, hasPass(entity, "ExtendedMags"))
				end
				setGrenades(entity, Combat.MaxGrenades(entity))
				notify(entity, "Message", { Text = "+ HEALTH & AMMO", Color = Config.Colors.Green })
				if entity.Player then
					Remotes.Effect:FireClient(entity.Player, "RefillAmmo")
				end
				pad.Transparency = 0.85
				task.delay(15, function()
					pad.Transparency = 0
					ready = true
				end)
			end)
		end
	end
end

-- REGEN LOOP -----------------------------------------------------------------
local accum = 0
RunService.Heartbeat:Connect(function(dt)
	accum += dt
	if accum < 0.2 then
		return
	end
	local step = accum
	accum = 0
	local now = os.clock()
	for _, entity in Combat.Entities do
		if Combat.IsAlive(entity) and entity.Downed then
			local hum = entity.Humanoid
			local left = hum.Health - Config.BleedRate * step
			if left <= 0.5 then
				Combat.Damage(nil, entity, 9999, entity.DownedInfo or { WeaponName = "BLED OUT" })
			else
				hum.Health = left
			end
		elseif Combat.IsAlive(entity) then
			local hum = entity.Humanoid
			if now - entity.LastDamaged >= Config.RegenDelay and hum.Health < hum.MaxHealth then
				hum.Health = math.min(hum.MaxHealth, hum.Health + Config.RegenRate * step)
			end
			if entity.Grenades < Combat.MaxGrenades(entity) then
				if now >= entity.NextGrenade then
					setGrenades(entity, entity.Grenades + 1)
					entity.NextGrenade = now + grenadeInterval(entity)
				end
			else
				entity.NextGrenade = now + grenadeInterval(entity)
			end
		end
	end
end)

return Combat
