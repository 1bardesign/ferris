--[[
	"lazy" behaviour system, for stuff that's too specialised to be bothered
	with its own separate system
]]

local path = (...)
local base = require(path:gsub("behaviour_system", "base"))

local behaviour_system = class()

function behaviour_system:new()
	return base.add_deferred_management(
		self:init({
			--debug info
			debug = {
				updated = 0,
				drawn = 0,
			},
		})
	)
end

--add a behaviour to the system
local function _behaviour_less(a, b)
	return a.order < b.order
end

function behaviour_system:create_component(b)
	b.order = b.order or 0 --patch order if it's not present
	return b
end

function behaviour_system:add_component(b)
	table.insert_sorted(self.all, b, _behaviour_less)
end

function behaviour_system:remove_component(b)
	self:_single_call(b, "remove")
	table.remove_value(self.all, b)
end

--make a call to a single object for all arguments
function behaviour_system:_single_call(b, f_name, ...)
	local rval = nil
	local called = false
	local f = b[f_name]
	if type(f) == "function" then
		rval = f(b, ...)
		called = true
	end
	return rval, called
end

--make a call to an object for all objects
function behaviour_system:_multi_call(f_name, debug_name, ...)
	self.debug[debug_name] = 0
	--todo: consider caching filtered lists
	--      needs some infrastructure to do it "actually faster"
	--      instead of slower for every cache-rebuilding tick
	for i, b in ipairs(self.all) do
		local rval, called = self:_single_call(b, f_name, ...)
		if called then
			self.debug[debug_name] = self.debug[debug_name] + 1
		end
	end
end

function behaviour_system:update(dt)
	self:_multi_call("update", "updated", dt)
end

function behaviour_system:draw()
	love.graphics.push("all")
	self:_multi_call("draw", "drawn")
	love.graphics.pop()
end

--register tasks for kernel
function behaviour_system:register(kernel, order)
	base.do_default_register(self, kernel, order)
end

return behaviour_system
