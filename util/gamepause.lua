--[[
	gamepause module
]]
require("lib.batteries"):export()

local gamepause = class({
	name = "gamepause",
})

function gamepause:new()
	self.paused = false
	self.pause_duration = 0
	self.timer = 0
end

function gamepause:update(dt)
	if self.paused then
		self.timer = self.timer - dt
		if self.timer <= 0 then
			self.paused = false
			self.timer = 0
		end
	end
end

function gamepause:is_paused()
	return self.paused
end

function gamepause:pause(time)
	self.paused = true
	self.pause_duration = time
	self.timer = time
end

return gamepause