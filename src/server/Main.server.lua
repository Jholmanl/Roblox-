-- Server entry point: wires all services together and handles players.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Weapons = require(Shared.Weapons)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local AchievementService = require(script.Parent.AchievementService)
local MonetizationService = require(script.Parent.MonetizationService)
local Combat = require(script.Parent.CombatService)
local KillstreakService = require(script.Parent.KillstreakService)
local MapService = require(script.Parent.MapService)
local RoundService = require(script.Parent.RoundService)
local BotService = require(script.Parent.BotService)
local VehicleService = require(script.Parent.VehicleService)

Players.CharacterAutoLoads = false
Players.RespawnTime = Config.RespawnTime

-- WIRING ---------------------------------------------------------------------
Combat.Hooks.Round = RoundService
Combat.Hooks.Killstreaks = KillstreakService
Combat.Hooks.Vehicles = VehicleService
KillstreakService.Round = RoundService
RoundService.Map = MapService
MapService.OnMapLoaded = VehicleService.OnMapLoaded
AchievementService.Init()
MapService.Init()

local deployed = {} :: { [Player]: boolean }

local function playerHolders()
	local list = {}
	for _, player in Players:GetPlayers() do
		if Combat.ByPlayer[player] then
			table.insert(list, { Holder = player, Name = player.Name, IsBot = false, Player = player })
		end
	end
	for _, h in BotService.Holders() do
		table.insert(list, h)
	end
	return list
end

RoundService.GetHolders = playerHolders

RoundService.OnEntityDied = function(entity)
	if entity.Bot then
		BotService.OnDied(entity)
		return
	end
	local player = entity.Player
	if not player then
		return
	end
	local delay = Combat.HasPass(entity, "InstantRespawn") and Config.InstantRespawnTime or Config.RespawnTime
	player:SetAttribute("RespawnAt", workspace:GetServerTimeNow() + delay)
	task.delay(delay, function()
		if player.Parent and deployed[player] and entity.Dead then
			player:LoadCharacter()
		end
	end)
end

RoundService.RespawnAll = function()
	for player in deployed do
		if player.Parent then
			task.spawn(player.LoadCharacter, player)
		end
	end
	BotService.RespawnAll()
end

-- PLAYERS ----------------------------------------------------------------------
local function onCharacter(player: Player, character: Model)
	local entity = Combat.ByPlayer[player]
	local data = DataService.Get(player)
	if not entity or not data then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart")
	character:PivotTo(MapService.PickSpawn(entity))
	if not root:IsDescendantOf(workspace) then
		character.AncestryChanged:Wait()
	end
	Combat.AttachCharacter(entity, character, { data.Loadout.Primary, data.Loadout.Secondary })
	Combat.GiveLoadout(player, data.Loadout)
end

local function onPlayerAdded(player: Player)
	for _, attr in { "Kills", "Deaths", "Score", "Streak", "MatchCash", "MatchXP" } do
		player:SetAttribute(attr, 0)
	end
	local data = DataService.Load(player)
	if not player.Parent then
		return
	end
	Combat.NewEntity(player.Name, player, player)
	MonetizationService.RefreshPasses(player)
	if player:GetAttribute("Pass_Railgun") then
		data.Owned.Railgun = true
	end
	AchievementService.CheckAll(player)
	DataService.Sync(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	player:SetAttribute("Loaded", true)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	deployed[player] = nil
	local entity = Combat.ByPlayer[player]
	if entity then
		Combat.RemoveEntity(entity)
	end
	DataService.Release(player)
end)

MonetizationService.OnPassesChanged = function(player)
	local entity = Combat.ByPlayer[player]
	local data = DataService.Get(player)
	if data and player:GetAttribute("Pass_Railgun") then
		data.Owned.Railgun = true
	end
	if entity and Combat.IsAlive(entity) then
		local max = Combat.MaxHealth(entity)
		entity.Humanoid.MaxHealth = max
		entity.Humanoid.Health = math.min(max, entity.Humanoid.Health + 35)
	end
end

Remotes.Deploy.OnServerEvent:Connect(function(player)
	if deployed[player] or not player:GetAttribute("Loaded") then
		return
	end
	deployed[player] = true
	player:LoadCharacter()
end)

Remotes.GetData.OnServerInvoke = function(player)
	local t = os.clock()
	while not DataService.Get(player) and os.clock() - t < 15 do
		task.wait(0.2)
	end
	DataService.Sync(player)
	return true
end

-- SHOP (in-game cash) -----------------------------------------------------------
Remotes.BuyWeapon.OnServerEvent:Connect(function(player, weaponId)
	local data = DataService.Get(player)
	local def = typeof(weaponId) == "string" and Weapons.Get(weaponId)
	if not data or not def or data.Owned[weaponId] or def.Pass then
		return
	end
	if data.Level < def.Level then
		Remotes.Notify:FireClient(player, "Message", { Text = "REACH LEVEL " .. def.Level .. " TO UNLOCK", Color = Config.Colors.Red })
		return
	end
	if not DataService.SpendCash(player, def.Price) then
		Remotes.Notify:FireClient(player, "Message", { Text = "NOT ENOUGH CASH", Color = Config.Colors.Red, Upsell = true })
		return
	end
	data.Owned[weaponId] = true
	data.Loadout[def.Slot] = weaponId
	AchievementService.Add(player, "WeaponsBought", 1)
	local owned = 0
	for _ in data.Owned do
		owned += 1
	end
	AchievementService.SetMax(player, "WeaponsOwned", owned)
	Remotes.Notify:FireClient(player, "Message", { Text = "UNLOCKED " .. def.Name, Color = Config.Colors.Green })
	DataService.Sync(player)
end)

Remotes.SetLoadout.OnServerEvent:Connect(function(player, slot, weaponId)
	local data = DataService.Get(player)
	local def = typeof(weaponId) == "string" and Weapons.Get(weaponId)
	if not data or not def or def.Slot ~= slot then
		return
	end
	local owned = data.Owned[weaponId] or (def.Pass and player:GetAttribute("Pass_" .. def.Pass))
	if not owned then
		return
	end
	data.Loadout[slot] = weaponId
	DataService.Sync(player)
	-- swap right away if you haven't been in a fight in the last few seconds
	local entity = Combat.ByPlayer[player]
	if Combat.IsAlive(entity) and not entity.Downed and os.clock() - entity.LastDamaged > 4 then
		Combat.ResetAmmo(entity, weaponId)
		Combat.GiveLoadout(player, data.Loadout)
	else
		Remotes.Notify:FireClient(player, "Message", { Text = "LOADOUT APPLIES ON NEXT SPAWN", Color = Config.Colors.Accent })
	end
end)

Remotes.ClaimDaily.OnServerEvent:Connect(function(player)
	local streak, reward = DataService.ClaimDaily(player)
	if streak then
		AchievementService.SetMax(player, "BestDaily", streak)
		Remotes.Notify:FireClient(player, "Message", { Text = "DAY " .. streak .. " REWARD: $" .. reward, Color = Config.Colors.Green })
		DataService.Sync(player)
	end
end)

local CROSSHAIRS = { White = true, Green = true, Cyan = true, Red = true, Yellow = true }
Remotes.SaveSettings.OnServerEvent:Connect(function(player, settings)
	local data = DataService.Get(player)
	if not data or typeof(settings) ~= "table" then
		return
	end
	local s = data.Settings
	local function num(v)
		return typeof(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
	end
	if num(settings.FOV) then
		s.FOV = math.clamp(math.floor(settings.FOV), 60, 100)
	end
	if num(settings.Shake) then
		s.Shake = math.clamp(settings.Shake, 0, 1)
	end
	if num(settings.AdsSens) then
		s.AdsSens = math.clamp(settings.AdsSens, 0.2, 1.5)
	end
	if typeof(settings.Crosshair) == "string" and CROSSHAIRS[settings.Crosshair] then
		s.Crosshair = settings.Crosshair
	end
end)

-- GO ---------------------------------------------------------------------------
RoundService.Start()
BotService.Start()
print("[" .. Config.GameName .. "] server ready")
