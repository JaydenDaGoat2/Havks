--[[
	Anim
	Tween helper that respects the player's AnimationSpeed and ReduceMotion settings.
]]

local TweenService = game:GetService("TweenService")
local Settings = require(script.Parent.Parent.Controllers.SettingsController)

local Anim = {}

--- Effective duration after applying settings (0 when motion is reduced).
function Anim.Duration(seconds: number): number
	if Settings:Get("ReduceMotion") then
		return 0
	end
	return seconds / (Settings:Get("AnimationSpeed") or 1)
end

function Anim.Tween(
	instance: Instance,
	props: { [string]: any },
	seconds: number?,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween?
	local duration = Anim.Duration(seconds or 0.2)
	if duration <= 0 then
		for property, value in pairs(props) do
			(instance :: any)[property] = value
		end
		return nil
	end

	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, info, props)
	tween:Play()
	return tween
end

return Anim
