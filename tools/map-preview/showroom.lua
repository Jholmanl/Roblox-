local ROOT = ARGS[2]
local MapKit = require({ __module = ROOT .. "/src/server/Maps/MapKit.lua" })
local GunBuilder = require({ __module = ROOT .. "/src/shared/GunBuilder.lua" })
local CarBuilder = require({ __module = ROOT .. "/src/shared/CarBuilder.lua" })
local Weapons = require({ __module = ROOT .. "/src/shared/Weapons.lua" })
local Achievements = require({ __module = ROOT .. "/src/shared/Achievements.lua" })
print("achievements:", #Achievements.List, "weapons:", #Weapons.Order)
local cats = {}
for _, a in Achievements.List do cats[a.Category] = (cats[a.Category] or 0) + 1 end
for k, v in cats do print("  ", k, v) end
return {
	Name = "SHOWROOM", Lighting = { ClockTime = 14 },
	Build = function()
		local kit = MapKit.new(1)
		local M = Enum.Material
		kit:Part(Vector3.new(120, 1, 70), CFrame.new(0, -0.5, 0), Color3.fromRGB(36, 40, 50), M.Concrete)
		for x = -50, 50, 10 do kit:Neon(Vector3.new(0.2, 0.05, 70), CFrame.new(x, 0.03, 0), Color3.fromRGB(0, 204, 255)) end
		-- gun racks
		local n = #Weapons.Order
		for i, id in Weapons.Order do
			local row = (i - 1) // 9
			local col = (i - 1) % 9
			local x = -40 + col * 10
			local z = -26 + row * 9
			kit:Part(Vector3.new(6.5, 3, 4), CFrame.new(x, 1.5, z), Color3.fromRGB(200, 202, 208), M.SmoothPlastic)
			kit:Neon(Vector3.new(6.6, 0.15, 0.2), CFrame.new(x, 3, z + 2), Color3.fromRGB(255, 198, 26))
			local gun = GunBuilder.Build(id, id == "Railgun")
			gun:PivotTo(CFrame.new(x, 4.4, z) * CFrame.Angles(0, math.rad(-90), 0))
			gun.Parent = kit.Props
		end
		local styles = { "Sedan", "Sports", "Jeep", "Truck" }
		for i, st in styles do
			local car = CarBuilder.Build(st, nil, true)
			car:PivotTo(CFrame.new(-36 + (i - 1) * 24, 0, 16) * CFrame.Angles(0, math.rad(200), 0))
			car.Parent = kit.Props
		end
		kit:Spawn(Vector3.new(0, 4, 34), Vector3.new(0, 4, 0))
		return kit
	end,
}
