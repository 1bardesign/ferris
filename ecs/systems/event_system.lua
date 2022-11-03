--[[
	pubsub event system, for lazy coupling
]]

local path = (...)
local base = require(path:gsub("event_system", "base"))

local event_system = class({
	name = "event_system"
})

function event_system:new()
	self.hub = pubsub()
end

--add a listener to the system
function event_system:add(event, handler)
	self.hub:subscribe(event, handler)
	return {event, handler}
end

--remove a behaviour from the system
function event_system:remove(b)
	self.hub:unsubscribe(b[1], b[2])
end

--proxy to hub for direct use
function event_system:publish(...)
	return self.hub:publish(...)
end

function event_system:subscribe(...)
	return self.hub:subscribe(...)
end

function event_system:subscribe_once(...)
	return self.hub:subscribe_once(...)
end

function event_system:unsubscribe(...)
	return self.hub:unsubscribe(...)
end

return event_system
