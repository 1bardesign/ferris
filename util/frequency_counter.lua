--[[
	count things happening over a period of time
]]

local frequency_counter = class({
	name = "frequency_counter"
})

function frequency_counter:new(sample_period)
	sample_period = sample_period or 1
	self.count = 0
	self.total = 0
	self.last_count = 0
	self.last_time = -1
	self.sample_period = sample_period
end

function frequency_counter:add()
	self.count = self.count + 1
	self.total = self.total + 1
end

function frequency_counter:get()
	local now = math.floor(love.timer.getTime() / self.sample_period)
	if now ~= self.last_time then
		self.last_time = now
		self.last_count = self.count
		self.count = 0
	end
	return self.last_count
end

function frequency_counter:get_total()
	return self.total
end

return frequency_counter
