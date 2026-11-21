-- Pre-match vote screen: 3 rotating map choices + the 3 game modes.
-- Shown to everyone while MatchState == "Voting" (above every other menu).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer
local T = UIKit.Theme
local new, Label = UIKit.new, UIKit.Label
local rgb = Color3.fromRGB

local VoteScreen = {}

-- per-map card art (gradient colors)
local THEMES = {
	Downtown = { rgb(255, 150, 60), rgb(60, 40, 110) },
	Harbor = { rgb(40, 170, 220), rgb(20, 40, 80) },
	Timberline = { rgb(90, 200, 90), rgb(20, 60, 40) },
	Arena = { rgb(255, 210, 40), rgb(0, 140, 200) },
}
local MODE_ICONS = { FFA = "💀", TDM = "⚔️", TTDM = "🔺" }

local gui, root, timerLabel, timerBar, mapRow, modeRow, footer
local blur
local cards = {} -- id -> { Kind, Frame, Stroke, Count, Fill, Badge, Lead, Scale }
local builtFor = nil
local myMap, myMode = nil, nil

local function votes(id: string): number
	return ReplicatedStorage:GetAttribute("Votes_" .. id) or 0
end

local function card(parent: Instance, id: string, kind: string, order: number, size: Vector2, top: Color3, bottom: Color3)
	local btn = new("TextButton", {
		Name = id, Size = UDim2.fromOffset(size.X, size.Y), BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false, Text = "", LayoutOrder = order, ClipsDescendants = true, Parent = parent,
	})
	UIKit.Corner(12).Parent = btn
	UIKit.Gradient(top, bottom, 90).Parent = btn
	local stroke = new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.75, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = btn })
	local scale = new("UIScale", { Parent = btn })
	-- glossy shine across the top
	local shine = new("Frame", { Size = UDim2.new(1, 0, 0.45, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, BorderSizePixel = 0, Parent = btn })
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1), Parent = shine })
	-- dark footer strip for the vote bar
	local bottomStrip = new("Frame", { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 1, -34), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = btn })
	local barBack = new("Frame", { Size = UDim2.new(1, -90, 0, 8), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.8, BorderSizePixel = 0, Parent = bottomStrip })
	UIKit.Corner(4).Parent = barBack
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = barBack })
	UIKit.Corner(4).Parent = fill
	local count = Label({ Text = "0 VOTES", Size = UDim2.new(0, 70, 1, 0), Position = UDim2.new(1, -10, 0, 0), AnchorPoint = Vector2.new(1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 13, Font = T.Black, Parent = bottomStrip })
	local badge = Label({
		Text = "✓ YOUR VOTE", Size = UDim2.fromOffset(104, 22), Position = UDim2.new(1, -10, 0, 10), AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, BackgroundColor3 = T.Accent, TextColor3 = Color3.new(0, 0, 0), TextSize = 11, Font = T.Black, Visible = false, ZIndex = 3, Parent = btn,
	})
	UIKit.Corner(11).Parent = badge
	local lead = Label({
		Text = "🔥 LEADING", Size = UDim2.fromOffset(96, 22), Position = UDim2.fromOffset(10, 10),
		TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0.2, BackgroundColor3 = rgb(230, 60, 50), TextSize = 11, Font = T.Black, Visible = false, ZIndex = 3, Parent = btn,
	})
	UIKit.Corner(11).Parent = lead

	btn.MouseEnter:Connect(function()
		UIKit.Tween(scale, 0.15, { Scale = 1.04 })
	end)
	btn.MouseLeave:Connect(function()
		UIKit.Tween(scale, 0.15, { Scale = 1 })
	end)
	btn.Activated:Connect(function()
		UIKit.Sound("Click")
		if kind == "Map" then
			myMap = id
		else
			myMode = id
		end
		Remotes.Vote:FireServer(id)
		scale.Scale = 0.95
		UIKit.Tween(scale, 0.25, { Scale = 1.04 }, Enum.EasingStyle.Back)
	end)
	cards[id] = { Kind = kind, Frame = btn, Stroke = stroke, Count = count, Fill = fill, Badge = badge, Lead = lead }
	return btn
end

local function section(title: string, sub: string, y: number, height: number)
	local holder = new("Frame", { Size = UDim2.new(1, 0, 0, height + 34), Position = UDim2.fromOffset(0, y), BackgroundTransparency = 1, Parent = root })
	local t = Label({ Text = title, Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 18, Font = T.Black, Parent = holder })
	UIKit.TextStroke(0.5).Parent = t
	Label({ Text = sub, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 20), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11, Font = T.Bold, TextColor3 = T.Sub, Parent = holder })
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, height), Position = UDim2.fromOffset(0, 40), BackgroundTransparency = 1, Parent = holder }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	return row
end

local function build(options: { string })
	for _, c in cards do
		c.Frame:Destroy()
	end
	cards = {}
	myMap, myMode = nil, nil
	for i, id in options do
		local info = Config.Maps[id] or { Name = id, Icon = "🗺️", Desc = "" }
		local theme = THEMES[id] or { T.Panel3, T.Panel }
		local c = card(mapRow, id, "Map", i, Vector2.new(250, 170), theme[1], theme[2])
		local icon = Label({ Text = info.Icon, Size = UDim2.new(1, 0, 0, 58), Position = UDim2.fromOffset(0, 30), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 54, Font = T.Black, Parent = c })
		icon.TextTransparency = 0.05
		local name = Label({ Text = info.Name, Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 88), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 22, Font = T.Black, Parent = c })
		UIKit.TextStroke(0.4).Parent = name
		Label({ Text = info.Desc, Size = UDim2.new(1, -20, 0, 16), Position = UDim2.fromOffset(10, 114), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12, Font = T.Bold, TextColor3 = rgb(225, 230, 240), Parent = c })
	end
	for i, id in Config.ModeOrder do
		local m = Config.Modes[id]
		local accent = (#m.Teams > 0) and Config.Teams[m.Teams[1]].Color or rgb(200, 70, 220)
		local c = card(modeRow, id, "Mode", i, Vector2.new(250, 156), accent:Lerp(Color3.new(0, 0, 0), 0.35), rgb(18, 20, 30))
		Label({ Text = MODE_ICONS[id] or "🎯", Size = UDim2.fromOffset(40, 36), Position = UDim2.fromOffset(12, 12), TextSize = 28, Font = T.Black, Parent = c })
		local name = Label({ Text = m.Name, Size = UDim2.new(1, -66, 0, 36), Position = UDim2.fromOffset(56, 10), TextSize = 15, Font = T.Black, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
		UIKit.TextStroke(0.5).Parent = name
		-- team color dots (one per team, or a rainbow ring of 6 for FFA)
		local dots = new("Frame", { Size = UDim2.fromOffset(120, 12), Position = UDim2.fromOffset(56, 50), BackgroundTransparency = 1, Parent = c }, { UIKit.List(4, true) })
		local colors = {}
		if #m.Teams > 0 then
			for _, team in m.Teams do
				table.insert(colors, Config.Teams[team].Color)
			end
		else
			for k = 0, 5 do
				table.insert(colors, Color3.fromHSV(k / 6, 0.7, 1))
			end
		end
		for k, col in colors do
			local d = new("Frame", { Size = UDim2.fromOffset(12, 12), BackgroundColor3 = col, BorderSizePixel = 0, LayoutOrder = k, Parent = dots })
			UIKit.Corner(6).Parent = d
		end
		Label({ Text = m.Desc or "", Size = UDim2.new(1, -24, 0, 28), Position = UDim2.fromOffset(12, 68), TextSize = 11, Font = T.Bold, TextColor3 = rgb(210, 215, 228), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
		c:FindFirstChild("Frame").Size = UDim2.new(1, 0, 0.35, 0)
		-- badges sit in their own row above the vote bar so they never cover the text
		cards[id].Badge.Position = UDim2.new(1, -10, 1, -60)
		cards[id].Lead.Position = UDim2.new(0, 10, 1, -60)
	end
end

local function refresh()
	local totals = { Map = 0, Mode = 0 }
	local best = { Map = { 0, nil }, Mode = { 0, nil } }
	for id, c in cards do
		local n = votes(id)
		totals[c.Kind] += n
		if n > best[c.Kind][1] then
			best[c.Kind] = { n, id }
		end
	end
	for id, c in cards do
		local n = votes(id)
		local mine = (c.Kind == "Map" and id == myMap) or (c.Kind == "Mode" and id == myMode)
		c.Count.Text = n .. (n == 1 and " VOTE" or " VOTES")
		local share = totals[c.Kind] > 0 and n / totals[c.Kind] or 0
		c.Fill.Size = c.Fill.Size:Lerp(UDim2.fromScale(share, 1), 0.2)
		c.Fill.BackgroundColor3 = mine and T.Accent or Color3.new(1, 1, 1)
		c.Badge.Visible = mine
		c.Lead.Visible = best[c.Kind][2] == id
		c.Stroke.Color = mine and T.Accent or Color3.new(1, 1, 1)
		c.Stroke.Thickness = mine and 4 or 2
		c.Stroke.Transparency = mine and 0 or 0.75
	end
end

function VoteScreen.Init(playerGui: PlayerGui)
	gui = new("ScreenGui", { Name = "Vote", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, Enabled = false, Parent = playerGui })
	local bg = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(6, 8, 14), BackgroundTransparency = 0.12, Text = "", AutoButtonColor = false, Modal = true, Parent = gui })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(rgb(30, 36, 60), rgb(4, 5, 10)),
		Parent = bg,
	})
	-- diagonal accent stripes
	for k = 0, 2 do
		local stripe = new("Frame", {
			Size = UDim2.new(0, 6, 2, 0), Position = UDim2.new(0.08 + k * 0.03, 0, -0.5, 0), Rotation = 25,
			BackgroundColor3 = T.Accent, BackgroundTransparency = 0.82 + k * 0.05, BorderSizePixel = 0, Parent = bg,
		})
		stripe.ZIndex = 0
	end

	root = new("Frame", { Size = UDim2.fromOffset(820, 570), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = bg })
	local rootScale = new("UIScale", { Parent = root })

	local title = Label({ Text = "VOTE FOR THE NEXT MATCH", Size = UDim2.new(1, 0, 0, 44), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 38, Font = T.Black, Parent = root })
	UIKit.Gradient(T.Accent, rgb(255, 120, 30), 90).Parent = title
	UIKit.TextStroke(0.5).Parent = title
	-- timer pill + shrinking bar
	local pill = UIKit.Panel({ Size = UDim2.fromOffset(150, 34), Position = UDim2.new(0.5, 0, 0, 50), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = rgb(0, 0, 0), BackgroundTransparency = 0.35 })
	pill.Parent = root
	UIKit.Corner(17).Parent = pill
	UIKit.Stroke(T.Accent, 1.5, 0.3).Parent = pill
	timerLabel = Label({ Text = "15", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 18, Font = T.Black, Parent = pill })
	local barBack = new("Frame", { Size = UDim2.fromOffset(360, 4), Position = UDim2.new(0.5, 0, 0, 92), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = root })
	UIKit.Corner(2).Parent = barBack
	timerBar = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = barBack })
	UIKit.Corner(2).Parent = timerBar

	mapRow = section("🗺️  CHOOSE A MAP", "A new set of maps every round", 110, 170)
	modeRow = section("🎮  CHOOSE A MODE", "No mode votes? The game moves on to the next mode", 330, 156)
	footer = Label({ Text = "Click a card to vote · you can change your vote any time", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -10), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12, Font = T.Bold, TextColor3 = T.Sub, Parent = root })

	blur = new("BlurEffect", { Name = "VoteBlur", Size = 0, Parent = Lighting })

	local wasOpen = false
	RunService.Heartbeat:Connect(function()
		local open = ReplicatedStorage:GetAttribute("MatchState") == "Voting"
		local options = ReplicatedStorage:GetAttribute("VoteOptions") or ""
		if open and options ~= "" and options ~= builtFor then
			builtFor = options
			build(string.split(options, ","))
		end
		if open ~= wasOpen then
			wasOpen = open
			gui.Enabled = open
			ClientState.VoteOpen = open
			UIKit.Tween(blur, 0.4, { Size = open and 18 or 0 })
			if open then
				root.Position = UDim2.new(0.5, 0, 0.5, 30)
				UIKit.Tween(root, 0.45, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
			else
				builtFor = nil
			end
		end
		if not open then
			return
		end
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		rootScale.Scale = math.clamp(math.min(vp.X / 880, vp.Y / 600), 0.45, 1.25)
		local left = math.max(0, (ReplicatedStorage:GetAttribute("MatchEnd") or 0) - workspace:GetServerTimeNow())
		timerLabel.Text = "⏱  " .. math.ceil(left) .. "s"
		timerLabel.TextColor3 = left <= 2 and T.Red or T.Text
		timerBar.Size = UDim2.fromScale(math.clamp(left / Config.VoteLength, 0, 1), 1)
		timerBar.BackgroundColor3 = left <= 2 and T.Red or T.Accent
		footer.Text = left <= 1 and "Locking in votes…" or "Click a card to vote · you can change your vote any time"
		refresh()
	end)
	player:GetAttributeChangedSignal("Team"):Connect(refresh)
end

return VoteScreen
