--[[
	ShotEvents
	The hook between YOUR game's shooting system and the shot trainer UI.

	The trainer never reads or changes shooting logic. Your own shooting LocalScript
	reports what happened after the player releases, and the trainer displays it:

	    local ShotEvents = require(game.ReplicatedStorage.Shared.ShotEvents)
	    ShotEvents.Report({
	        timingMs = releaseTime - idealReleaseTime, -- negative = early, positive = late
	        windowMs = 30,                            -- your game's perfect-release window
	        made = didScore,
	        shotType = "Jumper",
	    })
]]

local Signal = require(script.Parent.Signal)

export type ShotReport = {
	timingMs: number,
	windowMs: number,
	made: boolean,
	shotType: string,
	time: number,
}

local ShotEvents = {}
ShotEvents.Reported = Signal.new()

local DEFAULT_WINDOW_MS = 30

function ShotEvents.Report(data: { [string]: any })
	if typeof(data) ~= "table" or typeof(data.timingMs) ~= "number" or data.timingMs ~= data.timingMs then
		warn("[ShotEvents] Report requires a numeric timingMs")
		return
	end

	local window = data.windowMs
	if typeof(window) ~= "number" or window <= 0 then
		window = DEFAULT_WINDOW_MS
	end

	local report: ShotReport = {
		timingMs = data.timingMs,
		windowMs = window,
		made = data.made == true,
		shotType = typeof(data.shotType) == "string" and data.shotType or "Shot",
		time = os.clock(),
	}
	ShotEvents.Reported:Fire(report)
end

return ShotEvents
