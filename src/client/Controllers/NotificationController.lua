--[[
	NotificationController
	Animated toast notifications.

	    Notifications:Notify({ Title = "Saved", Text = "Settings updated", Type = "Success" })

	Types: Info (accent color), Success, Warning, Error
]]

local TweenService = game:GetService("TweenService")

local Settings = require(script.Parent.SettingsController)
local Theme = require(script.Parent.ThemeController)
local Anim = require(script.Parent.Parent.UI.Anim)
local Components = require(script.Parent.Parent.UI.Components)

local create = Components.Create

local MAX_VISIBLE = 5
local CARD_HEIGHT = 64
local WIDTH = 300

local NotificationController = {}

local container: Frame
local layout: UIListLayout
local active: { Frame } = {}
local dismissed: { [Frame]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local order = 0
local fromLeft = false

local POSITIONS = {
	TopRight = { Vector2.new(1, 0), UDim2.new(1, -12, 0, 12), Enum.VerticalAlignment.Top, false },
	BottomRight = { Vector2.new(1, 1), UDim2.new(1, -12, 1, -12), Enum.VerticalAlignment.Bottom, false },
	TopLeft = { Vector2.new(0, 0), UDim2.new(0, 12, 0, 12), Enum.VerticalAlignment.Top, true },
	BottomLeft = { Vector2.new(0, 1), UDim2.new(0, 12, 1, -12), Enum.VerticalAlignment.Bottom, true },
}

local function offscreen(): UDim2
	return UDim2.fromScale(fromLeft and -1.15 or 1.15, 0)
end

local function dismiss(holder: Frame)
	if dismissed[holder] then
		return
	end
	dismissed[holder] = true

	local index = table.find(active, holder)
	if index then
		table.remove(active, index)
	end

	local card = holder:FindFirstChild("Card")
	if card then
		Anim.Tween(card, { Position = offscreen() }, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	end
	task.delay(Anim.Duration(0.25), function()
		Anim.Tween(holder, { Size = UDim2.new(1, 0, 0, 0) }, 0.15)
		task.delay(Anim.Duration(0.15), function()
			holder:Destroy()
		end)
	end)
end

function NotificationController:Init(gui: ScreenGui)
	container = create("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, WIDTH, 1, -24),
		ZIndex = 50,
		Parent = gui,
	})
	layout = create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = container,
	})
	create("UIScale", { Parent = container }) -- kept in sync with the UIScale setting

	Settings:Observe("NotificationPosition", function(name)
		local position = POSITIONS[name] or POSITIONS.TopRight
		container.AnchorPoint = position[1]
		container.Position = position[2]
		layout.VerticalAlignment = position[3]
		fromLeft = position[4]
	end)
	Settings:Observe("UIScale", function(scale)
		(container:FindFirstChildOfClass("UIScale") :: UIScale).Scale = scale
	end)
end

function NotificationController:Notify(opts: { Title: string?, Text: string?, Type: string?, Duration: number?, Force: boolean? })
	if not container then
		return
	end
	if not Settings:Get("NotificationsEnabled") and not opts.Force then
		return
	end

	local duration = opts.Duration or Settings:Get("NotificationDuration")
	local color = Theme.Status[opts.Type or "Info"] or Theme.Get("Accent")
	order += 1

	local holder = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
		LayoutOrder = order,
		ClipsDescendants = false,
		Parent = container,
	})

	local card = create("TextButton", {
		Name = "Card",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		Position = offscreen(),
		ClipsDescendants = true,
		Parent = holder,
	}, { Components.Corner(8) })
	Theme.Bind(card, "BackgroundColor3", "Surface")
	Components.Stroke(card)

	create("Frame", { -- accent bar
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = card,
	})

	Components.Label(card, opts.Title or "Notice", {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -28, 0, 18),
		Font = Enum.Font.GothamBold,
	})
	Components.Label(card, opts.Text or "", {
		Position = UDim2.fromOffset(16, 28),
		Size = UDim2.new(1, -28, 0, 28),
		TextSize = 12,
		Font = Enum.Font.Gotham,
		Token = "SubText",
		Wrapped = true,
		AlignY = Enum.TextYAlignment.Top,
	})

	local progress = create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = card,
	})

	Anim.Tween(card, { Position = UDim2.fromScale(0, 0) }, 0.35)
	-- The countdown bar is a timer, so it is not affected by animation settings.
	TweenService:Create(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()

	card.MouseButton1Click:Connect(function()
		dismiss(holder)
	end)

	table.insert(active, holder)
	while #active > MAX_VISIBLE do
		dismiss(active[1])
	end

	task.delay(duration, function()
		if holder.Parent then
			dismiss(holder)
		end
	end)
end

return NotificationController
