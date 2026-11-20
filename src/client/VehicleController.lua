-- Arcade car handling. The server gives the driver network ownership,
-- so this client drives the car by setting its velocity directly.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer

local Vehicle = {}
Vehicle.Car = nil
Vehicle.Speed = 0
Vehicle.OnChanged = nil -- (driving: boolean) -> ()

local seat, chassis
local flippedTime = 0
local boostHeld = false
local handbrake = false

-- handling state
local steerSmooth = 0 -- eased steering input (-1..1)
local yawRate = 0 -- eased turning rate
local gripNow = 7.5 -- sideways grip (lower = more slide)
local driftTime = 0
local boostTimer = 0
local lastSmoke = 0
local rearTires = {}
local taillights = {}

Vehicle.Drifting = false
Vehicle.DriftTime = 0
Vehicle.Boosting = false

local BRAKE_DECEL = 170 -- studs/s² (80 → 0 in about half a second)
local HANDBRAKE_DECEL = 40
local COAST_DECEL = 10

local function cacheParts(car: Model?)
	rearTires, taillights = {}, {}
	if not car or not car.PrimaryPart then
		return
	end
	local root = car.PrimaryPart
	for _, p in car:GetChildren() do
		if p:IsA("BasePart") then
			local localPos = root.CFrame:PointToObjectSpace(p.Position)
			if p.Name == "Tire" and localPos.Z > 0 then
				table.insert(rearTires, p)
			elseif p.Name == "Taillight" then
				table.insert(taillights, p)
			end
		end
	end
end

local function setDriving(car: Model?, vehicleSeat: VehicleSeat?)
	Vehicle.Car = car
	seat = vehicleSeat
	chassis = car and car.PrimaryPart or nil
	ClientState.Driving = car ~= nil
	cacheParts(car)
	steerSmooth, yawRate, gripNow, driftTime, boostTimer = 0, 0, 7.5, 0, 0
	if car then
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 18
		player.CameraMaxZoomDistance = 40
	else
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 128
		if ClientState.Deployed and not ClientState.Dead then
			player.CameraMode = Enum.CameraMode.LockFirstPerson
		end
	end
	if Vehicle.OnChanged then
		Vehicle.OnChanged(car ~= nil)
	end
end

local function bindCharacter(char: Model)
	setDriving(nil, nil)
	local humanoid = char:WaitForChild("Humanoid")
	humanoid.Seated:Connect(function(active, seatPart)
		if active and seatPart and seatPart:IsA("VehicleSeat") and seatPart.Parent and seatPart.Parent:GetAttribute("Vehicle") then
			setDriving(seatPart.Parent, seatPart)
		elseif ClientState.Driving then
			setDriving(nil, nil)
		end
	end)
	humanoid.Died:Connect(function()
		if ClientState.Driving then
			setDriving(nil, nil)
		end
	end)
end

local function puff(position: Vector3, braking: boolean)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(1.4, 1.4, 1.4)
	p.CFrame = CFrame.new(position)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = braking and Color3.fromRGB(90, 90, 92) or Color3.fromRGB(215, 215, 220)
	p.Transparency = 0.45
	p.Parent = workspace:FindFirstChild("Effects") or workspace
	TweenService:Create(p, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Size = Vector3.new(5, 5, 5), Transparency = 1, CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0)) }):Play()
	Debris:AddItem(p, 1)
end

local function step(dt: number)
	if not Vehicle.Car or not chassis or not chassis.Parent or not seat then
		Vehicle.Speed = 0
		Vehicle.Drifting = false
		return
	end
	local car = Vehicle.Car
	local baseSpeed = car:GetAttribute("Speed") or 80
	local maxSpeed = baseSpeed * (boostHeld and 1.25 or 1) * (boostTimer > 0 and 1.15 or 1)
	local throttle = seat.ThrottleFloat
	local cf = chassis.CFrame
	local forward = cf.LookVector
	local flatForward = Vector3.new(forward.X, 0, forward.Z)
	flatForward = flatForward.Magnitude > 0.01 and flatForward.Unit or Vector3.zAxis
	local vel = chassis.AssemblyLinearVelocity
	local forwardSpeed = vel:Dot(flatForward)
	local lateral = vel - flatForward * forwardSpeed
	lateral = Vector3.new(lateral.X, 0, lateral.Z)
	local lateralSpeed = lateral.Magnitude
	local speedRatio = math.clamp(math.abs(forwardSpeed) / baseSpeed, 0, 1)

	-- SMOOTH STEERING: ease toward the input, return to center a bit faster
	local steerIn = seat.SteerFloat
	local steerRate = steerIn == 0 and 7 or 4.5
	steerSmooth += (steerIn - steerSmooth) * math.min(1, dt * steerRate)

	-- THROTTLE / BRAKES
	local braking = throttle ~= 0 and math.sign(throttle) ~= math.sign(forwardSpeed) and math.abs(forwardSpeed) > 1
	local target, accel
	if braking then
		target, accel = 0, BRAKE_DECEL
	elseif throttle > 0 then
		target = throttle * maxSpeed
		accel = 46 * (1 - 0.7 * speedRatio * speedRatio) + (boostTimer > 0 and 40 or 0)
	elseif throttle < 0 then
		target, accel = throttle * baseSpeed * 0.4, 30
	else
		target, accel = 0, COAST_DECEL
	end
	if handbrake then
		target = 0
		accel = math.max(accel, HANDBRAKE_DECEL)
	end
	forwardSpeed += math.clamp(target - forwardSpeed, -accel * dt, accel * dt)
	-- park instead of creeping
	if throttle == 0 and math.abs(forwardSpeed) < 1.5 and not handbrake then
		forwardSpeed = 0
	end

	-- DRIFT: Ctrl breaks the rear loose; throttle + steering keeps the slide going
	local drifting = handbrake or (driftTime > 0 and lateralSpeed > 8 and math.abs(steerSmooth) > 0.25 and throttle > 0)
	local gripTarget
	if handbrake then
		gripTarget = 0.9
	elseif drifting then
		gripTarget = 2.2
	elseif braking then
		gripTarget = 11 -- strong, straight-line braking
	else
		gripTarget = 7.5
	end
	-- lose grip quickly, regain it smoothly (no snapping out of a drift)
	gripNow += (gripTarget - gripNow) * math.min(1, dt * (gripTarget > gripNow and 2.5 or 12))
	local keep = math.max(0, 1 - dt * gripNow)
	local lostSideways = lateralSpeed * (1 - keep)
	lateral *= keep
	-- part of the sideways momentum turns into forward speed while drifting
	if drifting and forwardSpeed > 0 then
		forwardSpeed = math.min(maxSpeed, forwardSpeed + lostSideways * 0.35)
	end
	chassis.AssemblyLinearVelocity = flatForward * forwardSpeed + lateral + Vector3.new(0, vel.Y, 0)

	if drifting then
		driftTime += dt
	else
		if driftTime > 0.8 then
			boostTimer = 0.8 -- drift boost on exit
		end
		driftTime = 0
	end
	boostTimer = math.max(0, boostTimer - dt)
	Vehicle.Drifting = drifting and lateralSpeed > 6
	Vehicle.DriftTime = driftTime
	Vehicle.Boosting = boostTimer > 0

	-- TURNING: eased yaw rate, less twitchy at speed, looser while drifting
	local steerFactor = math.clamp(forwardSpeed / 16, -1, 1)
	local yawTarget = -steerSmooth * 1.8 * steerFactor * (1 - 0.4 * speedRatio)
	if drifting then
		yawTarget *= 1.7
	end
	yawRate += (yawTarget - yawRate) * math.min(1, dt * 7)
	local av = chassis.AssemblyAngularVelocity
	chassis.AssemblyAngularVelocity = Vector3.new(av.X * 0.6, yawRate, av.Z * 0.6)

	-- tire smoke when sliding or braking hard; brake lights
	local now = os.clock()
	local smoking = lateralSpeed > 10 or (braking and math.abs(forwardSpeed) > 25)
	if smoking and now - lastSmoke > 0.05 then
		lastSmoke = now
		for _, tire in rearTires do
			puff(tire.Position - Vector3.new(0, tire.Size.Y * 0.35, 0), braking)
		end
	end
	local brakeOn = braking or handbrake
	for _, light in taillights do
		light.Color = brakeOn and Color3.fromRGB(255, 45, 45) or Color3.fromRGB(150, 15, 15)
	end

	-- auto-flip when stuck upside down
	if cf.UpVector.Y < 0.3 then
		flippedTime += dt
		if flippedTime > 1.5 then
			flippedTime = 0
			chassis.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, 5, 0), cf.Position + Vector3.new(0, 5, 0) + flatForward)
			chassis.AssemblyLinearVelocity = Vector3.zero
		end
	else
		flippedTime = 0
	end
	Vehicle.Speed = math.abs(forwardSpeed)
	local cam = workspace.CurrentCamera
	cam.FieldOfView = cam.FieldOfView + ((70 + speedRatio * 18 + (boostTimer > 0 and 6 or 0)) - cam.FieldOfView) * math.min(1, dt * 4)
end

function Vehicle.Init()
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.LeftShift then
			boostHeld = true
		elseif not processed and (input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.ButtonL1) then
			handbrake = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			boostHeld = false
		elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.ButtonL1 then
			handbrake = false
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return Vehicle
