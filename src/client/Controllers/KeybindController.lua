--[[
	KeybindController
	Maps actions to keybind settings and supports in-UI rebinding.

	    Keybinds:Register("ToggleMenu", "Keybind_ToggleMenu", function() ... end)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Schema = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SettingsSchema"))
local Settings = require(script.Parent.SettingsController)

local KeybindController = {}

local actions: { [string]: { settingKey: string, callback: () -> () } } = {}
local captureCallback: ((string?) -> ())? = nil

function KeybindController:Register(name: string, settingKey: string, callback: () -> ())
	assert(Schema.ByKey[settingKey], "Unknown keybind setting: " .. settingKey)
	actions[name] = { settingKey = settingKey, callback = callback }
end

--- Listens for the next key press. Calls back with the KeyCode name, or nil if cancelled (Escape).
function KeybindController:Capture(callback: (string?) -> ())
	if captureCallback then
		captureCallback(nil)
	end
	captureCallback = callback
end

function KeybindController:IsCapturing(): boolean
	return captureCallback ~= nil
end

--- Checks whether keyName can be assigned to settingKey. Returns ok, reason.
function KeybindController:CanAssign(settingKey: string, keyName: string): (boolean, string?)
	if Schema.ReservedKeys[keyName] then
		return false, keyName .. " is reserved for movement or core controls"
	end
	for _, def in ipairs(Schema.List) do
		if def.type == "keybind" and def.key ~= settingKey and Settings:Get(def.key) == keyName then
			return false, keyName .. " is already used by \"" .. def.label .. "\""
		end
	end
	return true, nil
end

function KeybindController:GetKeyName(settingKey: string): string
	return Settings:Get(settingKey) or "None"
end

function KeybindController:Init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end

		if captureCallback then
			local callback = captureCallback
			captureCallback = nil
			if input.KeyCode == Enum.KeyCode.Escape then
				callback(nil)
			else
				callback(input.KeyCode.Name)
			end
			return
		end

		if gameProcessed then
			return
		end

		local keyName = input.KeyCode.Name
		for _, action in pairs(actions) do
			if Settings:Get(action.settingKey) == keyName then
				task.spawn(action.callback)
			end
		end
	end)
end

return KeybindController
