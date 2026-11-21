-- First-person gunplay: viewmodel, ADS, recoil, spread, reloads, knife, grenades.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared.Weapons)
local GunBuilder = require(Shared.GunBuilder)
local Remotes = require(Shared.Remotes)
local ClientState = require(script.Parent.ClientState)
local Effects = require(script.Parent.Effects)
local UIKit = require(script.Parent.UIKit)
local Movement = require(script.Parent.MovementController)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local WC = {}
WC.HUD = nil -- injected

local function baseFov()
	return ClientState.Settings.FOV or 72
end
local spin = 0 -- minigun spin-up progress (0..1)

local current = nil -- { Id, Def, Tool }
local ammo = {} -- [weaponId] = { Mag, Reserve }
local firing = false
local aiming = false
local reloading = false
local reloadStart, reloadEnd, reloadToken = 0, 0, 0
local lastShot = 0
local lastShotVis = -10 -- time of the last visual shot (drives moving parts)
local animParts = {} -- moving parts of the current viewmodel
local animPivots = {}
local gunFlags = {}
local cylAngle, cylTarget, barrelAngle = 0, 0, 0
local function infinite(): boolean
	return player:GetAttribute("InfiniteAmmo") == true
end
local burstBusy = false
local bloom = 0
local aimAlpha = 0
local sprintAlpha = 0
local recoilPitch, recoilYaw = 0, 0
local kick = 0
local bobT = 0
local sway = Vector2.zero
local equipTime = 0
local knifeTime = -10
local throwTime = -10
local viewmodel = nil
local knifeModel = nil
local character, humanoid

local function extended()
	return ClientState.HasPass("ExtendedMags")
end

local function fullAmmo(id: string)
	local def = Weapons.Get(id)
	ammo[id] = { Mag = Weapons.MagSize(def, extended()), Reserve = Weapons.ReserveSize(def, extended()) }
end

function WC.RefillReserve()
	for id, a in ammo do
		a.Reserve = Weapons.ReserveSize(Weapons.Get(id), extended())
	end
end

local function updateHud()
	if not WC.HUD then
		return
	end
	if current then
		local a = ammo[current.Id]
		WC.HUD.SetAmmo(a.Mag, a.Reserve, current.Def.Name, reloading, Weapons.MagSize(current.Def, extended()), infinite())
	else
		WC.HUD.SetAmmo(0, 0, "", false, 1)
	end
end

local function alive(): boolean
	return humanoid ~= nil and humanoid.Health > 0 and ClientState.Deployed
end

local function canAct(): boolean
	return alive() and not ClientState.MenuOpen and not ClientState.VoteOpen and not ClientState.Driving and player:GetAttribute("Downed") ~= true
end

-- VIEWMODEL --------------------------------------------------------------------
local function setVMPart(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

local function arm(parent, name, size, cf, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CFrame = cf
	setVMPart(p)
	p.Parent = parent
	return p
end

local function buildViewmodel(id: string)
	if viewmodel then
		viewmodel:Destroy()
	end
	local def = Weapons.Get(id)
	local model = GunBuilder.Build(id, ClientState.HasPass("GoldenArsenal"))
	local handle = model.PrimaryPart
	local L = def.Look.Length
	local skin = Color3.fromRGB(234, 184, 146)
	local sleeve = Color3.fromRGB(35, 38, 46)
	if character then
		local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		skin = hand and hand.Color or skin
		sleeve = torso and torso.Color or sleeve
	end
	local cf = handle.CFrame
	local gripA = handle:FindFirstChild("GripPoint")
	local foreA = handle:FindFirstChild("ForePoint")
	local g = gripA and gripA.Position or Vector3.new(0, -0.45, L * 0.22)
	local f = foreA and foreA.Position or Vector3.new(0, -0.25, -L * 0.3)
	arm(model, "RightHand", Vector3.new(0.38, 0.42, 0.42), cf * CFrame.new(g + Vector3.new(0.04, 0.02, 0)), skin)
	arm(model, "RightSleeve", Vector3.new(0.5, 0.5, 1.9), cf * CFrame.new(g + Vector3.new(0.3, -0.25, 1.05)) * CFrame.Angles(math.rad(14), math.rad(8), 0), sleeve)
	arm(model, "LeftHand", Vector3.new(0.38, 0.38, 0.48), cf * CFrame.new(f + Vector3.new(-0.04, -0.06, 0)), skin)
	arm(model, "LeftSleeve", Vector3.new(0.5, 0.5, 2.1), cf * CFrame.new(f + Vector3.new(-0.55, -0.32, 1.0)) * CFrame.Angles(math.rad(12), math.rad(-28), 0), sleeve)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			setVMPart(p)
		end
	end
	model.Parent = camera
	viewmodel = model
	-- remember every moving part relative to the receiver
	animParts = {}
	animPivots = {
		Cylinder = model:GetAttribute("CylinderPivot"),
		Barrels = model:GetAttribute("BarrelsPivot"),
		Break = model:GetAttribute("BreakPivot"),
	}
	gunFlags = { Shell = model:GetAttribute("Shell") or "Brass" }
	local hcf = handle.CFrame
	for _, p in model:GetDescendants() do
		local kind = p:IsA("BasePart") and p:GetAttribute("Anim")
		if kind then
			gunFlags[kind] = true
			table.insert(animParts, { Part = p, Kind = kind, Base = hcf:ToObjectSpace(p.CFrame), Color = p.Color })
		end
	end
	cylAngle, cylTarget, barrelAngle = 0, 0, 0
end

local function buildKnife()
	local model = Instance.new("Model")
	model.Name = "Knife"
	local handle = Instance.new("Part")
	handle.Size = Vector3.new(0.18, 0.25, 0.7)
	handle.Color = Color3.fromRGB(25, 25, 28)
	setVMPart(handle)
	handle.Parent = model
	local blade = Instance.new("Part")
	blade.Size = Vector3.new(0.05, 0.25, 1.1)
	blade.Color = Color3.fromRGB(220, 225, 235)
	blade.Material = Enum.Material.Metal
	blade.CFrame = handle.CFrame * CFrame.new(0, 0.02, -0.9)
	setVMPart(blade)
	blade.Parent = model
	model.PrimaryPart = handle
	model.Parent = nil
	return model
end

local function hideToolLocally()
	if current and current.Tool then
		for _, p in current.Tool:GetDescendants() do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = 1
			end
		end
	end
end

local function setViewmodelVisible(visible: boolean)
	if viewmodel then
		for _, p in viewmodel:GetDescendants() do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = visible and 0 or 1
			end
		end
	end
end

-- EQUIP ------------------------------------------------------------------------
local function equip(tool: Tool)
	local id = tool:GetAttribute("WeaponId")
	local def = id and Weapons.Get(id)
	if not def then
		return
	end
	reloading = false
	reloadToken += 1
	burstBusy = false
	current = { Id = id, Def = def, Tool = tool }
	if not ammo[id] then
		fullAmmo(id)
	end
	equipTime = os.clock()
	Movement.State.SpeedMult = def.Speed
	buildViewmodel(id)
	updateHud()
end

local function unequip()
	current = nil
	firing = false
	if viewmodel then
		viewmodel:Destroy()
		viewmodel = nil
	end
	updateHud()
end

function WC.EquipSlot(slot: string)
	if not canAct() then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	for _, tool in backpack:GetChildren() do
		if tool:IsA("Tool") and tool:GetAttribute("Slot") == slot then
			humanoid:EquipTool(tool)
			return
		end
	end
end

local function cycle()
	if current then
		WC.EquipSlot(current.Def.Slot == "Primary" and "Secondary" or "Primary")
	end
end

-- SHOOTING -------------------------------------------------------------------
local function currentSpread(): number
	if not current then
		return 0
	end
	local def = current.Def
	local s = def.Spread + (def.AdsSpread - def.Spread) * aimAlpha
	if humanoid and humanoid.MoveDirection.Magnitude > 0.1 and not Movement.State.Sliding then
		s *= 1.3
	end
	if Movement.State.Airborne then
		s *= 1.5
	end
	return s + bloom
end

local function spreadDir(cf: CFrame, degrees: number): Vector3
	local r = math.rad(degrees) * math.sqrt(math.random())
	local theta = math.random() * math.pi * 2
	return (cf.Rotation * CFrame.Angles(0, 0, theta) * CFrame.Angles(r, 0, 0)).LookVector
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function muzzlePosition(): Vector3
	if viewmodel and viewmodel.PrimaryPart then
		local m = viewmodel.PrimaryPart:FindFirstChild("Muzzle")
		if m then
			return m.WorldPosition
		end
	end
	return camera.CFrame.Position + camera.CFrame.LookVector * 2
end

local function shotVisual(dir: Vector3)
	if not current then
		return
	end
	local def = current.Def
	if def.Projectile then
		return -- the server simulates and replicates the rocket
	end
	rayParams.FilterDescendantsInstances = { character, camera, workspace:FindFirstChild("Effects") }
	local origin = camera.CFrame.Position
	local result = workspace:Raycast(origin, dir * def.Range, rayParams)
	local hitPos = result and result.Position or origin + dir * def.Range
	local neon = def.Look.Neon
	Effects.Tracer(muzzlePosition(), hitPos, neon and def.Look.Accent or nil, neon and 0.25 or 0.08)
	if result then
		Effects.Impact(hitPos)
	end
end

local function ejectShell(kind: string)
	if not viewmodel or kind == "None" then
		return
	end
	local att = viewmodel.PrimaryPart and viewmodel.PrimaryPart:FindFirstChild("Eject")
	if not att then
		return
	end
	local isShell = kind == "Shell"
	local shell = Instance.new("Part")
	shell.Name = "Casing"
	shell.Size = isShell and Vector3.new(0.14, 0.14, 0.3) or Vector3.new(0.06, 0.06, 0.16)
	shell.Color = isShell and Color3.fromRGB(190, 40, 40) or Color3.fromRGB(205, 165, 75)
	shell.Material = Enum.Material.Metal
	shell.CFrame = att.WorldCFrame * CFrame.Angles(0, math.rad(90), 0)
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.CastShadow = false
	shell.Parent = workspace:FindFirstChild("Effects") or workspace
	local cam = camera.CFrame
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local carry = root and root.AssemblyLinearVelocity or Vector3.zero
	shell.AssemblyLinearVelocity = carry + cam.RightVector * (9 + math.random() * 4) + cam.UpVector * (6 + math.random() * 3) - cam.LookVector * 2
	shell.AssemblyAngularVelocity = Vector3.new(math.random(-25, 25), math.random(-25, 25), math.random(-25, 25))
	task.delay(0.12, function()
		if shell.Parent then
			shell.CanCollide = true
		end
	end)
	Debris:AddItem(shell, 2.5)
end

local function kickRecoil(def)
	lastShotVis = os.clock()
	cylTarget += math.pi / 3
	-- spent casings: straight out for semi/auto, after the pump / bolt is cycled otherwise
	if not gunFlags.Break then
		local delay = (gunFlags.Pump or gunFlags.BoltAction) and 0.3 or 0
		local shellKind = gunFlags.Shell
		if delay > 0 then
			task.delay(delay, ejectShell, shellKind)
		else
			ejectShell(shellKind)
		end
	end
	-- slight physical kickback on the big guns
	if (def.Kickback or 0) > 0 and character and not ClientState.Driving then
		local root = character:FindFirstChild("HumanoidRootPart")
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if root and flat.Magnitude > 0.01 then
			root.AssemblyLinearVelocity += -flat.Unit * def.Kickback * (Movement.State.Airborne and 1.4 or 1)
		end
		Effects.Shake(def.Kickback * 0.07)
	end
	local adsFactor = 1 - aimAlpha * 0.45
	recoilPitch += def.Recoil * adsFactor
	recoilYaw += (math.random() - 0.5) * def.Recoil * 0.6 * adsFactor
	kick = math.min(kick + 0.6 + def.Recoil * 0.08, 2)
	bloom = math.min(bloom + def.Spread * 0.18, def.Spread * 1.2)
	Effects.Flash(muzzlePosition(), def.Look.Neon and def.Look.Accent or nil)
	UIKit.Sound((def.Class == "Sniper" or def.Class == "Exotic") and "ShotHeavy" or "Shot", 0.92 + math.random() * 0.16)
end

function WC.Reload()
	if not current or reloading or not alive() or infinite() then
		return
	end
	if gunFlags.Break then
		task.delay(0.35, ejectShell, "Shell")
		task.delay(0.4, ejectShell, "Shell")
	end
	local def = current.Def
	local a = ammo[current.Id]
	if a.Mag >= Weapons.MagSize(def, extended()) or a.Reserve <= 0 then
		return
	end
	reloading = true
	reloadToken += 1
	local token = reloadToken
	local id = current.Id
	local duration = def.Reload * (ClientState.HasPass("FastHands") and 0.65 or 1)
	reloadStart = os.clock()
	reloadEnd = reloadStart + duration
	Remotes.Reload:FireServer(id)
	UIKit.Sound("Reload")
	updateHud()
	task.delay(duration, function()
		if token ~= reloadToken or not current or current.Id ~= id then
			return
		end
		local need = Weapons.MagSize(def, extended()) - a.Mag
		local take = math.min(need, a.Reserve)
		a.Mag += take
		a.Reserve -= take
		reloading = false
		UIKit.Sound("Reload", 1.3)
		updateHud()
	end)
end

local function tryShoot()
	if not current or not canAct() or reloading or burstBusy then
		return
	end
	local def = current.Def
	local now = os.clock()
	local rate = def.FireRate * (ClientState.Overdrive() and 1.5 or 1)
	if now - lastShot < 1 / rate then
		return
	end
	if now - equipTime < 0.25 then
		return
	end
	if def.SpinUp and spin < 1 then
		return
	end
	local a = ammo[current.Id]
	local unlimited = infinite()
	if a.Mag <= 0 and not unlimited then
		UIKit.Sound("Empty")
		if ClientState.OnDryFire then
			ClientState.OnDryFire()
		end
		WC.Reload()
		return
	end
	lastShot = now

	local flags = {
		Ads = aimAlpha > 0.6,
		Slide = Movement.State.Sliding,
		Air = Movement.State.Airborne,
		Dash = Movement.Recently("Dash", 1),
	}
	local origin = camera.CFrame.Position
	local spread = currentSpread()
	local dirs = {}
	if def.Burst then
		local rounds = unlimited and def.Burst or math.min(def.Burst, a.Mag)
		for i = 1, rounds do
			dirs[i] = spreadDir(camera.CFrame * CFrame.Angles(math.rad(def.Recoil * 0.25 * (i - 1)), 0, 0), spread)
		end
		if not unlimited then
			a.Mag -= rounds
		end
		burstBusy = true
		for i, dir in dirs do
			task.delay((i - 1) * def.BurstDelay, function()
				shotVisual(dir)
				kickRecoil(def)
			end)
		end
		task.delay(rounds * def.BurstDelay, function()
			burstBusy = false
		end)
	else
		for i = 1, def.Pellets or 1 do
			dirs[i] = spreadDir(camera.CFrame, spread)
			shotVisual(dirs[i])
		end
		if not unlimited then
			a.Mag -= 1
		end
		kickRecoil(def)
	end
	Remotes.Fire:FireServer(current.Id, origin, dirs, flags)
	updateHud()
	if a.Mag <= 0 and not unlimited then
		task.delay(0.25, WC.Reload)
	end
end

function WC.Knife()
	if not canAct() or os.clock() - knifeTime < 0.7 then
		return
	end
	knifeTime = os.clock()
	Remotes.Knife:FireServer()
	UIKit.Sound("Knife")
end

function WC.Grenade()
	if not canAct() or (player:GetAttribute("Grenades") or 0) <= 0 or os.clock() - throwTime < 0.8 then
		return
	end
	throwTime = os.clock()
	Remotes.Grenade:FireServer(camera.CFrame.LookVector)
	UIKit.Sound("Dash", 0.6)
end

function WC.Spin(): number
	return spin
end

function WC.CurrentDef()
	return current and current.Def or nil
end

function WC.OnHit(info)
	if not info.Vehicle then
		Effects.HitFlash(info.Position, info.Headshot)
	end
	if WC.HUD then
		WC.HUD.Hitmarker(info.Headshot, info.Killed)
		WC.HUD.DamageNumber(info.Position, info.Damage, info.Headshot)
	end
	if info.Killed then
		UIKit.Sound("Kill", 1.4)
	else
		UIKit.Sound("Hit", info.Headshot and 2.1 or 1.6)
	end
end

-- MOVING PARTS ---------------------------------------------------------------------
local function animateViewmodel(dt: number, now: number)
	if not viewmodel or not current or not viewmodel.PrimaryPart then
		return
	end
	local hcf = viewmodel.PrimaryPart.CFrame
	local a = ammo[current.Id]
	local empty = a ~= nil and a.Mag <= 0 and not infinite()
	local t = now - lastShotVis
	-- fast snap back, slower return (slides, bolts)
	local pulse = t < 0.035 and t / 0.035 or math.max(0, 1 - (t - 0.035) / 0.09)
	-- delayed rack (pump & bolt action)
	local cycle = (t > 0.14 and t < 0.56) and math.sin((t - 0.14) / 0.42 * math.pi) or 0
	local magOut = 0
	if reloading then
		local r = math.clamp((now - reloadStart) / math.max(0.01, reloadEnd - reloadStart), 0, 1)
		magOut = r < 0.25 and r / 0.25 or (r < 0.6 and 1 or math.max(0, 1 - (r - 0.6) / 0.25))
	end
	cylAngle += (cylTarget - cylAngle) * math.min(1, dt * 18)
	if current.Def.SpinUp then
		barrelAngle += dt * spin * 45
	else
		barrelAngle += dt * (1.5 + pulse * 14)
	end
	local glow = math.max(0, 1 - t / 0.18)
	local function around(pivot, rot, base)
		local p = pivot or Vector3.zero
		return hcf * CFrame.new(p) * rot * CFrame.new(-p) * base
	end
	for _, ap in animParts do
		local kind = ap.Kind
		local cf
		if kind == "Slide" then
			cf = hcf * CFrame.new(0, 0, empty and 0.2 or 0.22 * pulse) * ap.Base -- locks back when empty
		elseif kind == "Bolt" then
			cf = hcf * CFrame.new(0, 0, empty and 0.12 or 0.14 * pulse) * ap.Base
		elseif kind == "Recoil" then
			cf = hcf * CFrame.new(0, 0, 0.28 * pulse) * ap.Base
		elseif kind == "Pump" then
			cf = hcf * CFrame.new(0, 0, 0.34 * cycle) * ap.Base
		elseif kind == "BoltAction" then
			cf = hcf * CFrame.new(0, 0.07 * cycle, 0.3 * cycle) * ap.Base
		elseif kind == "Trigger" then
			cf = hcf * CFrame.new(0, 0, (firing or pulse > 0.3) and 0.035 or 0) * ap.Base
		elseif kind == "Hammer" then
			cf = hcf * ap.Base * CFrame.Angles(math.rad(-35) * pulse, 0, 0)
		elseif kind == "Mag" then
			cf = hcf * CFrame.new(0, -1.6 * magOut, 0.15 * magOut) * ap.Base
		elseif kind == "Cylinder" then
			cf = around(animPivots.Cylinder, CFrame.Angles(0, 0, cylAngle), ap.Base)
		elseif kind == "Barrels" then
			cf = around(animPivots.Barrels, CFrame.Angles(0, 0, barrelAngle), ap.Base)
		elseif kind == "Break" then
			cf = around(animPivots.Break, CFrame.Angles(-0.5 * magOut, 0, 0), ap.Base)
		else
			cf = hcf * ap.Base
		end
		ap.Part.CFrame = cf
		if kind == "Payload" and empty then
			ap.Part.LocalTransparencyModifier = 1
		elseif kind == "Glow" then
			ap.Part.Color = ap.Color:Lerp(Color3.new(1, 1, 1), glow * 0.8)
		end
	end
end

-- PER FRAME --------------------------------------------------------------------
local function lerp(a, b, t)
	return a + (b - a) * t
end

local function render(dt: number)
	camera = workspace.CurrentCamera
	local now = os.clock()
	local S = Movement.State
	local isAlive = alive() and not ClientState.Driving
	if current and current.Def.SpinUp then
		local spinning = firing and canAct() and not reloading
		spin = math.clamp(spin + (spinning and dt / current.Def.SpinUp or -dt * 1.5), 0, 1)
	else
		spin = 0
	end
	-- ADS sensitivity
	UserInputService.MouseDeltaSensitivity = aimAlpha > 0.5 and (ClientState.Settings.AdsSens or 0.7) or 1

	-- input-driven state
	if not isAlive or ClientState.MenuOpen then
		firing = false
	end
	local wantAim = aiming and isAlive and not ClientState.MenuOpen and not S.Sprinting
	S.Aiming = wantAim
	aimAlpha = lerp(aimAlpha, wantAim and 1 or 0, math.min(1, dt * 16))
	sprintAlpha = lerp(sprintAlpha, (S.Sprinting and not wantAim and not firing) and 1 or 0, math.min(1, dt * 10))
	bloom = math.max(0, bloom - dt * 6)

	if firing and current and current.Def.Auto then
		tryShoot()
	end

	-- camera recoil + shake (visual kick that recovers)
	recoilPitch = lerp(recoilPitch, 0, math.min(1, dt * 9))
	recoilYaw = lerp(recoilYaw, 0, math.min(1, dt * 9))
	if isAlive then
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(recoilPitch), math.rad(recoilYaw), 0) * Effects.StepShake(dt)

		local fov = baseFov()
		if S.Sprinting then
			fov += 8
		end
		if S.Sliding then
			fov += 6
		end
		if Movement.Recently("Dash", 0.25) then
			fov += 14
		end
		if current then
			fov = lerp(fov, current.Def.ZoomFov, aimAlpha)
		end
		camera.FieldOfView = lerp(camera.FieldOfView, fov, math.min(1, dt * 14))
	end

	-- viewmodel
	if viewmodel and current and isAlive then
		local def = current.Def
		local L = def.Look.Length
		local sight = viewmodel.PrimaryPart:FindFirstChild("Sight")
		local hip = CFrame.new(1.0, -1.05, -L / 2 - 1.0)
		local ads = CFrame.new(0, -(sight and sight.Position.Y or 0.4), -L / 2 - 0.45)
		local offset = hip:Lerp(ads, aimAlpha)

		local root = character and character:FindFirstChild("HumanoidRootPart")
		local speed = root and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude or 0
		if Movement.State.Airborne or S.Sliding then
			speed = 0
		end
		bobT += dt * speed * 0.55
		local bobAmt = (1 - aimAlpha * 0.9) * math.min(speed / 16, 1.5)
		local bob = CFrame.new(math.sin(bobT) * 0.05 * bobAmt, -math.abs(math.cos(bobT)) * 0.06 * bobAmt, 0)

		local delta = UserInputService:GetMouseDelta()
		local target = Vector2.new(math.clamp(-delta.X * 0.003, -0.12, 0.12), math.clamp(-delta.Y * 0.003, -0.12, 0.12))
		sway = sway:Lerp(target * (1 - aimAlpha * 0.7), math.min(1, dt * 10))
		local swayCF = CFrame.Angles(sway.Y, sway.X, sway.X * 0.6)

		kick = lerp(kick, 0, math.min(1, dt * 14))
		local kickCF = CFrame.new(0, 0, kick * 0.18) * CFrame.Angles(math.rad(kick * 4), 0, 0)
		if def.SpinUp and spin > 0 then
			-- minigun rumble while spinning
			kickCF *= CFrame.new((math.random() - 0.5) * 0.02 * spin, (math.random() - 0.5) * 0.02 * spin, 0)
		end

		local reloadCF = CFrame.identity
		if reloading then
			local t = math.clamp((now - reloadStart) / math.max(0.01, reloadEnd - reloadStart), 0, 1)
			local d = math.sin(t * math.pi)
			reloadCF = CFrame.new(0, -0.5 * d, 0) * CFrame.Angles(math.rad(-35) * d, 0, math.rad(25) * d)
		end
		local equipT = math.clamp((now - equipTime) / 0.25, 0, 1)
		local equipCF = CFrame.new(0, -1.2 * (1 - equipT), 0) * CFrame.Angles(math.rad(-40) * (1 - equipT), 0, 0)
		local sprintCF = CFrame.new(-0.3 * sprintAlpha, -0.2 * sprintAlpha, 0) * CFrame.Angles(math.rad(-12) * sprintAlpha, math.rad(40) * sprintAlpha, math.rad(10) * sprintAlpha)
		local slideCF = S.Sliding and CFrame.Angles(0, 0, math.rad(-12)) or CFrame.identity

		-- knife / grenade: drop the gun out of view briefly
		local knifeT = (now - knifeTime) / 0.35
		local throwT = (now - throwTime) / 0.4
		local away = 0
		if knifeT < 1 then
			away = math.sin(knifeT * math.pi)
		elseif throwT < 1 then
			away = math.sin(throwT * math.pi)
		end
		local awayCF = CFrame.new(0, -1.4 * away, 0.3 * away)

		viewmodel:PivotTo(camera.CFrame * offset * bob * swayCF * kickCF * reloadCF * equipCF * sprintCF * slideCF * awayCF)

		local scoped = def.Scoped and aimAlpha > 0.85
		setViewmodelVisible(not scoped)
		animateViewmodel(dt, now)
		if WC.HUD then
			WC.HUD.SetScope(scoped)
			local px = math.tan(math.rad(currentSpread())) / math.tan(math.rad(camera.FieldOfView / 2)) * (camera.ViewportSize.Y / 2)
			WC.HUD.SetCrosshair(px, aimAlpha < 0.5 or def.Pellets ~= nil)
		end

		-- knife swing
		if knifeT < 1 then
			knifeModel = knifeModel or buildKnife()
			knifeModel.Parent = camera
			local swing = -60 + knifeT * 140
			knifeModel:PivotTo(camera.CFrame * CFrame.new(0.6 - knifeT * 1.2, -0.6, -1.6) * CFrame.Angles(math.rad(-20), math.rad(swing), math.rad(-70)))
		elseif knifeModel and knifeModel.Parent then
			knifeModel.Parent = nil
		end
	else
		setViewmodelVisible(false)
		if WC.HUD then
			WC.HUD.SetScope(false)
			WC.HUD.SetCrosshair(0, false)
		end
	end
	hideToolLocally()
end

-- INPUT ------------------------------------------------------------------------
local function onInputBegan(input: InputObject, processed: boolean)
	if processed then
		return
	end
	local t, k = input.UserInputType, input.KeyCode
	if t == Enum.UserInputType.MouseButton1 or k == Enum.KeyCode.ButtonR2 then
		firing = true
		tryShoot()
	elseif t == Enum.UserInputType.MouseButton2 or k == Enum.KeyCode.ButtonL2 then
		aiming = true
	elseif k == Enum.KeyCode.R or k == Enum.KeyCode.ButtonX then
		WC.Reload()
	elseif k == Enum.KeyCode.One then
		WC.EquipSlot("Primary")
	elseif k == Enum.KeyCode.Two then
		WC.EquipSlot("Secondary")
	elseif k == Enum.KeyCode.ButtonY then
		cycle()
	elseif k == Enum.KeyCode.V or k == Enum.KeyCode.F or k == Enum.KeyCode.ButtonR1 then
		WC.Knife()
	elseif k == Enum.KeyCode.G or k == Enum.KeyCode.ButtonL1 then
		WC.Grenade()
	elseif k == Enum.KeyCode.Z then
		Remotes.UseToken:FireServer("Airstrike")
	elseif k == Enum.KeyCode.X then
		Remotes.UseToken:FireServer("Nuke")
	end
end

local function onInputEnded(input: InputObject)
	local t, k = input.UserInputType, input.KeyCode
	if t == Enum.UserInputType.MouseButton1 or k == Enum.KeyCode.ButtonR2 then
		firing = false
	elseif t == Enum.UserInputType.MouseButton2 or k == Enum.KeyCode.ButtonL2 then
		aiming = false
	end
end

local function bindMobile()
	local function bind(name, title, pos, onBegin, onEnd)
		ContextActionService:BindAction(name, function(_, state)
			if state == Enum.UserInputState.Begin then
				onBegin()
			elseif state == Enum.UserInputState.End and onEnd then
				onEnd()
			end
			return Enum.ContextActionResult.Sink
		end, true)
		ContextActionService:SetTitle(name, title)
		ContextActionService:SetPosition(name, pos)
	end
	bind("NS_Fire", "FIRE", UDim2.new(1, -170, 1, -210), function()
		firing = true
		tryShoot()
	end, function()
		firing = false
	end)
	bind("NS_Aim", "AIM", UDim2.new(1, -110, 1, -270), function()
		aiming = not aiming
	end)
	bind("NS_Reload", "RELOAD", UDim2.new(1, -230, 1, -270), WC.Reload)
	bind("NS_Knife", "KNIFE", UDim2.new(1, -290, 1, -210), WC.Knife)
	bind("NS_Nade", "NADE", UDim2.new(1, -350, 1, -150), WC.Grenade)
	bind("NS_Swap", "SWAP", UDim2.new(1, -110, 1, -330), cycle)
end

local function bindCharacter(char: Model)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	ammo = {}
	aiming = false
	firing = false
	unequip()
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			equip(child)
		end
	end)
	char.ChildRemoved:Connect(function(child)
		if current and child == current.Tool then
			unequip()
		end
	end)
	local existing = char:FindFirstChildOfClass("Tool")
	if existing then
		equip(existing)
	end
	humanoid.Died:Connect(function()
		unequip()
		if knifeModel then
			knifeModel.Parent = nil
		end
	end)
end

function WC.Init()
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	UserInputService.InputChanged:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseWheel then
			cycle()
		end
	end)
	if UserInputService.TouchEnabled then
		bindMobile()
	end
	Remotes.HitConfirm.OnClientEvent:Connect(WC.OnHit)
	player:GetAttributeChangedSignal("InfiniteAmmo"):Connect(updateHud)
	RunService:BindToRenderStep("NS_Weapons", Enum.RenderPriority.Camera.Value + 1, render)
end

return WC
