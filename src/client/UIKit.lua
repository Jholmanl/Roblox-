-- Tiny UI helper library + the game's visual theme.
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sounds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sounds"))

local UIKit = {}

UIKit.Theme = {
	Bg = Color3.fromRGB(10, 12, 18),
	Panel = Color3.fromRGB(20, 23, 32),
	Panel2 = Color3.fromRGB(30, 34, 46),
	Panel3 = Color3.fromRGB(44, 49, 64),
	Text = Color3.fromRGB(255, 255, 255),
	Sub = Color3.fromRGB(150, 158, 176),
	Accent = Color3.fromRGB(255, 198, 26),
	Accent2 = Color3.fromRGB(0, 204, 255),
	Red = Color3.fromRGB(255, 64, 72),
	Green = Color3.fromRGB(70, 230, 120),
	Gold = Color3.fromRGB(255, 205, 60),
	Robux = Color3.fromRGB(0, 178, 110),
	Black = Enum.Font.GothamBlack,
	Bold = Enum.Font.GothamBold,
	Medium = Enum.Font.GothamMedium,
}
local T = UIKit.Theme

-- UIKit.new("Frame", { Size = ..., Parent = ... }, { children })
function UIKit.new(class: string, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in props or {} do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local new = UIKit.new

function UIKit.Corner(radius: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function UIKit.Stroke(color: Color3?, thickness: number?, transparency: number?)
	return new("UIStroke", {
		Color = color or Color3.new(1, 1, 1),
		Thickness = thickness or 1,
		Transparency = transparency or 0.85,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.TextStroke(transparency: number?)
	return new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Transparency = transparency or 0.4 })
end

function UIKit.Padding(all: number)
	local u = UDim.new(0, all)
	return new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function UIKit.List(padding: number?, horizontal: boolean?, align)
	return new("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

function UIKit.Gradient(top: Color3, bottom: Color3, rotation: number?)
	return new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90 })
end

function UIKit.Label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = T.Bold,
		TextColor3 = T.Text,
		TextSize = 16,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in props do
		defaults[k] = v
	end
	return new("TextLabel", defaults)
end

function UIKit.Panel(props, children)
	local defaults = {
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}
	for k, v in props do
		defaults[k] = v
	end
	local f = new("Frame", defaults, children)
	UIKit.Corner(8).Parent = f
	return f
end

function UIKit.Tween(inst: Instance, time: number, goal, style, direction)
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

function UIKit.Sound(name: string, pitch: number?)
	local info = Sounds[name]
	if not info then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = info.Id
	s.Volume = info.Volume
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(5, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- Big chunky button in the style of popular shooters.
function UIKit.Button(props, onClick)
	local color = props.Color or T.Accent
	local textColor = props.TextColor or (color == T.Accent and Color3.new(0, 0, 0) or T.Text)
	local btn = new("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(160, 44),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = props.Text or "",
		Font = props.Font or T.Black,
		TextSize = props.TextSize or 18,
		TextColor3 = textColor,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	UIKit.Corner(props.Radius or 6).Parent = btn
	local scale = new("UIScale", { Parent = btn })
	btn.MouseEnter:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1.04 })
		UIKit.Tween(btn, 0.12, { BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.15) })
	end)
	btn.MouseLeave:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1 })
		UIKit.Tween(btn, 0.12, { BackgroundColor3 = color })
	end)
	btn.MouseButton1Down:Connect(function()
		UIKit.Tween(scale, 0.06, { Scale = 0.96 })
	end)
	btn.MouseButton1Up:Connect(function()
		UIKit.Tween(scale, 0.1, { Scale = 1.04 })
	end)
	if onClick then
		btn.Activated:Connect(function()
			UIKit.Sound("Click")
			onClick()
		end)
	end
	return btn
end

function UIKit.SetButtonColor(btn: TextButton, color: Color3, textColor: Color3?)
	btn.BackgroundColor3 = color
	btn.TextColor3 = textColor or (color == T.Accent and Color3.new(0, 0, 0) or T.Text)
end

-- Horizontal progress bar. Returns frame, fill.
function UIKit.Bar(props)
	local frame = new("Frame", {
		Name = props.Name or "Bar",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.Back or Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = props.BackTransparency or 0.5,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	UIKit.Corner(props.Radius or 3).Parent = frame
	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(props.Value or 1, 1),
		BackgroundColor3 = props.Color or T.Accent,
		BorderSizePixel = 0,
		Parent = frame,
	})
	UIKit.Corner(props.Radius or 3).Parent = fill
	return frame, fill
end

return UIKit
