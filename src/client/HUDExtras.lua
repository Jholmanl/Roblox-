-- Extra HUD widgets: minimap radar, damage direction arrows, aimed-target info,
-- vehicle speedometer and the minigun spin meter.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UIKit = require(script.Parent.UIKit)
local ClientState = require(script.Parent.ClientState)
local Effects = require(script.Parent.Effects)
local Vehicle = require(script.Parent.VehicleController)
local Weapons = require(script.Parent.WeaponController)

local player = Players.LocalPlayer
local T = UIKit.Theme
local new, Label = UIKit.new, UIKit.Label

local Extras = {}
local refs = {}
local RADAR_RANGE = 160
local RADAR_SIZE = 170

local function enemies()
	local list = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character then
			table.insert(list, p.Character)
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, b in bots:GetChildren() do
			table.insert(list, b)
		end
	end
	return list
end

-- MINIMAP --------------------------------------------------------------------------
local function buildRadar(gui)
	local frame = UIKit.Panel({ Name = "Radar", Size = UDim2.fromOffset(RADAR_SIZE, RADAR_SIZE), Position = UDim2.fromOffset(16, 12), BackgroundColor3 = Color3.fromRGB(8, 12, 16), BackgroundTransparency = 0.3, Parent = gui })
	frame.ClipsDescendants = true
	UIKit.Stroke(Color3.new(1, 1, 1), 1.5, 0.75).Parent = frame
	for i = 1, 3 do
		local ring = new("Frame", { Size = UDim2.fromScale(i / 3, i / 3), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = frame })
		new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = ring })
		new("UIStroke", { Color = T.Accent2, Transparency = 0.8, Parent = ring })
	end
	new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = T.Accent2, BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = frame })
	new("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(0.5, 0), BackgroundColor3 = T.Accent2, BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = frame })
	-- view cone + you
	local me = Label({ Text = "▲", Size = UDim2.fromOffset(16, 16), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 14, Font = T.Black, TextColor3 = T.Accent, ZIndex = 5, Parent = frame })
	refs.RadarMe = me
	refs.North = Label({ Text = "N", Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11, Font = T.Black, TextColor3 = T.Sub, ZIndex = 5, Parent = frame })
	refs.MapName = Label({ Text = "", Size = UDim2.new(1, -8, 0, 14), Position = UDim2.new(0, 4, 1, -16), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 10, Font = T.Black, TextColor3 = T.Sub, ZIndex = 5, Parent = frame })
	refs.Radar = frame
	refs.Dots = {}
end

local function dot(i: number)
	local d = refs.Dots[i]
	if not d then
		d = new("Frame", { Size = UDim2.fromOffset(7, 7), AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, ZIndex = 4, Parent = refs.Radar })
		new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = d })
		refs.Dots[i] = d
	end
	d.Visible = true
	return d
end

local function updateRadar()
	local cam = workspace.CurrentCamera
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local origin = root and root.Position or cam.CFrame.Position
	local look = cam.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local cosY, sinY = math.cos(yaw), math.sin(yaw)
	local function toRadar(pos: Vector3)
		local dx, dz = pos.X - origin.X, pos.Z - origin.Z
		-- rotate so camera forward is "up"
		local rx = dx * cosY - dz * sinY
		local rz = dx * sinY + dz * cosY
		local s = (RADAR_SIZE / 2) / RADAR_RANGE
		return rx * s, rz * s, math.sqrt(dx * dx + dz * dz)
	end
	local n = 0
	local now = os.clock()
	local uav = Effects.UAVActive()
	for _, enemy in enemies() do
		local r = enemy:FindFirstChild("HumanoidRootPart")
		local hum = enemy:FindFirstChildOfClass("Humanoid")
		if r and hum and hum.Health > 0 and (uav or now - (Effects.LastFired[enemy] or -10) < 2.5) then
			local x, y, dist = toRadar(r.Position)
			if dist < RADAR_RANGE then
				n += 1
				local d = dot(n)
				d.BackgroundColor3 = T.Red
				d.Size = UDim2.fromOffset(8, 8)
				d.Position = UDim2.new(0.5, x, 0.5, y)
			end
		end
	end
	-- health packs + vehicles
	local map = workspace:FindFirstChild("Map")
	local props = map and map:FindFirstChild("Props")
	if props then
		for _, p in props:GetChildren() do
			if p:IsA("BasePart") and p:GetAttribute("HealthPack") then
				local x, y, dist = toRadar(p.Position)
				if dist < RADAR_RANGE then
					n += 1
					local d = dot(n)
					d.BackgroundColor3 = T.Green
					d.Size = UDim2.fromOffset(6, 6)
					d.Position = UDim2.new(0.5, x, 0.5, y)
				end
			end
		end
	end
	local vehicles = workspace:FindFirstChild("Vehicles")
	if vehicles then
		for _, car in vehicles:GetChildren() do
			if car.PrimaryPart and not car:GetAttribute("Parked") then
				local x, y, dist = toRadar(car.PrimaryPart.Position)
				if dist < RADAR_RANGE then
					n += 1
					local d = dot(n)
					d.BackgroundColor3 = Color3.new(1, 1, 1)
					d.Size = UDim2.fromOffset(6, 9)
					d.Position = UDim2.new(0.5, x, 0.5, y)
				end
			end
		end
	end
	for i = n + 1, #refs.Dots do
		refs.Dots[i].Visible = false
	end
	-- north marker on the rim
	local nx, ny = sinY, -cosY
	refs.North.Position = UDim2.new(0.5, nx * (RADAR_SIZE / 2 - 10), 0.5, ny * (RADAR_SIZE / 2 - 10))
	refs.MapName.Text = (ReplicatedStorage:GetAttribute("MapName") or "") .. (uav and "  ·  📡 UAV" or "")
end

-- DAMAGE ARROWS ------------------------------------------------------------------------
function Extras.DamageFrom(from: Vector3?)
	if not from or not refs.Arrows then
		return
	end
	local cam = workspace.CurrentCamera
	local dir = from - cam.CFrame.Position
	local look = cam.CFrame.LookVector
	local angle = math.atan2(dir.X, dir.Z) - math.atan2(look.X, look.Z)
	local deg = -math.deg(angle)
	local holder = new("Frame", { Size = UDim2.fromOffset(240, 240), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Rotation = deg, Parent = refs.Arrows })
	local arrow = Label({ Text = "▲", Size = UDim2.fromOffset(40, 30), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 34, Font = T.Black, TextColor3 = T.Red, Parent = holder })
	UIKit.TextStroke(0.3).Parent = arrow
	UIKit.Tween(arrow, 1.3, { TextTransparency = 1 })
	task.delay(1.35, function()
		holder:Destroy()
	end)
end

-- TARGET INFO ------------------------------------------------------------------------------
local function buildTarget(gui)
	local f = new("Frame", { Name = "Target", Size = UDim2.fromOffset(200, 34), Position = UDim2.new(0.5, 0, 0.5, -70), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
	refs.TargetName = Label({ Text = "", Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 14, Font = T.Black, TextColor3 = T.Red, Parent = f })
	UIKit.TextStroke(0.3).Parent = refs.TargetName
	local bar, fill = UIKit.Bar({ Size = UDim2.fromOffset(110, 5), Position = UDim2.new(0.5, 0, 0, 22), AnchorPoint = Vector2.new(0.5, 0), Color = T.Red, Parent = f })
	refs.TargetBar = bar
	refs.TargetFill = fill
	refs.Target = f
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function updateTarget()
	local cam = workspace.CurrentCamera
	rayParams.FilterDescendantsInstances = { player.Character, cam, workspace:FindFirstChild("Effects") }
	local result = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 400, rayParams)
	local model = result and result.Instance:FindFirstAncestorOfClass("Model")
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not hum and model and model.Parent and model.Parent:IsA("Model") then
		model = model.Parent
		hum = model:FindFirstChildOfClass("Humanoid")
	end
	if hum and hum.Health > 0 and ClientState.Deployed and not ClientState.Dead then
		local isBot = model:GetAttribute("BotName") ~= nil
		refs.TargetName.Text = string.upper(model.Name) .. (isBot and "  [BOT]" or "")
		refs.TargetFill.Size = UDim2.fromScale(math.clamp(hum.Health / hum.MaxHealth, 0, 1), 1)
		refs.Target.Visible = true
	else
		refs.Target.Visible = false
	end
end

-- VEHICLE HUD + MINIGUN --------------------------------------------------------------------
local function buildVehicle(gui)
	local f = UIKit.Panel({ Name = "VehicleHUD", Size = UDim2.fromOffset(300, 74), Position = UDim2.new(0.5, 0, 1, -40), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Visible = false, Parent = gui })
	refs.Speed = Label({ Text = "0", Size = UDim2.fromOffset(110, 44), Position = UDim2.fromOffset(12, 6), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 42, Font = T.Black, Parent = f })
	Label({ Text = "MPH", Size = UDim2.fromOffset(40, 16), Position = UDim2.fromOffset(126, 28), TextSize = 12, Font = T.Black, TextColor3 = T.Sub, Parent = f })
	refs.CarName = Label({ Text = "", Size = UDim2.fromOffset(120, 16), Position = UDim2.fromOffset(170, 10), TextSize = 12, Font = T.Black, TextColor3 = T.Accent, Parent = f })
	local _, fill = UIKit.Bar({ Size = UDim2.fromOffset(116, 8), Position = UDim2.fromOffset(170, 32), Color = T.Green, Parent = f })
	refs.CarHealth = fill
	Label({ Text = "W/S drive · A/D steer · SHIFT boost · CTRL drift · SPACE exit", Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -18), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 10, Font = T.Bold, TextColor3 = T.Sub, Parent = f })
	refs.Vehicle = f

	local spinBar, spinFill = UIKit.Bar({ Size = UDim2.fromOffset(80, 4), Position = UDim2.new(0.5, 0, 0.5, 34), AnchorPoint = Vector2.new(0.5, 0), Color = T.Accent, Parent = gui })
	refs.SpinBar = spinBar
	refs.SpinFill = spinFill
end

local function updateVehicle()
	local car = Vehicle.Car
	refs.Vehicle.Visible = car ~= nil
	local abilities = refs.Gui:FindFirstChild("Abilities")
	if abilities then
		abilities.Visible = car == nil
	end
	if car then
		refs.Speed.Text = tostring(math.floor(Vehicle.Speed * 0.6))
		if Vehicle.Boosting then
			refs.CarName.Text = "🚀 DRIFT BOOST"
		elseif Vehicle.Drifting then
			refs.CarName.Text = string.format("🌀 DRIFT %.1fs", Vehicle.DriftTime)
		else
			refs.CarName.Text = string.upper(car.Name)
		end
		local hp, max = car:GetAttribute("Health") or 0, car:GetAttribute("MaxHealth") or 1
		refs.CarHealth.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
		refs.CarHealth.BackgroundColor3 = T.Red:Lerp(T.Green, math.clamp(hp / max, 0, 1))
	end
	local def = Weapons.CurrentDef()
	local spin = Weapons.Spin()
	refs.SpinBar.Visible = def ~= nil and def.SpinUp ~= nil and spin > 0 and spin < 1
	refs.SpinFill.Size = UDim2.fromScale(spin, 1)
end

function Extras.Init(gui: ScreenGui)
	refs.Gui = gui
	buildRadar(gui)
	buildTarget(gui)
	buildVehicle(gui)
	refs.Arrows = new("Frame", { Name = "DamageArrows", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		updateVehicle()
		if acc >= 1 / 15 then
			acc = 0
			updateRadar()
			updateTarget()
		end
	end)
end

return Extras
