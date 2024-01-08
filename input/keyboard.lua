--[[
	keyboard abstraction;

	handles key input on a per-frame basis
	prevents missing input from polling by queuing inputs from callbacks
	allows checking how long something has been pressed or released (in seconds)
]]

local keyboard = class({
	name = "keyboard"
})

--the keys we care about
keyboard.all_keys = {
	--anum
	"a",
	"b",
	"c",
	"d",
	"e",
	"f",
	"g",
	"h",
	"i",
	"j",
	"k",
	"l",
	"m",
	"n",
	"o",
	"p",
	"q",
	"r",
	"s",
	"t",
	"u",
	"v",
	"w",
	"x",
	"y",
	"z",
	"1",
	"2",
	"3",
	"4",
	"5",
	"6",
	"7",
	"8",
	"9",
	"0",
	--whitespace
	"return",
	"escape",
	"backspace",
	"tab",
	"space",
	--misc letters
	"-",
	"=",
	"[",
	"]",
	"\\",
	"nonus#",
	";",
	"'",
	"`",
	",",
	".",
	"/",
	"capslock",
	--function keys
	"f1",
	"f2",
	"f3",
	"f4",
	"f5",
	"f6",
	"f7",
	"f8",
	"f9",
	"f10",
	"f11",
	"f12",
	"f13",
	"f14",
	"f15",
	"f16",
	"f17",
	"f18",
	"f19",
	"f20",
	"f21",
	"f22",
	"f23",
	"f24",
	--special
	"lctrl",
	"lshift",
	"lalt",
	"lgui",
	"rctrl",
	"rshift",
	"ralt",
	"rgui",
	"printscreen",
	"scrolllock",
	"pause",
	"insert",
	"home",
	"numlock",
	"pageup",
	"delete",
	"end",
	"pagedown",
	--arrows
	"right",
	"left",
	"down",
	"up",
	--numblock
	"kp/",
	"kp*",
	"kp-",
	"kp+",
	"kp=",
	"kpenter",
	"kp1",
	"kp2",
	"kp3",
	"kp4",
	"kp5",
	"kp6",
	"kp7",
	"kp8",
	"kp9",
	"kp0",
	"kp.",
	--unknown key
	"unknown"
}

function keyboard:new()
	self.key_data = {}
	self:clear()
end

function keyboard:update(dt)
	for _, v in ipairs(self.all_keys) do
		local d = self.key_data[v]
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
end

--callbacks
function keyboard:keypressed(key)
	local d = self.key_data[key]
	if d == nil then --unknown keys
		return
	end
	table.insert(d.events, "pressed")
end

function keyboard:keyreleased(key)
	local d = self.key_data[key]
	if d == nil then --unknown keys
		return
	end
	table.insert(d.events, "released")
end

--clear the key states to all-released (handy on state transition)
function keyboard:clear(v)
	if v then
		self.key_data[v] = {
			time = -1,
			events = {},
		}
	else
		for _, v in ipairs(self.all_keys) do
			self:clear(v)
		end
	end
end

function keyboard:_raw_time(key)
	local d = self.key_data[key]
	return d and d.time or 0
end

--get the time a key has been pressed for
--or -1 if the key is not pressed
function keyboard:pressed_time(key)
	local t = self:_raw_time(key)
	if t == nil or t < 0 then
		return -1
	end
	return t - 1
end

--get the time a key has been released for
--or -1 if the key is not released
function keyboard:released_time(key)
	local t = self:_raw_time(key)
	if t == nil or t > 0 then
		return -1
	end
	return (t * -1) - 1
end

--return true if a key is currently pressed
function keyboard:pressed(key)
	return self:pressed_time(key) >= 0
end

--return true if a key is currently released
function keyboard:released(key)
	return self:released_time(key) >= 0
end

--return true if a key was just pressed (this frame)
function keyboard:just_pressed(key)
	return self:pressed_time(key) == 0
end

--return true if a key was just released (this frame)
function keyboard:just_released(key)
	return self:released_time(key) == 0
end

--"any" key
function keyboard:any_pressed()
	for _, k in ipairs(self.all_keys) do
		if self:pressed(k) then
			return true
		end
	end
	return false
end

function keyboard:any_just_pressed()
	for _, k in ipairs(self.all_keys) do
		if self:just_pressed(k) then
			return true
		end
	end
	return false
end

return keyboard
