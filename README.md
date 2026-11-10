# Practical Basketball – UI & Settings

A settings and player-tools layer for **your own** Roblox basketball experience, written in Luau and synced into Studio with [Rojo](https://rojo.space).

## Features

| Area | What's included |
| --- | --- |
| **Interface** | Draggable settings window with tabs, animated open/close, on-screen menu button for touch players |
| **Customizable settings** | Generated from one schema (`SettingsSchema.lua`). Add a setting there and its control shows up automatically |
| **Visual customization** | Dark, Light and Midnight themes, accent color (swatches or hex), interface scale |
| **Animations** | Tween helper that follows the player's *Animation speed* and *Reduce motion* settings |
| **Keybinds** | Rebind in the UI, Escape cancels, blocks conflicts and reserved keys (WASD, Space, etc.) |
| **Notifications** | Toasts in four types, set duration and screen position, click to dismiss, stack limit |
| **Player configuration** | Preferred position, jersey number, shooting hand, camera FOV. The server copies the first three to player attributes |
| **Shot trainer** | Feedback after each release (Perfect / Good / Early / Late, offset in ms), a timing bar with recent shots, and session stats (FG%, perfect %, average error, streak) |
| **Persistence** | DataStore saving on the server. Every value is checked against the schema, updates are rate-limited, and nothing is saved if loading failed |

## Project layout

```
src/
  shared/                 -> ReplicatedStorage.Shared
    Signal.lua
    SettingsSchema.lua    every setting: type, default, limits, label, category
    ShotEvents.lua        hook your shooting system reports to
  server/                 -> ServerScriptService.Server
    SettingsService.server.lua
  client/                 -> StarterPlayerScripts.Client (LocalScript)
    init.client.lua       bootstrap
    Controllers/          Settings, Theme, Keybind, Notification
    UI/                   Anim, Components, MainWindow, SettingsPages, TrainerHud
    Tools/ShotTrainer.lua
```

## Setup

1. Install Rojo, then run `rojo serve` and connect from the Rojo plugin in Studio.
2. **Game Settings → Security → Enable Studio Access to API Services** so DataStores work in Studio.
3. Play. Press **RightShift**, or click **⚙ Settings**, to open the window.

## Hooking up the shot trainer

The trainer only displays results. Your own shooting LocalScript reports each shot after the release:

```lua
local ShotEvents = require(game.ReplicatedStorage.Shared.ShotEvents)

ShotEvents.Report({
	timingMs = releaseTime - idealReleaseTime, -- negative = early, positive = late
	windowMs = 30,                             -- your perfect-release window
	made = didScore,
	shotType = "Jumper",
})
```

In Studio, the Trainer tab has a **Send sample shot** button for testing the HUD before you wire this up.

## Using the API from other scripts

```lua
local Client = game.Players.LocalPlayer.PlayerScripts.Client
local Notifications = require(Client.Controllers.NotificationController)
Notifications:Notify({ Title = "Quarter 2", Text = "Game resumes in 10s", Type = "Info" })

local Settings = require(Client.Controllers.SettingsController)
Settings:Observe("ShootingHand", function(hand) ... end)
```

On the server: `player:GetAttribute("JerseyNumber")`, `"PreferredPosition"`, `"ShootingHand"`.

## Scope

This project runs inside a game you own. It does not include auto-timing, auto-release ("auto green"), input automation, or anything meant to inject into or change someone else's game through an executor.
