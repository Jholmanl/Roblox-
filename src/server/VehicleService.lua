-- Cars: spawning per map, network ownership for the driver, roadkills,
-- shooting/blowing up cars, and respawning wrecks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarBuilder = require(Shared.CarBuilder)
local Remotes = require(Shared.Remotes)
local Combat = require(script.Parent.CombatService)
local AchievementService = require(script.Parent.AchievementService)

local VehicleService = {}
VehicleService.Cars = {} -- [Model] = record

local folder = Instance.new("Folder")
folder.Name = "Vehicles"
folder.Parent = workspace

local RESPAWN = 25
local generation = 0

local function occupants(car: Model)
	local list = {}
	for _, seat in car:GetChildren() do
		if (seat:IsA("Seat") or seat:IsA("VehicleSeat")) and seat.Occupant then
			local entity = Combat.Entities[seat.Occupant.Parent]
			if entity then
				table.insert(list, entity)
			end
		end
	end
	return list
end

local function driverEntity(car: Model)
	local seat = car:FindFirstChild("DriverSeat")
	local occ = seat and seat.Occupant
	return occ and Combat.Entities[occ.Parent] or nil
end

local spawnCar

local function explode(car: Model, attacker)
	local record = VehicleService.Cars[car]
	if not record or record.Dead then
		return
	end
	record.Dead = true
	local chassis = car.PrimaryPart
	local pos = chassis and chassis.Position or car:GetPivot().Position
	for _, entity in occupants(car) do
		Combat.Damage(attacker, entity, 9999, { Weapon = "Car", WeaponName = "CAR EXPLOSION", Kind = "Vehicle", Explosive = true, Position = pos })
	end
	Combat.AreaDamage(attacker, pos, 20, 110, { Weapon = "Car", WeaponName = "CAR EXPLOSION", Kind = "Vehicle", Explosive = true })
	if attacker and attacker.Player then
		AchievementService.Add(attacker.Player, "CarsDestroyed", 1)
		Remotes.Notify:FireClient(attacker.Player, "Medal", { Medals = { { Text = "VEHICLE DESTROYED", Bonus = 100 } } })
	end
	-- burnt wreck
	for _, p in car:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			if p.Transparency < 1 then
				p.Color = p.Color:Lerp(Color3.fromRGB(25, 22, 20), 0.85)
				p.Material = Enum.Material.CorrodedMetal
			end
		elseif p:IsA("Light") then
			p.Enabled = false
		elseif p:IsA("ProximityPrompt") then
			p.Enabled = false
		end
	end
	if chassis then
		local fire = Instance.new("Fire")
		fire.Size = 9
		fire.Heat = 12
		fire.Parent = chassis
		local smoke = Instance.new("Smoke")
		smoke.Size = 6
		smoke.Opacity = 0.4
		smoke.RiseVelocity = 8
		smoke.Parent = chassis
	end
	local gen = generation
	task.delay(10, function()
		car:Destroy()
	end)
	task.delay(RESPAWN, function()
		if gen == generation and record.Spot.Parent then
			spawnCar(record.Spot)
		end
	end)
end

function VehicleService.DamageCar(car: Model, attacker, amount: number)
	local record = VehicleService.Cars[car]
	if not record or record.Dead then
		return
	end
	-- don't let drivers wreck their own ride
	if attacker and table.find(occupants(car), attacker) then
		return
	end
	local hp = (car:GetAttribute("Health") or 0) - amount
	car:SetAttribute("Health", hp)
	if attacker and attacker.Player then
		Remotes.HitConfirm:FireClient(attacker.Player, { Damage = amount, Headshot = false, Killed = hp <= 0, Position = car:GetPivot().Position + Vector3.new(0, 3, 0), Vehicle = true })
	end
	if hp <= 0 then
		explode(car, attacker)
	end
end

function VehicleService.CarFromPart(part: Instance?)
	local model = part and part:FindFirstAncestorOfClass("Model")
	while model and model.Parent ~= folder do
		model = model:FindFirstAncestorOfClass("Model")
	end
	return model
end

function VehicleService.AreaDamage(attacker, position: Vector3, radius: number, maxDamage: number)
	for car, record in VehicleService.Cars do
		if not record.Dead and car.PrimaryPart then
			local d = (car.PrimaryPart.Position - position).Magnitude
			if d <= radius + 4 then
				VehicleService.DamageCar(car, attacker, maxDamage * 2 * (1 - math.min(1, d / (radius + 4)) * 0.6))
			end
		end
	end
end

local function setupDriving(car: Model)
	local seat = car:FindFirstChild("DriverSeat") :: VehicleSeat
	local chassis = car.PrimaryPart
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Drive"
	prompt.ObjectText = car.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = seat
	prompt.Triggered:Connect(function(player)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and not seat.Occupant then
			seat:Sit(hum)
		end
	end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local hum = seat.Occupant
		local player = hum and Players:GetPlayerFromCharacter(hum.Parent)
		prompt.Enabled = hum == nil
		if player then
			pcall(chassis.SetNetworkOwner, chassis, player)
			car:SetAttribute("Driver", player.Name)
			AchievementService.Add(player, "Drives", 1)
		else
			pcall(chassis.SetNetworkOwner, chassis, nil)
			car:SetAttribute("Driver", nil)
		end
	end)

	-- roadkill
	local lastHit = {}
	local function onTouched(hit: BasePart)
		local record = VehicleService.Cars[car]
		if not record or record.Dead then
			return
		end
		local speed = chassis.AssemblyLinearVelocity.Magnitude
		if speed < 28 then
			return
		end
		local model = hit:FindFirstAncestorOfClass("Model")
		local victim = model and Combat.Entities[model]
		if not victim or not Combat.IsAlive(victim) then
			return
		end
		if victim.Humanoid.SeatPart and victim.Humanoid.SeatPart:IsDescendantOf(car) then
			return
		end
		if os.clock() - (lastHit[victim] or 0) < 1 then
			return
		end
		lastHit[victim] = os.clock()
		local driver = driverEntity(car)
		local killed = Combat.Damage(driver, victim, 60 + speed * 1.6, { Weapon = "Car", WeaponName = "ROADKILL", Kind = "Roadkill", Position = victim.Root.Position, Distance = 0 })
		if killed and driver and driver.Player then
			AchievementService.Add(driver.Player, "Roadkills", 1)
		end
	end
	for _, name in { "Body", "Chassis", "BumperF", "BumperR" } do
		local p = car:FindFirstChild(name)
		if p then
			p.Touched:Connect(onTouched)
		end
	end
end

spawnCar = function(spot: BasePart)
	local parked = spot:GetAttribute("Parked") == true
	local car = CarBuilder.Build(spot:GetAttribute("Style") or "Sedan", spot:GetAttribute("Color"), parked)
	car:PivotTo(spot.CFrame + Vector3.new(0, 0.3, 0))
	if parked then
		car:SetAttribute("Parked", true)
		local seat = car:FindFirstChild("DriverSeat")
		if seat then
			seat.Disabled = true
		end
		local p = car:FindFirstChild("PassengerSeat")
		if p then
			p.Disabled = true
		end
	end
	car.Parent = folder
	VehicleService.Cars[car] = { Spot = spot, Dead = false }
	car.AncestryChanged:Connect(function(_, parent)
		if not parent then
			VehicleService.Cars[car] = nil
		end
	end)
	if not parked then
		setupDriving(car)
	end
	return car
end

function VehicleService.OnMapLoaded(map: Instance)
	generation += 1
	folder:ClearAllChildren()
	VehicleService.Cars = {}
	local spots = map:FindFirstChild("VehicleSpots")
	if spots then
		for _, spot in spots:GetChildren() do
			spawnCar(spot)
		end
	end
end

-- Parked/unoccupied cars slow down instead of sliding forever
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0
	for car, record in VehicleService.Cars do
		local chassis = car.PrimaryPart
		if chassis and not record.Dead and not chassis.Anchored and not car:GetAttribute("Driver") then
			local v = chassis.AssemblyLinearVelocity
			chassis.AssemblyLinearVelocity = Vector3.new(v.X * 0.7, v.Y, v.Z * 0.7)
			chassis.AssemblyAngularVelocity *= 0.7
		end
	end
end)

return VehicleService
