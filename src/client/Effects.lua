-- Client-side visual effects: tracers, muzzle flashes, explosions, shake, UAV.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Sounds)
local Weapons = require(Shared.Weapons)
local GunAudio = require(script.Parent.GunAudio)
local Config = require(Shared.Config)

local player = Players.LocalPlayer
local Effects = {}
local uavUntil = 0
Effects.LastFired = setmetatable({}, { __mode = "k" }) -- [character] = os.clock() of their last shot (minimap)

local function folder()
	return workspace:FindFirstChild("Effects") or workspace
end

local function fxPart(size: Vector3, cf: CFrame, color: Color3, transparency: number?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Transparency = transparency or 0
	p.Parent = folder()
	return p
end

function Effects.Sound3D(name: string, position: Vector3, pitch: number?)
	local info = Sounds[name]
	if not info then
		return
	end
	local att = Instance.new("Attachment")
	att.WorldPosition = position
	att.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = info.Id
	s.Volume = info.Volume
	s.PlaybackSpeed = pitch or 1
	s.RollOffMaxDistance = 300
	s.Parent = att
	s:Play()
	Debris:AddItem(att, 3)
end

function Effects.Tracer(from: Vector3, to: Vector3, color: Color3?, width: number?)
	local dist = (to - from).Magnitude
	if dist < 0.5 then
		return
	end
	local w = width or 0.08
	local p = fxPart(Vector3.new(w, w, dist), CFrame.lookAt((from + to) / 2, to), color or Color3.fromRGB(255, 230, 150), 0.1)
	TweenService:Create(p, TweenInfo.new(0.12), { Transparency = 1, Size = Vector3.new(w * 0.2, w * 0.2, dist) }):Play()
	Debris:AddItem(p, 0.15)
end

function Effects.Impact(position: Vector3, color: Color3?)
	local p = fxPart(Vector3.new(0.4, 0.4, 0.4), CFrame.new(position), color or Color3.fromRGB(255, 220, 140), 0)
	TweenService:Create(p, TweenInfo.new(0.2), { Transparency = 1, Size = Vector3.new(1.1, 1.1, 1.1) }):Play()
	Debris:AddItem(p, 0.25)
end

function Effects.Flash(position: Vector3, color: Color3?)
	local p = fxPart(Vector3.new(0.5, 0.5, 0.5), CFrame.new(position), color or Color3.fromRGB(255, 200, 90), 0.2)
	p.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = color or Color3.fromRGB(255, 190, 90)
	light.Range = 10
	light.Brightness = 4
	light.Parent = p
	Debris:AddItem(p, 0.05)
end

-- CAMERA SHAKE -----------------------------------------------------------------
local shake = 0
Effects.ShakeScale = 1 -- from settings (0 = off)
function Effects.Shake(amount: number)
	shake = math.max(shake, amount * Effects.ShakeScale)
end

function Effects.StepShake(dt: number): CFrame
	if shake <= 0.001 then
		shake = 0
		return CFrame.identity
	end
	local s = shake
	shake = math.max(0, shake - dt * 3)
	local t = os.clock() * 40
	return CFrame.Angles(math.noise(t, 1) * s * 0.05, math.noise(t, 2) * s * 0.05, math.noise(t, 3) * s * 0.03)
end

local function shakeFrom(position: Vector3, strength: number, range: number)
	local cam = workspace.CurrentCamera
	local d = (cam.CFrame.Position - position).Magnitude
	if d < range then
		Effects.Shake(strength * (1 - d / range))
	end
end

function Effects.Explosion(position: Vector3, radius: number)
	local e = Instance.new("Explosion")
	e.Position = position
	e.BlastRadius = radius
	e.BlastPressure = 0
	e.DestroyJointRadiusPercent = 0
	e.Parent = workspace
	local ball = fxPart(Vector3.one * 2, CFrame.new(position), Color3.fromRGB(255, 150, 50), 0.1)
	ball.Shape = Enum.PartType.Ball
	TweenService:Create(ball, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = Vector3.one * radius * 1.6, Transparency = 1 }):Play()
	Debris:AddItem(ball, 0.4)
	shakeFrom(position, 3, radius * 4)
end

-- Sci-fi impacts
function Effects.Zap(position: Vector3, radius: number, color: Color3)
	local ball = fxPart(Vector3.one, CFrame.new(position), color, 0)
	ball.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = radius * 3
	light.Brightness = 5
	light.Parent = ball
	TweenService:Create(ball, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = Vector3.one * radius * 2, Transparency = 1 }):Play()
	Debris:AddItem(ball, 0.3)
	Effects.Sound3D("ShotHeavy", position, 1.3)
	shakeFrom(position, 1, radius * 4)
end

function Effects.Void(position: Vector3, radius: number)
	local purple = Color3.fromRGB(170, 70, 255)
	-- implode then burst
	local core = fxPart(Vector3.one * radius * 1.6, CFrame.new(position), Color3.fromRGB(20, 0, 40), 0.2)
	core.Shape = Enum.PartType.Ball
	core.Material = Enum.Material.Glass
	TweenService:Create(core, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.one * 0.5 }):Play()
	local ring = fxPart(Vector3.new(0.4, 2, 2), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), purple, 0.1)
	ring.Shape = Enum.PartType.Cylinder
	task.delay(0.35, function()
		TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = Vector3.new(0.2, radius * 2.4, radius * 2.4), Transparency = 1 }):Play()
		Effects.Zap(position, radius * 0.7, purple)
		shakeFrom(position, 3, radius * 4)
	end)
	Debris:AddItem(core, 0.4)
	Debris:AddItem(ring, 0.9)
end

function Effects.Shockwave(position: Vector3, radius: number)
	local ring = fxPart(Vector3.new(0.4, 2, 2), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), Config.Colors.Accent2, 0.1)
	ring.Shape = Enum.PartType.Cylinder
	TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.45)
	Effects.Sound3D("Slam", position)
	shakeFrom(position, 2.5, radius * 3)
end

-- Another player's/bot's shot (our own shots are drawn instantly by WeaponController).
function Effects.RemoteShot(character: Model?, weaponId: string, ends)
	if not character or character == player.Character then
		return
	end
	Effects.LastFired[character] = os.clock()
	local def = Weapons.Get(weaponId)
	local tool = character:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	local muzzle = handle and handle:FindFirstChild("Muzzle")
	local from
	if muzzle then
		from = muzzle.WorldPosition
	else
		local head = character:FindFirstChild("Head")
		if not head then
			return
		end
		from = head.Position
	end
	local color = def and def.Look.Neon and def.Look.Accent or nil
	for _, to in ends do
		Effects.Tracer(from, to, color, def and def.Look.Neon and 0.25 or 0.08)
		Effects.Impact(to)
	end
	Effects.Flash(from)
	local cam = workspace.CurrentCamera
	GunAudio.Shot(weaponId, from, cam and cam.CFrame.Position)
end

-- Target reaction: briefly flash the character you hit (white, gold for headshots).
function Effects.HitFlash(position: Vector3?, headshot: boolean?)
	if not position then
		return
	end
	local best, bestDist = nil, 6
	local candidates = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character then
			table.insert(candidates, p.Character)
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, b in bots:GetChildren() do
			table.insert(candidates, b)
		end
	end
	for _, char in candidates do
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			local d = (root.Position - position).Magnitude
			if d < bestDist then
				best, bestDist = char, d
			end
		end
	end
	if not best then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = headshot and Config.Colors.Gold or Color3.new(1, 1, 1)
	h.FillTransparency = 0.35
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = best
	h.Parent = folder()
	TweenService:Create(h, TweenInfo.new(0.15), { FillTransparency = 1 }):Play()
	Debris:AddItem(h, 0.2)
end

-- Rocket / grenade-launcher launch from someone else
function Effects.Launch(character: Model?, weaponId: string)
	if not character or character == player.Character then
		return
	end
	Effects.LastFired[character] = os.clock()
	local def = Weapons.Get(weaponId)
	local tool = character:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	local muzzle = handle and handle:FindFirstChild("Muzzle")
	local pos = muzzle and muzzle.WorldPosition or (character:FindFirstChild("Head") and character.Head.Position)
	if pos then
		Effects.Flash(pos, def and def.Look.Accent)
		Effects.Sound3D("ShotHeavy", pos, 0.7)
	end
end

function Effects.UAVActive(): boolean
	return os.clock() < uavUntil
end

-- UAV: highlight every enemy through walls.
local highlights = {}
local function clearHighlights()
	for _, h in highlights do
		h:Destroy()
	end
	highlights = {}
end

function Effects.UAV(duration: number)
	uavUntil = os.clock() + duration
	task.spawn(function()
		while os.clock() < uavUntil do
			clearHighlights()
			local targets = {}
			for _, p in Players:GetPlayers() do
				if p ~= player and p.Character then
					table.insert(targets, p.Character)
				end
			end
			local bots = workspace:FindFirstChild("Bots")
			if bots then
				for _, b in bots:GetChildren() do
					table.insert(targets, b)
				end
			end
			local myTeam = player:GetAttribute("Team")
			for _, char in targets do
				local p = Players:GetPlayerFromCharacter(char)
				local team = p and p:GetAttribute("Team") or char:GetAttribute("Team")
				if myTeam and team == myTeam then
					continue -- UAV only shows enemies
				end
				local h = Instance.new("Highlight")
				h.FillColor = Config.Colors.Red
				h.FillTransparency = 0.6
				h.OutlineColor = Color3.new(1, 1, 1)
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.Adornee = char
				h.Parent = folder()
				table.insert(highlights, h)
			end
			task.wait(1)
		end
		clearHighlights()
	end)
end

return Effects
