--[[
	SettingsSchema
	Single source of truth for every player setting. Shared by client and server:
	  * the client auto-builds the settings UI from this list
	  * the server validates every value it receives against it before saving

	Supported types: boolean, number, enum, color (hex "#RRGGBB"), keybind (Enum.KeyCode name)
]]

local Schema = {}

Schema.Categories = { "Interface", "Notifications", "Keybinds", "Player", "Trainer" }

Schema.List = {
	-- Interface ---------------------------------------------------------------
	{ key = "Theme", category = "Interface", type = "enum", label = "Theme",
		default = "Dark", options = { "Dark", "Light", "Midnight" } },
	{ key = "AccentColor", category = "Interface", type = "color", label = "Accent color",
		default = "#F97316" },
	{ key = "UIScale", category = "Interface", type = "number", label = "Interface scale",
		default = 1, min = 0.75, max = 1.5, step = 0.05, format = "%.2fx" },
	{ key = "AnimationSpeed", category = "Interface", type = "number", label = "Animation speed",
		default = 1, min = 0.25, max = 2, step = 0.25, format = "%.2fx" },
	{ key = "ReduceMotion", category = "Interface", type = "boolean", label = "Reduce motion",
		description = "Skip UI transitions", default = false },
	{ key = "ShowMenuButton", category = "Interface", type = "boolean", label = "Show menu button",
		description = "On-screen button for touch / controller", default = true },

	-- Notifications -----------------------------------------------------------
	{ key = "NotificationsEnabled", category = "Notifications", type = "boolean",
		label = "Enable notifications", default = true },
	{ key = "NotificationDuration", category = "Notifications", type = "number",
		label = "Duration", default = 4, min = 1, max = 10, step = 0.5, format = "%.1fs" },
	{ key = "NotificationPosition", category = "Notifications", type = "enum", label = "Position",
		default = "TopRight", options = { "TopRight", "BottomRight", "TopLeft", "BottomLeft" } },

	-- Keybinds ----------------------------------------------------------------
	{ key = "Keybind_ToggleMenu", category = "Keybinds", type = "keybind", label = "Open settings",
		default = "RightShift" },
	{ key = "Keybind_ToggleTrainer", category = "Keybinds", type = "keybind", label = "Toggle shot trainer",
		default = "F2" },
	{ key = "Keybind_ResetStats", category = "Keybinds", type = "keybind", label = "Reset session stats",
		default = "F3" },

	-- Player ------------------------------------------------------------------
	{ key = "PreferredPosition", category = "Player", type = "enum", label = "Preferred position",
		default = "PG", options = { "PG", "SG", "SF", "PF", "C" } },
	{ key = "JerseyNumber", category = "Player", type = "number", label = "Jersey number",
		default = 0, min = 0, max = 99, step = 1, format = "#%d" },
	{ key = "ShootingHand", category = "Player", type = "enum", label = "Shooting hand",
		default = "Right", options = { "Right", "Left" } },
	{ key = "CameraFOV", category = "Player", type = "number", label = "Camera field of view",
		default = 70, min = 60, max = 100, step = 1, format = "%d°" },

	-- Trainer -----------------------------------------------------------------
	{ key = "TrainerEnabled", category = "Trainer", type = "boolean", label = "Show shot trainer",
		description = "Release feedback after each of your shots", default = true },
	{ key = "TrainerShowHistory", category = "Trainer", type = "boolean", label = "Show release history",
		default = true },
	{ key = "TrainerHistorySize", category = "Trainer", type = "number", label = "History length",
		default = 10, min = 3, max = 30, step = 1, format = "%d shots" },
	{ key = "TrainerPosition", category = "Trainer", type = "enum", label = "HUD position",
		default = "Bottom", options = { "Bottom", "Top" } },
}

-- Keys that would break movement / core UI if bound.
Schema.ReservedKeys = {
	W = true, A = true, S = true, D = true, Space = true, Escape = true,
	Slash = true, Backquote = true, Tab = true, Unknown = true,
}

Schema.ByKey = {}
for index, def in ipairs(Schema.List) do
	def.order = index
	Schema.ByKey[def.key] = def
end

local function roundTo(value: number, decimals: number): number
	local m = 10 ^ decimals
	return math.floor(value * m + 0.5) / m
end

--- Validates (and normalises) a single value. Returns ok, normalisedValue.
function Schema.Validate(key: string, value: any): (boolean, any)
	local def = Schema.ByKey[key]
	if not def then
		return false, nil
	end

	if def.type == "boolean" then
		return typeof(value) == "boolean", value
	elseif def.type == "number" then
		if typeof(value) ~= "number" or value ~= value then -- reject NaN
			return false, nil
		end
		local v = math.clamp(value, def.min, def.max)
		if def.step then
			v = def.min + math.floor((v - def.min) / def.step + 0.5) * def.step
		end
		return true, math.clamp(roundTo(v, 4), def.min, def.max)
	elseif def.type == "enum" then
		return table.find(def.options, value) ~= nil, value
	elseif def.type == "color" then
		if typeof(value) ~= "string" or not value:match("^#%x%x%x%x%x%x$") then
			return false, nil
		end
		return true, value:upper()
	elseif def.type == "keybind" then
		if typeof(value) ~= "string" or Schema.ReservedKeys[value] then
			return false, nil
		end
		local ok, keyCode = pcall(function()
			return (Enum.KeyCode :: any)[value]
		end)
		return ok and keyCode ~= nil, value
	end

	return false, nil
end

function Schema.Defaults(): { [string]: any }
	local defaults = {}
	for _, def in ipairs(Schema.List) do
		defaults[def.key] = def.default
	end
	return defaults
end

--- Merges untrusted data over the defaults, dropping anything invalid.
function Schema.Sanitize(data: any): { [string]: any }
	local result = Schema.Defaults()
	if typeof(data) == "table" then
		for key, value in pairs(data) do
			if typeof(key) == "string" then
				local ok, normalised = Schema.Validate(key, value)
				if ok then
					result[key] = normalised
				end
			end
		end
	end
	return result
end

function Schema.InCategory(category: string)
	local defs = {}
	for _, def in ipairs(Schema.List) do
		if def.category == category then
			table.insert(defs, def)
		end
	end
	return defs
end

return Schema
