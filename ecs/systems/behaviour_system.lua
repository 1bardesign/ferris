--[[
	"lazy" behaviour system, for stuff that's too specialised to be bothered
	with its own separate system
]]

local path = (...):gsub("systems.behaviour_system", "")
local base = require(path .. "base_system")

local behaviour_system = class()

function behaviour_system:new()
	return base.add_deferred_removal(
		self:init({
			--list of behaviours
			elements = {},
			--debug info
			debug = {
				updated = 0,
				drawn = 0,
			},
		})
	)
end

--add a behaviour to the system
function behaviour_system:add(b)
	table.insert(self.elements, b)
	return b
end

--remove a behaviour from the system
function behaviour_system:remove(b)
	--(defer any removals encountered from the call too)
	--(this can only be called at level 0)
	self._deferred_remove = 1
	self:_single_call(b, "remove")
	self._deferred_remove = 0

	table.remove_value(self.elements, b)
end

--make a call to a single object for all arguments
function behaviour_system:_single_call(b, f_name, _a, _b, _c)
	local rval = nil
	local called = false
	local f = b[f_name]
	if type(f) == "function" then
		rval = f(b, _a, _b, _c)
		called = true
	end
	return rval, called
end

--make a call to an object for all objects
--(support for up to 3 passed arguments)
function behaviour_system:_multi_call(f_name, debug_name, _a, _b, _c)
	self.debug[debug_name] = 0
	--todo: consider caching filtered lists
	--      needs some infrastructure to do it "actually faster"
	--      instead of slower for every cache-rebuilding tick
	table.foreach(self.elements, function(b)
		local rval, called = self:_single_call(b, f_name, _a, _b, _c)
		if called then
			self.debug[debug_name] = self.debug[debug_name] + 1
		end
	end)
end

function behaviour_system:update(dt)
	--todo: limit amount updated by flag
	if self.timescale then
		dt = dt * self.timescale:get()
		if dt == 0 then
			return
		end
	end
	--
	self:with_deferred_remove(function()
		self:_multi_call("update", "updated", dt)
	end)
end

function behaviour_system:draw()
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setShader()
	self:_multi_call("draw", "drawn")
end

--register tasks for kernel
function behaviour_system:register(kernel, order)
	base.do_default_register(self, kernel, order)
end

--debug console
function behaviour_system:add_console_watch(name, console)
	console:add_watch(name, function()
		local d = self.debug
		return table.concat({
			#self.elements, " total ",
			d.updated, " updated ",
			d.drawn, " drawn"
		}, "")
	end)
end

return behaviour_system
