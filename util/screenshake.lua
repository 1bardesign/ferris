--[[
	shared screenshake module
]]

local screenshake = {}

function screenshake:init()
	self.amplitude = 0
	self.time = 1
	self.timer = 0
end

function screenshake:update(dt)
	self.timer = self.timer + dt
end

function screenshake:amount()
	if self.time == 0 or self.timer > self.time then
		return 0
	end
	return math.lerp(self.amplitude, 0, math.clamp01(self.timer / self.time))
end

local _av = vec2:zero()
function screenshake:apply(campos)
	local am = self:amount()
	if am > 0 then
		_av:sset(love.math.random() * am)
			:rotatei(love.math.random() * math.tau)
		campos:vaddi(_av)
	end
end

function screenshake:trigger(amplitude, time)
	self.timer = 0
	self.time = time
	self.amplitude = amplitude
end

return screenshake
