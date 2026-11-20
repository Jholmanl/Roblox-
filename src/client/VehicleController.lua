-- Arcade car handling. The server gives the driver network ownership,
-- so this client drives the car by setting its velocity directly.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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

local function setDriving(car: Model?, vehicleSeat: VehicleSeat?)
	Vehicle.Car = car
	seat = vehicleSeat
	chassis = car and car.PrimaryPart or nil
	ClientState.Driving = car ~= nil
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

local function step(dt: number)
	if not Vehicle.Car or not chassis or not chassis.Parent or not seat then
		Vehicle.Speed = 0
		return
	end
	local car = Vehicle.Car
	local maxSpeed = (car:GetAttribute("Speed") or 80) * (boostHeld and 1.25 or 1)
	local throttle = seat.ThrottleFloat
	local steer = seat.SteerFloat
	local cf = chassis.CFrame
	local forward = cf.LookVector
	local flatForward = Vector3.new(forward.X, 0, forward.Z)
	flatForward = flatForward.Magnitude > 0.01 and flatForward.Unit or Vector3.zAxis
	local vel = chassis.AssemblyLinearVelocity
	local forwardSpeed = vel:Dot(flatForward)

	-- throttle / brake / reverse
	local target = throttle > 0 and throttle * maxSpeed or throttle * maxSpeed * 0.4
	-- torque curve: strong off the line, tapering near top speed
	local speedRatio = math.clamp(math.abs(forwardSpeed) / maxSpeed, 0, 1)
	local accel = 46 * (1 - 0.7 * speedRatio * speedRatio)
	if throttle ~= 0 and math.sign(throttle) ~= math.sign(forwardSpeed) and math.abs(forwardSpeed) > 2 then
		accel = 110 -- braking
	elseif throttle == 0 then
		accel = 14 -- engine braking / rolling resistance
	end
	if handbrake then
		target = 0
		accel = 60
	end
	local delta = math.clamp(target - forwardSpeed, -accel * dt, accel * dt)
	forwardSpeed += delta

	-- grip: kill most sideways sliding (a little drift is fun)
	local lateral = vel - flatForward * vel:Dot(flatForward)
	local grip = handbrake and 1.2 or 6 -- handbrake lets the rear slide out
	lateral = Vector3.new(lateral.X, 0, lateral.Z) * math.max(0, 1 - dt * grip)
	chassis.AssemblyLinearVelocity = flatForward * forwardSpeed + lateral + Vector3.new(0, vel.Y, 0)

	-- steering scales with speed and flips when reversing
	local steerFactor = math.clamp(forwardSpeed / 18, -1, 1)
	-- steering gets less sharp at high speed, sharper with the handbrake
	local yaw = -steer * 1.9 * steerFactor * (1 - 0.45 * speedRatio) * (handbrake and 1.5 or 1)
	local av = chassis.AssemblyAngularVelocity
	chassis.AssemblyAngularVelocity = Vector3.new(av.X * 0.6, yaw, av.Z * 0.6)

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
	cam.FieldOfView = cam.FieldOfView + ((70 + speedRatio * 18) - cam.FieldOfView) * math.min(1, dt * 4)
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
