--[[
	SettingsService (server)
	Loads, validates, and saves each player's settings with DataStoreService.
	Every value from the client is checked against SettingsSchema before it is stored.
	Player-facing profile values (position, jersey, hand) are mirrored as attributes
	so your other game scripts can read them, e.g. player:GetAttribute("JerseyNumber").
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schema = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SettingsSchema"))

local STORE_NAME = "PB_PlayerSettings_v1"
local AUTOSAVE_INTERVAL = 60
local MAX_KEYS_PER_UPDATE = 32
local UPDATE_RATE_LIMIT = 0.5 -- seconds between accepted update batches
local LOAD_TIMEOUT = 15

local ATTRIBUTE_KEYS = { "PreferredPosition", "JerseyNumber", "ShootingHand" }

local store = DataStoreService:GetDataStore(STORE_NAME)

-- Remotes --------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "SettingsRemotes"

local getSettings = Instance.new("RemoteFunction")
getSettings.Name = "GetSettings"
getSettings.Parent = remotes

local updateSettings = Instance.new("RemoteEvent")
updateSettings.Name = "UpdateSettings"
updateSettings.Parent = remotes

remotes.Parent = ReplicatedStorage

-- State ----------------------------------------------------------------------
local profiles: { [Player]: { data: { [string]: any }, dirty: boolean, canSave: boolean } } = {}
local lastUpdate: { [Player]: number } = {}

local function dataKey(player: Player): string
	return "user_" .. player.UserId
end

local function applyAttributes(player: Player, data)
	for _, key in ipairs(ATTRIBUTE_KEYS) do
		player:SetAttribute(key, data[key])
	end
end

local function withRetries(fn: () -> any, attempts: number)
	local ok, result
	for attempt = 1, attempts do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		task.wait(attempt * 2)
	end
	return false, result
end

local function loadProfile(player: Player)
	local ok, result = withRetries(function()
		return store:GetAsync(dataKey(player))
	end, 3)

	if not ok then
		warn(("[SettingsService] Failed to load %s: %s"):format(player.Name, tostring(result)))
	end

	if not player.Parent then
		return
	end

	profiles[player] = {
		data = Schema.Sanitize(ok and result or nil),
		dirty = false,
		-- If loading failed, never save: that would overwrite their real data with defaults.
		canSave = ok,
	}
	applyAttributes(player, profiles[player].data)
end

local function saveProfile(player: Player)
	local profile = profiles[player]
	if not profile or not profile.dirty or not profile.canSave then
		return
	end
	profile.dirty = false

	local snapshot = table.clone(profile.data)
	local ok, err = withRetries(function()
		store:SetAsync(dataKey(player), snapshot, { player.UserId })
	end, 3)

	if not ok then
		profile.dirty = true
		warn(("[SettingsService] Failed to save %s: %s"):format(player.Name, tostring(err)))
	end
end

-- Remote handlers ------------------------------------------------------------
getSettings.OnServerInvoke = function(player: Player)
	local started = os.clock()
	while not profiles[player] and player.Parent and os.clock() - started < LOAD_TIMEOUT do
		task.wait(0.1)
	end
	local profile = profiles[player]
	return profile and table.clone(profile.data) or Schema.Defaults()
end

updateSettings.OnServerEvent:Connect(function(player: Player, changes: any)
	local profile = profiles[player]
	if not profile or typeof(changes) ~= "table" then
		return
	end

	local now = os.clock()
	if lastUpdate[player] and now - lastUpdate[player] < UPDATE_RATE_LIMIT then
		return
	end
	lastUpdate[player] = now

	local count = 0
	for key, value in pairs(changes) do
		count += 1
		if count > MAX_KEYS_PER_UPDATE then
			break
		end
		if typeof(key) == "string" then
			local ok, normalised = Schema.Validate(key, value)
			if ok and profile.data[key] ~= normalised then
				profile.data[key] = normalised
				profile.dirty = true
			end
		end
	end

	applyAttributes(player, profile.data)
end)

-- Lifecycle ------------------------------------------------------------------
Players.PlayerAdded:Connect(loadProfile)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadProfile, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveProfile(player)
	profiles[player] = nil
	lastUpdate[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for player in pairs(profiles) do
			task.spawn(saveProfile, player)
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for player in pairs(profiles) do
		pending += 1
		task.spawn(function()
			saveProfile(player)
			pending -= 1
		end)
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 25 do
		task.wait(0.1)
	end
end)
