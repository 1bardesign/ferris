--[[
	screenshake module
]]

local screenshake = class({
	name = "screenshake",
})

function screenshake:new()
	self.amplitude = 0
	self.time = 1
	self.timer = 0
	self.decay_rate = 2  -- Rate at which shake amplitude reduces over time
end

function screenshake:update(dt)
	self.timer = self.timer + dt
	self.amplitude = self.amplitude * math.exp(-self.decay_rate * dt)  -- Exponential decay
end

function screenshake:amount()
	if self.time == 0 or self.timer > self.time then
		return 0
	end
	return math.lerp(self.amplitude, 0, math.clamp01(self.timer / self.time))
end

local _av = vec2() --cached to avoid gc
function screenshake:apply(camera_position)
	local am = self:amount()
	if am > 0 then
		_av:sset(love.math.random() * am)
			:rotatei(love.math.random() * math.tau)
		camera_position:vaddi(_av)
	end
end

function screenshake:trigger(amplitude, time)
	self.timer = 0
	self.time = time
	self.amplitude = amplitude + love.math.random() * 0.1 * amplitude -- Adding randomness to amplitude
end

return screenshake
