--[[
	dead-simple publish-subscribe message bus
]]

local pubsub = class()

function pubsub:new()
	return self:init({
		subscriptions = {},
	})
end

function pubsub:_notify(callbacks, ...)
	if callbacks then
		for _, f in callbacks:ipairs() do
			f(...)
		end
	end
end

function pubsub:publish(event, ...)
	self:_notify(self.subscriptions[event], ...)
	self:_notify(self.subscriptions.everything, event, ...)
end

function pubsub:subscribe(event, callback)
	local callbacks = self.subscriptions[event]
	if not callbacks then
		callbacks = set()
		self.subscriptions[event] = callbacks
	end
	callbacks:add(callback)
end

function pubsub:unsubscribe(event, callback)
	local callbacks = assert:some(self.subscriptions[event], "unsubscribe without any subscriptions, potential double-unsubscribe")
	callbacks:remove(callback)
end

return pubsub
