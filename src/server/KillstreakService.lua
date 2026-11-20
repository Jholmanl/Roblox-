-- Killstreak rewards: UAV, Overdrive, Airstrike and the match-ending Tactical Nuke.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Combat = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local AchievementService = require(script.Parent.AchievementService)

local KillstreakService = {}
KillstreakService.Round = nil -- injected RoundService
KillstreakService.NukeActive = false

local function announce(text: string, sub: string, color: Color3, icon: string)
	Remotes.Notify:FireAllClients("Announce", { Text = text, Sub = sub, Color = color, Icon = icon })
end

local function groundBelow(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local map = workspace:FindFirstChild("Map")
	params.FilterDescendantsInstances = map and { map } or {}
	local result = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -200, 0), params)
	return result and result.Position or pos
end

local function airstrike(entity)
	local targets = {}
	for _, other in Combat.Entities do
		if other ~= entity and Combat.IsAlive(other) then
			table.insert(targets, groundBelow(other.Root.Position))
		end
	end
	for i = #targets, 2, -1 do
		local j = math.random(1, i)
		targets[i], targets[j] = targets[j], targets[i]
	end
	while #targets > 4 do
		table.remove(targets)
	end
	while #targets < 3 do
		table.insert(targets, groundBelow(Vector3.new(math.random(-90, 90), 50, math.random(-90, 90))))
	end
	local effects = workspace:FindFirstChild("Effects") or workspace
	for _, pos in targets do
		local marker = Instance.new("Part")
		marker.Shape = Enum.PartType.Cylinder
		marker.Size = Vector3.new(0.3, Config.AirstrikeRadius * 2, Config.AirstrikeRadius * 2)
		marker.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.Material = Enum.Material.Neon
		marker.Color = Config.Colors.Red
		marker.Transparency = 0.55
		marker.Parent = effects
		Debris:AddItem(marker, 3)
	end
	Remotes.Effect:FireAllClients("AirstrikeIncoming", targets)
	task.delay(2.5, function()
		for _, pos in targets do
			Combat.AreaDamage(entity, pos, Config.AirstrikeRadius, Config.AirstrikeDamage, {
				Weapon = "Airstrike", WeaponName = "AIRSTRIKE", Kind = "Airstrike", Explosive = true,
			})
			task.wait(0.2)
		end
	end)
end

local function nuke(entity)
	if KillstreakService.NukeActive then
		return false
	end
	KillstreakService.NukeActive = true
	Remotes.Effect:FireAllClients("NukeIncoming", Config.NukeCountdown, entity.Name)
	task.delay(Config.NukeCountdown, function()
		Remotes.Effect:FireAllClients("NukeDetonate")
		local victims = {}
		for _, other in Combat.Entities do
			if other ~= entity and Combat.IsAlive(other) then
				table.insert(victims, other)
			end
		end
		for _, other in victims do
			local ff = other.Character:FindFirstChildOfClass("ForceField")
			if ff then
				ff:Destroy()
			end
			Combat.Damage(entity, other, 99999, { Weapon = "Nuke", WeaponName = "TACTICAL NUKE", Kind = "Nuke", Explosive = true })
		end
		KillstreakService.NukeActive = false
		local round = KillstreakService.Round
		if round and round.State == "Active" then
			round.EndMatch(entity)
		end
	end)
	return true
end

function KillstreakService.Activate(entity, id: string): boolean
	local player = entity.Player
	local radarPro = Combat.HasPass(entity, "RadarPro")
	if id == "UAV" then
		local duration = 20 * (radarPro and 2 or 1)
		if player then
			Remotes.Killstreak:FireClient(player, "UAV", duration)
		end
		AchievementService.Add(player, "UAVs", 1)
		announce("UAV ONLINE", entity.Name .. " can see everyone", Config.Colors.Accent2, "📡")
	elseif id == "Overdrive" then
		local duration = 15
		entity.OverdriveUntil = os.clock() + duration
		if player then
			player:SetAttribute("OverdriveUntil", workspace:GetServerTimeNow() + duration)
			Remotes.Killstreak:FireClient(player, "Overdrive", duration)
		end
		AchievementService.Add(player, "Overdrives", 1)
		announce("OVERDRIVE", entity.Name .. " is moving and shooting faster", Config.Colors.Accent, "⚡")
	elseif id == "InfiniteAmmo" then
		entity.InfiniteAmmo = true
		for weaponId in entity.Ammo do
			entity.Reload[weaponId] = nil
		end
		if player then
			player:SetAttribute("InfiniteAmmo", true)
			Remotes.Killstreak:FireClient(player, "InfiniteAmmo", 0)
		end
		AchievementService.Add(player, "InfiniteAmmos", 1)
		announce("INFINITE AMMO", entity.Name .. " never has to reload again (until they die)", Config.Colors.Gold, "♾️")
	elseif id == "Airstrike" then
		airstrike(entity)
		AchievementService.Add(player, "Airstrikes", 1)
		announce("AIRSTRIKE INBOUND", "Called in by " .. entity.Name .. " — MOVE!", Config.Colors.Red, "✈️")
	elseif id == "Nuke" then
		if not nuke(entity) then
			return false
		end
		AchievementService.Add(player, "Nukes", 1)
		announce("TACTICAL NUKE INCOMING", entity.Name .. " is ending this match", Config.Colors.Red, "☢️")
	end
	return true
end

function KillstreakService.OnStreak(entity, streak: number)
	if not entity.Player then
		return -- bots don't get killstreaks
	end
	local reduce = Combat.HasPass(entity, "RadarPro") and 1 or 0
	for _, ks in Config.Killstreaks do
		if streak == ks.Kills - reduce then
			KillstreakService.Activate(entity, ks.Id)
		end
	end
end

-- Purchased call-ins (Developer Products) are stored as tokens.
Remotes.UseToken.OnServerEvent:Connect(function(player, kind)
	if kind ~= "Airstrike" and kind ~= "Nuke" then
		return
	end
	local data = DataService.Get(player)
	local entity = Combat.ByPlayer[player]
	if not data or not Combat.IsAlive(entity) or (data.Tokens[kind] or 0) <= 0 then
		return
	end
	if kind == "Nuke" then
		local round = KillstreakService.Round
		if not round or round.State ~= "Active" then
			Remotes.Notify:FireClient(player, "Message", { Text = "NUKES CAN ONLY BE USED DURING A LIVE MATCH", Color = Config.Colors.Red })
			return
		end
	end
	if KillstreakService.Activate(entity, kind) then
		data.Tokens[kind] -= 1
		DataService.Sync(player)
	end
end)

return KillstreakService
