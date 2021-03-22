--[[
	base functionality often needed for a sucessful system.
]]

local base = {}

--[[
	deferred removal
		put off removing something til after we're done some processing
		often best to avoid order-of-operation dependence on removal,
		if removal can happen mid-update for a system, or from callbacks
		or similar
]]

function base.add_deferred_removal(system, remove_impl)

	--add required properties
	system._to_remove = {}
	system._deferred_remove = 0
	system._needs_removing = false
	system._currently_removing = false
	--copy it now, in case it was previously system.remove
	system.remove_impl = remove_impl or system.remove

	--remove a component (deferred if needed)
	function system:remove(comp)
		if self._deferred_remove > 0 then
			self._to_remove[comp] = true
			self._needs_removing = true
		else
			self:remove_impl(comp)
		end
	end

	--add a deferred removal level
	function system:push_defer_remove()
		self._deferred_remove = self._deferred_remove + 1
	end

	--remove a deferred removal level
	--perform the deferred removals if we hit the bottom of the stack
	function system:pop_defer_remove()
		--sanity check
		if self._deferred_remove == 0 then
			error('popped too many deferred remove levels')
		end
		self._deferred_remove = self._deferred_remove - 1
		if
			self._deferred_remove == 0
			and self._needs_removing
			and not self._currently_removing
		then
			--flag here so we don't re-enter here if we push/pop again inside the remove call
			self._currently_removing = true
			--(not using pairs;
			-- allows deferred removals to trigger _during_ removal and get removed here too)
			local b = next(self._to_remove)
			while b do
				self:remove(b)
				self._to_remove[b] = nil
				b = next(self._to_remove)
			end
			--release flag
			self._currently_removing = false
			self._needs_removing = false
		end
	end

	--perform some functionality with deferred removal either side
	function system:with_deferred_remove(func, ...)
		self:push_defer_remove()
		func(self, ...)
		self:pop_defer_remove()
	end

	--wrap an existing method with deferral
	--eg `sys.update = sys:wrap_deferral(sys.update)`
	function system:wrap_deferral(func)
		return function(self, ...)
			self:push_defer_remove()
			func(self, ...)
			self:pop_defer_remove()
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
