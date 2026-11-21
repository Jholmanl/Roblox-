-- Layered, more realistic gun audio built from sounds that ship with Roblox.
-- Every shot is several layers (sharp crack + low body + mechanical), shaped with
-- EQ / compression, and distant shots get muffled with an outdoor slap-back echo.
-- Reloads play a timed sequence (mag out, mag in, charging handle / pump / bolt).
--
-- Want studio-quality samples? Paste Creator Store sound ids into
-- Sounds.GunOverrides (see Sounds.lua) and they replace the built-in layers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Sounds)
local GunBuilder = require(Shared.GunBuilder)

local GunAudio = {}

local CRACK = "rbxasset://sounds/snap.mp3"
local BODY = "rbxasset://sounds/collide.wav"
local CLICK = "rbxasset://sounds/clickfast.wav"
local TICK = "rbxasset://sounds/button.wav"
local WHOOSH = "rbxasset://sounds/swoosh.wav"
local ZAP = "rbxasset://sounds/electronicpingshort.wav"

-- layer = { id, volume, pitch, distortion? }
local PROFILES = {
	Rifle = { Layers = { { CRACK, 0.75, 1.0 }, { BODY, 0.6, 0.55, 0.25 }, { CLICK, 0.18, 1.6 } }, Tail = 0.45, Brass = true },
	SMG = { Layers = { { CRACK, 0.6, 1.25 }, { BODY, 0.4, 0.75, 0.15 }, { CLICK, 0.2, 1.9 } }, Tail = 0.3, Brass = true },
	Pistol = { Layers = { { CRACK, 0.65, 1.15 }, { BODY, 0.45, 0.8, 0.15 }, { CLICK, 0.25, 1.7 } }, Tail = 0.3, Brass = true },
	Magnum = { Layers = { { CRACK, 0.85, 0.82 }, { BODY, 0.8, 0.42, 0.35 }, { BODY, 0.35, 0.7 } }, Tail = 0.7, Brass = false },
	Shotgun = { Layers = { { BODY, 0.95, 0.4, 0.4 }, { CRACK, 0.7, 0.72 }, { BODY, 0.4, 0.62 } }, Tail = 0.8, Brass = false },
	Sniper = { Layers = { { CRACK, 0.95, 0.72 }, { BODY, 0.9, 0.34, 0.45 }, { BODY, 0.45, 0.55 } }, Tail = 1.2, Brass = true },
	LMG = { Layers = { { CRACK, 0.75, 0.95 }, { BODY, 0.65, 0.5, 0.3 }, { CLICK, 0.15, 1.4 } }, Tail = 0.5, Brass = true },
	Launcher = { Layers = { { BODY, 0.9, 0.45, 0.3 }, { WHOOSH, 0.8, 0.7 } }, Tail = 0.8, Brass = false },
	Energy = { Layers = { { ZAP, 0.55, 0.55 }, { WHOOSH, 0.4, 1.6 }, { BODY, 0.3, 1.2 } }, Tail = 0.3, Brass = false },
}

local STYLE_PROFILE = {
	M4 = "Rifle", AK = "Rifle", SCAR = "Rifle", FAMAS = "Rifle", SVD = "Rifle",
	MP5 = "SMG", PDW = "SMG", Uzi = "SMG",
	Pistol = "Pistol", Deagle = "Magnum", Revolver = "Magnum",
	Pump = "Shotgun", AA12 = "Shotgun", Double = "Shotgun",
	AWM = "Sniper", Barrett = "Sniper",
	M249 = "LMG", Minigun = "LMG",
	RPG = "Launcher", M32 = "Launcher",
	Railgun = "Energy", Energy = "Energy", RayGun = "Energy", Plasma = "Energy", Void = "Energy",
	MachinePistol = "Pistol", ARPistol = "Rifle", Vector = "SMG",
}
-- manual actions rack after every shot
local RACK_AFTER_SHOT = { Pump = 0.32, AWM = 0.45 }

local function styleOf(weaponId: string): string
	return (GunBuilder.Styles and GunBuilder.Styles[weaponId]) or "M4"
end

local function profileOf(weaponId: string)
	return PROFILES[STYLE_PROFILE[styleOf(weaponId)] or "Rifle"]
end

-- Plays one layer. position = nil -> 2D (your own gun), otherwise 3D at that point.
local function layer(id: string, volume: number, pitch: number, position: Vector3?, opts)
	opts = opts or {}
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = pitch * (0.97 + math.random() * 0.06)
	local holder
	if position then
		holder = Instance.new("Attachment")
		holder.WorldPosition = position
		holder.Parent = workspace.Terrain
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = opts.MinDistance or 12
		s.RollOffMaxDistance = opts.MaxDistance or 600
		s.Parent = holder
	else
		s.Parent = SoundService
	end
	if opts.Distortion and opts.Distortion > 0 then
		local d = Instance.new("DistortionSoundEffect")
		d.Level = opts.Distortion
		d.Parent = s
	end
	if opts.Punch then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = 6
		eq.MidGain = 0
		eq.HighGain = 2
		eq.Parent = s
		local comp = Instance.new("CompressorSoundEffect")
		comp.Threshold = -14
		comp.Ratio = 4
		comp.Attack = 0.002
		comp.Release = 0.12
		comp.GainMakeup = 2
		comp.Parent = s
	end
	if opts.Muffle and opts.Muffle > 0 then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.HighGain = -opts.Muffle
		eq.MidGain = -opts.Muffle * 0.4
		eq.LowGain = 2
		eq.Parent = s
	end
	if opts.Echo then
		local echo = Instance.new("EchoSoundEffect")
		echo.Delay = opts.Echo
		echo.Feedback = 0.25
		echo.DryLevel = 0
		echo.WetLevel = -10
		echo.Parent = s
	end
	s:Play()
	Debris:AddItem(holder or s, 4)
	return s
end

local function override(kind: string, weaponId: string)
	local o = Sounds.GunOverrides
	if not o then
		return nil
	end
	local entry = o[weaponId] or o[STYLE_PROFILE[styleOf(weaponId)] or ""]
	return entry and entry[kind]
end

-- A gunshot. position nil = your own gun (2D, punchy); otherwise someone else's.
function GunAudio.Shot(weaponId: string, position: Vector3?, listener: Vector3?)
	local prof = profileOf(weaponId)
	local dist = (position and listener) and (position - listener).Magnitude or 0
	local muffle = position and math.clamp((dist - 40) / 12, 0, 24) or 0
	local echo = (position and dist > 70) and math.clamp(dist / 900, 0.12, 0.4) or nil
	local custom = override("Shot", weaponId)
	if custom then
		layer(custom, position and 0.9 or 1, 1, position, { Punch = not position, Muffle = muffle, Echo = echo })
	else
		for i, l in prof.Layers do
			-- the far-away sound of a gun is mostly the low "boom"; drop the crack with distance
			local vol = l[2]
			if position and i == 1 then
				vol *= math.clamp(1 - dist / 400, 0.25, 1)
			end
			layer(l[1], vol, l[3], position, { Distortion = l[4], Punch = not position and i == 2, Muffle = muffle, Echo = (i == 2) and echo or nil })
		end
	end
	-- outdoor tail: a quiet low rumble that hangs after the shot
	if prof.Tail > 0 and (not position or dist < 500) then
		task.delay(0.04, function()
			layer(BODY, 0.18 * prof.Tail, 0.3, position, { Muffle = muffle + 6, MaxDistance = 800 })
		end)
	end
	-- only your own gun gets the close-up mechanical details
	if not position then
		local rack = RACK_AFTER_SHOT[styleOf(weaponId)]
		if rack then
			task.delay(rack, function()
				layer(CLICK, 0.45, 0.62)
				task.wait(0.12)
				layer(CLICK, 0.4, 0.78)
			end)
		end
		if prof.Brass and math.random() < 0.6 then
			task.delay(0.28 + math.random() * 0.2, function()
				layer(TICK, 0.12, 2.6 + math.random() * 0.6)
			end)
		end
	end
end

-- Dry fire click.
function GunAudio.Empty()
	layer(CLICK, 0.5, 1.25)
end

-- A timed reload: mag out -> mag in -> charging handle / pump / bolt.
-- position nil = your own reload; otherwise someone else's (quieter, 3D).
function GunAudio.Reload(weaponId: string, duration: number, position: Vector3?)
	local style = styleOf(weaponId)
	local prof = STYLE_PROFILE[style] or "Rifle"
	local v = position and 0.6 or 1
	local custom = override("Reload", weaponId)
	if custom then
		layer(custom, 0.8 * v, 1, position)
		return
	end
	local function at(frac, fn)
		task.delay(duration * frac, fn)
	end
	local o = { MaxDistance = 90, MinDistance = 6 }
	if prof == "Shotgun" and style ~= "AA12" then
		-- shells pushed in one by one, then rack
		local shells = style == "Double" and 2 or 4
		for i = 1, shells do
			at(0.12 + (i - 1) * (0.62 / shells), function()
				layer(CLICK, 0.4 * v, 0.95 + math.random() * 0.1, position, o)
				layer(TICK, 0.15 * v, 1.4, position, o)
			end)
		end
		at(0.86, function()
			layer(CLICK, 0.55 * v, 0.6, position, o)
			task.wait(0.1)
			layer(CLICK, 0.5 * v, 0.75, position, o)
		end)
	elseif prof == "Magnum" and style == "Revolver" then
		at(0.1, function()
			layer(CLICK, 0.45 * v, 0.8, position, o) -- cylinder out
		end)
		at(0.25, function()
			for _ = 1, 5 do
				layer(TICK, 0.12 * v, 2.2 + math.random() * 0.5, position, o) -- casings drop
				task.wait(0.03)
			end
		end)
		at(0.55, function()
			layer(CLICK, 0.35 * v, 1.2, position, o) -- speedloader
		end)
		at(0.85, function()
			layer(CLICK, 0.55 * v, 0.7, position, o) -- cylinder closed
		end)
	elseif prof == "Energy" then
		at(0.2, function()
			layer(ZAP, 0.3 * v, 0.4, position, o)
		end)
		at(0.8, function()
			layer(ZAP, 0.4 * v, 0.9, position, o)
		end)
	else
		at(0.12, function()
			layer(CLICK, 0.5 * v, 0.85, position, o) -- mag release
		end)
		at(0.22, function()
			layer(BODY, 0.15 * v, 1.8, position, o) -- empty mag drops
		end)
		at(0.55, function()
			layer(CLICK, 0.55 * v, 1.05, position, o) -- new mag seated
			layer(BODY, 0.12 * v, 2.2, position, o)
		end)
		at(0.82, function()
			layer(CLICK, 0.6 * v, 0.62, position, o) -- charging handle back...
			task.wait(0.09)
			layer(CLICK, 0.55 * v, 0.9, position, o) -- ...and forward
		end)
	end
end

return GunAudio
