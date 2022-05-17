--[[
	core entity class

	handles ordered creation and destruction of components from a given set of systems
]]
local entity = class({
	name = "entity",
})

--unique name handler
local _component_id_gen = 0
local function generate_unique_name(fragment)
	local name = fragment.._component_id_gen
	_component_id_gen = _component_id_gen + 1
	return name
end

--construct a new entity
function entity:new(systems)
	self.systems = systems
	--component and destructor storage
	self.components = {}
	self.origin_system = {}
	self.destructors = {}
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
function entity:add_existing_component(name, component, system, destructor)
	if self.components[name] ~= nil then
		error("component name clash for '"..name.."' on this entity")
	end
	self.components[name] = component
	self.origin_system[name] = system
	self.destructors[name] = destructor
	return component
end

--default destructor for components
--just remove from the system they were added from
local function call_default_destructor(entity, component, system)
	system:remove(component)
end

--add a component to this entity using its accessible systems
function entity:add_component(system, name, ...)
	local sys = self.systems[system]
	if sys == nil then
		error("system "..system.." not registered for this entity")
	end

	if name == nil then
		name = generate_unique_name("__unnamed_component_")
	end

	--add it and move on
	local comp = sys:add(...)
	return self:add_existing_component(
		name,
		comp,
		sys,
		call_default_destructor
	)
end

--remove a component by name
function entity:remove_component(name)
	--capture, then shred out before calling
	local component = self.components[name]
	local system = self.origin_system[name]
	local destructor = self.destructors[name]
	self.components[name] = nil
	self.origin_system[name] = nil
	self.destructors[name] = nil
	--call dtor if there is one
	if type(destructor) == "function" then
		destructor(self, component, system)
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
	for _, name in ipairs(table.keys(self.components)) do
		self:remove_component(name)
	end
end

--entity destruction

--(helper to check if something was already destroyed, but we're destroying it again)
function entity:_check_double_destroyed()
	if self._destroyed then
		error("entity double-destroyed")
	end
end

--set of entities to destroy upon flush_entities
local entities_to_destroy = set()

--deferred
function entity:destroy()
	self:_check_double_destroyed()
	entities_to_destroy:add(self)
end

--immediate
function entity:destroy_now()
	self:_check_double_destroyed()
	self._destroyed = true
	self:remove_all_components()
end

--flush all deferred entities - should do this at least once per frame
function entity.flush_entities()
	if entities_to_destroy:size() > 0 then
		for _, e in entities_to_destroy:ipairs() do
			e:destroy_now()
		end
		entities_to_destroy:clear()
	end
end

return entity
