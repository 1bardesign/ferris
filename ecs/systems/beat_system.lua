--[[
	time-based "beat" behaviour system
	works on the principal of a single beat frequency
	and any integer multiples of that beat can be registered,
	with possible pattern masks for firing or not firing
	for beat callbacks
]]

local path = (...)
local base = require(path:gsub("beat_system", "base"))

local beat_system = class({
	name = "beat_system"
})

function beat_system:new(frequency)
	--trigger
	self.timer = 0
	self.base_frequency = frequency
	--beat counter
	self.beat = 0
	--debug info
	self.debug = {
		beat_this_frame = false,
		last_beat = 0,
	}
	--set up deferred
	base.add_deferred_management(self)
end

-- argument must be a table with members:
--  beat      - function
-- optional:
--  frequency - number, default 1
--  mask      - sequence of booleans, default {true}
function beat_system:create_component(b)
	b.frequency = b.frequency or 1
	b.mask = b.mask or {true}
	b._beat_counter = 0
	b._mask_counter = 0
	return b
end

--
function beat_system:update(dt)
	--tick forward
	self.debug.beat_this_frame = false
	self.timer = self.timer + dt
	if self.timer < self.base_frequency then
		return
	end
	self.timer = self.timer - self.base_frequency
	self.debug.beat_this_frame = true
	--count beats
	self.beat = self.beat + 1

	--tally most recent beat
	self.debug.last_beat = 0
	--(update everything)
	for _, b in ipairs(self.all) do
		--step beat counter
		if (self.beat % b.frequency) == 0 then
			--if not masked out this beat
			if b.mask[b._mask_counter] == true then
				--call
				if type(b.beat) == "function" then
					b:beat()
				end
				--tally
				self.debug.last_beat = self.debug.last_beat + 1
			end
			--next mask
			b._mask_counter = b._mask_counter + 1
			if b._mask_counter > #b.mask then
				b._mask_counter = 1
			end
		end
	end
end

--register tasks for kernel
function beat_system:register(kernel, order)
	base.do_default_register(self, kernel, order)
end

return beat_system
