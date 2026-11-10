--[[
	SettingsController (client)
	Holds the local copy of the player's settings, validates changes with the shared
	schema, and batches them to the server so rapid slider drags cost one request.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Schema = require(Shared:WaitForChild("SettingsSchema"))
local Signal = require(Shared:WaitForChild("Signal"))

local FLUSH_DELAY = 1.5

local SettingsController = {}
SettingsController.Changed = Signal.new() -- (key: string, value: any)

local values = Schema.Defaults()
local pending: { [string]: any } = {}
local flushScheduled = false
local updateRemote: RemoteEvent? = nil

local function flush()
	flushScheduled = false
	if next(pending) == nil or not updateRemote then
		return
	end
	local batch = pending
	pending = {}
	updateRemote:FireServer(batch)
end

function SettingsController:Init()
	local remotes = ReplicatedStorage:WaitForChild("SettingsRemotes", 30)
	if not remotes then
		warn("[SettingsController] SettingsRemotes not found; settings will not persist")
		return
	end
	updateRemote = remotes:WaitForChild("UpdateSettings") :: RemoteEvent

	local ok, data = pcall(function()
		return (remotes:WaitForChild("GetSettings") :: RemoteFunction):InvokeServer()
	end)
	if ok then
		values = Schema.Sanitize(data)
	else
		warn("[SettingsController] Could not load settings:", data)
	end
end

function SettingsController:Get(key: string): any
	return values[key]
end

--- Returns true if the value was valid and applied.
function SettingsController:Set(key: string, value: any): boolean
	local ok, normalised = Schema.Validate(key, value)
	if not ok then
		return false
	end
	if values[key] == normalised then
		return true
	end

	values[key] = normalised
	pending[key] = normalised
	self.Changed:Fire(key, normalised)

	if not flushScheduled then
		flushScheduled = true
		task.delay(FLUSH_DELAY, flush)
	end
	return true
end

--- Calls fn immediately with the current value, then on every change.
function SettingsController:Observe(key: string, fn: (any) -> ())
	fn(values[key])
	return self.Changed:Connect(function(changedKey, value)
		if changedKey == key then
			fn(value)
		end
	end)
end

function SettingsController:ResetCategory(category: string)
	for _, def in ipairs(Schema.InCategory(category)) do
		self:Set(def.key, def.default)
	end
end

return SettingsController
