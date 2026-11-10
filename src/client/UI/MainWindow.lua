--[[
	MainWindow
	Draggable settings window with a tab sidebar and animated open/close.
]]

local UserInputService = game:GetService("UserInputService")

local Settings = require(script.Parent.Parent.Controllers.SettingsController)
local Theme = require(script.Parent.Parent.Controllers.ThemeController)
local Anim = require(script.Parent.Anim)
local Components = require(script.Parent.Components)

local create = Components.Create

local WIDTH, HEIGHT = 640, 420
local TOPBAR, SIDEBAR = 48, 150
local CLOSED_SCALE = 0.92

local MainWindow = {}
MainWindow.__index = MainWindow

function MainWindow.new(gui: ScreenGui, title: string)
	local self = setmetatable({ _tabs = {}, _open = false, _selected = nil }, MainWindow)

	local root = create("CanvasGroup", {
		Name = "SettingsWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	}, { Components.Corner(12) })
	Theme.Bind(root, "BackgroundColor3", "Background")
	self.Root = root

	-- Scale = player's UIScale setting x open/close animation factor.
	local uiScale = create("UIScale", { Parent = root })
	local animFactor = Instance.new("NumberValue")
	animFactor.Value = CLOSED_SCALE
	self._animFactor = animFactor
	local function applyScale()
		uiScale.Scale = Settings:Get("UIScale") * animFactor.Value
	end
	animFactor.Changed:Connect(applyScale)
	Settings:Observe("UIScale", applyScale)

	-- Top bar ---------------------------------------------------------------
	local topbar = create("Frame", { Size = UDim2.new(1, 0, 0, TOPBAR), BackgroundTransparency = 1, Parent = root })
	Components.Label(topbar, title, {
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.new(1, -80, 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
	})
	Components.Label(topbar, "Settings & tools", {
		Position = UDim2.fromOffset(18, 26),
		Size = UDim2.new(1, -80, 0, 16),
		TextSize = 12,
		Font = Enum.Font.Gotham,
		Token = "SubText",
	})
	local close = create("TextButton", {
		Text = "✕",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		Parent = topbar,
	}, { Components.Corner(6) })
	Theme.Bind(close, "BackgroundColor3", "Surface")
	Theme.Bind(close, "TextColor3", "SubText")
	close.MouseButton1Click:Connect(function()
		self:SetOpen(false)
	end)
	local divider = create("Frame", {
		Position = UDim2.fromOffset(0, TOPBAR - 1),
		Size = UDim2.new(1, 0, 0, 1),
		BorderSizePixel = 0,
		Parent = root,
	})
	Theme.Bind(divider, "BackgroundColor3", "Stroke")

	self:_makeDraggable(topbar)

	-- Sidebar & content -----------------------------------------------------
	local sidebar = create("Frame", {
		Position = UDim2.fromOffset(0, TOPBAR),
		Size = UDim2.new(0, SIDEBAR, 1, -TOPBAR),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		Components.Padding(10),
		create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	self._sidebar = sidebar

	self._content = create("Frame", {
		Position = UDim2.fromOffset(SIDEBAR, TOPBAR),
		Size = UDim2.new(1, -SIDEBAR, 1, -TOPBAR),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = root,
	})

	Theme.OnChanged(root, function()
		self:_renderTabs()
	end)

	return self
end

function MainWindow:_makeDraggable(handle: GuiObject)
	local dragging, dragStart, startPosition = false, nil, nil

	handle.InputBegan:Connect(function(input)
		if Components.IsPointerDown(input) then
			dragging = true
			dragStart = input.Position
			startPosition = self.Root.Position
		end
	end)
	Components.ConnectUntilDestroyed(handle, UserInputService.InputChanged, function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			self.Root.Position = UDim2.new(
				startPosition.X.Scale, startPosition.X.Offset + delta.X,
				startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
			)
		end
	end)
	Components.ConnectUntilDestroyed(handle, UserInputService.InputEnded, function(input)
		if Components.IsPointerDown(input) then
			dragging = false
		end
	end)
end

--- Adds a tab and returns its scrolling page to put controls in.
function MainWindow:AddTab(name: string): ScrollingFrame
	local button = create("TextButton", {
		Text = name,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = #self._tabs + 1,
		Parent = self._sidebar,
	}, {
		Components.Corner(8),
		create("UIPadding", { PaddingLeft = UDim.new(0, 14) }),
	})

	local indicator = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -14, 0.5, 0),
		Size = UDim2.fromOffset(3, 0),
		BorderSizePixel = 0,
		Parent = button,
	}, { Components.Corner(2) })
	Theme.Bind(indicator, "BackgroundColor3", "Accent")

	local page = create("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = self._content,
	}, {
		Components.Padding(12, 18),
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Theme.Bind(page, "ScrollBarImageColor3", "SubText")

	table.insert(self._tabs, { Name = name, Button = button, Indicator = indicator, Page = page })
	button.MouseButton1Click:Connect(function()
		self:SelectTab(name)
	end)

	if not self._selected then
		self:SelectTab(name)
	else
		self:_renderTabs()
	end
	return page
end

function MainWindow:_renderTabs()
	for _, tab in ipairs(self._tabs) do
		local selected = tab.Name == self._selected
		tab.Button.BackgroundColor3 = Theme.Get("Surface")
		tab.Button.BackgroundTransparency = selected and 0 or 1
		Theme.Bind(tab.Button, "TextColor3", selected and "Text" or "SubText")
		tab.Indicator.Size = UDim2.fromOffset(3, selected and 18 or 0)
	end
end

function MainWindow:SelectTab(name: string)
	if self._selected == name then
		return
	end
	self._selected = name
	for _, tab in ipairs(self._tabs) do
		local selected = tab.Name == name
		tab.Page.Visible = selected
		if selected then
			tab.Page.Position = UDim2.fromOffset(0, 10)
			Anim.Tween(tab.Page, { Position = UDim2.new() }, 0.22)
		end
	end
	self:_renderTabs()
end

function MainWindow:IsOpen(): boolean
	return self._open
end

function MainWindow:SetOpen(open: boolean)
	if self._open == open then
		return
	end
	self._open = open
	local root = self.Root

	if open then
		root.Visible = true
		Anim.Tween(root, { GroupTransparency = 0 }, 0.22)
		Anim.Tween(self._animFactor, { Value = 1 }, 0.3, Enum.EasingStyle.Back)
	else
		Anim.Tween(root, { GroupTransparency = 1 }, 0.18)
		Anim.Tween(self._animFactor, { Value = CLOSED_SCALE }, 0.18)
		task.delay(Anim.Duration(0.18), function()
			if not self._open then
				root.Visible = false
			end
		end)
	end
end

function MainWindow:Toggle()
	self:SetOpen(not self._open)
end

return MainWindow
