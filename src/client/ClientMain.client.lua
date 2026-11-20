-- Client entry point: builds the UI, starts the controllers and routes
-- server messages to the right place.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local ClientState = require(script.Parent.ClientState)
local UIKit = require(script.Parent.UIKit)
local Effects = require(script.Parent.Effects)
local HUD = require(script.Parent.HUD)
local Menus = require(script.Parent.Menus)
local Movement = require(script.Parent.MovementController)
local Weapons = require(script.Parent.WeaponController)
local Vehicle = require(script.Parent.VehicleController)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- hide default Roblox UI we replace
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

-- UI + controllers --------------------------------------------------------------
HUD.Init(playerGui)
Menus.Init(playerGui)
Weapons.HUD = HUD
Menus.Notify = HUD.Message
HUD.OpenMenu = function(name)
	if name == "Scoreboard" then
		Menus.ShowScoreboard(true)
		task.delay(4, function()
			Menus.ShowScoreboard(false)
		end)
	else
		Menus.Open(name)
	end
end
Movement.Init()
Weapons.Init()
Vehicle.Init()
ClientState.Changed.Event:Connect(function()
	Effects.ShakeScale = ClientState.Settings.Shake or 1
end)

Menus.OnDeploy = function()
	ClientState.Deployed = true
	HUD.SetVisible(true)
	Remotes.Deploy:FireServer()
end
Menus.ShowMain()

task.spawn(function()
	Remotes.GetData:InvokeServer()
end)

-- CHARACTER / CAMERA ----------------------------------------------------------------
local camera = workspace.CurrentCamera

local function onCharacter(char: Model)
	local humanoid = char:WaitForChild("Humanoid")
	ClientState.Dead = false
	HUD.HideDeath()
	camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	humanoid.Died:Connect(function()
		ClientState.Dead = true
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 8
		task.delay(0.1, function()
			player.CameraMinZoomDistance = 0.5
		end)
	end)
end
if player.Character then
	task.spawn(onCharacter, player.Character)
end
player.CharacterAdded:Connect(onCharacter)

-- Menu backdrop: slow orbit over the arena until you hit PLAY.
local orbit = 0
RunService.RenderStepped:Connect(function(dt)
	camera = workspace.CurrentCamera
	if not ClientState.Deployed then
		orbit += dt * 0.06
		camera.CameraType = Enum.CameraType.Scriptable
		local pos = Vector3.new(math.cos(orbit) * 140, 60, math.sin(orbit) * 140)
		camera.CFrame = CFrame.lookAt(pos, Vector3.new(0, 8, 0))
		camera.FieldOfView = 70
	end
	local freeMouse = ClientState.MenuOpen or ClientState.Dead or not ClientState.Deployed
	UserInputService.MouseIconEnabled = freeMouse
end)

-- HOTKEYS ---------------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local k = input.KeyCode
	if k == Enum.KeyCode.B then
		Menus.Toggle("Armory")
	elseif k == Enum.KeyCode.N then
		Menus.Toggle("Store")
	elseif k == Enum.KeyCode.J then
		Menus.Toggle("Achievements")
	elseif k == Enum.KeyCode.P then
		Menus.Toggle("Settings")
	elseif k == Enum.KeyCode.Tab then
		Menus.ShowScoreboard(true)
	elseif k == Enum.KeyCode.ButtonSelect then
		Menus.ShowScoreboard(true)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Tab or input.KeyCode == Enum.KeyCode.ButtonSelect then
		Menus.ShowScoreboard(false)
	end
end)

-- SERVER MESSAGES ---------------------------------------------------------------------------
Remotes.Notify.OnClientEvent:Connect(function(kind, payload)
	if kind == "Kill" then
		HUD.Kill(payload)
	elseif kind == "Medal" then
		HUD.Medals(payload.Medals)
	elseif kind == "Achievement" then
		HUD.Achievement(payload)
	elseif kind == "LevelUp" then
		HUD.LevelUp(payload.Level, payload.Reward)
	elseif kind == "Cash" then
		HUD.Cash(payload.Amount, payload.Reason)
	elseif kind == "Announce" then
		HUD.Announce(payload)
	elseif kind == "Message" then
		HUD.Message(payload.Text, payload.Color)
		if payload.Upsell then
			task.delay(0.6, function()
				Menus.Open("Store", "Cash & Boosts")
			end)
		end
	end
end)

Remotes.KillFeed.OnClientEvent:Connect(HUD.Feed)

Remotes.KillInfo.OnClientEvent:Connect(function(info)
	HUD.Death(info)
	-- killcam: watch the player who got you
	local killerChar = info.KillerCharacter
	local hum = killerChar and killerChar:FindFirstChildOfClass("Humanoid")
	if hum then
		task.delay(0.6, function()
			if ClientState.Dead then
				workspace.CurrentCamera.CameraSubject = hum
			end
		end)
	end
end)

Remotes.Damaged.OnClientEvent:Connect(function(from, amount)
	HUD.Damaged(from, amount)
	Effects.Shake(math.clamp(amount / 40, 0.2, 1.5))
	if amount >= 20 then
		UIKit.Sound("Hurt", 1 + math.random() * 0.2)
	end
end)

Remotes.Killstreak.OnClientEvent:Connect(function(kind, duration)
	if kind == "UAV" then
		Effects.UAV(duration)
		HUD.Status("📡 UAV ACTIVE", duration)
	elseif kind == "Overdrive" then
		HUD.Status("⚡ OVERDRIVE", duration)
	end
end)

Remotes.Effect.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "Shot" then
		Effects.RemoteShot(a, b, c)
	elseif kind == "Launch" then
		Effects.Launch(a, b)
	elseif kind == "Explosion" then
		Effects.Explosion(a, b)
	elseif kind == "Slam" then
		Effects.Shockwave(a, b)
	elseif kind == "Knife" then
		if a and a ~= player.Character and a:FindFirstChild("Head") then
			Effects.Sound3D("Knife", a.Head.Position)
		end
	elseif kind == "AirstrikeIncoming" then
		for _, pos in a do
			Effects.Sound3D("Empty", pos, 0.4)
		end
	elseif kind == "NukeIncoming" then
		HUD.Nuke(a, b)
	elseif kind == "NukeDetonate" then
		HUD.WhiteFlash()
		Effects.Shake(8)
	elseif kind == "RefillAmmo" then
		Weapons.RefillReserve()
	end
end)

Remotes.MatchResults.OnClientEvent:Connect(Menus.ShowResults)

-- VIP chat tag
pcall(function()
	TextChatService.OnIncomingMessage = function(message)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local p = source and Players:GetPlayerByUserId(source.UserId)
		if p and p:GetAttribute("Pass_VIP") then
			props.PrefixText = "<font color='#FFCD3C'>[👑 VIP]</font> " .. message.PrefixText
		end
		return props
	end
end)
