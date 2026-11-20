local ROOT = ARGS[2]
local MapKit = require({ __module = ROOT .. "/src/server/Maps/MapKit.lua" })
local GunBuilder = require({ __module = ROOT .. "/src/shared/GunBuilder.lua" })
-- pose: apply the same offsets WeaponController uses at full action
local function pose(model, k, only)
	local h = model.PrimaryPart
	local hcf = h.CFrame
	local piv = { Cylinder = model:GetAttribute("CylinderPivot"), Barrels = model:GetAttribute("BarrelsPivot"), Break = model:GetAttribute("BreakPivot") }
	for _, p in model:GetDescendants() do
		local kind = p:IsA("BasePart") and p:GetAttribute("Anim")
		if kind and only[kind] then
			local base = hcf:Inverse() * p.CFrame
			local function around(pv, rot) local v = pv or Vector3.zero return hcf * CFrame.new(v) * rot * CFrame.new(-v) * base end
			local cf
			if kind == "Slide" then cf = hcf * CFrame.new(0, 0, 0.22 * k) * base
			elseif kind == "Bolt" then cf = hcf * CFrame.new(0, 0, 0.14 * k) * base
			elseif kind == "Recoil" then cf = hcf * CFrame.new(0, 0, 0.28 * k) * base
			elseif kind == "Pump" then cf = hcf * CFrame.new(0, 0, 0.34 * k) * base
			elseif kind == "BoltAction" then cf = hcf * CFrame.new(0, 0.07 * k, 0.3 * k) * base
			elseif kind == "Mag" then cf = hcf * CFrame.new(0, -1.6 * k, 0.15 * k) * base
			elseif kind == "Cylinder" then cf = around(piv.Cylinder, CFrame.Angles(0, 0, math.pi / 6 * k))
			elseif kind == "Barrels" then cf = around(piv.Barrels, CFrame.Angles(0, 0, 0.5 * k))
			elseif kind == "Break" then cf = around(piv.Break, CFrame.Angles(-0.5 * k, 0, 0))
			elseif kind == "Payload" then if k > 0.5 then p.Transparency = 1 end cf = p.CFrame
			else cf = p.CFrame end
			p.CFrame = cf
		end
	end
end
local GUNS = { { "Sidekick", { Slide = true } }, { "Brute", { Pump = true } }, { "Longbow", { BoltAction = true } }, { "Judge", { Cylinder = true } }, { "Duke", { Break = true } }, { "Striker", { Mag = true } }, { "Titan", { Recoil = true } }, { "Havoc", { Payload = true } } }
return {
	Name = "ANIM", Lighting = { ClockTime = 14 },
	Build = function()
		local kit = MapKit.new(1)
		kit:Part(Vector3.new(400, 1, 60), CFrame.new(0, -0.5, 0), Color3.fromRGB(205, 208, 214), Enum.Material.SmoothPlastic)
		for i, g in GUNS do
			for j, k in { 0, 1 } do
				local gun = GunBuilder.Build(g[1], false)
				gun:PivotTo(CFrame.new((i - 1) * 40 - 150 + (j - 1) * 16, 3, 0) * CFrame.Angles(0, math.rad(-90), 0))
				pose(gun, k, g[2])
				gun.Parent = kit.Props
			end
		end
		kit:Spawn(Vector3.new(0, 4, 20))
		return kit
	end,
}
