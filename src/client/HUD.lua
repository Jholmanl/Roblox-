-- In-game HUD in the style of the big shooters:
-- score bar + timer (top), killfeed (top-right), health (bottom-left),
-- ammo (bottom-right), abilities + XP (bottom-center), crosshair, hitmarkers,
-- medals, kill popups, achievement toasts, death/killcam card.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Monetization = require(Shared.Monetization)
local UIKit = require(script.Parent.UIKit)
local ClientState = require(script.Parent.ClientState)
local Movement = require(script.Parent.MovementController)

local player = Players.LocalPlayer
local T = UIKit.Theme
local new, Label = UIKit.new, UIKit.Label

local HUD = {}
HUD.OpenMenu = nil -- injected: function(name)

local gui
local refs = {}

local function shadowText(props)
	local l = Label(props)
	UIKit.TextStroke(0.5).Parent = l
	return l
end

-- TOP BAR ----------------------------------------------------------------------
local function buildTopBar()
	local bar = new("Frame", {
		Name = "TopBar", Size = UDim2.fromOffset(420, 62), Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = gui,
	})
	local function box(x, w, color, name)
		local f = UIKit.Panel({ Name = name, Size = UDim2.fromOffset(w, 62), Position = UDim2.fromOffset(x, 0), BackgroundColor3 = color, BackgroundTransparency = 0.2, Parent = bar })
		return f
	end
	local you = box(0, 104, Color3.fromRGB(0, 90, 130), "You")
	new("Frame", { Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 1, -3), BackgroundColor3 = T.Accent2, BorderSizePixel = 0, Parent = you })
	Label({ Text = "YOU", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 6), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12, TextColor3 = T.Accent2, Font = T.Black, Parent = you })
	refs.YouKills = Label({ Text = "0", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 22), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 30, Font = T.Black, Parent = you })

	local mid = box(110, 200, T.Panel, "Timer")
	refs.Timer = Label({ Text = "5:00", Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 4), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 32, Font = T.Black, Parent = mid })
	refs.Mode = Label({ Text = Config.ModeName .. " · FIRST TO " .. Config.KillsToWin, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 40), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11, TextColor3 = T.Sub, Font = T.Bold, Parent = mid })

	local lead = box(316, 104, Color3.fromRGB(130, 20, 30), "Leader")
	new("Frame", { Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 1, -3), BackgroundColor3 = T.Red, BorderSizePixel = 0, Parent = lead })
	refs.LeaderName = Label({ Text = "LEADER", Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 6), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12, TextColor3 = Color3.fromRGB(255, 140, 140), Font = T.Black, TextTruncate = Enum.TextTruncate.AtEnd, Parent = lead })
	refs.LeaderKills = Label({ Text = "0", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 22), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 30, Font = T.Black, Parent = lead })

	refs.Banner = shadowText({
		Text = "", Size = UDim2.fromOffset(500, 22), Position = UDim2.new(0.5, 0, 0, 76), AnchorPoint = Vector2.new(0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, Font = T.Black, TextColor3 = T.Accent, Parent = gui,
	})
	refs.Status = shadowText({
		Text = "", Size = UDim2.fromOffset(500, 20), Position = UDim2.new(0.5, 0, 0, 98), AnchorPoint = Vector2.new(0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Center, TextSize = 14, Font = T.Black, TextColor3 = T.Accent2, Parent = gui,
	})
end

-- PROFILE (top-left) -------------------------------------------------------------
local function buildProfile()
	local f = new("Frame", { Name = "Profile", Size = UDim2.fromOffset(260, 80), Position = UDim2.fromOffset(16, 192), BackgroundTransparency = 1, Parent = gui })
	local badge = UIKit.Panel({ Size = UDim2.fromOffset(46, 46), BackgroundColor3 = T.Accent, BackgroundTransparency = 0, Parent = f })
	Label({ Text = "LVL", Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 5), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 10, Font = T.Black, TextColor3 = Color3.new(0, 0, 0), Parent = badge })
	refs.Level = Label({ Text = "1", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 16), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 22, Font = T.Black, TextColor3 = Color3.new(0, 0, 0), Parent = badge })
	refs.Name = shadowText({ Text = player.DisplayName, Size = UDim2.fromOffset(200, 18), Position = UDim2.fromOffset(54, 2), TextSize = 15, Font = T.Black, Parent = f })
	refs.Cash = shadowText({ Text = "$0", Size = UDim2.fromOffset(200, 22), Position = UDim2.fromOffset(54, 22), TextSize = 20, Font = T.Black, TextColor3 = T.Green, Parent = f })
	refs.CashPop = shadowText({ Text = "", Size = UDim2.fromOffset(200, 18), Position = UDim2.fromOffset(54, 46), TextSize = 15, Font = T.Black, TextColor3 = T.Green, TextTransparency = 1, Parent = f })
	refs.Boosts = new("Frame", { Size = UDim2.fromOffset(260, 20), Position = UDim2.fromOffset(0, 54), BackgroundTransparency = 1, Parent = f }, { UIKit.List(4, true) })
end

local function pill(parent, text, color)
	local p = UIKit.Panel({ Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = color, BackgroundTransparency = 0.1, Parent = parent })
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = p })
	Label({ Text = text, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, TextSize = 11, Font = T.Black, TextColor3 = Color3.new(0, 0, 0), Parent = p })
	return p
end

-- SIDE MENU (left) ---------------------------------------------------------------
local function buildSideMenu()
	local f = new("Frame", { Name = "Side", Size = UDim2.fromOffset(150, 240), Position = UDim2.new(0, 16, 0.62, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Parent = gui }, { UIKit.List(6) })
	local items = {
		{ "Armory", "🔫 ARMORY", "B", T.Panel2 },
		{ "Store", "💎 STORE", "N", T.Robux },
		{ "Achievements", "🏆 TROPHIES", "J", T.Panel2 },
		{ "Scoreboard", "📋 SCORES", "TAB", T.Panel2 },
		{ "Settings", "⚙️ SETTINGS", "P", T.Panel2 },
	}
	for i, item in items do
		local b = UIKit.Button({ Text = "", Size = UDim2.fromOffset(150, 34), Color = item[4], LayoutOrder = i, Parent = f }, function()
			if HUD.OpenMenu then
				HUD.OpenMenu(item[1])
			end
		end)
		b.BackgroundTransparency = 0.15
		Label({ Text = item[2], Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(10, 0), TextSize = 13, Font = T.Black, Parent = b })
		local key = UIKit.Panel({ Size = UDim2.fromOffset(30, 20), Position = UDim2.new(1, -36, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Parent = b })
		Label({ Text = item[3], Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 10, Font = T.Black, TextColor3 = T.Sub, Parent = key })
	end
	refs.Side = f
end

-- KILLFEED -----------------------------------------------------------------------
local function buildKillfeed()
	refs.Feed = new("Frame", {
		Name = "Killfeed", Size = UDim2.fromOffset(400, 200), Position = UDim2.new(1, -16, 0, 12), AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1, Parent = gui,
	}, { UIKit.List(4, false, Enum.HorizontalAlignment.Right) })
end

local feedOrder = 0
function HUD.Feed(entry)
	feedOrder += 1
	local me = player.Name
	local function colorName(name, vip)
		if not name then
			return ""
		end
		local color = "#FFFFFF"
		if name == me then
			color = "#FFC61A"
		elseif vip then
			color = "#FFD34A"
		end
		local prefix = vip and "👑 " or ""
		return string.format('<font color="%s">%s%s</font>', color, prefix, name)
	end
	local text
	if entry.Killer then
		text = string.format('%s  <font color="#9AA2B4">[%s]</font>%s  %s', colorName(entry.Killer, entry.KillerVIP), entry.Weapon, entry.Headshot and " 💀" or "", colorName(entry.Victim, entry.VictimVIP))
	else
		text = string.format('%s  <font color="#9AA2B4">[%s]</font>', colorName(entry.Victim, entry.VictimVIP), entry.Weapon)
	end
	local involved = entry.Killer == me or entry.Victim == me
	local row = UIKit.Panel({
		Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = -feedOrder,
		BackgroundColor3 = involved and Color3.fromRGB(90, 70, 10) or Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Parent = refs.Feed,
	})
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = row })
	Label({ Text = text, RichText = true, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, TextSize = 14, Font = T.Bold, Parent = row })
	local rows = {}
	for _, c in refs.Feed:GetChildren() do
		if c:IsA("Frame") then
			table.insert(rows, c)
		end
	end
	table.sort(rows, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 7, #rows do
		rows[i]:Destroy()
	end
	task.delay(6, function()
		if row.Parent then
			UIKit.Tween(row, 0.4, { BackgroundTransparency = 1 })
			for _, d in row:GetDescendants() do
				if d:IsA("TextLabel") then
					UIKit.Tween(d, 0.4, { TextTransparency = 1 })
				end
			end
			task.wait(0.45)
			row:Destroy()
		end
	end)
end

-- HEALTH (bottom-left) -------------------------------------------------------------
local function buildHealth()
	local f = new("Frame", { Name = "Health", Size = UDim2.fromOffset(300, 84), Position = UDim2.new(0, 16, 1, -16), AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Parent = gui })
	refs.HP = shadowText({ Text = "100", Size = UDim2.fromOffset(90, 44), Position = UDim2.fromOffset(0, 0), TextSize = 44, Font = T.Black, Parent = f })
	Label({ Text = "HEALTH", Size = UDim2.fromOffset(100, 14), Position = UDim2.fromOffset(94, 6), TextSize = 11, Font = T.Black, TextColor3 = T.Sub, Parent = f })
	local bar, fill = UIKit.Bar({ Size = UDim2.fromOffset(190, 12), Position = UDim2.fromOffset(94, 24), Color = T.Green, Parent = f })
	refs.HPFill = fill
	refs.HPBar = bar
	refs.Streak = shadowText({ Text = "", RichText = true, Size = UDim2.fromOffset(300, 18), Position = UDim2.fromOffset(0, 50), TextSize = 13, Font = T.Black, TextColor3 = T.Text, Parent = f })
	refs.StreakPips = new("Frame", { Size = UDim2.fromOffset(300, 8), Position = UDim2.fromOffset(0, 72), BackgroundTransparency = 1, Parent = f }, { UIKit.List(3, true) })
end

-- AMMO (bottom-right) ------------------------------------------------------------
local function buildAmmo()
	local f = new("Frame", { Name = "Ammo", Size = UDim2.fromOffset(300, 110), Position = UDim2.new(1, -16, 1, -16), AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1, Parent = gui })
	refs.WeaponName = shadowText({ Text = "", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 15, Font = T.Black, TextColor3 = T.Accent, Parent = f })
	refs.Reserve = shadowText({ Text = "/ 0", Size = UDim2.fromOffset(90, 30), Position = UDim2.new(1, -90, 0, 32), TextSize = 22, Font = T.Black, TextColor3 = T.Sub, Parent = f })
	refs.Mag = shadowText({ Text = "0", Size = UDim2.fromOffset(140, 56), Position = UDim2.new(1, -236, 0, 16), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 56, Font = T.Black, Parent = f })
	local _, magFill = UIKit.Bar({ Size = UDim2.fromOffset(230, 4), Position = UDim2.new(1, -230, 0, 74), Color = T.Text, Parent = f })
	refs.MagFill = magFill
	refs.Equip = new("Frame", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 84), BackgroundTransparency = 1, Parent = f }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function chip(order, text)
		local c = UIKit.Panel({ Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, LayoutOrder = order, Parent = refs.Equip })
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = c })
		return Label({ Text = text, RichText = true, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, TextSize = 12, Font = T.Black, Parent = c })
	end
	refs.TokenAir = chip(1, "")
	refs.TokenNuke = chip(2, "")
	refs.Nades = chip(3, "💣 x2 <font color='#9AA2B4'>[G]</font>")
	chip(4, "🔪 <font color='#9AA2B4'>[V]</font>")
end

function HUD.SetAmmo(mag: number, reserve: number, name: string, reloading: boolean, magSize: number, unlimited: boolean?)
	if not refs.Mag then
		return
	end
	refs.WeaponName.Text = name
	refs.Reserve.Text = unlimited and "/ ∞" or ("/ " .. reserve)
	if unlimited then
		refs.Mag.Text = "∞"
		refs.Mag.TextColor3 = T.Accent
		refs.MagFill.Size = UDim2.fromScale(1, 1)
		return
	end
	if reloading then
		refs.Mag.Text = "···"
		refs.Mag.TextColor3 = T.Accent
	else
		refs.Mag.Text = tostring(mag)
		refs.Mag.TextColor3 = (mag / math.max(1, magSize) <= 0.25) and T.Red or T.Text
	end
	refs.MagFill.Size = UDim2.fromScale(math.clamp(mag / math.max(1, magSize), 0, 1), 1)
end

-- ABILITIES + XP (bottom-center) ---------------------------------------------------
local function buildAbilities()
	local f = new("Frame", { Name = "Abilities", Size = UDim2.fromOffset(240, 60), Position = UDim2.new(0.5, 0, 1, -30), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = gui }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.Abilities = {}
	for i, a in { { "Dash", "💨", "Q" }, { "Slide", "🛝", "C" }, { "Slam", "☄️", "C AIR" } } do
		local box = UIKit.Panel({ Size = UDim2.fromOffset(64, 56), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, LayoutOrder = i, Parent = f })
		box.ClipsDescendants = true
		local cd = new("Frame", { Name = "Cooldown", Size = UDim2.fromScale(1, 0), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = T.Accent, BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = box })
		Label({ Text = a[2], Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 4), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 24, Parent = box })
		Label({ Text = a[3], Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -18), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11, Font = T.Black, TextColor3 = T.Sub, Parent = box })
		refs.Abilities[a[1]] = cd
	end
	local xp = new("Frame", { Name = "XP", Size = UDim2.fromOffset(460, 20), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = gui })
	local _, xpFill = UIKit.Bar({ Size = UDim2.new(1, 0, 0, 5), Position = UDim2.new(0, 0, 1, -5), Color = T.Accent2, Parent = xp })
	refs.XPFill = xpFill
	refs.XPText = Label({ Text = "", Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11, Font = T.Black, TextColor3 = T.Sub, Parent = xp })
end

-- CROSSHAIR / HITMARKER / SCOPE ----------------------------------------------------
local function buildCrosshair()
	local c = new("Frame", { Name = "Crosshair", Size = UDim2.fromOffset(2, 2), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = gui })
	refs.Cross = c
	refs.CrossBars = {}
	for i, spec in { { 2, 10, 0, -1 }, { 2, 10, 0, 1 }, { 10, 2, -1, 0 }, { 10, 2, 1, 0 } } do
		local bar = new("Frame", { Size = UDim2.fromOffset(spec[1], spec[2]), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = c }, {
			new("UIStroke", { Thickness = 1, Transparency = 0.5 }),
		})
		refs.CrossBars[i] = { bar, spec[3], spec[4] }
	end
	new("Frame", { Size = UDim2.fromOffset(2, 2), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = c })

	local hm = new("Frame", { Name = "Hitmarker", Size = UDim2.fromOffset(34, 34), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = gui })
	refs.HitBars = {}
	for _, d in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local bar = new("Frame", {
			Size = UDim2.fromOffset(3, 11), Position = UDim2.new(0.5, d[1] * 10, 0.5, d[2] * 10), AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = d[1] * d[2] > 0 and -45 or 45, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = hm,
		})
		table.insert(refs.HitBars, bar)
	end
	refs.HitScale = new("UIScale", { Parent = hm })

	-- sniper scope: a circle with a huge black stroke around it
	local scope = new("Frame", { Name = "Scope", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
	local ring = new("Frame", {
		Size = UDim2.fromScale(0.9, 0.9), SizeConstraint = Enum.SizeConstraint.RelativeYY, Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = scope,
	})
	new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = ring })
	new("UIStroke", { Thickness = 1200, Color = Color3.new(0, 0, 0), Parent = ring })
	new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = ring })
	new("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(0.5, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = ring })
	new("Frame", { Size = UDim2.fromOffset(4, 4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.Red, BorderSizePixel = 0, Parent = ring })
	refs.Scope = scope
end

function HUD.SetCrosshair(px: number, visible: boolean)
	if not refs.Cross then
		return
	end
	refs.Cross.Visible = visible
	local color = ClientState.CrosshairColors[ClientState.Settings.Crosshair] or Color3.new(1, 1, 1)
	if refs.CrossColor ~= color then
		refs.CrossColor = color
		for _, b in refs.CrossBars do
			b[1].BackgroundColor3 = color
		end
	end
	local gap = math.clamp(px, 4, 120) + 4
	for _, b in refs.CrossBars do
		b[1].Position = UDim2.new(0.5, b[2] * gap, 0.5, b[3] * gap)
	end
end

function HUD.SetScope(on: boolean)
	if refs.Scope then
		refs.Scope.Visible = on
	end
end

local hitToken = 0
function HUD.Hitmarker(headshot: boolean, killed: boolean)
	hitToken += 1
	local token = hitToken
	local color = killed and T.Red or (headshot and T.Accent or Color3.new(1, 1, 1))
	for _, b in refs.HitBars do
		b.BackgroundColor3 = color
		b.BackgroundTransparency = 0
	end
	refs.HitScale.Scale = killed and 1.6 or 1.2
	UIKit.Tween(refs.HitScale, 0.15, { Scale = 1 })
	task.delay(killed and 0.35 or 0.15, function()
		if token == hitToken then
			for _, b in refs.HitBars do
				UIKit.Tween(b, 0.15, { BackgroundTransparency = 1 })
			end
		end
	end)
end

function HUD.DamageNumber(position: Vector3?, damage: number, headshot: boolean)
	if not position then
		return
	end
	local att = Instance.new("Attachment")
	att.WorldPosition = position + Vector3.new(math.random() - 0.5, 1 + math.random(), math.random() - 0.5)
	att.Parent = workspace.Terrain
	local bb = new("BillboardGui", { Size = UDim2.fromOffset(80, 30), AlwaysOnTop = true, LightInfluence = 0, Adornee = att, Parent = att })
	local l = Label({
		Text = tostring(math.floor(damage)), Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = headshot and 26 or 20, Font = T.Black, TextColor3 = headshot and T.Accent or Color3.new(1, 1, 1), Parent = bb,
	})
	UIKit.TextStroke(0.2).Parent = l
	UIKit.Tween(bb, 0.7, { StudsOffset = Vector3.new(0, 2, 0) })
	task.delay(0.4, function()
		UIKit.Tween(l, 0.3, { TextTransparency = 1 })
	end)
	task.delay(0.75, function()
		att:Destroy()
	end)
end

-- CENTER MESSAGES ------------------------------------------------------------------
local function buildCenter()
	refs.KillPop = new("Frame", { Name = "KillPop", Size = UDim2.fromOffset(500, 120), Position = UDim2.fromScale(0.5, 0.6), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = gui })
	refs.KillTitle = shadowText({ Text = "", Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 14, Font = T.Black, TextColor3 = T.Red, Parent = refs.KillPop })
	refs.KillName = shadowText({ Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 16), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 28, Font = T.Black, Parent = refs.KillPop })
	refs.KillScore = shadowText({ Text = "", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 46), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 20, Font = T.Black, TextColor3 = T.Accent, Parent = refs.KillPop })
	refs.KillScale = new("UIScale", { Parent = refs.KillPop })
	refs.MedalRow = new("Frame", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 74), BackgroundTransparency = 1, Parent = refs.KillPop }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	refs.Announce = new("Frame", { Name = "Announce", Size = UDim2.fromOffset(700, 90), Position = UDim2.fromScale(0.5, 0.2), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Visible = false, Parent = gui })
	refs.AnnounceText = shadowText({ Text = "", Size = UDim2.new(1, 0, 0, 44), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 40, Font = T.Black, Parent = refs.Announce })
	refs.AnnounceSub = shadowText({ Text = "", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 48), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, Font = T.Bold, TextColor3 = T.Sub, Parent = refs.Announce })
	refs.AnnounceScale = new("UIScale", { Parent = refs.Announce })

	refs.Message = shadowText({ Text = "", Size = UDim2.fromOffset(600, 24), Position = UDim2.fromScale(0.5, 0.78), AnchorPoint = Vector2.new(0.5, 0), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 18, Font = T.Black, TextTransparency = 1, Parent = gui })

	refs.Nuke = shadowText({ Text = "", Size = UDim2.fromOffset(600, 120), Position = UDim2.fromScale(0.5, 0.35), AnchorPoint = Vector2.new(0.5, 0.5), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 110, Font = T.Black, TextColor3 = T.Red, Parent = gui })

	refs.White = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50, Parent = gui })

	-- damage vignette (4 gradient edges)
	refs.Vignette = {}
	for _, e in { { UDim2.new(1, 0, 0.25, 0), UDim2.new(), 90 }, { UDim2.new(1, 0, 0.25, 0), UDim2.fromScale(0, 0.75), -90 }, { UDim2.new(0.2, 0, 1, 0), UDim2.new(), 0 }, { UDim2.new(0.2, 0, 1, 0), UDim2.fromScale(0.8, 0), 180 } } do
		local f = new("Frame", { Size = e[1], Position = e[2], BackgroundColor3 = T.Red, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })
		new("UIGradient", { Rotation = e[3], Transparency = NumberSequence.new(0, 1), Parent = f })
		table.insert(refs.Vignette, f)
	end
end

local killToken = 0
local medalToken = 0
function HUD.Medals(medals)
	for _, c in refs.MedalRow:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i, m in medals do
		task.delay((i - 1) * 0.12, function()
			local tag = UIKit.Panel({ Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, LayoutOrder = i, Parent = refs.MedalRow })
			UIKit.Stroke(T.Accent, 1.5, 0.2).Parent = tag
			new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = tag })
			Label({ Text = m.Text .. (m.Bonus and m.Bonus > 0 and ("  <font color='#FFC61A'>+" .. m.Bonus .. "</font>") or ""), RichText = true, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, TextSize = 13, Font = T.Black, Parent = tag })
			local sc = new("UIScale", { Scale = 1.8, Parent = tag })
			UIKit.Tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end
	medalToken += 1
	local token = medalToken
	task.delay(3, function()
		if token == medalToken then
			for _, c in refs.MedalRow:GetChildren() do
				if c:IsA("Frame") then
					c:Destroy()
				end
			end
		end
	end)
end

function HUD.Kill(info)
	killToken += 1
	local token = killToken
	refs.KillTitle.Text = info.Headshot and "💀 HEADSHOT ELIMINATION" or "ELIMINATED"
	refs.KillName.Text = string.upper(info.Victim)
	refs.KillScore.Text = "+" .. info.Score
	for _, l in { refs.KillTitle, refs.KillName, refs.KillScore } do
		l.TextTransparency = 0
	end
	refs.KillScale.Scale = 1.4
	UIKit.Tween(refs.KillScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	HUD.Medals(info.Medals or {})
	task.delay(2.2, function()
		if token == killToken then
			for _, l in { refs.KillTitle, refs.KillName, refs.KillScore } do
				UIKit.Tween(l, 0.3, { TextTransparency = 1 })
			end
		end
	end)
end

local announceToken = 0
function HUD.Announce(info)
	announceToken += 1
	local token = announceToken
	refs.Announce.Visible = true
	refs.AnnounceText.Text = (info.Icon and info.Icon .. "  " or "") .. info.Text
	refs.AnnounceText.TextColor3 = info.Color or T.Accent
	refs.AnnounceSub.Text = info.Sub or ""
	refs.AnnounceScale.Scale = 0.6
	UIKit.Tween(refs.AnnounceScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	UIKit.Sound("Unlock", 0.6)
	task.delay(3, function()
		if token == announceToken then
			refs.Announce.Visible = false
		end
	end)
end

local msgToken = 0
function HUD.Message(text: string, color: Color3?)
	msgToken += 1
	local token = msgToken
	refs.Message.Text = text
	refs.Message.TextColor3 = color or T.Text
	refs.Message.TextTransparency = 0
	task.delay(2.2, function()
		if token == msgToken then
			UIKit.Tween(refs.Message, 0.3, { TextTransparency = 1 })
		end
	end)
end

function HUD.Cash(amount: number, reason: string?)
	refs.CashPop.Text = "+$" .. Util.Comma(amount) .. (reason and ("  " .. reason) or "")
	refs.CashPop.TextTransparency = 0
	refs.CashPop.Position = UDim2.fromOffset(54, 46)
	UIKit.Tween(refs.CashPop, 1.5, { TextTransparency = 1, Position = UDim2.fromOffset(54, 36) })
end

-- ACHIEVEMENT TOASTS (queued) -----------------------------------------------------
local toastQueue = {}
local toastBusy = false
local function showNextToast()
	if toastBusy or #toastQueue == 0 then
		return
	end
	toastBusy = true
	local info = table.remove(toastQueue, 1)
	local toast = UIKit.Panel({
		Size = UDim2.fromOffset(380, 70), Position = UDim2.new(0.5, 0, 0, -80), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = T.Panel, BackgroundTransparency = 0.05, ZIndex = 20, Parent = gui,
	})
	UIKit.Stroke(info.Color or T.Gold, 2, 0).Parent = toast
	UIKit.Gradient(Color3.fromRGB(60, 50, 20), T.Panel, 0).Parent = toast
	Label({ Text = info.Icon or "🏆", Size = UDim2.fromOffset(60, 70), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 34, ZIndex = 21, Parent = toast })
	Label({ Text = info.Title, Size = UDim2.new(1, -150, 0, 14), Position = UDim2.fromOffset(62, 10), TextSize = 11, Font = T.Black, TextColor3 = info.Color or T.Gold, ZIndex = 21, Parent = toast })
	Label({ Text = info.Name, Size = UDim2.new(1, -150, 0, 22), Position = UDim2.fromOffset(62, 24), TextSize = 19, Font = T.Black, ZIndex = 21, TextTruncate = Enum.TextTruncate.AtEnd, Parent = toast })
	Label({ Text = info.Desc or "", Size = UDim2.new(1, -150, 0, 14), Position = UDim2.fromOffset(62, 47), TextSize = 11, Font = T.Medium, TextColor3 = T.Sub, ZIndex = 21, TextTruncate = Enum.TextTruncate.AtEnd, Parent = toast })
	Label({ Text = info.Right or "", Size = UDim2.fromOffset(80, 70), Position = UDim2.new(1, -88, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 18, Font = T.Black, TextColor3 = T.Green, ZIndex = 21, Parent = toast })
	UIKit.Sound("Unlock", 1.2)
	UIKit.Tween(toast, 0.4, { Position = UDim2.new(0.5, 0, 0, 124) }, Enum.EasingStyle.Back)
	task.delay(3.2, function()
		UIKit.Tween(toast, 0.3, { Position = UDim2.new(0.5, 0, 0, -80) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.35)
		toast:Destroy()
		toastBusy = false
		showNextToast()
	end)
end

function HUD.Toast(info)
	table.insert(toastQueue, info)
	showNextToast()
end

function HUD.Achievement(info)
	HUD.Toast({ Title = "ACHIEVEMENT UNLOCKED", Name = info.Name, Desc = info.Desc, Icon = info.Icon, Right = "+$" .. Util.Comma(info.Reward) })
end

function HUD.LevelUp(level: number, reward: number)
	HUD.Toast({ Title = "LEVEL UP", Name = "YOU REACHED LEVEL " .. level, Desc = "New weapons may be unlocked in the Armory", Icon = "⭐", Right = "+$" .. Util.Comma(reward), Color = T.Accent2 })
end

-- DAMAGE / DEATH ---------------------------------------------------------------------
local hurtFlash = 0
function HUD.Damaged(from: Vector3?, amount: number)
	hurtFlash = math.min(1, hurtFlash + amount / 40)
	if HUD.Extras then
		HUD.Extras.DamageFrom(from)
	end
end

local function buildDeath()
	local d = UIKit.Panel({ Name = "Death", Size = UDim2.fromOffset(420, 150), Position = UDim2.new(0.5, 0, 1, -120), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.1, Visible = false, Parent = gui })
	UIKit.Stroke(T.Red, 2, 0.1).Parent = d
	refs.DeathTitle = Label({ Text = "ELIMINATED BY", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 10), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12, Font = T.Black, TextColor3 = T.Sub, Parent = d })
	refs.DeathKiller = Label({ Text = "", Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 26), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 28, Font = T.Black, TextColor3 = T.Red, Parent = d })
	refs.DeathInfo = Label({ Text = "", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 60), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 13, Font = T.Bold, TextColor3 = T.Text, Parent = d })
	refs.DeathTimer = Label({ Text = "", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 80), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 14, Font = T.Black, TextColor3 = T.Accent, Parent = d })
	local pass = Monetization.GamePasses.InstantRespawn
	refs.DeathUpsell = UIKit.Button({ Text = "⏩ INSTANT RESPAWN  ·  R$ " .. pass.Price, Size = UDim2.fromOffset(300, 32), Position = UDim2.new(0.5, 0, 1, -40), AnchorPoint = Vector2.new(0.5, 0), Color = T.Robux, TextSize = 14, Parent = d }, function()
		if pass.Id > 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		else
			HUD.Message("Set the InstantRespawn pass Id in Monetization.lua", T.Red)
		end
	end)
	refs.Death = d
end

function HUD.Death(info)
	refs.Death.Visible = true
	if info.Killer then
		refs.DeathTitle.Text = "ELIMINATED BY"
		refs.DeathKiller.Text = string.upper(info.Killer)
		refs.DeathInfo.Text = string.format("%s%s  ·  %d studs  ·  %d/%d HP left", info.Weapon, info.Headshot and " (HEADSHOT)" or "", info.Distance or 0, info.KillerHealth or 0, info.KillerMax or 100)
	else
		refs.DeathTitle.Text = "YOU DIED"
		refs.DeathKiller.Text = "WASTED"
		refs.DeathInfo.Text = info.Weapon or ""
	end
	refs.DeathUpsell.Visible = not ClientState.HasPass("InstantRespawn")
end

function HUD.HideDeath()
	if refs.Death then
		refs.Death.Visible = false
	end
end

-- K.O STREAK 🔥 (5 kills without dying) -------------------------------------------------
function HUD.KOStreak()
	local holder = new("Frame", { Name = "KOStreak", Size = UDim2.fromOffset(720, 150), Position = UDim2.fromScale(0.5, 0.3), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 30, Parent = gui })
	local band = new("Frame", { Size = UDim2.new(1, 0, 0, 96), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 90, 20), BorderSizePixel = 0, ZIndex = 30, Parent = holder })
	new("UIGradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 40, 20)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 170, 30)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 40, 20)) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.25), NumberSequenceKeypoint.new(0.8, 0.25), NumberSequenceKeypoint.new(1, 1) }),
		Parent = band,
	})
	local title = Label({ Text = "🔥 K.O STREAK 🔥", Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 72, Font = T.Black, TextColor3 = Color3.new(1, 1, 1), ZIndex = 31, Parent = holder })
	new("UIStroke", { Color = Color3.fromRGB(120, 20, 0), Thickness = 4, Parent = title })
	local sub = Label({ Text = "5 KILLS WITHOUT DYING  ·  INFINITE AMMO AT 15", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0.5, 0, 0.45, 56), AnchorPoint = Vector2.new(0.5, 0), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, Font = T.Black, TextColor3 = Color3.fromRGB(255, 230, 180), ZIndex = 31, Parent = holder })
	UIKit.TextStroke(0.2).Parent = sub
	local scale = new("UIScale", { Scale = 2.6, Parent = holder })
	holder.Rotation = -8
	UIKit.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	UIKit.Tween(holder, 0.35, { Rotation = 0 }, Enum.EasingStyle.Back)
	UIKit.Sound("Unlock", 0.7)
	UIKit.Sound("Kill", 0.6)
	hurtFlash = 0
	-- flicker like flames
	task.spawn(function()
		local start = os.clock()
		while holder.Parent and os.clock() - start < 2.6 do
			local f = 0.5 + 0.5 * math.sin((os.clock() - start) * 18)
			title.TextColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 220, 120), f)
			task.wait(0.03)
		end
	end)
	task.delay(2.6, function()
		UIKit.Tween(scale, 0.3, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		UIKit.Tween(band, 0.3, { BackgroundTransparency = 1 })
		UIKit.Tween(title, 0.3, { TextTransparency = 1 })
		UIKit.Tween(sub, 0.3, { TextTransparency = 1 })
		task.wait(0.35)
		holder:Destroy()
	end)
end

-- NUKE ------------------------------------------------------------------------------
function HUD.Nuke(seconds: number, owner: string)
	HUD.Announce({ Text = "TACTICAL NUKE INCOMING", Sub = "Dropped by " .. owner, Color = T.Red, Icon = "☢️" })
	task.spawn(function()
		for i = seconds, 1, -1 do
			refs.Nuke.Text = tostring(i)
			refs.Nuke.TextTransparency = 0
			UIKit.Tween(refs.Nuke, 0.9, { TextTransparency = 0.6 })
			UIKit.Sound("Empty", 0.5)
			task.wait(1)
		end
		refs.Nuke.Text = ""
	end)
end

function HUD.WhiteFlash()
	refs.White.BackgroundTransparency = 0
	UIKit.Tween(refs.White, 2.5, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
end

local statusUntil, statusText = 0, ""
function HUD.Status(text: string, duration: number)
	statusText = text
	statusUntil = os.clock() + duration
end

-- PER FRAME --------------------------------------------------------------------------
local function streakText(streak: number)
	local reduce = ClientState.HasPass("RadarPro") and 1 or 0
	for _, ks in Config.Killstreaks do
		local need = ks.Kills - reduce
		if streak < need then
			return string.format("STREAK <font color='#FFC61A'>%d</font>  ·  NEXT: %s %s <font color='#9AA2B4'>(%d)</font>", streak, ks.Icon, ks.Name, need), need
		end
	end
	return string.format("STREAK <font color='#FFC61A'>%d</font>  ·  ALL REWARDS EARNED", streak), streak
end

local lastPipCount = -1
local function update(dt: number)
	local now = workspace:GetServerTimeNow()
	local state = ReplicatedStorage:GetAttribute("MatchState") or "Intermission"
	local left = math.max(0, (ReplicatedStorage:GetAttribute("MatchEnd") or 0) - now)

	refs.Timer.Text = Util.Time(left)
	refs.Mode.Text = (ReplicatedStorage:GetAttribute("MapName") or "") .. " · FFA · FIRST TO " .. Config.KillsToWin
	refs.Timer.TextColor3 = (state == "Active" and left < 30) and T.Red or T.Text
	if state == "Intermission" then
		refs.Banner.Text = "WARMUP  ·  MATCH STARTS IN " .. math.ceil(left)
	elseif state == "Results" then
		refs.Banner.Text = "MATCH OVER  ·  NEXT ROUND IN " .. math.ceil(left)
	else
		refs.Banner.Text = ""
	end
	refs.YouKills.Text = tostring(player:GetAttribute("Kills") or 0)
	local leader = ReplicatedStorage:GetAttribute("Leader") or ""
	refs.LeaderName.Text = leader ~= "" and string.upper(leader) or "LEADER"
	refs.LeaderKills.Text = tostring(ReplicatedStorage:GetAttribute("LeaderScore") or 0)

	-- profile
	refs.Level.Text = tostring(player:GetAttribute("Level") or 1)
	refs.Cash.Text = "$" .. Util.Comma(player:GetAttribute("Cash") or 0)
	local xp, need = player:GetAttribute("XP") or 0, player:GetAttribute("XPNeeded") or 1
	refs.XPFill.Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1)
	refs.XPText.Text = string.format("LVL %d  ·  %s / %s XP", player:GetAttribute("Level") or 1, Util.Comma(xp), Util.Comma(need))

	-- boost pills
	local boosts = {}
	if ClientState.HasPass("VIP") then
		table.insert(boosts, { "👑 VIP 2X CASH", T.Gold })
	end
	if ClientState.HasPass("DoubleXP") then
		table.insert(boosts, { "2X XP", T.Accent2 })
	end
	local boostLeft = (player:GetAttribute("BoostUntil") or 0) - os.time()
	if boostLeft > 0 then
		table.insert(boosts, { "🚀 3X XP " .. Util.Time(boostLeft), T.Green })
	end
	local key = ""
	for _, b in boosts do
		key ..= b[1]
	end
	if refs.BoostKey ~= key then
		refs.BoostKey = key
		for _, c in refs.Boosts:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		for _, b in boosts do
			pill(refs.Boosts, b[1], b[2])
		end
	end

	-- health
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		local frac = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
		refs.HP.Text = tostring(math.ceil(hum.Health))
		refs.HPFill.Size = UDim2.fromScale(frac, 1)
		refs.HPFill.BackgroundColor3 = T.Red:Lerp(T.Green, frac)
		refs.HP.TextColor3 = frac < 0.3 and T.Red or T.Text
		local low = frac < 0.35 and hum.Health > 0 and (0.35 - frac) * 1.6 or 0
		hurtFlash = math.max(0, hurtFlash - dt * 1.5)
		local v = math.clamp(math.max(low, hurtFlash), 0, 0.85)
		for _, f in refs.Vignette do
			f.BackgroundTransparency = 1 - v
		end
	end

	-- streak
	local streak = player:GetAttribute("Streak") or 0
	local text, target = streakText(streak)
	refs.Streak.Text = text
	if target ~= lastPipCount then
		lastPipCount = target
		for _, c in refs.StreakPips:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		for i = 1, math.min(target, 25) do
			new("Frame", { Name = "Pip", Size = UDim2.fromOffset(14, 6), BackgroundColor3 = T.Panel3, BorderSizePixel = 0, LayoutOrder = i, Parent = refs.StreakPips })
		end
	end
	for _, c in refs.StreakPips:GetChildren() do
		if c:IsA("Frame") then
			c.BackgroundColor3 = c.LayoutOrder <= streak and T.Accent or T.Panel3
		end
	end

	-- equipment + tokens
	refs.Nades.Text = string.format("💣 x%d <font color='#9AA2B4'>[G]</font>", player:GetAttribute("Grenades") or 0)
	local air, nuke = player:GetAttribute("AirstrikeTokens") or 0, player:GetAttribute("NukeTokens") or 0
	refs.TokenAir.Parent.Visible = air > 0
	refs.TokenAir.Text = string.format("✈️ x%d <font color='#9AA2B4'>[Z]</font>", air)
	refs.TokenNuke.Parent.Visible = nuke > 0
	refs.TokenNuke.Text = string.format("☢️ x%d <font color='#9AA2B4'>[X]</font>", nuke)

	-- ability cooldowns
	local S = Movement.State
	local clock = os.clock()
	local function cd(last, duration)
		return math.clamp(1 - (clock - last) / duration, 0, 1)
	end
	refs.Abilities.Dash.Size = UDim2.fromScale(1, cd(S.LastDash, Movement.DashCooldown()))
	refs.Abilities.Slide.Size = UDim2.fromScale(1, cd(S.LastSlide, Config.SlideCooldown))
	refs.Abilities.Slam.Size = UDim2.fromScale(1, cd(S.LastSlam, Config.SlamCooldown))

	-- status line (killstreaks)
	if clock < statusUntil then
		refs.Status.Text = string.format("%s  %ds", statusText, math.ceil(statusUntil - clock))
	elseif player:GetAttribute("InfiniteAmmo") then
		refs.Status.Text = "♾️ INFINITE AMMO — NO RELOADS UNTIL YOU DIE"
	elseif ClientState.Overdrive() then
		refs.Status.Text = "⚡ OVERDRIVE ACTIVE"
	else
		refs.Status.Text = ""
	end

	-- death timer
	if refs.Death.Visible then
		local respawn = (player:GetAttribute("RespawnAt") or 0) - now
		refs.DeathTimer.Text = respawn > 0 and string.format("RESPAWNING IN %.1f", respawn) or "RESPAWNING..."
	end
end

-- PUBLIC ----------------------------------------------------------------------------
HUD.Extras = nil
function HUD.SetVisible(visible: boolean)
	if gui then
		gui.Enabled = visible
	end
end

function HUD.Init(playerGui: PlayerGui)
	gui = new("ScreenGui", { Name = "HUD", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false, Parent = playerGui })
	buildCenter()
	buildTopBar()
	buildProfile()
	buildSideMenu()
	buildKillfeed()
	buildHealth()
	buildAmmo()
	buildAbilities()
	buildCrosshair()
	buildDeath()
	HUD.Gui = gui
	HUD.Extras = require(script.Parent.HUDExtras)
	HUD.Extras.Init(gui)
	RunService.RenderStepped:Connect(update)
end

return HUD
