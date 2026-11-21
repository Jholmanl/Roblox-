-- Advanced movement: sprint, slide, dash, double/triple jump, ground slam, jump pads.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ClientState = require(script.Parent.ClientState)
local Effects = require(script.Parent.Effects)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer

local Movement = {}
Movement.State = {
	Sprinting = false,
	Sliding = false,
	Slamming = false,
	Airborne = false,
	LastDash = -100,
	LastSlide = -100,
	LastSlam = -100,
	AirJumps = 0,
	Aiming = false, -- set by WeaponController
	SpeedMult = 1, -- set by WeaponController (weapon mobility)
}
local S = Movement.State

local character, humanoid, root
local sprintHeld = false
local slideDir = Vector3.zero
local slideStart = 0
local dashDir = Vector3.zero
local lastJumpRequest = 0
local leftGround = 0
local lastPad = 0

local function grounded(): boolean
	if not humanoid then
		return false
	end
	return humanoid.FloorMaterial ~= Enum.Material.Air
end

local function speedBonus(): number
	local mult = 1
	if ClientState.HasPass("SpeedDemon") then
		mult *= 1.15
	end
	if ClientState.Overdrive() then
		mult *= 1.25
	end
	return mult
end

function Movement.DashCooldown(): number
	return Config.DashCooldown / (ClientState.HasPass("SpeedDemon") and 2 or 1)
end

function Movement.Recently(name: string, window: number): boolean
	return os.clock() - (S["Last" .. name] or -100) < window
end

local function flatLook(): Vector3
	local cam = workspace.CurrentCamera
	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return flat.Magnitude > 0.01 and flat.Unit or Vector3.zAxis
end

local function moveDir(): Vector3
	if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
		return humanoid.MoveDirection.Unit
	end
	return flatLook()
end

local function setCameraDip(y: number)
	if humanoid then
		TweenService:Create(humanoid, TweenInfo.new(0.15), { CameraOffset = Vector3.new(0, y, 0) }):Play()
	end
end

function Movement.Slide()
	if not root or S.Sliding or not grounded() or ClientState.MenuOpen then
		return
	end
	if os.clock() - S.LastSlide < Config.SlideCooldown then
		return
	end
	if humanoid.MoveDirection.Magnitude < 0.1 then
		return
	end
	S.Sliding = true
	S.LastSlide = os.clock()
	slideStart = os.clock()
	slideDir = humanoid.MoveDirection.Unit
	setCameraDip(-1.6)
	UIKit.Sound("Dash", 0.8)
end

local function endSlide()
	if S.Sliding then
		S.Sliding = false
		setCameraDip(0)
	end
end

function Movement.Dash()
	if not root or ClientState.MenuOpen or ClientState.Driving or (humanoid and humanoid.Sit) or player:GetAttribute("Downed") then
		return
	end
	if os.clock() - S.LastDash < Movement.DashCooldown() then
		return
	end
	S.LastDash = os.clock()
	dashDir = moveDir()
	endSlide()
	UIKit.Sound("Dash", 1.1)
	Effects.Shake(0.6)
end

function Movement.Slam()
	if not root or S.Slamming or grounded() then
		return
	end
	if os.clock() - S.LastSlam < Config.SlamCooldown then
		return
	end
	-- must be high enough above the ground
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(root.Position, Vector3.new(0, -Config.SlamMinHeight, 0), params)
	if result then
		return
	end
	S.Slamming = true
	S.LastSlam = os.clock()
	root.AssemblyLinearVelocity = Vector3.new(0, -150, 0)
end

local function canMove(): boolean
	return not (ClientState.Driving or (humanoid and humanoid.Sit) or player:GetAttribute("Downed"))
end

-- C / Ctrl: slide (on the ground)
function Movement.Crouch()
	if canMove() and grounded() then
		Movement.Slide()
	end
end

-- T: ground slam (in the air)
function Movement.GroundSlam()
	if canMove() and not grounded() then
		Movement.Slam()
	end
end

local function airJump()
	if not humanoid or grounded() or ClientState.MenuOpen or humanoid.Sit or player:GetAttribute("Downed") then
		return
	end
	if os.clock() - leftGround < 0.15 then
		return
	end
	local maxJumps = Config.AirJumps + (ClientState.HasPass("TripleJump") and 1 or 0)
	if S.AirJumps >= maxJumps then
		return
	end
	S.AirJumps += 1
	local v = root.AssemblyLinearVelocity
	local dir = humanoid.MoveDirection * 20
	root.AssemblyLinearVelocity = Vector3.new(v.X * 0.6 + dir.X, Config.AirJumpPower, v.Z * 0.6 + dir.Z)
	UIKit.Sound("Jump", 1.2)
	-- little ring effect under your feet
	Effects.Shockwave(root.Position - Vector3.new(0, 3, 0), 3)
end

local function onLanded()
	S.AirJumps = 0
	if S.Slamming then
		S.Slamming = false
		local pos = root.Position - Vector3.new(0, 2.5, 0)
		Remotes.Slam:FireServer(pos)
		Effects.Shockwave(pos, Config.SlamRadius)
		Effects.Shake(4)
	end
end

local function bindCharacter(char: Model)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	root = char:WaitForChild("HumanoidRootPart")
	S.Sliding = false
	S.Slamming = false
	S.AirJumps = 0
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			if S.Airborne then
				S.Airborne = false
				onLanded()
			end
		elseif new == Enum.HumanoidStateType.Freefall or new == Enum.HumanoidStateType.Jumping then
			if not S.Airborne then
				S.Airborne = true
				leftGround = os.clock()
			end
		end
	end)
end

local wasDowned = false
local function step(_dt: number)
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end
	local now = os.clock()

	-- downed: crawl slowly, no jumping or abilities
	local downed = player:GetAttribute("Downed") == true
	if downed ~= wasDowned then
		wasDowned = downed
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not downed)
		TweenService:Create(humanoid, TweenInfo.new(0.3), { CameraOffset = Vector3.new(0, downed and -2.4 or 0, 0) }):Play()
		if downed then
			S.Sliding = false
		end
	end
	if downed then
		humanoid.WalkSpeed = 5
		S.Sprinting = false
		return
	end

	-- walk speed
	local base = Config.BaseWalkSpeed
	S.Sprinting = sprintHeld and not S.Aiming and humanoid.MoveDirection.Magnitude > 0.1
	if S.Aiming then
		base = Config.AimWalkSpeed
	elseif S.Sprinting then
		base = Config.SprintSpeed
	end
	humanoid.WalkSpeed = base * speedBonus() * (S.SpeedMult or 1)

	-- slide
	if S.Sliding then
		local t = (now - slideStart) / Config.SlideDuration
		if t >= 1 or not grounded() then
			endSlide()
		else
			local speed = Config.SlideSpeed * (1 - t * 0.7) * speedBonus()
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(slideDir.X * speed, v.Y, slideDir.Z * speed)
		end
	end

	-- dash
	if now - S.LastDash < Config.DashDuration then
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(dashDir.X * Config.DashSpeed, math.max(v.Y, 2), dashDir.Z * Config.DashSpeed)
	end

	-- jump pads (checked on the client for smooth physics)
	if now - lastPad > 0.5 then
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { character }
		local result = workspace:Raycast(root.Position, Vector3.new(0, -4, 0), params)
		local power = result and result.Instance:GetAttribute("JumpPad")
		if power then
			lastPad = now
			S.AirJumps = 0
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X * 1.3, power, v.Z * 1.3)
			UIKit.Sound("Jump", 0.7)
			Effects.Shockwave(result.Position, 5)
			Remotes.JumpPad:FireServer()
		end
	end
end

function Movement.Init()
	if player.Character then
		bindCharacter(player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.LeftShift then
			sprintHeld = true
		elseif key == Enum.KeyCode.C or key == Enum.KeyCode.LeftControl then
			Movement.Crouch()
		elseif key == Enum.KeyCode.T or key == Enum.KeyCode.DPadDown then
			Movement.GroundSlam()
		elseif key == Enum.KeyCode.Q then
			Movement.Dash()
		elseif key == Enum.KeyCode.ButtonL3 then
			sprintHeld = not sprintHeld
		elseif key == Enum.KeyCode.ButtonB then
			Movement.Crouch()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			sprintHeld = false
		end
	end)
	UserInputService.JumpRequest:Connect(function()
		local now = os.clock()
		if now - lastJumpRequest < 0.2 then
			return
		end
		lastJumpRequest = now
		airJump()
	end)

	-- mobile buttons
	if UserInputService.TouchEnabled then
		sprintHeld = true -- auto sprint on mobile
		ContextActionService:BindAction("NS_Slide", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				Movement.Crouch()
			end
			return Enum.ContextActionResult.Sink
		end, true)
		ContextActionService:SetTitle("NS_Slide", "SLIDE")
		ContextActionService:SetPosition("NS_Slide", UDim2.new(1, -230, 1, -80))
		ContextActionService:BindAction("NS_Slam", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				Movement.GroundSlam()
			end
			return Enum.ContextActionResult.Sink
		end, true)
		ContextActionService:SetTitle("NS_Slam", "SLAM")
		ContextActionService:SetPosition("NS_Slam", UDim2.new(1, -170, 1, -140))
		ContextActionService:BindAction("NS_Dash", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				Movement.Dash()
			end
			return Enum.ContextActionResult.Sink
		end, true)
		ContextActionService:SetTitle("NS_Dash", "DASH")
		ContextActionService:SetPosition("NS_Dash", UDim2.new(1, -290, 1, -140))
	end

	RunService.Heartbeat:Connect(step)
end

return Movement
