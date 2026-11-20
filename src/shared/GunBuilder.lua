-- Builds a gun model out of parts from the weapon's Look table.
-- No meshes needed, so the game runs with zero uploaded assets.
-- The barrel points down the Handle's -Z axis.
local Weapons = require(script.Parent.Weapons)

local GunBuilder = {}

local GOLD = Color3.fromRGB(255, 196, 40)

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Returns Model (PrimaryPart = Handle) with "Muzzle" and "Sight" attachments on the Handle.
function GunBuilder.Build(weaponId: string, golden: boolean?)
	local def = Weapons.Get(weaponId)
	local look = def.Look
	local L = look.Length
	local B = look.Barrel
	local bodyColor = golden and GOLD or look.Body
	local bodyMat = golden and Enum.Material.Metal or Enum.Material.SmoothPlastic
	local accentMat = look.Neon and Enum.Material.Neon or Enum.Material.SmoothPlastic

	local model = Instance.new("Model")
	model.Name = weaponId

	local origin = CFrame.new()
	local handle = part(model, "Handle", Vector3.new(0.35, 0.45, L), origin, bodyColor, bodyMat)
	if golden then
		handle.Reflectance = 0.25
	end
	model.PrimaryPart = handle

	local alongZ = CFrame.Angles(0, math.rad(90), 0) -- cylinders run along X, rotate onto Z
	local pieces = {
		part(model, "Barrel", Vector3.new(B + 0.1, 0.18, 0.18), origin * CFrame.new(0, 0.08, -L / 2 - B / 2 + 0.05) * alongZ, Color3.fromRGB(25, 25, 28), Enum.Material.Metal, Enum.PartType.Cylinder),
		part(model, "Grip", Vector3.new(0.24, 0.6, 0.32), origin * CFrame.new(0, -0.42, L * 0.22) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(28, 28, 30)),
		part(model, "Mag", Vector3.new(0.22, 0.55, 0.32), origin * CFrame.new(0, -0.45, -L * 0.12), bodyColor, bodyMat),
		part(model, "Rail", Vector3.new(0.37, 0.06, L * 0.85), origin * CFrame.new(0, 0.25, 0), look.Accent, accentMat),
		part(model, "Stripe", Vector3.new(0.37, 0.08, L * 0.5), origin * CFrame.new(0, -0.05, -L * 0.1), look.Accent, accentMat),
	}
	if L >= 2 then
		table.insert(pieces, part(model, "Stock", Vector3.new(0.28, 0.38, 0.7), origin * CFrame.new(0, -0.08, L / 2 + 0.3), bodyColor, bodyMat))
	end

	local sightHeight = 0.36
	if look.Scope then
		sightHeight = 0.48
		table.insert(pieces, part(model, "Scope", Vector3.new(0.9, 0.24, 0.24), origin * CFrame.new(0, 0.46, -0.1) * alongZ, Color3.fromRGB(20, 20, 22), Enum.Material.Metal, Enum.PartType.Cylinder))
		table.insert(pieces, part(model, "Lens", Vector3.new(0.02, 0.2, 0.2), origin * CFrame.new(0, 0.46, -0.56) * alongZ, look.Accent, Enum.Material.Neon, Enum.PartType.Cylinder))
	else
		table.insert(pieces, part(model, "SightFront", Vector3.new(0.06, 0.12, 0.06), origin * CFrame.new(0, 0.34, -L / 2 + 0.1), look.Accent, Enum.Material.Neon))
		table.insert(pieces, part(model, "SightRear", Vector3.new(0.2, 0.1, 0.06), origin * CFrame.new(0, 0.33, L / 2 - 0.2), Color3.fromRGB(20, 20, 20)))
	end

	for _, p in pieces do
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = p
		w.Parent = handle
	end

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0.08, -L / 2 - B)
	muzzle.Parent = handle

	local sight = Instance.new("Attachment")
	sight.Name = "Sight"
	sight.Position = Vector3.new(0, sightHeight, 0)
	sight.Parent = handle

	return model
end

-- Turns a built gun into a Tool the character can hold (third-person view).
function GunBuilder.BuildTool(weaponId: string, golden: boolean?)
	local def = Weapons.Get(weaponId)
	local model = GunBuilder.Build(weaponId, golden)
	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	tool:SetAttribute("WeaponId", weaponId)
	tool:SetAttribute("Slot", def.Slot)
	tool.Grip = CFrame.new(0, -0.35, def.Look.Length * 0.22)
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()
	return tool
end

return GunBuilder
