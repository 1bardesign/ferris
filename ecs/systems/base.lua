--[[
	base functionality often needed for a sucessful system.
]]

local base = {}

--[[
	deferred add/remove management
		put off changing the list of components til after we're done some processing
		for iteration consistency etc

		requires a `create_component` method
		optional `add_component`/`remove_component` can do any special handling required
		`add`/`remove` should not already exist

		access system.all for the components by default
]]

function base.add_deferred_management(system)
	system.all = {}
	system.to_add = {}
	system.to_remove = {}

	--sanity check
	assert(not system.add, "system should just have `add_component`, not `add`")
	assert(not system.remove, "system should just have `remove_component`, not `remove`")

	local add_impl = add_impl or system.add_component or function(self, v)
		table.insert(self.all, v)
	end
	local remove_impl = remove_impl or system.remove_component or function(self, v)
		table.remove_value(self.all, b)
	end

	local _old_update = system.update

	--patch various functionality
	function system:update(dt)
		--update
		--	double flush feels dirty BUT it enables not updating stuff
		--	that was destroyed earlier in the frame, and getting removal
		--	callbacks asap after update if they happened then
		--	it's a NOP if nothing was added/removed anyway
		self:flush()
		_old_update(self, dt)
		self:flush()
	end

	function system:add(...)
		local v = self:create_component(...)
		table.insert(self.to_add, v)
		return v
	end

	function system:remove(v)
		table.insert(self.to_remove, v)
	end

	--strip out as needed
	--this supports multiple "cascades" of resulting adds/removes
	function system:flush()
		while #self.to_add > 0 or #self.to_remove > 0 do
			--swap beforehand, so any newly added things go into here
			local _to_add = self.to_add
			local _to_remove = self.to_remove
			self.to_add = {}
			self.to_remove = {}
			for _, v in ipairs(_to_add) do
				add_impl(self, v)
			end
			for _, v in ipairs(_to_remove) do
				remove_impl(self, v)
			end
		end
	end

	return system
end

--perform default registration with a kernel
--just calls the update and draw functions of the system as appropriate
--which is often all you need for a simple system
function base.do_default_register(sys, kernel, order)
	if type(sys.update) == "function" then
		kernel:add_task("update", function(k, dt)
			sys:update(dt)
		end, order)
	end
	if type(sys.draw) == "function" then
		kernel:add_task("draw", function(k)
			sys:draw()
		end, order)
	end
end

return base
