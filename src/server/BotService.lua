-- AI bots that fill empty servers so there's always someone to fight.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Weapons = require(Shared.Weapons)
local GunBuilder = require(Shared.GunBuilder)
local Util = require(Shared.Util)
local Combat = require(script.Parent.CombatService)
local MapService = require(script.Parent.MapService)
local TeamService = require(script.Parent.TeamService)

local BotService = {}
BotService.Bots = {} -- list of records

local NAMES = { "Vortex", "Nyx", "Blitz", "Rogue", "Havoc", "Echo", "Spectre", "Raptor", "Jinx", "Talon", "Onyx", "Zephyr", "Kilo", "Nova", "Wraith", "Ember" }
local BOT_WEAPONS = { "Striker", "Viper", "Brute", "Hornet", "Striker", "Viper", "Inferno", "HandCannon" }
local PREFERRED_RANGE = { SMG = 25, Shotgun = 10, LMG = 50, Revolver = 35, ["Assault Rifle"] = 45, ["Burst Rifle"] = 55 }
local SKIN = { Color3.fromRGB(255, 204, 153), Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 134, 66), Color3.fromRGB(141, 85, 36), Color3.fromRGB(90, 60, 40) }
local OUTFIT = { Color3.fromRGB(40, 40, 46), Color3.fromRGB(60, 70, 50), Color3.fromRGB(30, 50, 90), Color3.fromRGB(90, 30, 30), Color3.fromRGB(80, 80, 90) }
local ANIMS = { Idle = "rbxassetid://507766388", Run = "rbxassetid://913376220", Hold = "rbxassetid://507768375" }

local holdersFolder = Instance.new("Folder")
holdersFolder.Name = "BotStats"
holdersFolder.Parent = ReplicatedStorage

local botsFolder = Instance.new("Folder")
botsFolder.Name = "Bots"
botsFolder.Parent = workspace

local function pick(t)
	return t[math.random(1, #t)]
end

local function freeName(): string
	local used = {}
	for _, r in BotService.Bots do
		used[r.Name] = true
	end
	for _ = 1, 50 do
		local n = pick(NAMES)
		if not used[n] then
			return n
		end
	end
	return "Bot" .. math.random(100, 999)
end

local function hasLineOfSight(fromPos: Vector3, target, exclude): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local toPos = target.Root.Position + Vector3.new(0, 1.5, 0)
	local result = workspace:Raycast(fromPos, toPos - fromPos, params)
	if not result then
		return true
	end
	local _, model = Util.HumanoidFromPart(result.Instance)
	return model == target.Character
end

local function runAI(record, model: Model)
	local entity = record.Entity
	local humanoid = entity.Humanoid
	local root = entity.Root
	local head = model:FindFirstChild("Head") or root
	local def = Weapons.Get(record.Weapon)
	local preferred = PREFERRED_RANGE[def.Class] or 40

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local tracks = {}
	for name, id in ANIMS do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(animator.LoadAnimation, animator, anim)
		if ok then
			tracks[name] = track
		end
	end
	if tracks.Hold then
		tracks.Hold.Priority = Enum.AnimationPriority.Action
		tracks.Hold:Play()
	end

	local strafe = 1
	local nextStrafe = 0
	local nextShot = os.clock() + 1
	local shotsInMag = def.Mag
	local wander = MapService.RandomPoint()
	local nextWander = 0
	local currentTarget = nil
	local reactionUntil = 0

	while Combat.IsAlive(entity) and model.Parent do
		task.wait(0.1)
		if not Combat.IsAlive(entity) then
			break
		end
		local now = os.clock()
		local myPos = root.Position

		-- pick the closest visible enemy, otherwise head for the closest one
		local best, bestDist, bestVisible = nil, math.huge, false
		for _, other in Combat.Entities do
			if other ~= entity and TeamService.Enemies(entity, other) and Combat.IsAlive(other) then
				local d = (other.Root.Position - myPos).Magnitude
				if d < 260 then
					local visible = hasLineOfSight(head.Position, other, { model, workspace:FindFirstChild("Effects") })
					if (visible and not bestVisible) or (visible == bestVisible and d < bestDist) then
						best, bestDist, bestVisible = other, d, visible
					end
				end
			end
		end
		if best ~= currentTarget then
			currentTarget = best
			reactionUntil = now + 0.35 + math.random() * 0.3 -- human-ish reaction time
		end

		local move = Vector3.zero
		if best then
			local offset = best.Root.Position - myPos
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local toward = flat.Magnitude > 0.1 and flat.Unit or Vector3.zAxis
			if now > nextStrafe then
				strafe = -strafe
				nextStrafe = now + 0.8 + math.random() * 1.4
			end
			local side = Vector3.new(-toward.Z, 0, toward.X) * strafe
			if not bestVisible then
				move = toward
			elseif bestDist > preferred + 10 then
				move = toward + side * 0.6
			elseif bestDist < preferred - 8 then
				move = -toward + side * 0.6
			else
				move = side
			end
			root.CFrame = CFrame.lookAt(myPos, myPos + toward)

			if bestVisible and now >= nextShot and now >= reactionUntil then
				if shotsInMag <= 0 then
					shotsInMag = def.Mag
					nextShot = now + def.Reload
				else
					local accuracy = Config.BotAccuracy * math.clamp(1 - bestDist / 350, 0.35, 1)
					local aimPart = math.random() < 0.15 and best.Character:FindFirstChild("Head") or best.Character:FindFirstChild("UpperTorso") or best.Root
					local rays = def.Pellets or def.Burst or 1
					local dirs = {}
					for i = 1, rays do
						local aim = aimPart.Position
						if math.random() > accuracy then
							aim += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (4 + bestDist * 0.08)
						elseif def.Pellets then
							aim += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (bestDist * 0.1)
						end
						dirs[i] = (aim - head.Position).Unit
					end
					Combat.Shoot(entity, record.Weapon, head.Position, dirs, {})
					shotsInMag -= def.Burst or 1
					local interval = 1 / def.FireRate
					nextShot = now + (def.Auto and interval * 1.3 or interval * 1.6 + math.random() * 0.3)
				end
			end
		else
			if now > nextWander or (wander - myPos).Magnitude < 8 then
				wander = MapService.RandomPoint()
				nextWander = now + 6
			end
			local flat = Vector3.new(wander.X - myPos.X, 0, wander.Z - myPos.Z)
			move = flat.Magnitude > 0.1 and flat.Unit or Vector3.zero
		end

		humanoid:Move(move.Magnitude > 0 and move.Unit or Vector3.zero, false)
		-- hop when stuck or randomly like a real player
		local speed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
		if (move.Magnitude > 0 and speed < 2) or math.random() < 0.02 then
			humanoid.Jump = true
		end
		if tracks.Run and tracks.Idle then
			if speed > 2 then
				if not tracks.Run.IsPlaying then
					tracks.Idle:Stop()
					tracks.Run:Play()
				end
			elseif not tracks.Idle.IsPlaying then
				tracks.Run:Stop()
				tracks.Idle:Play()
			end
		end
	end
end

local function spawnBot(record)
	if record.Model then
		record.Model:Destroy()
		record.Model = nil
	end
	local desc = Instance.new("HumanoidDescription")
	local skin = pick(SKIN)
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = pick(OUTFIT)
	local legs = pick(OUTFIT)
	desc.LeftLegColor = legs
	desc.RightLegColor = legs
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[BotService] Could not create bot rig: " .. tostring(model))
		return
	end
	model.Name = record.Name
	model:SetAttribute("BotName", record.Name)
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	record.Weapon = pick(BOT_WEAPONS)
	local tool = GunBuilder.BuildTool(record.Weapon, false)
	model:PivotTo(MapService.PickSpawn(record.Entity))
	model.Parent = botsFolder
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.WalkSpeed = Config.BaseWalkSpeed
	humanoid.AutoRotate = false
	tool.Parent = model -- parenting a Tool to a character equips it
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		root:SetNetworkOwner(nil)
	end
	record.Model = model
	Combat.AttachCharacter(record.Entity, model, { record.Weapon })
	task.spawn(runAI, record, model)
end

local function addBot()
	local name = freeName()
	local holder = Instance.new("Configuration")
	holder.Name = name
	holder:SetAttribute("IsBot", true)
	for _, attr in { "Kills", "Deaths", "Score", "Streak" } do
		holder:SetAttribute(attr, 0)
	end
	holder.Parent = holdersFolder
	local record = { Name = name, Holder = holder }
	record.Entity = Combat.NewEntity(name, holder, nil)
	record.Entity.Bot = record
	table.insert(BotService.Bots, record)
	spawnBot(record)
end

local function removeBot()
	-- take a bot off the biggest team so teams stay even
	local largest = TeamService.Largest()
	local index = #BotService.Bots
	for i = #BotService.Bots, 1, -1 do
		if BotService.Bots[i].Entity.Team == largest then
			index = i
			break
		end
	end
	local record = table.remove(BotService.Bots, index)
	if not record then
		return
	end
	record.Removed = true
	Combat.RemoveEntity(record.Entity)
	if record.Model then
		record.Model:Destroy()
	end
	record.Holder:Destroy()
end

function BotService.OnDied(entity)
	local record = entity.Bot
	if not record then
		return
	end
	task.delay(Config.RespawnTime, function()
		if not record.Removed and entity.Dead then
			spawnBot(record)
		end
	end)
end

function BotService.RespawnAll()
	for _, record in BotService.Bots do
		task.spawn(spawnBot, record)
	end
end

function BotService.Holders()
	local list = {}
	for _, record in BotService.Bots do
		table.insert(list, { Holder = record.Holder, Name = record.Name, IsBot = true })
	end
	return list
end

function BotService.Start()
	task.spawn(function()
		while true do
			local want = math.max(0, Config.BotFill - #Players:GetPlayers())
			if #Players:GetPlayers() == 0 then
				want = 0
			end
			if #BotService.Bots < want then
				addBot()
			elseif #BotService.Bots > want then
				removeBot()
			end
			task.wait(#BotService.Bots == want and 3 or 0.5)
		end
	end)
end

return BotService
