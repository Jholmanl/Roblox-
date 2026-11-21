-- Melee knives. The Combat Knife is free; the rest are Robux game passes.
-- Each has its own detailed model (KnifeBuilder below) plus a small perk.
local Knives = {}

local rgb = Color3.fromRGB
local M = Enum.Material

Knives.Defs = {
	Standard = {
		Name = "COMBAT KNIFE", Icon = "🔪", Pass = nil,
		Damage = 100, Range = 8, Cooldown = 0.7,
		Perk = "Standard issue",
	},
	Karambit = {
		Name = "KARAMBIT", Icon = "🪝", Pass = "KnifeKarambit",
		Damage = 100, Range = 8, Cooldown = 0.5,
		Perk = "Faster swings (0.5s)",
	},
	Butterfly = {
		Name = "BUTTERFLY KNIFE", Icon = "🦋", Pass = "KnifeButterfly",
		Damage = 100, Range = 8.5, Cooldown = 0.55,
		Perk = "Quick swings + a little extra reach",
	},
	Machete = {
		Name = "JUNGLE MACHETE", Icon = "🗡️", Pass = "KnifeMachete",
		Damage = 120, Range = 10, Cooldown = 0.75,
		Perk = "Long reach, hits harder",
	},
	Katana = {
		Name = "DRAGON KATANA", Icon = "🐉", Pass = "KnifeKatana",
		Damage = 120, Range = 11, Cooldown = 0.6,
		Perk = "Glowing energy blade, longest reach",
	},
}

Knives.Order = { "Standard", "Karambit", "Butterfly", "Machete", "Katana" }

function Knives.Get(id: string?)
	return (id and Knives.Defs[id]) or Knives.Defs.Standard
end

-- Builds the knife model. The handle is the PrimaryPart; the blade points along -Z.
function Knives.Build(id: string?)
	local key = (id and Knives.Defs[id]) and id or "Standard"
	local model = Instance.new("Model")
	model.Name = key
	local parts = {}
	local function part(name, size, cf, color, material, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or M.Metal
		if shape then
			p.Shape = shape
		end
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.Parent = model
		table.insert(parts, p)
		return p
	end
	local function wedge(name, size, cf, color, material)
		local w = Instance.new("WedgePart")
		w.Name = name
		w.Size = size
		w.CFrame = cf
		w.Color = color
		w.Material = material or M.Metal
		w.CanCollide, w.CanQuery, w.CanTouch, w.Massless, w.CastShadow = false, false, false, true, false
		w.Parent = model
		table.insert(parts, w)
		return w
	end
	local steel = rgb(200, 205, 214)
	local edge = rgb(235, 238, 245)
	local handle

	if key == "Karambit" then
		handle = part("Handle", Vector3.new(0.16, 0.26, 0.6), CFrame.new(), rgb(30, 30, 34), M.SmoothPlastic)
		part("Ring", Vector3.new(0.06, 0.34, 0.34), CFrame.new(0, 0, 0.42) * CFrame.Angles(0, 0, 0), rgb(60, 60, 66), M.Metal, Enum.PartType.Cylinder)
		part("RingHole", Vector3.new(0.065, 0.2, 0.2), CFrame.new(0, 0, 0.42), rgb(10, 10, 12), M.SmoothPlastic, Enum.PartType.Cylinder)
		for i = 0, 4 do
			-- curved claw blade: short segments sweeping down and forward
			local a = math.rad(-8 - i * 14)
			local pos = Vector3.new(0, -0.02 - i * 0.07 - i * i * 0.012, -0.36 - i * 0.16)
			part("Blade" .. i, Vector3.new(0.04, 0.2 - i * 0.02, 0.2), CFrame.new(pos) * CFrame.Angles(a, 0, 0), i % 2 == 0 and steel or edge, M.Metal)
		end
		part("Accent", Vector3.new(0.17, 0.05, 0.5), CFrame.new(0, 0.1, 0), rgb(255, 70, 90), M.Neon)
	elseif key == "Butterfly" then
		handle = part("Handle", Vector3.new(0.12, 0.22, 0.7), CFrame.new(0.05, 0, 0), rgb(160, 120, 255), M.Metal)
		part("HandleB", Vector3.new(0.12, 0.22, 0.7), CFrame.new(-0.07, 0, 0), rgb(120, 90, 210), M.Metal)
		for i = -2, 2 do
			part("Cutout", Vector3.new(0.25, 0.08, 0.06), CFrame.new(0, 0, i * 0.12), rgb(20, 18, 30), M.SmoothPlastic)
		end
		part("Latch", Vector3.new(0.05, 0.08, 0.16), CFrame.new(0, -0.12, 0.33), rgb(210, 210, 220), M.Metal)
		part("Pivot", Vector3.new(0.26, 0.08, 0.08), CFrame.new(0, 0, -0.36), rgb(210, 210, 220), M.Metal, Enum.PartType.Cylinder)
		part("Blade", Vector3.new(0.04, 0.2, 0.7), CFrame.new(0, 0.01, -0.74), steel, M.Metal)
		wedge("Tip", Vector3.new(0.04, 0.2, 0.22), CFrame.new(0, 0.01, -1.2) * CFrame.Angles(0, math.rad(180), 0), edge, M.Metal)
		part("Swedge", Vector3.new(0.045, 0.04, 0.6), CFrame.new(0, 0.1, -0.76), edge, M.Metal)
	elseif key == "Machete" then
		handle = part("Handle", Vector3.new(0.18, 0.26, 0.7), CFrame.new(), rgb(60, 40, 26), M.Wood)
		for i = -1, 1 do
			part("Rivet", Vector3.new(0.2, 0.05, 0.05), CFrame.new(0, 0, i * 0.22), rgb(200, 170, 80), M.Metal, Enum.PartType.Cylinder)
		end
		part("Guard", Vector3.new(0.2, 0.34, 0.06), CFrame.new(0, 0.02, -0.38), rgb(50, 50, 54), M.Metal)
		part("Blade", Vector3.new(0.035, 0.3, 1.5), CFrame.new(0, 0.04, -1.15), rgb(150, 155, 160), M.Metal)
		part("Belly", Vector3.new(0.035, 0.12, 0.9), CFrame.new(0, -0.15, -1.45), rgb(150, 155, 160), M.Metal)
		part("Edge", Vector3.new(0.04, 0.04, 1.55), CFrame.new(0, -0.11, -1.18), edge, M.Metal)
		wedge("Tip", Vector3.new(0.035, 0.42, 0.3), CFrame.new(0, -0.02, -2.05) * CFrame.Angles(0, math.rad(180), 0), rgb(150, 155, 160), M.Metal)
		part("Lanyard", Vector3.new(0.05, 0.05, 0.3), CFrame.new(0, -0.1, 0.48), rgb(200, 60, 40), M.Fabric)
	elseif key == "Katana" then
		handle = part("Handle", Vector3.new(0.16, 0.2, 0.9), CFrame.new(), rgb(25, 22, 28), M.Fabric)
		for i = -3, 3 do
			part("Wrap", Vector3.new(0.17, 0.21, 0.04), CFrame.new(0, 0, i * 0.12) * CFrame.Angles(math.rad(25), 0, 0), rgb(170, 20, 40), M.Fabric)
		end
		part("Pommel", Vector3.new(0.18, 0.22, 0.08), CFrame.new(0, 0, 0.48), rgb(200, 160, 60), M.Metal)
		part("Tsuba", Vector3.new(0.4, 0.06, 0.4), CFrame.new(0, 0, -0.48) * CFrame.Angles(math.rad(90), 0, 0), rgb(200, 160, 60), M.Metal, Enum.PartType.Cylinder)
		local glow = rgb(255, 60, 40)
		part("Core", Vector3.new(0.04, 0.12, 2.1), CFrame.new(0, 0.02, -1.55), rgb(255, 230, 200), M.Neon)
		part("Blade", Vector3.new(0.06, 0.2, 2.1), CFrame.new(0, 0.02, -1.55), glow, M.Neon).Transparency = 0.35
		wedge("Tip", Vector3.new(0.06, 0.2, 0.3), CFrame.new(0, 0.02, -2.75) * CFrame.Angles(0, math.rad(180), 0), glow, M.Neon)
		local light = Instance.new("PointLight")
		light.Color = glow
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = handle
	else
		handle = part("Handle", Vector3.new(0.18, 0.25, 0.7), CFrame.new(), rgb(25, 25, 28), M.SmoothPlastic)
		for i = -2, 2 do
			part("Grip", Vector3.new(0.19, 0.26, 0.04), CFrame.new(0, 0, i * 0.12), rgb(40, 40, 44), M.Rubber)
		end
		part("Guard", Vector3.new(0.2, 0.34, 0.05), CFrame.new(0, 0.02, -0.38), rgb(60, 60, 64), M.Metal)
		part("Blade", Vector3.new(0.05, 0.25, 0.9), CFrame.new(0, 0.02, -0.85), steel, M.Metal)
		part("Serrations", Vector3.new(0.055, 0.05, 0.4), CFrame.new(0, 0.13, -0.62), rgb(150, 155, 162), M.DiamondPlate)
		wedge("Tip", Vector3.new(0.05, 0.25, 0.3), CFrame.new(0, 0.02, -1.45) * CFrame.Angles(0, math.rad(180), 0), steel, M.Metal)
	end

	model.PrimaryPart = handle
	for _, p in parts do
		if p ~= handle then
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = handle
		end
	end
	return model
end

return Knives
