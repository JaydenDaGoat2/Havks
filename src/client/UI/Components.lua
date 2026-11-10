--[[
	Components
	Reusable, theme-aware UI controls. Each control returns { Instance, Set = function(self, value) }.
	Controls never own state: they call opts.OnChanged(newValue) and wait for Set() to be
	called back, so the SettingsController remains the single source of truth.
]]

local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.Controllers.ThemeController)
local Anim = require(script.Parent.Anim)

local Components = {}

local layoutCounter = 0
local function nextOrder(): number
	layoutCounter += 1
	return layoutCounter
end

function Components.Create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			(instance :: any)[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end
local create = Components.Create

function Components.Corner(radius: number?)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function Components.Padding(all: number, right: number?)
	return create("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, right or all),
	})
end

function Components.Stroke(parent: Instance)
	local stroke = create("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
	Theme.Bind(stroke, "Color", "Stroke")
	return stroke
end

function Components.Label(parent: Instance, text: string, opts: { [string]: any }?)
	local o = opts or {}
	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Font = o.Font or Enum.Font.GothamMedium,
		TextSize = o.TextSize or 14,
		TextXAlignment = o.Align or Enum.TextXAlignment.Left,
		TextYAlignment = o.AlignY or Enum.TextYAlignment.Center,
		TextWrapped = o.Wrapped or false,
		TextTruncate = o.Wrapped and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd,
		Size = o.Size or UDim2.new(1, 0, 0, 20),
		Position = o.Position or UDim2.new(),
		AnchorPoint = o.AnchorPoint or Vector2.zero,
		LayoutOrder = o.LayoutOrder or 0,
		Parent = parent,
	})
	Theme.Bind(label, "TextColor3", o.Token or "Text")
	return label
end

local function smallButton(parent: Instance, text: string, props: { [string]: any })
	local button = create("TextButton", {
		Text = text,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		Parent = parent,
	}, { Components.Corner(6) })
	for key, value in pairs(props) do
		(button :: any)[key] = value
	end
	Theme.Bind(button, "BackgroundColor3", "SurfaceAlt")
	Theme.Bind(button, "TextColor3", "Text")

	button.MouseEnter:Connect(function()
		Anim.Tween(button, { BackgroundTransparency = 0.25 }, 0.12)
	end)
	button.MouseLeave:Connect(function()
		Anim.Tween(button, { BackgroundTransparency = 0 }, 0.12)
	end)
	return button
end

-- Connects to a global input signal and cleans up when the owner is destroyed.
local function connectUntilDestroyed(owner: Instance, signal: RBXScriptSignal, fn: (...any) -> ())
	local connection = signal:Connect(fn)
	owner.Destroying:Connect(function()
		connection:Disconnect()
	end)
end

local function isPointerDown(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

--- A settings row: label (and optional description) on the left, control area on the right.
local function row(parent: Instance, label: string, description: string?)
	local height = description and 50 or 40
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = nextOrder(),
		Parent = parent,
	}, { Components.Corner(8) })
	Theme.Bind(frame, "BackgroundColor3", "Surface")

	Components.Label(frame, label, {
		Position = UDim2.fromOffset(12, description and 7 or 10),
		Size = UDim2.new(0.5, -12, 0, 20),
	})
	if description then
		Components.Label(frame, description, {
			Position = UDim2.fromOffset(12, 27),
			Size = UDim2.new(0.5, -12, 0, 16),
			TextSize = 12,
			Font = Enum.Font.Gotham,
			Token = "SubText",
		})
	end
	return frame
end

local function rightAnchored(parent: Instance, width: number, height: number, className: string?)
	return create(className or "Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(width, height),
		Parent = parent,
	})
end

---------------------------------------------------------------------------
-- Section header
---------------------------------------------------------------------------
function Components.Section(parent: Instance, title: string)
	return Components.Label(parent, string.upper(title), {
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		Token = "SubText",
		AlignY = Enum.TextYAlignment.Bottom,
		LayoutOrder = nextOrder(),
	})
end

---------------------------------------------------------------------------
-- Toggle
---------------------------------------------------------------------------
function Components.Toggle(parent: Instance, opts)
	local frame = row(parent, opts.Label, opts.Description)
	local value = opts.Value == true

	local track = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(44, 24),
		Parent = frame,
	}, { Components.Corner(12) })

	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = track,
	}, { Components.Corner(9) })

	local function render(animate: boolean)
		local color = value and Theme.Get("Accent") or Theme.Get("SurfaceAlt")
		local position = value and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		if animate then
			Anim.Tween(track, { BackgroundColor3 = color }, 0.18)
			Anim.Tween(knob, { Position = position }, 0.18)
		else
			track.BackgroundColor3 = color
			knob.Position = position
		end
	end
	Theme.OnChanged(frame, function()
		render(false)
	end)

	track.MouseButton1Click:Connect(function()
		opts.OnChanged(not value)
	end)

	return {
		Instance = frame,
		Set = function(_, newValue: boolean)
			if newValue ~= value then
				value = newValue
				render(true)
			end
		end,
	}
end

---------------------------------------------------------------------------
-- Slider
---------------------------------------------------------------------------
function Components.Slider(parent: Instance, opts)
	local frame = row(parent, opts.Label, opts.Description)
	local value = opts.Value
	local min, max, step = opts.Min, opts.Max, opts.Step or 0

	local holder = rightAnchored(frame, 210, 24)
	local valueLabel = Components.Label(holder, "", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 2),
		Size = UDim2.fromOffset(62, 20),
		Align = Enum.TextXAlignment.Right,
		TextSize = 13,
	})

	local track = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, -72, 0, 6),
		Parent = holder,
	}, { Components.Corner(3) })
	Theme.Bind(track, "BackgroundColor3", "SurfaceAlt")

	local fill = create("Frame", { Size = UDim2.fromScale(0, 1), Parent = track }, { Components.Corner(3) })
	Theme.Bind(fill, "BackgroundColor3", "Accent")

	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = track,
	}, { Components.Corner(7) })

	local function format(v: number): string
		if opts.Format then
			return string.format(opts.Format, v)
		end
		return tostring(v)
	end

	local function render()
		local alpha = math.clamp((value - min) / (max - min), 0, 1)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		valueLabel.Text = format(value)
	end
	render()

	local dragging = false
	local function updateFromX(x: number)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local raw = min + alpha * (max - min)
		if step > 0 then
			raw = min + math.floor((raw - min) / step + 0.5) * step
		end
		raw = math.floor(raw * 10000 + 0.5) / 10000
		if raw ~= value then
			opts.OnChanged(raw)
		end
	end

	track.InputBegan:Connect(function(input)
		if isPointerDown(input) then
			dragging = true
			updateFromX(input.Position.X)
		end
	end)
	connectUntilDestroyed(frame, UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromX(input.Position.X)
		end
	end)
	connectUntilDestroyed(frame, UserInputService.InputEnded, function(input)
		if isPointerDown(input) then
			dragging = false
		end
	end)

	return {
		Instance = frame,
		Set = function(_, newValue: number)
			value = newValue
			render()
		end,
	}
end

---------------------------------------------------------------------------
-- Selector (cycles through a list of options; works well on touch)
---------------------------------------------------------------------------
function Components.Selector(parent: Instance, opts)
	local frame = row(parent, opts.Label, opts.Description)
	local options = opts.Options
	local index = table.find(options, opts.Value) or 1

	local holder = rightAnchored(frame, 170, 26)
	local prev = smallButton(holder, "‹", { Size = UDim2.fromOffset(26, 26), TextSize = 18 })
	local nextButton = smallButton(holder, "›", {
		Size = UDim2.fromOffset(26, 26),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		TextSize = 18,
	})
	local valueLabel = Components.Label(holder, "", {
		Position = UDim2.fromOffset(30, 3),
		Size = UDim2.new(1, -60, 0, 20),
		Align = Enum.TextXAlignment.Center,
		TextSize = 13,
	})

	local function display(option: string): string
		return opts.Display and opts.Display(option) or option
	end
	local function render()
		valueLabel.Text = display(options[index])
	end
	render()

	prev.MouseButton1Click:Connect(function()
		opts.OnChanged(options[(index - 2) % #options + 1])
	end)
	nextButton.MouseButton1Click:Connect(function()
		opts.OnChanged(options[index % #options + 1])
	end)

	return {
		Instance = frame,
		Set = function(_, newValue: string)
			index = table.find(options, newValue) or index
			render()
			valueLabel.Position = UDim2.fromOffset(30, 7)
			Anim.Tween(valueLabel, { Position = UDim2.fromOffset(30, 3) }, 0.15)
		end,
	}
end

---------------------------------------------------------------------------
-- Keybind button
---------------------------------------------------------------------------
function Components.Keybind(parent: Instance, opts)
	local frame = row(parent, opts.Label, opts.Description)
	local value = opts.Value
	local capturing = false

	local button = smallButton(frame, value, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(120, 26),
	})

	local function render()
		button.Text = capturing and "Press a key…" or value
		Theme.Bind(button, "TextColor3", capturing and "Accent" or "Text")
	end

	button.MouseButton1Click:Connect(function()
		if capturing then
			return
		end
		capturing = true
		render()
		opts.Capture(function(keyName: string?)
			capturing = false
			if keyName then
				opts.OnChanged(keyName)
			end
			render()
		end)
	end)

	return {
		Instance = frame,
		Set = function(_, newValue: string)
			value = newValue
			render()
		end,
	}
end

---------------------------------------------------------------------------
-- Color picker (preset swatches + hex input)
---------------------------------------------------------------------------
local SWATCHES = { "#F97316", "#EF4444", "#22C55E", "#06B6D4", "#3B82F6", "#8B5CF6" }

function Components.ColorPicker(parent: Instance, opts)
	local frame = row(parent, opts.Label, opts.Description)
	local value = opts.Value

	local holder = rightAnchored(frame, 220, 24)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
		Parent = holder,
	})

	local swatchStrokes = {}
	for index, hex in ipairs(SWATCHES) do
		local swatch = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = Color3.fromHex(hex),
			LayoutOrder = index,
			Parent = holder,
		}, { Components.Corner(9) })
		swatchStrokes[hex] = create("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Enabled = false, Parent = swatch })
		swatch.MouseButton1Click:Connect(function()
			opts.OnChanged(hex)
		end)
	end

	local box = create("TextBox", {
		Size = UDim2.fromOffset(74, 24),
		Font = Enum.Font.Code,
		TextSize = 13,
		ClearTextOnFocus = false,
		LayoutOrder = #SWATCHES + 1,
		Parent = holder,
	}, { Components.Corner(6) })
	Theme.Bind(box, "BackgroundColor3", "SurfaceAlt")
	Theme.Bind(box, "TextColor3", "Text")

	local function render()
		box.Text = value
		for hex, stroke in pairs(swatchStrokes) do
			stroke.Enabled = hex == value
		end
	end
	render()

	box.FocusLost:Connect(function()
		local text = box.Text:gsub("%s", ""):upper()
		if text:sub(1, 1) ~= "#" then
			text = "#" .. text
		end
		if not opts.OnChanged(text) then
			render() -- invalid input: restore the current value
		end
	end)

	return {
		Instance = frame,
		Set = function(_, newValue: string)
			value = newValue
			render()
		end,
	}
end

---------------------------------------------------------------------------
-- Action button row
---------------------------------------------------------------------------
function Components.Button(parent: Instance, opts)
	local frame = row(parent, opts.Label, opts.Description)
	local button = smallButton(frame, opts.Text or "Run", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(120, 26),
	})
	button.MouseButton1Click:Connect(opts.OnClick)
	return { Instance = frame, Button = button }
end

---------------------------------------------------------------------------
-- Read-only stat row
---------------------------------------------------------------------------
function Components.Stat(parent: Instance, opts)
	local frame = row(parent, opts.Label, opts.Description)
	local valueLabel = Components.Label(frame, tostring(opts.Value or "—"), {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(160, 20),
		Align = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBold,
	})
	return {
		Instance = frame,
		Set = function(_, newValue: any)
			valueLabel.Text = tostring(newValue)
		end,
	}
end

Components.ConnectUntilDestroyed = connectUntilDestroyed
Components.IsPointerDown = isPointerDown

return Components
