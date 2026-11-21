-- Featured pass spotlight: a big, good-looking card for one random game pass the
-- player doesn't own, about every 20 minutes of play.
-- It waits for a calm moment (dead, between matches, or 10s out of combat), never
-- covers the vote screen, and always has a clear "Maybe later" button.
-- Copy is honest: real perks, real price, no fake timers or "limited" claims.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared.Monetization)
local UIKit = require(script.Parent.UIKit)
local ClientState = require(script.Parent.ClientState)

local T = UIKit.Theme
local new, Label = UIKit.new, UIKit.Label
local rgb = Color3.fromRGB

local INTERVAL = 20 * 60

local Spotlight = {}
Spotlight.BuyPass = function(_key) end -- injected (Menus.BuyPass)
Spotlight.LastDamaged = 0 -- set by ClientMain when you take damage

local gui, overlay, card
local nextAt = math.huge
local lastKey = nil

local function calmMoment(): boolean
	local state = ReplicatedStorage:GetAttribute("MatchState")
	if state == "Voting" or ClientState.VoteOpen or ClientState.MenuOpen then
		return false
	end
	if ClientState.Dead or not ClientState.Deployed or state == "Results" or state == "Intermission" then
		return true
	end
	return os.clock() - Spotlight.LastDamaged > 10
end

local function pickPass(): string?
	local pool = {}
	for _, key in Monetization.PassOrder do
		if not ClientState.HasPass(key) and key ~= lastKey then
			table.insert(pool, key)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[math.random(1, #pool)]
end

function Spotlight.Hide()
	if not overlay or not overlay.Visible then
		return
	end
	ClientState.SpotlightOpen = false
	local scale = card:FindFirstChildOfClass("UIScale")
	UIKit.Tween(scale, 0.2, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	UIKit.Tween(overlay, 0.25, { BackgroundTransparency = 1 })
	task.delay(0.25, function()
		overlay.Visible = false
	end)
end

function Spotlight.Show(key: string)
	local pass = Monetization.GamePasses[key]
	if not pass then
		return
	end
	lastKey = key
	if card then
		card:Destroy()
	end
	local accent = pass.Color or T.Accent
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	UIKit.Tween(overlay, 0.3, { BackgroundTransparency = 0.45 })
	ClientState.SpotlightOpen = true

	card = new("Frame", {
		Name = "Card", Size = UDim2.fromOffset(520, 380), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = rgb(14, 16, 24), BorderSizePixel = 0, ClipsDescendants = true, Parent = overlay,
	})
	UIKit.Corner(16).Parent = card
	new("UIStroke", { Color = accent, Thickness = 2, Transparency = 0.2, Parent = card })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(accent:Lerp(rgb(14, 16, 24), 0.55), rgb(10, 12, 18)), Parent = card })
	local scale = new("UIScale", { Scale = 0.8, Parent = card })
	UIKit.Tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

	-- light sweep across the card
	local sweep = new("Frame", { Size = UDim2.new(0, 90, 2, 0), Position = UDim2.new(-0.3, 0, -0.5, 0), Rotation = 20, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, BorderSizePixel = 0, Parent = card })
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = sweep })
	task.spawn(function()
		while sweep.Parent do
			sweep.Position = UDim2.new(-0.3, 0, -0.5, 0)
			UIKit.Tween(sweep, 1.2, { Position = UDim2.new(1.2, 0, -0.5, 0) }, Enum.EasingStyle.Quad)
			task.wait(3.5)
		end
	end)

	local tag = Label({
		Text = "⭐ FEATURED PASS", Size = UDim2.fromOffset(150, 24), Position = UDim2.new(0.5, 0, 0, 18), AnchorPoint = Vector2.new(0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0.2, BackgroundColor3 = rgb(0, 0, 0), TextSize = 12, Font = T.Black, TextColor3 = T.Gold, Parent = card,
	})
	UIKit.Corner(12).Parent = tag

	-- icon with a slowly spinning glow ring
	local ring = new("Frame", { Size = UDim2.fromOffset(120, 120), Position = UDim2.new(0.5, 0, 0, 52), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = accent, BorderSizePixel = 0, Parent = card })
	UIKit.Corner(60).Parent = ring
	local ringGrad = new("UIGradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, accent), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, accent) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 0.2) }),
		Parent = ring,
	})
	local inner = new("Frame", { Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = rgb(18, 20, 30), BorderSizePixel = 0, Parent = ring })
	UIKit.Corner(55).Parent = inner
	UIKit.Gradient(accent:Lerp(rgb(18, 20, 30), 0.4), rgb(18, 20, 30), 90).Parent = inner
	Label({ Text = pass.Icon or "💎", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 58, Font = T.Black, Parent = inner })
	local spin
	spin = RunService.RenderStepped:Connect(function(dt)
		if not ring.Parent then
			spin:Disconnect()
			return
		end
		ringGrad.Rotation = (ringGrad.Rotation + dt * 60) % 360
	end)

	local title = Label({ Text = string.upper(pass.Name), Size = UDim2.new(1, -40, 0, 34), Position = UDim2.new(0, 20, 0, 182), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 30, Font = T.Black, Parent = card })
	UIKit.TextStroke(0.4).Parent = title
	local perks = new("Frame", { Size = UDim2.new(1, -80, 0, 70), Position = UDim2.new(0, 40, 0, 222), BackgroundTransparency = 1, Parent = card }, { UIKit.List(4) })
	for i, perk in pass.Perks or {} do
		if i > 3 then
			break
		end
		Label({ Text = "✓  " .. perk, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 14, Font = T.Bold, TextColor3 = rgb(225, 230, 240), LayoutOrder = i, Parent = perks })
	end
	local buy = UIKit.Button({ Text = "GET IT  ·  R$ " .. tostring(pass.Price), Size = UDim2.fromOffset(260, 46), Position = UDim2.new(0.5, 0, 1, -76), AnchorPoint = Vector2.new(0.5, 0), Color = T.Robux, TextSize = 18, Radius = 10, Parent = card }, function()
		Spotlight.BuyPass(key)
		Spotlight.Hide()
	end)
	buy.Name = "Buy"
	local later = new("TextButton", {
		Text = "Maybe later", Size = UDim2.fromOffset(160, 22), Position = UDim2.new(0.5, 0, 1, -26), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1, Font = T.Bold, TextSize = 13, TextColor3 = T.Sub, Parent = card,
	})
	later.Activated:Connect(Spotlight.Hide)
end

function Spotlight.Init(playerGui: PlayerGui)
	gui = new("ScreenGui", { Name = "Spotlight", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 15, Parent = playerGui })
	overlay = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Modal = true, Visible = false, Parent = gui })
	nextAt = os.clock() + INTERVAL
	task.spawn(function()
		while true do
			task.wait(2)
			if os.clock() >= nextAt and not overlay.Visible and calmMoment() then
				local key = pickPass()
				if key then
					Spotlight.Show(key)
				end
				nextAt = os.clock() + INTERVAL
			end
		end
	end)
end

return Spotlight
