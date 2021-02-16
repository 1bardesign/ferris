
local entity = class()

--unique name handler
local _component_id_gen = 0
local function generate_unique_name(fragment)
	local name = fragment.._component_id_gen
	_component_id_gen = _component_id_gen + 1
	return name
end

--construct a new entity
function entity:new(systems)
	return self:init({
		systems = systems,
		components = {},
		destructors = {},
		event_handlers = {},
	})
end

--by-name access
function entity:get_component(name)
	return self.components[name]
end

--shorthand
function entity:c(name)
	return self.components[name]
end

--add an existing component to this entity
function entity:add_existing_component(name, component, destructor)
	if self.components[name] ~= nil then
		error("component name clash for '"..name.."' on this entity")
	end
	self.components[name] = component
	self.destructors[name] = destructor
	return component
end

--add a component to this entity using its accessible systems
function entity:add_component(system, name, args)
	local sys = self.systems[system]
	if sys == nil then
		error("system "..system.." not registered for this entity")
	end

	if name == nil then
		name = generate_unique_name("__unnamed_component_")
	end

	--add it and move on
	local comp = sys:add(args)
	return self:add_existing_component(
		name,
		comp,
		--default destructor
		--remove from the system
		function()
			sys:remove(comp)
		end
	)
end

--remove a component by name
function entity:remove_component(name)
	--capture dtor
	local dtor = self.destructors[name]
	--shred out of the maps before calling
	self.components[name] = nil
	self.destructors[name] = nil
	--call dtor if there is one
	if (type(dtor) == "function") then
		dtor()
	end
end

--remove a component by value
--slow, because we have to walk through with pairs to find it
function entity:remove_component_by_value(comp)
	for name, c in pairs(self.components) do
		if c == comp then
			self:remove_component(name)
			return
		end
	end
end

--remove all this entity's components
function entity:remove_all_components()
	table.foreach(table.keys(self.components), function(name)
		self:remove_component(name)
	end)
end

--entity event handling
--for "fuzzy" function calls which may not even do anything
--most commonly for stuff like "hit" and "kill" where you want
--both a varied response, and the possibility of ignoring things

function entity:add_event_handler(event, handler)
	--multi-add
	if type(event) == "table" then
		table.foreach(event, function(e)
			self:add_event_handler(e, handler)
		end)
		return
	end
	--single add
	local list = self.event_handlers[event]
	if list == nil then
		list = {}
		self.event_handlers[event] = list
	end
	table.insert(list, handler)
end

--remove an event handler for a specific event
--it is an error if there is no handler to be removed
--as this call is very specific; seems like you may
function entity:remove_event_handler(event, handler)
	local list = self.event_handlers[event]
	if list == nil then
		error("cannot remove event handler, no handlers present for event "..event);
	end
	table.remove_value(list, handler)
	if #list == 0 then
		--remove list
		self.event_handlers[event] = nil
	end
end

--clear a specific handler from multiple events
function entity:remove_multi_event_handler(handler)
	for event,list in pairs(self.event_handlers) do
		for i,h in ipairs(list) do
			if h == handler then
				table.remove(list, i)
				break
			end
		end
	end
end

--remove all handlers for a specific event
function entity:remove_event_handlers(event)
	self.event_handlers[event] = nil
end

--remove all handlers completely
function entity:remove_all_event_handlers()
	self.event_handlers = {}
end

--check if an entity has handlers for an event (can be useful for providing a default impl)
function entity:has_handler(event)
	return self.event_handlers[event] ~= nil
end

--call handlers
--each handler gets called with the entity, the event, and whatever args were passed in
function entity:event(event, args)
	local list = self.event_handlers[event]
	if list ~= nil then
		table.foreach(list, function(h)
			h(self, event, args)
		end)
	end
end

--entity destruction

--(helper)
function entity:_check_double_destroyed()
	if self._destroyed then
		error("entity double-destroyed")
	end
end

--set of entities to destroy upon flush_entities
local entities_to_destroy = {}

--deferred
function entity:destroy()
	self:_check_double_destroyed()
	entities_to_destroy[self] = true
end

--immediate
function entity:destroy_now()
	self:_check_double_destroyed()
	self._destroyed = true
	self:remove_all_components()
end

--flush all deferred entities - should do this at least once per frame
function entity.flush_entities()
	local e = next(entities_to_destroy)
	while e do
		e:destroy_now()
		entities_to_destroy[e] = nil
		e = next(entities_to_destroy)
	end
end

return entity
