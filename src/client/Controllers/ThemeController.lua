--[[
	ThemeController
	Components bind properties to theme tokens with Theme.Bind(instance, property, token).
	When the theme or accent color changes, every bound property updates automatically.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))
local Settings = require(script.Parent.SettingsController)

local Theme = {}
Theme.Changed = Signal.new()

Theme.Presets = {
	Dark = {
		Background = Color3.fromRGB(18, 18, 22),
		Surface = Color3.fromRGB(28, 28, 34),
		SurfaceAlt = Color3.fromRGB(44, 44, 52),
		Stroke = Color3.fromRGB(58, 58, 68),
		Text = Color3.fromRGB(240, 240, 245),
		SubText = Color3.fromRGB(150, 150, 165),
	},
	Light = {
		Background = Color3.fromRGB(242, 242, 246),
		Surface = Color3.fromRGB(255, 255, 255),
		SurfaceAlt = Color3.fromRGB(222, 222, 230),
		Stroke = Color3.fromRGB(205, 205, 215),
		Text = Color3.fromRGB(22, 22, 28),
		SubText = Color3.fromRGB(100, 100, 115),
	},
	Midnight = {
		Background = Color3.fromRGB(10, 14, 30),
		Surface = Color3.fromRGB(18, 24, 46),
		SurfaceAlt = Color3.fromRGB(32, 40, 70),
		Stroke = Color3.fromRGB(44, 54, 90),
		Text = Color3.fromRGB(230, 235, 255),
		SubText = Color3.fromRGB(135, 145, 185),
	},
}

-- Fixed status colors (independent of theme).
Theme.Status = {
	Success = Color3.fromRGB(34, 197, 94),
	Good = Color3.fromRGB(163, 230, 53),
	Warning = Color3.fromRGB(245, 158, 11),
	Error = Color3.fromRGB(239, 68, 68),
}

local current = Theme.Presets.Dark
local accent = Color3.fromHex("#F97316")
local bindings: { [Instance]: { [string]: string } } = setmetatable({}, { __mode = "k" }) :: any

function Theme.Get(token: string): Color3
	if token == "Accent" then
		return accent
	end
	return current[token] or Theme.Status[token] or Color3.new(1, 0, 1)
end

function Theme.Bind(instance: Instance, property: string, token: string)
	bindings[instance] = bindings[instance] or {}
	bindings[instance][property] = token;
	(instance :: any)[property] = Theme.Get(token)
end

function Theme.Unbind(instance: Instance, property: string)
	local props = bindings[instance]
	if props then
		props[property] = nil
	end
end

--- Runs fn now and on every theme change until instance is destroyed.
function Theme.OnChanged(instance: Instance, fn: () -> ())
	fn()
	local connection = Theme.Changed:Connect(fn)
	instance.Destroying:Connect(function()
		connection:Disconnect()
	end)
end

local function apply()
	for instance, props in pairs(bindings) do
		for property, token in pairs(props) do
			(instance :: any)[property] = Theme.Get(token)
		end
	end
	Theme.Changed:Fire()
end

function Theme:Init()
	Settings:Observe("Theme", function(name)
		current = Theme.Presets[name] or Theme.Presets.Dark
		apply()
	end)
	Settings:Observe("AccentColor", function(hex)
		local ok, color = pcall(Color3.fromHex, hex)
		if ok then
			accent = color
			apply()
		end
	end)
end

return Theme
