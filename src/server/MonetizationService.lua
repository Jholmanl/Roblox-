-- Game passes + developer products (Robux store).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Monetization = require(Shared.Monetization)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local AchievementService = require(script.Parent.AchievementService)

local MonetizationService = {}
MonetizationService.OnPassesChanged = nil :: ((Player) -> ())?

function MonetizationService.Has(player: Player, passKey: string): boolean
	return player:GetAttribute("Pass_" .. passKey) == true
end

function MonetizationService.RefreshPasses(player: Player)
	for passKey, pass in Monetization.GamePasses do
		local owned = false
		if Config.StudioGrantAllPasses and RunService:IsStudio() then
			owned = true
		elseif pass.Id and pass.Id > 0 then
			local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			owned = ok and result == true
		end
		player:SetAttribute("Pass_" .. passKey, owned)
	end
	if MonetizationService.OnPassesChanged then
		MonetizationService.OnPassesChanged(player)
	end
end

local function grantProduct(player: Player, productKey: string, product)
	local data = DataService.Get(player)
	if not data then
		return false
	end
	if product.Cash then
		DataService.AddCash(player, product.Cash, false, "PURCHASE")
	end
	if product.BoostMinutes then
		data.BoostUntil = math.max(os.time(), data.BoostUntil) + product.BoostMinutes * 60
		player:SetAttribute("BoostUntil", data.BoostUntil)
	end
	if product.Token then
		data.Tokens[product.Token] = (data.Tokens[product.Token] or 0) + 1
	end
	Remotes.Notify:FireClient(player, "Message", { Text = "PURCHASED: " .. string.upper(product.Name), Color = Config.Colors.Robux })
	AchievementService.Add(player, "RobuxPurchases", 1)
	DataService.Sync(player)
	return true
end

MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Never grant the same receipt twice
	for _, id in data.Receipts do
		if id == info.PurchaseId then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	local productKey, product = Monetization.FindProductById(info.ProductId)
	if not productKey then
		warn("[Monetization] Unknown product id " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok = pcall(grantProduct, player, productKey, product)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(data.Receipts, info.PurchaseId)
	while #data.Receipts > 50 do
		table.remove(data.Receipts, 1)
	end
	DataService.Save(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	local passKey, pass = Monetization.FindPassById(passId)
	if not passKey then
		return
	end
	player:SetAttribute("Pass_" .. passKey, true)
	Remotes.Notify:FireClient(player, "Message", { Text = pass.Icon .. " " .. string.upper(pass.Name) .. " UNLOCKED!", Color = pass.Color })
	AchievementService.Add(player, "RobuxPurchases", 1)
	-- a freshly bought knife gets equipped right away
	local knifeId = string.match(passKey, "^Knife(%w+)$")
	if knifeId then
		local data = DataService.Get(player)
		if data then
			data.Knife = knifeId
			DataService.Sync(player)
		end
	end
	if passKey == "Railgun" then
		local data = DataService.Get(player)
		if data then
			data.Owned.Railgun = true
			DataService.Sync(player)
		end
	end
	if MonetizationService.OnPassesChanged then
		MonetizationService.OnPassesChanged(player)
	end
end)

return MonetizationService
