local Util = {}

function Util.Comma(n: number): string
	local s = tostring(math.floor(n))
	local formatted, k = s, 0
	repeat
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return formatted
end

function Util.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Util.DeepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = Util.DeepCopy(v)
	end
	return out
end

-- Fills in any keys missing from `data` with defaults (for data migrations).
function Util.Reconcile(data, defaults)
	for k, v in defaults do
		if data[k] == nil then
			data[k] = Util.DeepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" then
			Util.Reconcile(data[k], v)
		end
	end
	return data
end

-- Finds the Humanoid that owns a hit part (handles accessories too).
function Util.HumanoidFromPart(part: Instance?)
	local current = part
	while current and current ~= workspace do
		local hum = current:FindFirstChildOfClass("Humanoid")
		if hum then
			return hum, current
		end
		current = current.Parent
	end
	return nil
end

return Util
