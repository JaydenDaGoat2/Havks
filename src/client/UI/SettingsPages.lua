--[[
	SettingsPages
	Builds one tab per schema category, plus the trainer stats and keybind helpers.
	Adding a setting to SettingsSchema automatically adds its control here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Schema = require(Shared:WaitForChild("SettingsSchema"))
local ShotEvents = require(Shared:WaitForChild("ShotEvents"))

local Controllers = script.Parent.Parent.Controllers
local Settings = require(Controllers.SettingsController)
local Keybinds = require(Controllers.KeybindController)
local Notifications = require(Controllers.NotificationController)
local ShotTrainer = require(script.Parent.Parent.Tools.ShotTrainer)
local Components = require(script.Parent.Components)

local SettingsPages = {}

local POSITION_NAMES = {
	PG = "Point Guard", SG = "Shooting Guard", SF = "Small Forward", PF = "Power Forward", C = "Center",
	TopRight = "Top right", BottomRight = "Bottom right", TopLeft = "Top left", BottomLeft = "Bottom left",
}

local function buildControl(page: Instance, def)
	local opts = {
		Label = def.label,
		Description = def.description,
		Value = Settings:Get(def.key),
		OnChanged = function(value)
			if def.type == "keybind" then
				local ok, reason = Keybinds:CanAssign(def.key, value)
				if not ok then
					Notifications:Notify({ Title = "Keybind not changed", Text = reason, Type = "Warning" })
					return false
				end
			end
			local ok = Settings:Set(def.key, value)
			if not ok then
				Notifications:Notify({ Title = "Invalid value", Text = def.label .. " was not changed.", Type = "Error" })
			end
			return ok
		end,
	}

	local control
	if def.type == "boolean" then
		control = Components.Toggle(page, opts)
	elseif def.type == "number" then
		opts.Min, opts.Max, opts.Step, opts.Format = def.min, def.max, def.step, def.format
		control = Components.Slider(page, opts)
	elseif def.type == "enum" then
		opts.Options = def.options
		opts.Display = function(option)
			return POSITION_NAMES[option] or option
		end
		control = Components.Selector(page, opts)
	elseif def.type == "color" then
		control = Components.ColorPicker(page, opts)
	elseif def.type == "keybind" then
		opts.Capture = function(callback)
			Keybinds:Capture(callback)
		end
		control = Components.Keybind(page, opts)
	else
		warn("[SettingsPages] No control for type " .. tostring(def.type))
		return
	end

	local connection = Settings.Changed:Connect(function(key, value)
		if key == def.key then
			control:Set(value)
		end
	end)
	control.Instance.Destroying:Connect(function()
		connection:Disconnect()
	end)
end

local function buildTrainerStats(page: Instance)
	Components.Section(page, "Session stats")
	local rows = {
		FG = Components.Stat(page, { Label = "Field goals" }),
		Perfect = Components.Stat(page, { Label = "Perfect releases" }),
		Avg = Components.Stat(page, { Label = "Average timing error" }),
		Streak = Components.Stat(page, { Label = "Perfect streak (best)" }),
	}

	local function render(stats)
		rows.FG:Set(("%d / %d  (%.0f%%)"):format(stats.Makes, stats.Attempts, stats.FieldGoalPct))
		rows.Perfect:Set(("%d  (%.0f%%)"):format(stats.Perfect, stats.PerfectPct))
		rows.Avg:Set(stats.Attempts > 0 and ("±%d ms"):format(math.floor(stats.AvgErrorMs + 0.5)) or "—")
		rows.Streak:Set(("%d  (%d)"):format(stats.Streak, stats.BestStreak))
	end
	render(ShotTrainer:GetStats())
	ShotTrainer.StatsChanged:Connect(render)

	Components.Button(page, {
		Label = "Reset session stats",
		Text = "Reset",
		OnClick = function()
			ShotTrainer:Reset()
			Notifications:Notify({ Title = "Stats reset", Text = "Session stats cleared.", Type = "Success" })
		end,
	})

	-- Studio-only: feeds sample reports into the trainer so you can test the HUD
	-- before your shooting system is wired up to ShotEvents.
	if RunService:IsStudio() then
		Components.Section(page, "Studio testing")
		Components.Button(page, {
			Label = "Send sample shot",
			Description = "Studio only · tests the HUD with fake data",
			Text = "Send",
			OnClick = function()
				local timing = math.random(-120, 120)
				ShotEvents.Report({ timingMs = timing, windowMs = 30, made = math.abs(timing) < 60, shotType = "Sample" })
			end,
		})
	end
end

function SettingsPages.Build(window)
	for _, category in ipairs(Schema.Categories) do
		local page = window:AddTab(category)
		Components.Section(page, category)

		for _, def in ipairs(Schema.InCategory(category)) do
			buildControl(page, def)
		end

		if category == "Trainer" then
			buildTrainerStats(page)
		end

		Components.Section(page, "")
		Components.Button(page, {
			Label = "Reset " .. string.lower(category) .. " settings",
			Text = "Reset",
			OnClick = function()
				Settings:ResetCategory(category)
				Notifications:Notify({ Title = "Defaults restored", Text = category .. " settings were reset.", Type = "Info" })
			end,
		})
	end
end

return SettingsPages
