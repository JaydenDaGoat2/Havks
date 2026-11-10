--[[
	TrainerHud
	On-screen release feedback: rating, timing offset, a timing bar with recent
	releases, and a one-line session summary.
]]

local Settings = require(script.Parent.Parent.Controllers.SettingsController)
local Theme = require(script.Parent.Parent.Controllers.ThemeController)
local ShotTrainer = require(script.Parent.Parent.Tools.ShotTrainer)
local Anim = require(script.Parent.Anim)
local Components = require(script.Parent.Components)

local create = Components.Create

local RANGE_MS = 200 -- the bar spans -RANGE_MS (early) .. +RANGE_MS (late)
local DEFAULT_WINDOW_MS = 30

local RATING_COLORS = {
	Perfect = Theme.Status.Success,
	Good = Theme.Status.Good,
	Early = Theme.Status.Warning,
	Late = Theme.Status.Error,
}

local TrainerHud = {}
TrainerHud.__index = TrainerHud

local function timingToX(timingMs: number): number
	return 0.5 + math.clamp(timingMs / RANGE_MS, -1, 1) * 0.5
end

function TrainerHud.new(gui: ScreenGui)
	local self = setmetatable({ _markers = {} }, TrainerHud)

	local root = create("Frame", {
		Name = "ShotTrainer",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(420, 100),
		BackgroundTransparency = 0.08,
		Parent = gui,
	}, { Components.Corner(10) })
	Theme.Bind(root, "BackgroundColor3", "Surface")
	Components.Stroke(root)
	local scale = create("UIScale", { Parent = root })
	self.Root = root

	self._rating = Components.Label(root, "Waiting for a shot…", {
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(0.6, 0, 0, 24),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
	})
	self._offset = Components.Label(root, "", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 12),
		Size = UDim2.new(0.4, -14, 0, 20),
		Align = Enum.TextXAlignment.Right,
		Token = "SubText",
		TextSize = 13,
	})

	local bar = create("Frame", {
		Position = UDim2.fromOffset(14, 44),
		Size = UDim2.new(1, -28, 0, 12),
		ClipsDescendants = false,
		Parent = root,
	}, { Components.Corner(6) })
	Theme.Bind(bar, "BackgroundColor3", "SurfaceAlt")
	self._bar = bar

	self._zone = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(DEFAULT_WINDOW_MS / RANGE_MS, 1),
		BackgroundColor3 = Theme.Status.Success,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Parent = bar,
	})
	create("Frame", { -- center line
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 2, 1, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = bar,
	})
	Components.Label(root, "EARLY", {
		Position = UDim2.fromOffset(14, 58), Size = UDim2.fromOffset(60, 12),
		TextSize = 10, Token = "SubText", Font = Enum.Font.GothamBold,
	})
	Components.Label(root, "LATE", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 58), Size = UDim2.fromOffset(60, 12),
		TextSize = 10, Token = "SubText", Font = Enum.Font.GothamBold, Align = Enum.TextXAlignment.Right,
	})

	self._stats = Components.Label(root, "", {
		Position = UDim2.fromOffset(14, 74),
		Size = UDim2.new(1, -28, 0, 18),
		TextSize = 12,
		Font = Enum.Font.Gotham,
		Token = "SubText",
	})

	-- Settings --------------------------------------------------------------
	Settings:Observe("TrainerEnabled", function(enabled)
		self:_setVisible(enabled)
	end)
	Settings:Observe("TrainerPosition", function(position)
		if position == "Top" then
			root.AnchorPoint = Vector2.new(0.5, 0)
			root.Position = UDim2.new(0.5, 0, 0, 16)
		else
			root.AnchorPoint = Vector2.new(0.5, 1)
			root.Position = UDim2.new(0.5, 0, 1, -120)
		end
	end)
	Settings:Observe("UIScale", function(value)
		scale.Scale = value
	end)
	Settings.Changed:Connect(function(key)
		if key == "TrainerShowHistory" or key == "TrainerHistorySize" then
			self:_renderMarkers()
		end
	end)

	-- Trainer events --------------------------------------------------------
	ShotTrainer.ShotRecorded:Connect(function(shot, rating)
		self:_renderShot(shot, rating)
	end)
	ShotTrainer.StatsChanged:Connect(function(stats)
		self:_renderStats(stats)
		if stats.Attempts == 0 then
			self._rating.Text = "Waiting for a shot…"
			Theme.Bind(self._rating, "TextColor3", "Text")
			self._offset.Text = ""
			self:_renderMarkers()
		end
	end)
	self:_renderStats(ShotTrainer:GetStats())

	return self
end

function TrainerHud:_setVisible(visible: boolean)
	local root = self.Root
	if visible then
		root.Visible = true
		Anim.Tween(root, { BackgroundTransparency = 0.08 }, 0.2)
	else
		root.Visible = false
	end
end

function TrainerHud:_renderShot(shot, rating: string)
	local color = RATING_COLORS[rating] or Theme.Get("Accent")
	self._rating.Text = rating .. (shot.made and "  •  Made" or "  •  Missed")
	Theme.Unbind(self._rating, "TextColor3")
	self._rating.TextColor3 = color

	local ms = math.floor(math.abs(shot.timingMs) + 0.5)
	if ms == 0 then
		self._offset.Text = "On time · " .. shot.shotType
	else
		self._offset.Text = ("%d ms %s · %s"):format(ms, shot.timingMs < 0 and "early" or "late", shot.shotType)
	end

	self._zone.Size = UDim2.fromScale(math.clamp(shot.windowMs / RANGE_MS, 0.01, 1), 1)

	-- small "pop" on the rating text
	self._rating.TextSize = 22
	Anim.Tween(self._rating, { TextSize = 18 }, 0.25, Enum.EasingStyle.Back)

	self:_renderMarkers()
end

function TrainerHud:_renderMarkers()
	for _, marker in ipairs(self._markers) do
		marker:Destroy()
	end
	table.clear(self._markers)

	local shots = ShotTrainer:GetHistory()
	if not Settings:Get("TrainerShowHistory") then
		shots = { shots[#shots] }
	end

	local count = #shots
	for index, shot in ipairs(shots) do
		local newest = index == count
		local age = (count - index) / math.max(count, 1)
		local marker = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(timingToX(shot.timingMs), 0.5),
			Size = newest and UDim2.fromOffset(12, 12) or UDim2.fromOffset(7, 7),
			BackgroundColor3 = RATING_COLORS[shot.rating] or Color3.new(1, 1, 1),
			BackgroundTransparency = newest and 0 or 0.2 + age * 0.6,
			ZIndex = newest and 3 or 2,
			Parent = self._bar,
		}, { Components.Corner(6) })
		if newest then
			create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5, Parent = marker })
		end
		table.insert(self._markers, marker)
	end
end

function TrainerHud:_renderStats(stats)
	if stats.Attempts == 0 then
		self._stats.Text = "No shots yet this session"
		return
	end
	self._stats.Text = ("FG %d/%d (%.0f%%)  ·  Perfect %d (%.0f%%)  ·  Avg ±%d ms  ·  Streak %d"):format(
		stats.Makes,
		stats.Attempts,
		stats.FieldGoalPct,
		stats.Perfect,
		stats.PerfectPct,
		math.floor(stats.AvgErrorMs + 0.5),
		stats.Streak
	)
end

return TrainerHud
