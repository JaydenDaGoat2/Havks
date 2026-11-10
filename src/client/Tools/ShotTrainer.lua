--[[
	ShotTrainer
	Practice feedback for the player's own shots. It listens to ShotEvents (reported by
	your game's shooting system *after* a release) and keeps session stats.
	It is read-only: it never presses inputs, times releases, or changes shot results.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShotEvents = require(Shared:WaitForChild("ShotEvents"))
local Signal = require(Shared:WaitForChild("Signal"))
local Settings = require(script.Parent.Parent.Controllers.SettingsController)

local MAX_STORED_HISTORY = 30

local ShotTrainer = {}
ShotTrainer.ShotRecorded = Signal.new() -- (shot, rating)
ShotTrainer.StatsChanged = Signal.new() -- (stats)

local history = {}
local stats = { Attempts = 0, Makes = 0, Perfect = 0, TotalAbsErrorMs = 0, BestStreak = 0, Streak = 0 }

--- Rates a release. Perfect = inside the game's window, Good = within 3x the window.
function ShotTrainer.Rate(timingMs: number, windowMs: number): string
	local absolute = math.abs(timingMs)
	if absolute <= windowMs then
		return "Perfect"
	elseif absolute <= windowMs * 3 then
		return "Good"
	elseif timingMs < 0 then
		return "Early"
	end
	return "Late"
end

function ShotTrainer:GetStats()
	local attempts = stats.Attempts
	return {
		Attempts = attempts,
		Makes = stats.Makes,
		Perfect = stats.Perfect,
		FieldGoalPct = attempts > 0 and stats.Makes / attempts * 100 or 0,
		PerfectPct = attempts > 0 and stats.Perfect / attempts * 100 or 0,
		AvgErrorMs = attempts > 0 and stats.TotalAbsErrorMs / attempts or 0,
		Streak = stats.Streak,
		BestStreak = stats.BestStreak,
	}
end

--- Most recent shots, newest last, trimmed to the TrainerHistorySize setting.
function ShotTrainer:GetHistory()
	local size = Settings:Get("TrainerHistorySize")
	local first = math.max(1, #history - size + 1)
	return table.move(history, first, #history, 1, {})
end

function ShotTrainer:Reset()
	table.clear(history)
	stats = { Attempts = 0, Makes = 0, Perfect = 0, TotalAbsErrorMs = 0, BestStreak = 0, Streak = 0 }
	self.StatsChanged:Fire(self:GetStats())
end

function ShotTrainer:_record(shot)
	local rating = ShotTrainer.Rate(shot.timingMs, shot.windowMs)
	shot.rating = rating

	table.insert(history, shot)
	if #history > MAX_STORED_HISTORY then
		table.remove(history, 1)
	end

	stats.Attempts += 1
	stats.TotalAbsErrorMs += math.abs(shot.timingMs)
	if shot.made then
		stats.Makes += 1
	end
	if rating == "Perfect" then
		stats.Perfect += 1
		stats.Streak += 1
		stats.BestStreak = math.max(stats.BestStreak, stats.Streak)
	else
		stats.Streak = 0
	end

	self.ShotRecorded:Fire(shot, rating)
	self.StatsChanged:Fire(self:GetStats())
end

function ShotTrainer:Init()
	ShotEvents.Reported:Connect(function(shot)
		self:_record(shot)
	end)
end

return ShotTrainer
