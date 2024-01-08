--[[
	gamepad class
]]
local gamepad = class({
	name = "gamepad",
})

gamepad.buttons = {
	--axis remappings
	"lsup",
	"lsdown",
	"lsleft",
	"lsright",
	"rsup",
	"rsdown",
	"rsleft",
	"rsright",
	"triggerleft",
	"triggerright",
	--normal buttons
	"a",
	"b",
	"x",
	"y",
	"back",
	"guide",
	"start",
	"leftstick",
	"rightstick",
	"leftshoulder",
	"rightshoulder",
	"dpup",
	"dpdown",
	"dpleft",
	"dpright"
}

gamepad.axes = {
	["lsup"] = {0, -1, "lefty"},
	["lsdown"] = {0, 1, "lefty"},
	["lsleft"] = {0, -1, "leftx"},
	["lsright"] = {0, 1, "leftx"},
	["rsup"] = {0, -1, "righty"},
	["rsdown"] = {0, 1, "righty"},
	["rsleft"] = {0, -1, "rightx"},
	["rsright"] = {0, 1, "rightx"},
	["triggerleft"] = {0, 1, "triggerleft"},
	["triggerright"] = {0, 1, "triggerright"}
}

--load a mapping database to support more controllers
--do this before you create any gamepads!
--eg from https://github.com/gabomdq/SDL_GameControllerDB
function gamepad:load_mapping_database(path)
	love.joystick.loadGamepadMappings(path)
end

--create a new gamepad interface
--todo: consider supporting >1 of these for multiplayer :)
function gamepad:new(controller_index)
	self.controller_index = controller_index or 1
	self.stick = love.joystick.getJoysticks()[self.controller_index]
	self.button_times = {}
	self:clear()
end

function gamepad:active()
	return self.stick ~= nil
end

function gamepad:refresh()
	if not self.stick then
		if love.joystick.getJoystickCount() > 0 then
			self.stick = love.joystick.getJoysticks()[self.controller_index]
		end
	elseif not self.stick:isConnected() then
		self.stick = nil
		self:clear()
	end
end

--get the time a key has been pressed for
--or -1 if the key is not pressed
function gamepad:pressed_time(key)
	local t = self.button_times[key]
	if t == nil or t < 0 then
		return -1
	end
	return t - 1
end

--get the time a key has been released for
--or -1 if the key is not released
function gamepad:released_time(key)
	local t = self.button_times[key]
	if t == nil or t > 0 then
		return -1
	end
	return (t * -1) - 1
end

--read an axis (todo per-frame caching in update)
local active_region = {0.15, 0.95}
function gamepad:axis(name)
	if not self.stick then
		return vec2()
	end
	local d = vec2(
		self.stick:getGamepadAxis(name.."x"),
		self.stick:getGamepadAxis(name.."y")
	)
	local l = d:normalise_len_inplace()
	local min = active_region[1]
	local range = active_region[2] - active_region[1]
	local scale = math.clamp01((l - min) / range)
	return d:scalar_mul_inplace(scale)
end

--clear out the device (done when we disconnect)
function gamepad:clear()
	for i, p in ipairs(
		{
			self.axes,
			self.buttons
		}
	) do
		for k, v in ipairs(p) do
			self.button_times[v] = -1
		end
	end
end

--update all the joy buttons
function gamepad:update(dt)
	--check
	self:refresh()

	if not self:active() then
		return
	end

	--update each button
	for i, v in ipairs(self.buttons) do
		--check pressed (different for axis vs button)
		local pressed = false
		if self.axes[v] then
			local axis_start, axis_end, axis_name = unpack(self.axes[v])
			local direction = axis_end - axis_start
			local axis_value = self.stick:getGamepadAxis(axis_name)
			if axis_value * direction > 0.5 then
				pressed = true
			end
		else
			if self.stick:isGamepadDown(v) then
				pressed = true
			end
		end

		--integrate forward
		local t = self.button_times[v]
		if pressed then
			if t < 1 then
				t = 1
			else
				t = t + dt
			end
		else
			if t > -1 then
				t = -1
			else
				t = t - dt
			end
		end
		self.button_times[v] = t
	end
end

--return true if a key is currently pressed
function gamepad:pressed(key)
	if not self:active() then return false end
	return self:pressed_time(key) >= 0
end

--return true if a key is currently released
function gamepad:released(key)
	if not self:active() then return false end
	return self:released_time(key) >= 0
end

--return true if a key was just pressed (this frame)
function gamepad:just_pressed(key)
	if not self:active() then return false end
	return self:pressed_time(key) == 0
end

--return true if a key was just released (this frame)
function gamepad:just_released(key)
	if not self:active() then return false end
	return self:released_time(key) == 0
end

--"any" key
function gamepad:any_pressed()
	if not self:active() then return false end
	for _, k in ipairs(self.buttons) do
		if self:pressed(k) then
			return true
		end
	end
	return false
end

function gamepad:any_just_pressed()
	if not self:active() then return false end
	for _, k in ipairs(self.buttons) do
		if self:just_pressed(k) then
			return true
		end
	end
	return false
end

return gamepad
