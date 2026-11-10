--[[
	Practical Basketball – client bootstrap
	Starts controllers, builds the UI, and registers keybind actions.
]]

local Players = game:GetService("Players")

local Controllers = script.Controllers
local Settings = require(Controllers.SettingsController)
local Theme = require(Controllers.ThemeController)
local Keybinds = require(Controllers.KeybindController)
local Notifications = require(Controllers.NotificationController)
local ShotTrainer = require(script.Tools.ShotTrainer)
local MainWindow = require(script.UI.MainWindow)
local SettingsPages = require(script.UI.SettingsPages)
local TrainerHud = require(script.UI.TrainerHud)
local Components = require(script.UI.Components)

local player = Players.LocalPlayer

-- 1. Data & theme ------------------------------------------------------------
Settings:Init()
Theme:Init()

-- 2. Screen ------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "PracticalBasketballUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

Notifications:Init(gui)
Keybinds:Init()
ShotTrainer:Init()

-- 3. UI ----------------------------------------------------------------------
local window = MainWindow.new(gui, "Practical Basketball")
SettingsPages.Build(window)
TrainerHud.new(gui)

-- On-screen button for touch / gamepad players.
local menuButton = Components.Create("TextButton", {
	Name = "MenuButton",
	Text = "⚙  Settings",
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	AutoButtonColor = false,
	Position = UDim2.fromOffset(12, 12),
	Size = UDim2.fromOffset(104, 32),
	Parent = gui,
}, { Components.Corner(8) })
Theme.Bind(menuButton, "BackgroundColor3", "Surface")
Theme.Bind(menuButton, "TextColor3", "Text")
Components.Stroke(menuButton)
menuButton.MouseButton1Click:Connect(function()
	window:Toggle()
end)
Settings:Observe("ShowMenuButton", function(visible)
	menuButton.Visible = visible
end)

-- 4. Keybind actions ---------------------------------------------------------
Keybinds:Register("ToggleMenu", "Keybind_ToggleMenu", function()
	window:Toggle()
end)

Keybinds:Register("ToggleTrainer", "Keybind_ToggleTrainer", function()
	local enabled = not Settings:Get("TrainerEnabled")
	Settings:Set("TrainerEnabled", enabled)
	Notifications:Notify({ Title = "Shot trainer", Text = enabled and "Trainer shown" or "Trainer hidden", Type = "Info" })
end)

Keybinds:Register("ResetStats", "Keybind_ResetStats", function()
	ShotTrainer:Reset()
	Notifications:Notify({ Title = "Stats reset", Text = "Session stats cleared.", Type = "Success" })
end)

-- 5. Player configuration that applies client-side ---------------------------
local function applyFov()
	local camera = workspace.CurrentCamera
	if camera then
		camera.FieldOfView = Settings:Get("CameraFOV")
	end
end
Settings:Observe("CameraFOV", applyFov)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(applyFov)

-- 6. Welcome -----------------------------------------------------------------
Notifications:Notify({
	Title = "Welcome, " .. player.DisplayName,
	Text = ("Press %s to open settings."):format(Keybinds:GetKeyName("Keybind_ToggleMenu")),
	Type = "Info",
})
