-- Full-screen menus: Main Menu, Armory, Store (Robux), Achievements,
-- Scoreboard (hold TAB), Match Results and Daily Rewards.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Weapons = require(Shared.Weapons)
local Achievements = require(Shared.Achievements)
local Monetization = require(Shared.Monetization)
local GunBuilder = require(Shared.GunBuilder)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)
local UIKit = require(script.Parent.UIKit)
local ClientState = require(script.Parent.ClientState)
local Effects = require(script.Parent.Effects)

local player = Players.LocalPlayer
local T = UIKit.Theme
local new, Label = UIKit.new, UIKit.Label

local Menus = {}
Menus.OnDeploy = nil -- injected
Menus.Notify = function(_text, _color) end -- injected (HUD.Message)

local gui
local renderSettings
local windows = {}
local openName = nil
local mainMenu, scoreboard, results

-- PURCHASES ----------------------------------------------------------------------
function Menus.BuyPass(key: string)
	local pass = Monetization.GamePasses[key]
	if not pass then
		return
	end
	if pass.Id and pass.Id > 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	else
		Menus.Notify("Developer: set the '" .. key .. "' game pass Id in Monetization.lua", T.Red)
	end
end

function Menus.BuyProduct(key: string)
	local product = Monetization.Products[key]
	if not product then
		return
	end
	if product.Id and product.Id > 0 then
		MarketplaceService:PromptProductPurchase(player, product.Id)
	else
		Menus.Notify("Developer: set the '" .. key .. "' product Id in Monetization.lua", T.Red)
	end
end

-- WINDOW FRAME ---------------------------------------------------------------------
local function window(name: string, title: string, tabs)
	local overlay = new("TextButton", {
		Name = name, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35,
		Text = "", AutoButtonColor = false, Modal = true, Visible = false, ZIndex = 5, Parent = gui,
	})
	local panel = UIKit.Panel({
		Size = UDim2.fromScale(0.92, 0.86), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.Bg, BackgroundTransparency = 0.03, ZIndex = 5, Parent = overlay,
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(980, 620), Parent = panel })
	UIKit.Stroke(Color3.new(1, 1, 1), 1, 0.9).Parent = panel
	Label({ Text = title, Size = UDim2.new(1, -200, 0, 40), Position = UDim2.fromOffset(24, 14), TextSize = 30, Font = T.Black, ZIndex = 6, Parent = panel })
	new("Frame", { Size = UDim2.fromOffset(60, 4), Position = UDim2.fromOffset(24, 56), BackgroundColor3 = T.Accent, BorderSizePixel = 0, ZIndex = 6, Parent = panel })
	local right = new("Frame", { Size = UDim2.fromOffset(400, 40), Position = UDim2.new(1, -64, 0, 14), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, ZIndex = 6, Parent = panel }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local close = UIKit.Button({ Text = "✕", Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -14, 0, 14), AnchorPoint = Vector2.new(1, 0), Color = T.Panel3, TextSize = 18, Parent = panel }, function()
		Menus.Close()
	end)
	close.ZIndex = 6

	local tabBar = new("Frame", { Size = UDim2.new(1, -48, 0, 34), Position = UDim2.fromOffset(24, 70), BackgroundTransparency = 1, ZIndex = 6, Parent = panel }, { UIKit.List(6, true) })
	local content = new("Frame", { Name = "Content", Size = UDim2.new(1, -48, 1, -124), Position = UDim2.fromOffset(24, 112), BackgroundTransparency = 1, ZIndex = 6, Parent = panel })

	local w = { Name = name, Overlay = overlay, Panel = panel, Content = content, Right = right, Tab = tabs and tabs[1] or nil, TabButtons = {} }
	if tabs then
		for i, tab in tabs do
			local b = UIKit.Button({ Text = string.upper(tab), Size = UDim2.fromOffset(0, 34), Color = T.Panel2, TextSize = 13, LayoutOrder = i, Parent = tabBar }, function()
				w.Tab = tab
				if w.Render then
					w.Render()
				end
			end)
			b.AutomaticSize = Enum.AutomaticSize.X
			new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = b })
			b.ZIndex = 6
			w.TabButtons[tab] = b
		end
	end
	function w.SyncTabs()
		for tab, b in w.TabButtons do
			UIKit.SetButtonColor(b, tab == w.Tab and T.Accent or T.Panel2)
		end
	end
	windows[name] = w
	return w
end

local function clear(frame: Instance)
	for _, c in frame:GetChildren() do
		c:Destroy()
	end
end

local function scroller(parent: Instance, cell: UDim2?)
	local s = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.Accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 6, Parent = parent,
	})
	if cell then
		new("UIGridLayout", { CellSize = cell, CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = s })
	else
		UIKit.List(8).Parent = s
	end
	new("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), Parent = s })
	return s
end

local function cashChip(parent)
	local chip = UIKit.Panel({ Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.Panel2, LayoutOrder = 1, Parent = parent })
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = chip })
	Label({ Text = "$" .. Util.Comma(player:GetAttribute("Cash") or 0), Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, TextSize = 18, Font = T.Black, TextColor3 = T.Green, ZIndex = 7, Parent = chip })
	chip.ZIndex = 6
	local more = UIKit.Button({ Text = "+ GET CASH", Size = UDim2.fromOffset(120, 36), Color = T.Robux, TextSize = 13, LayoutOrder = 2, Parent = parent }, function()
		Menus.Open("Store", "Cash & Boosts")
	end)
	more.ZIndex = 6
end

-- ARMORY ---------------------------------------------------------------------------
local function gunPreview(parent, id: string)
	local def = Weapons.Get(id)
	local vpf = new("ViewportFrame", {
		Size = UDim2.new(1, -16, 0, 74), Position = UDim2.fromOffset(8, 44), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6,
		Ambient = Color3.fromRGB(170, 170, 180), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1, -0.5), ZIndex = 7, Parent = parent,
	})
	UIKit.Corner(6).Parent = vpf
	local model = GunBuilder.Build(id, ClientState.HasPass("GoldenArsenal"))
	model.Parent = vpf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local L = def.Look.Length + def.Look.Barrel
	cam.CFrame = CFrame.lookAt(Vector3.new(L * 2.3 + 1.5, 0.6, -0.4), Vector3.new(0, 0, -0.4))
	cam.Parent = vpf
	vpf.CurrentCamera = cam
end

local function statBar(parent, y, name, value)
	Label({ Text = name, Size = UDim2.fromOffset(70, 12), Position = UDim2.fromOffset(10, y), TextSize = 10, Font = T.Black, TextColor3 = T.Sub, ZIndex = 7, Parent = parent })
	local bar = UIKit.Bar({ Size = UDim2.new(1, -96, 0, 6), Position = UDim2.fromOffset(84, y + 3), Value = math.clamp(value, 0.04, 1), Color = T.Accent, Parent = parent })
	bar.ZIndex = 7
	bar.Fill.ZIndex = 7
end

local function renderArmory(w)
	w.SyncTabs()
	clear(w.Content)
	clear(w.Right)
	cashChip(w.Right)
	local data = ClientState.Data
	if not data then
		return
	end
	local slot = w.Tab
	local list = scroller(w.Content, UDim2.fromOffset(220, 232))
	local level = player:GetAttribute("Level") or 1
	local cash = player:GetAttribute("Cash") or 0
	for order, id in Weapons.Order do
		local def = Weapons.Get(id)
		if def.Slot == slot then
			local owned = data.Owned[id] or (def.Pass and ClientState.HasPass(def.Pass))
			local equipped = data.Loadout[slot] == id
			local card = UIKit.Panel({ BackgroundColor3 = equipped and Color3.fromRGB(50, 44, 20) or T.Panel, BackgroundTransparency = 0, LayoutOrder = order, ZIndex = 6, Parent = list })
			UIKit.Stroke(equipped and T.Accent or (def.Pass and T.Robux or Color3.new(1, 1, 1)), equipped and 2 or 1, equipped and 0 or 0.85).Parent = card
			Label({ Text = def.Name, Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(10, 8), TextSize = 14, Font = T.Black, ZIndex = 7, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
			Label({ Text = string.upper(def.Class) .. (def.Pass and "  ·  💎 EXCLUSIVE" or (def.Model and ("  ·  " .. string.upper(def.Model)) or "")), Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(10, 26), TextSize = 10, Font = T.Bold, TextColor3 = def.Pass and T.Robux or T.Sub, ZIndex = 7, Parent = card })
			gunPreview(card, id)
			local dps = def.Damage * (def.Pellets or 1) * def.FireRate * (def.Burst or 1)
			statBar(card, 126, "DAMAGE", def.Damage * (def.Pellets or 1) / 130)
			statBar(card, 140, "FIRE RATE", def.FireRate * (def.Burst or 1) / 15)
			statBar(card, 154, "DPS", dps / 400)
			statBar(card, 168, "RANGE", def.FalloffStart / 400)
			statBar(card, 182, "MOBILITY", (def.Speed - 0.7) / 0.45)

			local text, color, action
			if equipped then
				text, color = "EQUIPPED", T.Panel3
			elseif owned then
				text, color = "EQUIP", T.Accent
				action = function()
					Remotes.SetLoadout:FireServer(slot, id)
				end
			elseif def.Pass then
				text, color = "💎 R$ " .. Monetization.GamePasses[def.Pass].Price, T.Robux
				action = function()
					Menus.BuyPass(def.Pass)
				end
			elseif level < def.Level then
				text, color = "🔒 LEVEL " .. def.Level, T.Panel3
				action = function()
					Menus.Notify("Reach level " .. def.Level .. " — get 2x XP in the Store to level faster!", T.Accent)
				end
			else
				local afford = cash >= def.Price
				text, color = "BUY  $" .. Util.Comma(def.Price), afford and T.Green or T.Panel3
				action = function()
					if afford then
						Remotes.BuyWeapon:FireServer(id)
					else
						Menus.Open("Store", "Cash & Boosts")
					end
				end
			end
			local b = UIKit.Button({ Text = text, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 1, -38), Color = color, TextSize = 13, Parent = card }, action)
			b.ZIndex = 7
		end
	end
end

-- STORE ------------------------------------------------------------------------------
local function storeCard(list, order, icon, name, lines, price, color, owned, highlight, onBuy)
	local card = UIKit.Panel({ BackgroundColor3 = T.Panel, BackgroundTransparency = 0, LayoutOrder = order, ZIndex = 6, Parent = list })
	UIKit.Stroke(color, highlight and 2 or 1, highlight and 0 or 0.5).Parent = card
	UIKit.Gradient(color:Lerp(T.Panel, 0.72), T.Panel, 90).Parent = card
	if highlight then
		local tag = UIKit.Panel({ Size = UDim2.fromOffset(96, 20), Position = UDim2.new(1, -8, 0, 8), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = T.Accent, BackgroundTransparency = 0, ZIndex = 8, Parent = card })
		Label({ Text = highlight, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 10, Font = T.Black, TextColor3 = Color3.new(0, 0, 0), ZIndex = 9, Parent = tag })
	end
	Label({ Text = icon, Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 12), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 42, ZIndex = 7, Parent = card })
	Label({ Text = string.upper(name), Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 66), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 15, Font = T.Black, ZIndex = 7, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	Label({
		Text = "• " .. table.concat(lines, "\n• "), Size = UDim2.new(1, -20, 0, 70), Position = UDim2.fromOffset(10, 90),
		TextSize = 11, Font = T.Medium, TextColor3 = T.Sub, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 7, Parent = card,
	})
	local b = UIKit.Button({
		Text = owned and "OWNED ✓" or ("R$ " .. price), Size = UDim2.new(1, -20, 0, 34), Position = UDim2.new(0, 10, 1, -42),
		Color = owned and T.Panel3 or T.Robux, TextSize = 15, Parent = card,
	}, (not owned) and onBuy or nil)
	b.ZIndex = 7
end

local function renderStore(w)
	w.SyncTabs()
	clear(w.Content)
	clear(w.Right)
	cashChip(w.Right)
	local list = scroller(w.Content, UDim2.fromOffset(210, 236))
	if w.Tab == "Game Passes" then
		for i, key in Monetization.PassOrder do
			local pass = Monetization.GamePasses[key]
			local highlight = (key == "VIP" and "MOST POPULAR") or (key == "GoldenArsenal" and "MORE DAMAGE") or (key == "Railgun" and "EXCLUSIVE") or nil
			storeCard(list, i, pass.Icon, pass.Name, pass.Perks, pass.Price, pass.Color, ClientState.HasPass(key), highlight, function()
				Menus.BuyPass(key)
			end)
		end
	else
		for i, key in Monetization.ProductOrder do
			local p = Monetization.Products[key]
			local highlight = (key == "Cash2" and "POPULAR") or (key == "Cash3" and "BEST VALUE") or nil
			storeCard(list, i, p.Icon, p.Name, { p.Desc }, p.Price, key == "Nuke" and T.Red or T.Robux, false, highlight, function()
				Menus.BuyProduct(key)
			end)
		end
	end
end

-- ACHIEVEMENTS ---------------------------------------------------------------------
local function renderAchievements(w)
	w.SyncTabs()
	clear(w.Content)
	clear(w.Right)
	local data = ClientState.Data
	if not data then
		return
	end
	local unlocked = 0
	for _ in data.Achievements do
		unlocked += 1
	end
	local total = #Achievements.List
	local chip = UIKit.Panel({ Size = UDim2.fromOffset(240, 36), BackgroundColor3 = T.Panel2, Parent = w.Right })
	chip.ZIndex = 6
	Label({ Text = string.format("🏆 %d / %d UNLOCKED", unlocked, total), Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(10, 3), TextSize = 13, Font = T.Black, TextColor3 = T.Gold, ZIndex = 7, Parent = chip })
	local bar = UIKit.Bar({ Size = UDim2.new(1, -20, 0, 5), Position = UDim2.fromOffset(10, 25), Value = unlocked / total, Color = T.Gold, Parent = chip })
	bar.ZIndex = 7
	bar.Fill.ZIndex = 7

	local list = scroller(w.Content)
	local rows = {}
	for i, a in Achievements.List do
		if w.Tab == "All" or a.Category == w.Tab then
			table.insert(rows, { a = a, i = i, done = data.Achievements[a.Id] ~= nil })
		end
	end
	-- closest-to-complete first, finished ones last
	table.sort(rows, function(x, y)
		if x.done ~= y.done then
			return not x.done
		end
		local px = math.min(1, (data.Stats[x.a.Stat] or 0) / x.a.Goal)
		local py = math.min(1, (data.Stats[y.a.Stat] or 0) / y.a.Goal)
		if px ~= py then
			return px > py
		end
		return x.i < y.i
	end)
	for order, r in rows do
		local a = r.a
		local value = math.min(data.Stats[a.Stat] or 0, a.Goal)
		local row = UIKit.Panel({ Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = r.done and Color3.fromRGB(52, 44, 16) or T.Panel, BackgroundTransparency = 0, LayoutOrder = order, ZIndex = 6, Parent = list })
		if r.done then
			UIKit.Stroke(T.Gold, 1, 0.4).Parent = row
		end
		local iconBox = UIKit.Panel({ Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = r.done and T.Gold or T.Panel3, BackgroundTransparency = r.done and 0.2 or 0, ZIndex = 7, Parent = row })
		Label({ Text = a.Icon, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 24, ZIndex = 8, TextTransparency = r.done and 0 or 0.4, Parent = iconBox })
		Label({ Text = a.Name .. (r.done and "  ✓" or ""), Size = UDim2.new(0.5, 0, 0, 20), Position = UDim2.fromOffset(64, 9), TextSize = 15, Font = T.Black, TextColor3 = r.done and T.Gold or T.Text, ZIndex = 7, Parent = row })
		Label({ Text = a.Desc, Size = UDim2.new(0.55, 0, 0, 16), Position = UDim2.fromOffset(64, 30), TextSize = 12, Font = T.Medium, TextColor3 = T.Sub, ZIndex = 7, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
		local pb = UIKit.Bar({ Size = UDim2.new(0.28, 0, 0, 8), Position = UDim2.new(0.62, 0, 0, 16), Value = value / a.Goal, Color = r.done and T.Gold or T.Accent2, Parent = row })
		pb.ZIndex = 7
		pb.Fill.ZIndex = 7
		Label({ Text = Util.Comma(value) .. " / " .. Util.Comma(a.Goal), Size = UDim2.new(0.28, 0, 0, 14), Position = UDim2.new(0.62, 0, 0, 30), TextSize = 11, Font = T.Bold, TextColor3 = T.Sub, ZIndex = 7, Parent = row })
		Label({ Text = "$" .. Util.Comma(a.Reward), Size = UDim2.fromOffset(80, 62), Position = UDim2.new(1, -90, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 15, Font = T.Black, TextColor3 = r.done and T.Sub or T.Green, ZIndex = 7, Parent = row })
	end
end

-- SETTINGS ------------------------------------------------------------------------------
local function saveSettings()
	Effects.ShakeScale = ClientState.Settings.Shake
	Remotes.SaveSettings:FireServer(ClientState.Settings)
end

function renderSettings(w)
	clear(w.Content)
	clear(w.Right)
	local S = ClientState.Settings
	local list = scroller(w.Content)
	local function row(order, title, desc)
		local r = UIKit.Panel({ Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = T.Panel, BackgroundTransparency = 0, LayoutOrder = order, ZIndex = 6, Parent = list })
		Label({ Text = title, Size = UDim2.new(0.5, 0, 0, 22), Position = UDim2.fromOffset(16, 10), TextSize = 16, Font = T.Black, ZIndex = 7, Parent = r })
		Label({ Text = desc, Size = UDim2.new(0.5, 0, 0, 16), Position = UDim2.fromOffset(16, 34), TextSize = 12, Font = T.Medium, TextColor3 = T.Sub, ZIndex = 7, Parent = r })
		local controls = new("Frame", { Size = UDim2.new(0.5, -16, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), BackgroundTransparency = 1, ZIndex = 7, Parent = r }, {
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		return controls
	end
	local function stepper(parent, text, onMinus, onPlus)
		local minus = UIKit.Button({ Text = "−", Size = UDim2.fromOffset(40, 36), Color = T.Panel3, LayoutOrder = 1, Parent = parent }, onMinus)
		minus.ZIndex = 8
		local value = UIKit.Panel({ Size = UDim2.fromOffset(90, 36), BackgroundColor3 = T.Panel2, LayoutOrder = 2, ZIndex = 8, Parent = parent })
		Label({ Text = text, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, Font = T.Black, ZIndex = 9, Parent = value })
		local plus = UIKit.Button({ Text = "+", Size = UDim2.fromOffset(40, 36), Color = T.Panel3, LayoutOrder = 3, Parent = parent }, onPlus)
		plus.ZIndex = 8
	end
	local function change(key, value)
		S[key] = value
		saveSettings()
		w.Render()
	end
	stepper(row(1, "FIELD OF VIEW", "Wider view vs. bigger targets"), tostring(S.FOV), function()
		change("FOV", math.max(60, S.FOV - 5))
	end, function()
		change("FOV", math.min(100, S.FOV + 5))
	end)
	stepper(row(2, "AIM SENSITIVITY", "Mouse speed while aiming down sights"), string.format("%.1fx", S.AdsSens), function()
		change("AdsSens", math.max(0.2, math.floor((S.AdsSens - 0.1) * 10 + 0.5) / 10))
	end, function()
		change("AdsSens", math.min(1.5, math.floor((S.AdsSens + 0.1) * 10 + 0.5) / 10))
	end)
	local shakeRow = row(3, "SCREEN SHAKE", "Reduce if explosions make you dizzy")
	for i, opt in { { "OFF", 0 }, { "LOW", 0.5 }, { "FULL", 1 } } do
		local b = UIKit.Button({ Text = opt[1], Size = UDim2.fromOffset(70, 36), Color = math.abs(S.Shake - opt[2]) < 0.01 and T.Accent or T.Panel3, TextSize = 13, LayoutOrder = i, Parent = shakeRow }, function()
			change("Shake", opt[2])
		end)
		b.ZIndex = 8
	end
	local crossRow = row(4, "CROSSHAIR COLOR", "Pick what stands out on every map")
	for i, name in { "White", "Green", "Cyan", "Red", "Yellow" } do
		local b = UIKit.Button({ Text = S.Crosshair == name and "✓" or "", Size = UDim2.fromOffset(36, 36), Color = ClientState.CrosshairColors[name], TextColor = Color3.new(0, 0, 0), TextSize = 16, LayoutOrder = i, Parent = crossRow }, function()
			change("Crosshair", name)
		end)
		b.ZIndex = 8
	end
end

-- OPEN / CLOSE ---------------------------------------------------------------------
function Menus.Open(name: string, tab: string?)
	local w = windows[name]
	if not w then
		return
	end
	for other, ow in windows do
		if other ~= name then
			ow.Overlay.Visible = false
		end
	end
	if tab then
		w.Tab = tab
	end
	openName = name
	ClientState.MenuOpen = true
	w.Overlay.Visible = true
	w.Render()
	local scale = w.Panel:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = w.Panel })
	scale.Scale = 0.92
	UIKit.Tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
end

function Menus.Toggle(name: string)
	if openName == name then
		Menus.Close()
	else
		Menus.Open(name)
	end
end

function Menus.Close()
	for _, w in windows do
		w.Overlay.Visible = false
	end
	openName = nil
	ClientState.MenuOpen = mainMenu.Visible or results.Visible
end

function Menus.IsOpen(): boolean
	return openName ~= nil
end

-- SCOREBOARD -------------------------------------------------------------------------
local function buildScoreboard()
	scoreboard = UIKit.Panel({ Name = "Scoreboard", Size = UDim2.fromOffset(620, 560), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.1, Visible = false, ZIndex = 4, Parent = gui })
	Label({ Name = "Title", Text = Config.ModeName, Size = UDim2.new(1, -32, 0, 30), Position = UDim2.fromOffset(16, 10), TextSize = 22, Font = T.Black, ZIndex = 5, Parent = scoreboard })
	local header = new("Frame", { Size = UDim2.new(1, -32, 0, 20), Position = UDim2.fromOffset(16, 46), BackgroundTransparency = 1, ZIndex = 5, Parent = scoreboard })
	for _, col in { { "#", 0, 30 }, { "PLAYER", 36, 250 }, { "KILLS", 330, 70 }, { "DEATHS", 400, 70 }, { "SCORE", 480, 100 } } do
		Label({ Text = col[1], Size = UDim2.fromOffset(col[3], 20), Position = UDim2.fromOffset(col[2], 0), TextSize = 11, Font = T.Black, TextColor3 = T.Sub, ZIndex = 5, Parent = header })
	end
	new("ScrollingFrame", { Name = "Rows", Size = UDim2.new(1, -32, 1, -80), Position = UDim2.fromOffset(16, 70), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 5, Parent = scoreboard }, { UIKit.List(3) })
end

local function renderScoreboard()
	local rowsFrame = scoreboard.Rows
	for _, c in rowsFrame:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local rows = {}
	for _, p in Players:GetPlayers() do
		local char = p.Character
		table.insert(rows, { Name = p.Name, VIP = p:GetAttribute("Pass_VIP"), Level = p:GetAttribute("Level") or 1, Kills = p:GetAttribute("Kills") or 0, Deaths = p:GetAttribute("Deaths") or 0, Score = p:GetAttribute("Score") or 0, Me = p == player, Team = p:GetAttribute("Team"), Downed = char and char:GetAttribute("Downed") })
	end
	local bots = ReplicatedStorage:FindFirstChild("BotStats")
	if bots then
		for _, b in bots:GetChildren() do
			table.insert(rows, { Name = b.Name, Bot = true, Kills = b:GetAttribute("Kills") or 0, Deaths = b:GetAttribute("Deaths") or 0, Score = b:GetAttribute("Score") or 0, Team = b:GetAttribute("Team") })
		end
	end
	local modeDef = Config.Modes[ReplicatedStorage:GetAttribute("Mode") or "TDM"] or Config.Modes.TDM
	scoreboard.Title.Text = modeDef.Name .. "  ·  " .. (ReplicatedStorage:GetAttribute("MapName") or "")
	-- team modes: my team first, then the others, each sorted by score
	local myTeam = player:GetAttribute("Team")
	local order = {}
	for i, t in modeDef.Teams do
		order[t] = (t == myTeam) and 0 or i
	end
	table.sort(rows, function(a, b)
		local ta, tb = order[a.Team] or 9, order[b.Team] or 9
		if ta ~= tb then
			return ta < tb
		end
		return a.Score > b.Score
	end)
	local layout = 0
	local lastTeam = false
	local place = 0
	for _, r in rows do
		if #modeDef.Teams > 0 and r.Team ~= lastTeam then
			lastTeam = r.Team
			place = 0
			layout += 1
			local info = Config.Teams[r.Team or ""]
			local header = UIKit.Panel({ Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = info and info.Color:Lerp(Color3.new(), 0.45) or T.Panel3, BackgroundTransparency = 0.1, LayoutOrder = layout, ZIndex = 5, Parent = rowsFrame })
			Label({ Text = (info and info.Name or "NO TEAM") .. (r.Team == myTeam and "  (YOUR TEAM)" or "") .. "   " .. tostring(ReplicatedStorage:GetAttribute("Score_" .. tostring(r.Team)) or 0) .. " KILLS", Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(8, 0), TextSize = 13, Font = T.Black, ZIndex = 6, Parent = header })
		end
		place += 1
		layout += 1
		local i = place
		local row = UIKit.Panel({ Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = r.Me and Color3.fromRGB(80, 66, 14) or T.Panel2, BackgroundTransparency = 0.2, LayoutOrder = layout, ZIndex = 5, Parent = rowsFrame })
		local nameColor = r.VIP and T.Gold or (r.Bot and T.Sub or T.Text)
		local name = (r.VIP and "👑 " or "") .. r.Name .. (r.Bot and "  [BOT]" or ("  · LVL " .. (r.Level or 1))) .. (r.Downed and "  ⬇" or "")
		for _, col in { { tostring(i), 6, 30, T.Sub }, { name, 36, 290, nameColor }, { tostring(r.Kills), 330, 70, T.Text }, { tostring(r.Deaths), 400, 70, T.Text }, { Util.Comma(r.Score), 480, 100, T.Accent } } do
			Label({ Text = col[1], Size = UDim2.fromOffset(col[3], 26), Position = UDim2.fromOffset(col[2], 0), TextSize = 13, Font = T.Black, TextColor3 = col[4], ZIndex = 6, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
		end
	end
end

function Menus.ShowScoreboard(on: boolean)
	scoreboard.Visible = on
	if on then
		renderScoreboard()
	end
end

-- RESULTS ------------------------------------------------------------------------------
local function buildResults()
	results = new("TextButton", { Name = "Results", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25, Text = "", AutoButtonColor = false, Modal = true, Visible = false, ZIndex = 8, Parent = gui })
end

function Menus.ShowResults(info)
	clear(results)
	results.Visible = true
	local teamMode = info.Mode ~= nil and Config.Modes[info.Mode] and #Config.Modes[info.Mode].Teams > 0
	local won = info.Won == true or (not teamMode and info.Place == 1)
	local title, color
	if teamMode then
		if info.WinnerTeam == nil then
			title, color = "DRAW", T.Accent2
		elseif won then
			title, color = "VICTORY", T.Gold
		else
			title, color = "DEFEAT", T.Red
		end
	else
		title = won and "VICTORY" or (info.Place <= 3 and ("#" .. info.Place .. " PLACE") or "MATCH OVER")
		color = won and T.Gold or (info.Place <= 3 and T.Accent2 or T.Red)
	end
	local t = Label({ Text = title, Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromScale(0, 0.08), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 72, Font = T.Black, TextColor3 = color, ZIndex = 9, Parent = results })
	UIKit.TextStroke(0.3).Parent = t
	local sc = new("UIScale", { Scale = 0.5, Parent = t })
	UIKit.Tween(sc, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	local winnerText = "WINNER: " .. string.upper(info.Winner)
	if teamMode then
		local parts = {}
		for _, t in Config.Modes[info.Mode].Teams do
			table.insert(parts, Config.Teams[t].Name .. " " .. tostring(info.Scores and info.Scores[t] or 0))
		end
		winnerText = (info.WinnerTeam and (Config.Teams[info.WinnerTeam].Name .. " WINS  ·  ") or "") .. table.concat(parts, "  –  ")
	end
	Label({ Text = (info.Nuke and "☢️ TACTICAL NUKE · " or "") .. winnerText, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0.08, 84), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 20, Font = T.Black, ZIndex = 9, Parent = results })

	-- podium
	local podium = new("Frame", { Size = UDim2.fromOffset(600, 170), Position = UDim2.fromScale(0.5, 0.32), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, ZIndex = 9, Parent = results })
	local places = { { 2, 0, 120, T.Sub }, { 1, 200, 160, T.Gold }, { 3, 400, 100, Color3.fromRGB(205, 127, 50) } }
	for _, p in places do
		local row = info.Rows[p[1]]
		if row then
			local col = UIKit.Panel({ Size = UDim2.fromOffset(190, p[3]), Position = UDim2.new(0, p[2], 1, 0), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = p[4], BackgroundTransparency = 0.25, ZIndex = 9, Parent = podium })
			Label({ Text = "#" .. p[1], Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 6), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 30, Font = T.Black, ZIndex = 10, Parent = col })
			Label({ Text = row.Name, Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(5, 42), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, Font = T.Black, ZIndex = 10, TextTruncate = Enum.TextTruncate.AtEnd, Parent = col })
			Label({ Text = string.format("%d KILLS · %s PTS", row.Kills, Util.Comma(row.Score)), Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 64), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11, Font = T.Bold, ZIndex = 10, Parent = col })
		end
	end

	-- your summary
	local mine = UIKit.Panel({ Size = UDim2.fromOffset(600, 120), Position = UDim2.fromScale(0.5, 0.55), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = T.Panel, ZIndex = 9, Parent = results })
	local kd = info.Deaths > 0 and (info.Kills / info.Deaths) or info.Kills
	local cells = {
		{ "PLACE", "#" .. info.Place, color }, { "KILLS", tostring(info.Kills), T.Text }, { "K/D", string.format("%.2f", kd), T.Text },
		{ "CASH EARNED", "$" .. Util.Comma(info.Cash), T.Green }, { "XP EARNED", Util.Comma(info.XP), T.Accent2 },
	}
	for i, c in cells do
		Label({ Text = c[1], Size = UDim2.fromOffset(120, 14), Position = UDim2.fromOffset((i - 1) * 120, 20), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11, Font = T.Black, TextColor3 = T.Sub, ZIndex = 10, Parent = mine })
		Label({ Text = c[2], Size = UDim2.fromOffset(120, 34), Position = UDim2.fromOffset((i - 1) * 120, 38), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 28, Font = T.Black, TextColor3 = c[3], ZIndex = 10, Parent = mine })
	end
	if not ClientState.HasPass("DoubleXP") then
		local b = UIKit.Button({ Text = "⭐ DOUBLE YOUR XP EVERY MATCH  ·  R$ " .. Monetization.GamePasses.DoubleXP.Price, Size = UDim2.fromOffset(380, 30), Position = UDim2.new(0.5, 0, 1, -38), AnchorPoint = Vector2.new(0.5, 0), Color = T.Robux, TextSize = 13, Parent = mine }, function()
			Menus.BuyPass("DoubleXP")
		end)
		b.ZIndex = 10
	end
	ClientState.MenuOpen = true
end

function Menus.HideResults()
	if results.Visible then
		results.Visible = false
		ClientState.MenuOpen = openName ~= nil or mainMenu.Visible
	end
end

-- MAIN MENU + DAILY -------------------------------------------------------------------
local dailyPanel
local function renderDaily()
	clear(dailyPanel)
	local data = ClientState.Data
	if not data then
		return
	end
	local available = data.DailyAvailable
	local streak = data.Daily.Streak or 0
	Label({ Text = available and "🎁 DAILY REWARD READY!" or "🎁 DAILY REWARDS", Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(12, 8), TextSize = 14, Font = T.Black, TextColor3 = available and T.Accent or T.Sub, ZIndex = 3, Parent = dailyPanel })
	local row = new("Frame", { Size = UDim2.new(1, -24, 0, 50), Position = UDim2.fromOffset(12, 32), BackgroundTransparency = 1, ZIndex = 3, Parent = dailyPanel }, { UIKit.List(5, true) })
	local days = #Config.DailyRewards
	local cycleDone = streak > 0 and ((streak - 1) % days + 1) or 0
	local nextDay = available and (cycleDone % days) + 1 or nil
	if nextDay == 1 then
		cycleDone = 0
	end
	for i, reward in Config.DailyRewards do
		local claimed = i <= cycleDone
		local box = UIKit.Panel({ Size = UDim2.fromOffset(44, 50), BackgroundColor3 = (i == nextDay) and T.Accent or (claimed and T.Panel3 or T.Panel2), BackgroundTransparency = 0, LayoutOrder = i, ZIndex = 3, Parent = row })
		local textColor = i == nextDay and Color3.new(0, 0, 0) or T.Text
		Label({ Text = "DAY " .. i, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 6), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 9, Font = T.Black, TextColor3 = textColor, ZIndex = 4, Parent = box })
		Label({ Text = claimed and "✓" or ("$" .. reward), Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 22), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11, Font = T.Black, TextColor3 = textColor, ZIndex = 4, Parent = box })
	end
	if available then
		local b = UIKit.Button({ Text = "CLAIM", Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, 1, -38), TextSize = 14, Parent = dailyPanel }, function()
			Remotes.ClaimDaily:FireServer()
		end)
		b.ZIndex = 3
	end
end

local profileLabels = {}
local function buildMainMenu()
	mainMenu = new("TextButton", { Name = "MainMenu", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.25, Text = "", AutoButtonColor = false, Modal = true, ZIndex = 1, Parent = gui })
	new("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.5), NumberSequenceKeypoint.new(1, 1) }), Parent = mainMenu })

	local left = new("Frame", { Size = UDim2.new(0, 420, 1, 0), Position = UDim2.fromOffset(60, 0), BackgroundTransparency = 1, ZIndex = 2, Parent = mainMenu })
	local title = Label({ Text = Config.GameName, Size = UDim2.new(1, 0, 0, 80), Position = UDim2.new(0, 0, 0.16, 0), TextSize = 68, Font = T.Black, ZIndex = 2, Parent = left })
	UIKit.Gradient(T.Accent, Color3.fromRGB(255, 120, 30), 90).Parent = title
	UIKit.TextStroke(0.6).Parent = title
	Label({ Text = "SLIDE. DASH. SLAM. DOMINATE.", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 4, 0.16, 82), TextSize = 16, Font = T.Black, TextColor3 = T.Accent2, ZIndex = 2, Parent = left })

	local buttons = new("Frame", { Size = UDim2.fromOffset(320, 300), Position = UDim2.new(0, 0, 0.16, 130), BackgroundTransparency = 1, ZIndex = 2, Parent = left }, { UIKit.List(10) })
	local play = UIKit.Button({ Text = "▶  PLAY", Size = UDim2.fromOffset(320, 64), TextSize = 28, LayoutOrder = 1, Parent = buttons }, function()
		Menus.HideMain()
		if Menus.OnDeploy then
			Menus.OnDeploy()
		end
	end)
	play.ZIndex = 2
	for i, item in { { "🔫  ARMORY", "Armory", T.Panel2 }, { "💎  STORE", "Store", T.Robux }, { "🏆  ACHIEVEMENTS", "Achievements", T.Panel2 }, { "⚙️  SETTINGS", "Settings", T.Panel2 } } do
		local b = UIKit.Button({ Text = item[1], Size = UDim2.fromOffset(320, 46), Color = item[3], TextSize = 18, LayoutOrder = i + 1, Parent = buttons }, function()
			Menus.Open(item[2])
		end)
		b.ZIndex = 2
	end

	local controls = Label({
		Text = "WASD move · SHIFT sprint · SPACE double jump · C slide · T slam (in air) · Q dash · E drive cars\nLMB shoot · RMB aim · R reload · 1/2 swap · V knife · G grenade · Z/X call-ins · TAB scores",
		Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -70), TextSize = 12, Font = T.Medium, TextColor3 = T.Sub, TextWrapped = true, ZIndex = 2, Parent = left,
	})
	controls.TextYAlignment = Enum.TextYAlignment.Top

	-- right: profile card + daily
	local right = new("Frame", { Size = UDim2.fromOffset(340, 400), Position = UDim2.new(1, -40, 0.16, 0), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, ZIndex = 2, Parent = mainMenu })
	local card = UIKit.Panel({ Size = UDim2.fromOffset(340, 150), BackgroundColor3 = T.Panel, ZIndex = 2, Parent = right })
	local avatar = new("ImageLabel", { Size = UDim2.fromOffset(80, 80), Position = UDim2.fromOffset(14, 14), BackgroundColor3 = T.Panel3, ZIndex = 3, Parent = card })
	UIKit.Corner(40).Parent = avatar
	task.spawn(function()
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok then
			avatar.Image = img
		end
	end)
	Label({ Text = player.DisplayName, Size = UDim2.fromOffset(220, 24), Position = UDim2.fromOffset(106, 18), TextSize = 20, Font = T.Black, ZIndex = 3, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	profileLabels.Level = Label({ Text = "", Size = UDim2.fromOffset(220, 18), Position = UDim2.fromOffset(106, 44), TextSize = 14, Font = T.Black, TextColor3 = T.Accent, ZIndex = 3, Parent = card })
	profileLabels.Cash = Label({ Text = "", Size = UDim2.fromOffset(220, 20), Position = UDim2.fromOffset(106, 64), TextSize = 18, Font = T.Black, TextColor3 = T.Green, ZIndex = 3, Parent = card })
	profileLabels.Stats = Label({ Text = "", Size = UDim2.new(1, -28, 0, 36), Position = UDim2.fromOffset(14, 104), TextSize = 12, Font = T.Bold, TextColor3 = T.Sub, TextWrapped = true, ZIndex = 3, Parent = card })

	dailyPanel = UIKit.Panel({ Size = UDim2.fromOffset(340, 130), Position = UDim2.fromOffset(0, 162), BackgroundColor3 = T.Panel, ZIndex = 2, Parent = right })

	local vip = UIKit.Button({ Text = "", Size = UDim2.fromOffset(340, 64), Position = UDim2.fromOffset(0, 304), Color = Color3.fromRGB(70, 56, 10), Parent = right }, function()
		Menus.Open("Store", "Game Passes")
	end)
	vip.ZIndex = 2
	UIKit.Stroke(T.Gold, 2, 0).Parent = vip
	Label({ Text = "👑 GET VIP", Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(12, 8), TextSize = 20, Font = T.Black, TextColor3 = T.Gold, ZIndex = 3, Parent = vip })
	Label({ Text = "2x cash · +10 HP · gold name · VIP tag", Size = UDim2.new(1, -20, 0, 16), Position = UDim2.fromOffset(12, 36), TextSize = 12, Font = T.Bold, ZIndex = 3, Parent = vip })
	profileLabels.VIP = vip
end

local function refreshMain()
	local data = ClientState.Data
	profileLabels.Level.Text = "LEVEL " .. (player:GetAttribute("Level") or 1)
	profileLabels.Cash.Text = "$" .. Util.Comma(player:GetAttribute("Cash") or 0)
	if data then
		local s = data.Stats
		local kills, deaths = s.Kills or 0, s.Deaths or 0
		profileLabels.Stats.Text = string.format("KILLS %s  ·  K/D %.2f  ·  WINS %s  ·  BEST STREAK %s", Util.Comma(kills), deaths > 0 and kills / deaths or kills, Util.Comma(s.Wins or 0), s.BestStreak or 0)
		renderDaily()
	end
	profileLabels.VIP.Visible = not ClientState.HasPass("VIP")
end

function Menus.ShowMain()
	mainMenu.Visible = true
	ClientState.MenuOpen = true
	refreshMain()
end

function Menus.HideMain()
	mainMenu.Visible = false
	ClientState.MenuOpen = openName ~= nil
end

-- INIT ----------------------------------------------------------------------------------
function Menus.Init(playerGui: PlayerGui)
	gui = new("ScreenGui", { Name = "Menus", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5, Parent = playerGui })

	local armory = window("Armory", "ARMORY", { "Primary", "Secondary" })
	armory.Render = function()
		renderArmory(armory)
	end
	local store = window("Store", "💎 STORE", { "Game Passes", "Cash & Boosts" })
	store.Render = function()
		renderStore(store)
	end
	local tabs = { "All" }
	for _, c in Achievements.Categories do
		table.insert(tabs, c)
	end
	local ach = window("Achievements", "🏆 ACHIEVEMENTS", tabs)
	ach.Render = function()
		renderAchievements(ach)
	end

	local settings = window("Settings", "⚙️ SETTINGS", nil)
	settings.Render = function()
		renderSettings(settings)
	end

	buildScoreboard()
	buildResults()
	buildMainMenu()

	ClientState.Changed.Event:Connect(function()
		if openName and windows[openName] then
			windows[openName].Render()
		end
		if mainMenu.Visible then
			refreshMain()
		end
	end)

	local last = 0
	RunService.Heartbeat:Connect(function()
		if scoreboard.Visible and os.clock() - last > 0.5 then
			last = os.clock()
			renderScoreboard()
		end
		if results.Visible and ReplicatedStorage:GetAttribute("MatchState") ~= "Results" then
			Menus.HideResults()
		end
	end)
end

return Menus
