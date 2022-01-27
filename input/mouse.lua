--mouse handling

local mouse = class({
	name = "mouse",
})

local _mouse_buttons = {
	1, 2, 3
}

function mouse:new()
	self.button_data = {}
	self.pos = vec2()
	self:clear()
end

function mouse:update(dt)
	for _, v in ipairs(_mouse_buttons) do
		local d = self.button_data[v]
		if #d.events > 0 then
			local e = table.remove(d.events, 1)
			if e == "pressed" then
				d.time = 1
			elseif e == "released" then
				d.time = -1
			end
		else
			d.time = d.time + dt * math.sign(d.time)
		end
	end
	self.pos:sset(love.mouse.getPosition())
end

--callbacks
function mouse:mousepressed(x, y, button)
	self.pos:sset(x, y)
	local d = self.button_data[button]
	if d == nil then --unknown buttons
		return
	end
	table.insert(d.events, "pressed")
end

function mouse:mousereleased(x, y, button)
	self.pos:sset(x, y)
	local d = self.button_data[button]
	if d == nil then --unknown buttons
		return
	end
	table.insert(d.events, "released")
end

--clear the button states to all-released (handy on state transition)
function mouse:clear()
	for _, v in ipairs(_mouse_buttons) do
		self.button_data[v] = {
			time = -1,
			events = {},
		}
	end
end

function mouse:_raw_time(button)
	local d = self.button_data[button]
	return d and d.time or 0
end

--get the time a button has been pressed for
--or -1 if the button is not pressed
function mouse:pressed_time(button)
	local t = self:_raw_time(button)
	if t == nil or t < 0 then
		return -1
	end
	return t - 1
end

--get the time a button has been released for
--or -1 if the button is not released
function mouse:released_time(button)
	local t = self:_raw_time(button)
	if t == nil or t > 0 then
		return -1
	end
	return (t * -1) - 1
end

--return true if a button is currently pressed
function mouse:pressed(button)
	return self:pressed_time(button) >= 0
end

--return true if a button is currently released
function mouse:released(button)
	return self:released_time(button) >= 0
end

--return true if a button was just pressed (this frame)
function mouse:just_pressed(button)
	return self:pressed_time(button) == 0
end

--return true if a button was just released (this frame)
function mouse:just_released(button)
	return self:released_time(button) == 0
end

--"any" button
function mouse:any_pressed()
	for _, button in ipairs(_mouse_buttons) do
		if self:pressed(button) then
			return true
		end
	end
	return false
end

function mouse:any_just_pressed()
	for _, button in ipairs(_mouse_buttons) do
		if self:just_pressed(button) then
			return true
		end
	end
	return false
end

return mouse
