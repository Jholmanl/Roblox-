-- Subtle, contextual Robux offers.
-- A small card slides in at the side of the screen when an upgrade is actually
-- relevant (died a few times, ran dry, couldn't afford a gun), then slides away on
-- its own. Rules that keep it from being annoying:
--   * at most one card every 4 minutes, and 3 per session
--   * never while you're in a fight (took damage in the last 6 seconds) or voting
--   * never for something you already own; no close button needed, it leaves by itself
--   * honest copy: real perks and real prices only, no fake timers or scarcity
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared.Monetization)
local UIKit = require(script.Parent.UIKit)
local ClientState = require(script.Parent.ClientState)

local T = UIKit.Theme
local new, Label = UIKit.new, UIKit.Label

local COOLDOWN = 240
local MAX_PER_SESSION = 3
local SHOW_TIME = 9

local OfferToast = {}
OfferToast.BuyPass = function(_key) end -- injected (Menus.BuyPass)
OfferToast.BuyProduct = function(_key) end -- injected (Menus.BuyProduct)
OfferToast.LastDamaged = 0

local gui, card
local shown = 0
local lastShown = -math.huge
local current = nil
local deathsSince = 0
local dryFires = 0

-- Context lines (why this is relevant *right now*).
local REASONS = {
	Vampire = "Heal 25 HP on every kill and stay in the fight.",
	Juggernaut = "+35 max health to win more of those close fights.",
	ExtendedMags = "+50% magazine size, so fewer reloads mid-fight.",
	FastHands = "35% faster reloads.",
	Cash2 = "5,000 cash for the guns in the Armory.",
}

local function canShow(): boolean
	if shown >= MAX_PER_SESSION or os.clock() - lastShown < COOLDOWN or current then
		return false
	end
	if ReplicatedStorage:GetAttribute("MatchState") == "Voting" then
		return false
	end
	if os.clock() - OfferToast.LastDamaged < 6 then
		return false
	end
	return true
end

local function hide()
	if not card or not current then
		return
	end
	current = nil
	local c = card
	UIKit.Tween(c, 0.35, { Position = UDim2.new(1, 340, 0.6, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
end

local function build(kind: string, key: string)
	local info = kind == "Pass" and Monetization.GamePasses[key] or Monetization.Products[key]
	if not info then
		return
	end
	if card then
		card:Destroy()
	end
	local accent = info.Color or T.Robux
	card = new("Frame", {
		Name = "Offer", Size = UDim2.fromOffset(300, 96), Position = UDim2.new(1, 340, 0.6, 0), AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = T.Panel, BackgroundTransparency = 0.08, BorderSizePixel = 0, Parent = gui,
	})
	UIKit.Corner(10).Parent = card
	new("UIStroke", { Color = accent, Thickness = 1.5, Transparency = 0.35, Parent = card })
	new("UIGradient", { Rotation = 0, Color = ColorSequence.new(accent:Lerp(T.Panel, 0.75), T.Panel), Parent = card })
	-- icon tile
	local tile = new("Frame", { Size = UDim2.fromOffset(62, 62), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = accent, BorderSizePixel = 0, Parent = card })
	UIKit.Corner(10).Parent = tile
	UIKit.Gradient(accent:Lerp(Color3.new(1, 1, 1), 0.25), accent:Lerp(Color3.new(), 0.35), 90).Parent = tile
	Label({ Text = info.Icon or "💎", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 32, Font = T.Black, Parent = tile })
	-- text
	Label({ Text = string.upper(info.Name), Size = UDim2.new(1, -96, 0, 18), Position = UDim2.fromOffset(86, 12), TextSize = 14, Font = T.Black, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	Label({
		Text = REASONS[key] or (info.Perks and info.Perks[1]) or info.Desc or "", Size = UDim2.new(1, -96, 0, 30), Position = UDim2.fromOffset(86, 31),
		TextSize = 11, Font = T.Medium, TextColor3 = T.Sub, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = card,
	})
	local buy = UIKit.Button({ Text = "R$ " .. tostring(info.Price), Size = UDim2.fromOffset(82, 24), Position = UDim2.fromOffset(86, 62), Color = T.Robux, TextSize = 13, Radius = 12, Parent = card }, function()
		if kind == "Pass" then
			OfferToast.BuyPass(key)
		else
			OfferToast.BuyProduct(key)
		end
		hide()
	end)
	buy.Name = "Buy"
	-- auto-dismiss bar
	local bar = new("Frame", { Size = UDim2.new(1, -20, 0, 2), Position = UDim2.new(0, 10, 1, -4), BackgroundColor3 = accent, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = card })
	UIKit.Tween(bar, SHOW_TIME, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)
	return card
end

-- Show an offer if the rules allow it. kind = "Pass" | "Product".
function OfferToast.Offer(kind: string, key: string, force: boolean?): boolean
	if kind == "Pass" and ClientState.HasPass(key) then
		return false
	end
	if not force and not canShow() then
		return false
	end
	local c = build(kind, key)
	if not c then
		return false
	end
	shown += 1
	lastShown = os.clock()
	local token = {}
	current = token
	UIKit.Tween(c, 0.45, { Position = UDim2.new(1, -16, 0.6, 0) }, Enum.EasingStyle.Back)
	task.delay(SHOW_TIME, function()
		if current == token then
			hide()
		end
	end)
	return true
end

-- CONTEXT HOOKS --------------------------------------------------------------------------
function OfferToast.OnDeath()
	deathsSince += 1
	if deathsSince < 3 then
		return
	end
	-- (the death screen already has its own Instant Respawn button)
	for _, key in { "Juggernaut", "Vampire" } do
		if not ClientState.HasPass(key) then
			if OfferToast.Offer("Pass", key) then
				deathsSince = 0
			end
			return
		end
	end
end

function OfferToast.OnDryFire()
	dryFires += 1
	if dryFires < 6 then
		return
	end
	for _, key in { "ExtendedMags", "FastHands" } do
		if not ClientState.HasPass(key) then
			if OfferToast.Offer("Pass", key) then
				dryFires = 0
			end
			return
		end
	end
end

-- The player just tried to buy something they can't afford: they asked, so this
-- one skips the cooldown (but still only appears once at a time).
function OfferToast.OnCantAfford()
	OfferToast.Offer("Product", "Cash2", true)
end

function OfferToast.Init(playerGui: PlayerGui)
	gui = new("ScreenGui", { Name = "Offers", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 6, Parent = playerGui })
	-- don't pitch anything in the first two minutes of a session
	lastShown = os.clock() - COOLDOWN + 120
end

return OfferToast
