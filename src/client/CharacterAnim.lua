-- Third-person gun gestures for OTHER characters (players and bots), done by
-- offsetting the arm/torso joints on each client (no uploaded animations needed):
--   * Reload: tilt the gun, support hand drops the mag, grabs a new one from the
--     belt, seats it, then racks the charging handle; head follows the gun.
--   * Recoil: a quick upward arm kick on every shot.
-- Works on R15 and R6 rigs. Joint C0 changes are local to this client.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GunAudio = require(script.Parent.GunAudio)

local player = Players.LocalPlayer
local CharacterAnim = {}

local rad = math.rad

-- keyframes: { t, rightShoulder {x,y,z}, leftShoulder {x,y,z}, leftElbow x, waist y, neck x }
local RELOAD_KEYS = {
	{ 0.00, { 0, 0, 0 }, { 0, 0, 0 }, 0, 0, 0 },
	{ 0.14, { -10, 0, 22 }, { -25, 0, -10 }, -30, 8, -12 }, -- tilt gun, hand to mag
	{ 0.30, { -10, 0, 22 }, { 25, 0, -18 }, -10, 8, -16 }, -- pull mag out, arm drops
	{ 0.45, { -8, 0, 18 }, { 40, 0, -35 }, -55, 10, -14 }, -- reach to belt pouch
	{ 0.60, { -10, 0, 22 }, { 5, 0, -12 }, -25, 8, -16 }, -- bring new mag up
	{ 0.70, { -12, 0, 24 }, { -30, 0, -8 }, -35, 6, -14 }, -- seat it (push up)
	{ 0.80, { -4, 0, 10 }, { -70, 0, -20 }, -60, 4, -8 }, -- hand to charging handle
	{ 0.88, { -4, 0, 10 }, { -55, 0, -28 }, -95, 2, -6 }, -- pull it back
	{ 1.00, { 0, 0, 0 }, { 0, 0, 0 }, 0, 0, 0 },
}

local active = {} -- [character] = { Joints, Base, Start, Duration, Kick, KickAt }

local function joints(character: Model)
	local function find(names)
		for _, n in names do
			local m = character:FindFirstChild(n, true)
			if m and m:IsA("Motor6D") then
				return m
			end
		end
		return nil
	end
	return {
		RS = find({ "RightShoulder", "Right Shoulder" }),
		LS = find({ "LeftShoulder", "Left Shoulder" }),
		LE = find({ "LeftElbow" }),
		Waist = find({ "Waist" }),
		Neck = find({ "Neck" }),
	}
end

local function state(character: Model)
	local st = active[character]
	if st then
		return st
	end
	local j = joints(character)
	if not j.RS then
		return nil
	end
	local base = {}
	for k, m in j do
		base[k] = m.C0
	end
	st = { Joints = j, Base = base, Start = 0, Duration = 0, KickAt = -10 }
	active[character] = st
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			active[character] = nil
		end
	end)
	return st
end

local function sample(r: number)
	for i = 1, #RELOAD_KEYS - 1 do
		local a, b = RELOAD_KEYS[i], RELOAD_KEYS[i + 1]
		if r >= a[1] and r <= b[1] then
			local u = (r - a[1]) / math.max(0.001, b[1] - a[1])
			u = u * u * (3 - 2 * u)
			local function v3(x, y)
				return { x[1] + (y[1] - x[1]) * u, x[2] + (y[2] - x[2]) * u, x[3] + (y[3] - x[3]) * u }
			end
			return v3(a[2], b[2]), v3(a[3], b[3]), a[4] + (b[4] - a[4]) * u, a[5] + (b[5] - a[5]) * u, a[6] + (b[6] - a[6]) * u
		end
	end
	return { 0, 0, 0 }, { 0, 0, 0 }, 0, 0, 0
end

function CharacterAnim.Reload(character: Model?, weaponId: string, duration: number)
	if not character or character == player.Character then
		return
	end
	local st = state(character)
	if not st then
		return
	end
	st.Start = os.clock()
	st.Duration = math.max(0.3, duration or 2)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and weaponId then
		GunAudio.Reload(weaponId, st.Duration, root.Position)
	end
end

function CharacterAnim.Recoil(character: Model?)
	if not character or character == player.Character then
		return
	end
	local st = state(character)
	if st then
		st.KickAt = os.clock()
	end
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for _, st in active do
		local j, base = st.Joints, st.Base
		local reloading = now - st.Start < st.Duration
		local kickT = now - st.KickAt
		local kick = kickT < 0.16 and (1 - kickT / 0.16) or 0
		if not reloading and kick == 0 then
			if not st.Rest then
				for k, m in j do
					if m and base[k] then
						m.C0 = base[k]
					end
				end
				st.Rest = true
			end
			continue
		end
		st.Rest = false
		local rs, ls, le, waist, neck = { 0, 0, 0 }, { 0, 0, 0 }, 0, 0, 0
		if reloading then
			rs, ls, le, waist, neck = sample((now - st.Start) / st.Duration)
		end
		if j.RS then
			j.RS.C0 = base.RS * CFrame.Angles(rad(rs[1] + 14 * kick), rad(rs[2]), rad(rs[3]))
		end
		if j.LS then
			j.LS.C0 = base.LS * CFrame.Angles(rad(ls[1] + 10 * kick), rad(ls[2]), rad(ls[3]))
		end
		if j.LE then
			j.LE.C0 = base.LE * CFrame.Angles(rad(le), 0, 0)
		end
		if j.Waist then
			j.Waist.C0 = base.Waist * CFrame.Angles(rad(-3 * kick), rad(waist), 0)
		end
		if j.Neck then
			j.Neck.C0 = base.Neck * CFrame.Angles(rad(neck), 0, 0)
		end
	end
end)

return CharacterAnim
