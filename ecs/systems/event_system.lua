--[[
	pubsub event system, for lazy coupling

	has both a central "hub" bus and allows creating isolated buses as components
]]

local path = (...)
local base = require(path:gsub("event_system", "base"))

local event_system = class()

function event_system:new()
	self = base.add_deferred_removal(
		self:init({
			--list of event buses
			elements = {},
			--shared
			hub = pubsub(),
		})
	)
	self.update = self:wrap_deferral(self.update)
	return self
end

--add a behaviour to the system
function event_system:add()
	local b = pubsub()
	table.insert(self.elements, b)
	return b
end

--remove a behaviour from the system
function event_system:remove(b)
	table.remove_value(self.elements, b)
end

return event_system
