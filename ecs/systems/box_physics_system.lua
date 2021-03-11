--[[
	physics system

	todo: refactor to use batteries.set instead of pairs
]]

local path = (...):gsub("systems.box_physics_system", "")
local base = require(path .. "base_system")

--physical body
local body = class()

--todo: refactor this so that system ref is only
--      stored once, rather than back ref in every body
function body:new(sys, args)
	return self:init({
		--system ref
		sys = sys,
		--aabb
		pos = args.pos or vec2:zero(),
		halfsize = args.halfsize or (args.size or vec2:zero()):smul(0.5),
		size = args.size or (args.halfsize or vec2:zero()):smul(2),
		--newton integration
		oldpos = (args.pos and args.pos:copy()) or vec2:zero(),
		vel = args.vel or vec2:zero(),
		acc = args.acc or vec2:zero(),
		--tracking the entity
		entity = args.entity,
		--tracking collisions
		collided = {up = false, down = false, left = false, right = false},
		collisions = {},
	})
end

--return true on overlap, false otherwise
function body:overlap_point(v)
	return intersect.aabb_point_overlap(self.pos, self.halfsize, v)
end

--return true on overlap, false otherwise
function body:overlap(other)
	return intersect.aabb_aabb_overlap(self.pos, self.halfsize, other.pos, other.halfsize)
end

--discrete displacement
--return msv on collision, false otherwise
function body:collide(other, into)
	return intersect.aabb_aabb_collide(self.pos, self.halfsize, other.pos, other.halfsize, into)
end

--return normal and fraction of dt encountered on collision, false otherwise
function body:collide_continuous(other, into)
	return intersect.aabb_aabb_collide_continuous(
		self.oldpos, self.pos, self.halfsize,
		other.oldpos, other.pos, other.halfsize,
		into
	)
end

--flush this body's collision record
function body:flush_collisions()
	--clear collision list
	if #self.collisions > 0 then
		self.collisions = {}
	end
	--reset directions
	self.collided.up = false
	self.collided.down = false
	self.collided.left = false
	self.collided.right = false
end

--set the body active
function body:set_active()
	self.sys:set_active(self)
end

--set the body static
function body:set_static()
	self.sys:set_static(self)
end

--set a new size
function body:set_size(size)
	self.size:vset(size)
	self.halfsize:vset(size):smuli(0.5)
end

--physics system
local box_physics_system = class()

function box_physics_system:new()
	local sys = self:init({
		--sets of bodies
		active_bodies = {},
		static_bodies = {},
		--shape collision groupings
		--todo: rework as sets, cache sequence version for iteration
		groups = {},
	})

	return base.add_deferred_removal(sys)
end

--call a function for all active bodies
function box_physics_system:foreach_active(func)
	self:with_deferred_remove(function(self)
		for body in pairs(self.active_bodies) do
			func(body)
		end
	end)
end

--call a function for all static bodies
function box_physics_system:foreach_static(func)
	self:with_deferred_remove(function(self)
		for body in pairs(self.static_bodies) do
			func(body)
		end
	end)
end

--call a function for all bodies in a group
function box_physics_system:foreach_group(group, func)
	self:with_deferred_remove(function(self)
		for _,body in ipairs(self:group(group)) do
			func(body)
		end
	end)
end

--call a function for all bodies
function box_physics_system:foreach_all(func)
	self:with_deferred_remove(function(self)
		self:foreach_active(func)
		self:foreach_static(func)
	end)
end

function box_physics_system:update(dt)
	--time dilation
	if self.timescale then
		dt = dt * self.timescale:get()
		if dt == 0 then
			return
		end
	end

	--integrate active
	self:foreach_active(function(body)
		--copy
		body.oldpos:vset(body.pos)
		--integrate
		body.vel:fmai(body.acc, dt)
		if body.maxvel then
			body.vel.x = math.clamp(body.vel.x, -body.maxvel.x, body.maxvel.x)
			body.vel.y = math.clamp(body.vel.y, -body.maxvel.y, body.maxvel.y)
		end
		body.pos:fmai(body.vel, dt)
	end)
end

--static mode
function box_physics_system:set_static(body)
	if body.static ~= true then
		--update sets
		self.active_bodies[body] = nil
		self.static_bodies[body] = true
		--update flag
		body.static = true
	end
end

--active mode
function box_physics_system:set_active(body)
	if body.static ~= false then
		--update sets
		self.static_bodies[body] = nil
		self.active_bodies[body] = true
		--update flag
		body.static = false
	end
end

--add/remove shape
function box_physics_system:add(args)
	local shape = body:new(self, args)
	--handle static/active
	if args.static then
		self:set_static(shape)
	else
		self:set_active(shape)
	end
	--handle groups
	if type(args.group) == "string" then
		self:add_group(shape, args.group)
	elseif type(args.groups) == "table" then
		self:update_groups(shape, args.groups)
	end
	return shape
end

function box_physics_system:remove(body)
	self:remove_all_groups(body)
	self.active_bodies[body] = nil
	self.static_bodies[body] = nil
end

--group handling
function box_physics_system:add_group(shape, group)
	if not self.groups[group] then
		self.groups[group] = {}
	end
	local group_tab = self.groups[group]
	table.insert(group_tab, shape)
end

function box_physics_system:add_groups(shape, groups)
	for _, group in ipairs(groups) do
		self:add_group(shape, group)
	end
end

function box_physics_system:remove_group(shape, group)
	if not self.groups[group] then
		return
	end
	table.remove_value(self.groups[group], shape)
end

function box_physics_system:remove_groups(shape, groups)
	for _, group in ipairs(groups) do
		self:remove_group(shape, group)
	end
end

function box_physics_system:remove_all_groups(shape)
	for name, v in pairs(self.groups) do
		self:remove_group(shape, name)
	end
end

function box_physics_system:update_groups(shape, groups)
	self:remove_all_groups(shape)
	self:add_groups(shape, groups)
end

--get a group from a string (or pass anything else unchanged)
function box_physics_system:group(v)
	if type(v) == "string" then
		if not self.groups[v] then
			self.groups[v] = {}
		end
		return self.groups[v]
	end
	return v
end

--point test query

function box_physics_system:query_point(v, filter)
	local ret = {}
	self:foreach_all(function(body)
		if filter(body) and body:overlap_point(v) then
			table.insert(ret, body)
		end
	end)
	return ret
end

--call a function for all filtered pairs between groups
function box_physics_system:_call_filtered_pairs(group_a, group_b, filter, func)
	--defer
	self:push_defer_remove()

	--parse args
	group_a = self:group(group_a)
	group_b = self:group(group_b)

	local function call_if_filtered(a, b)
		local filter_result = filter(a, b) or false
		if filter_result then
			func(a, b, filter_result)
		end
	end

	if group_a == group_b then
		--minimal pairs
		for i=1,#group_a do
			local a = group_a[i]
			for j=i+1,#group_a do
				local b = group_a[j]
				call_if_filtered(a, b)
			end
		end
	else
		--"full" pairs (end up with double order a->b, b->a)
		for i=1,#group_a do
			local a = group_a[i]
			for j=1,#group_b do
				local b = group_b[j]
				if a ~= b then
					call_if_filtered(a, b)
				end
			end
		end
	end

	self:pop_defer_remove()
end

--call a function for the best n pairs between groups
function box_physics_system:_call_minimum_pairs(group_a, group_b, passes, filter, func)
	--defer
	self:push_defer_remove()

	--parse args
	group_a = self:group(group_a)
	group_b = self:group(group_b)

	--minimum result handling
	local minimum_factor, minimum_a, minimum_b, minimum_result
	local function clear_minimum()
		minimum_factor = math.huge
		minimum_result = nil
	end

	local function check_minimum(a, b)
		local filter_result, sort_factor = filter(a, b)
		if
			filter_result and
			sort_factor < minimum_factor and
			(minimum_a ~= a or minimum_b ~= b) --new pair
		then
			minimum_factor = sort_factor
			minimum_a = a
			minimum_b = b
			minimum_result = filter_result
		end
	end

	local function call_minimum()
		if minimum_result then
			func(minimum_a, minimum_b, minimum_result)
			return true
		end
		return false
	end

	if group_a == group_b then
		--minimal pairs
		for i = 1, #group_a do
			for _ = 1, passes do
				clear_minimum()
				local a = group_a[i]
				for j = i + 1, #group_a do
					local b = group_a[j]
					check_minimum(a, b)
				end
				--call, or bail out of more passes if we found nothing
				if not call_minimum() then break end
			end
		end
	else
		for i = 1, #group_a do
			for _ = 1, passes do
				clear_minimum()
				local a = group_a[i]
				for j = 1, #group_b do
					local b = group_b[j]
					if a ~= b then
						check_minimum(a, b)
					end
				end
				--call, or bail out of more passes if we found nothing
				if not call_minimum() then break end
			end
		end
	end

	self:pop_defer_remove()
end

--overlap functions

--call a callback for overlapping shapes
function box_physics_system:overlap(group_a, group_b, func)
	self:_call_filtered_pairs(group_a, group_b, function(a, b)
		return a:overlap(b)
	end, func)
end

--call a callback for overlapping active shapes
function box_physics_system:overlap_active(group_a, group_b, func)
	self:_call_filtered_pairs(group_a, group_b, function(a, b)
		return not (a.static and b.static) and a:overlap(b)
	end, func)
end

--call a callback for overlapping shapes (both active)
function box_physics_system:overlap_both_active(group_a, group_b, func)
	self:_call_filtered_pairs(group_a, group_b, function(a, b)
		return not a.static and not b.static and a:overlap(b)
	end, func)
end

--collide function

--call a callback for colliding shapes with msv
function box_physics_system:collide(group_a, group_b, func)
	self:_call_filtered_pairs(group_a, group_b, function(a, b)
		return a:collide(b)
	end, func)
end

--call a callback for colliding active shapes with msv
function box_physics_system:collide_active(group_a, group_b, func)
	self:_call_filtered_pairs(group_a, group_b, function(a, b)
		return not (a.static and b.static) and a:collide(b)
	end, func)
end

--call a callback for colliding shapes with msv
function box_physics_system:collide_both_active(group_a, group_b, func)
	self:_call_filtered_pairs(group_a, group_b, function(a, b)
		return not a.static and not b.static and a:collide(b)
	end, func)
end

--call a callback for continuously colliding shapes with msv
function box_physics_system:collide_continuous(group_a, group_b, func, passes)
	self:_call_minimum_pairs(group_a, group_b, passes, function(a, b)
		return a:collide_continuous(b)
	end, func)
end

--call a callback for continuously colliding active shapes with msv
function box_physics_system:collide_continuous_active(group_a, group_b, func, passes)
	self:_call_minimum_pairs(group_a, group_b, passes, function(a, b)
		if not (a.static and b.static) then
			return a:collide_continuous(b)
		end
	end, func)
end

--call a callback for continuously colliding shapes with msv
function box_physics_system:collide_continuous_both_active(group_a, group_b, func, passes)
	self:_call_minimum_pairs(group_a, group_b, passes, function(a, b)
		if not a.static and not b.static then
			return a:collide_continuous(b)
		end
	end, func)
end

--builtin functions for tracking collisions
--update collided directions based on collision separating vector
function box_physics_system.collision_directions_from_separating_vector(body, sv)
	if sv.x > 0 then
		body.collided.left = true
	elseif sv.x < 0 then
		body.collided.right = true
	end

	if sv.y > 0 then
		body.collided.up = true
	elseif sv.y < 0 then
		body.collided.down = true
	end
end

--update bodies' collided directions based on col
function box_physics_system.record_single_collision_direction(a, b, col)
	box_physics_system.collision_directions_from_separating_vector(a, col)
end

function box_physics_system.record_both_collision_directions(a, b, col)
	local msv_temp = col:pooled_copy(col)
	box_physics_system.collision_directions_from_separating_vector(a, msv_temp)
	msv_temp:smuli(-1)
	box_physics_system.collision_directions_from_separating_vector(b, msv_temp)
	msv_temp:release()
end

--record a collision in the collision list
function box_physics_system.record_single_collision(a, b)
	table.insert(a.collisions, b)
end

function box_physics_system.record_both_collisions(a, b)
	table.insert(a.collisions, b)
	table.insert(b.collisions, a)
end

--record both a collision happening, and the collision direction for each body
function box_physics_system.record_single_collision_and_direction(a, b, col)
	box_physics_system.record_single_collision_direction(a, b, col)
	box_physics_system.record_single_collision(a, b, col)
end

function box_physics_system.record_both_collisions_and_directions(a, b, col)
	box_physics_system.record_both_collision_directions(a, b, col)
	box_physics_system.record_both_collisions(a, b, col)
end

--resolution only
function box_physics_system.make_resolve_fn(amount, ratio)
	local amount_a = ratio * amount
	local amount_b = ratio * (1.0 - amount)
	local tmp = vec2:zero()
	--todo: compile out branchless versions?
	return function(a, b, col)
		--a offset
		if amount_a > 0 then
			tmp:vset(col):smuli(amount_a)
			a.pos:vaddi(tmp)
		end
		--b offset
		if amount_b > 0 then
			tmp:vset(col):smuli(-amount_b)
			b.pos:vaddi(tmp)
		end
	end
end

--builtin resolutions
--"a only" resolutions
box_physics_system.resolve_soft = box_physics_system.make_resolve_fn(0.5, 1.0)
box_physics_system.resolve_hard = box_physics_system.make_resolve_fn(1.0, 1.0)
--"both" resolutions
box_physics_system.resolve_both_soft = box_physics_system.make_resolve_fn(0.5, 0.5)
box_physics_system.resolve_both_hard = box_physics_system.make_resolve_fn(1.0, 0.5)

--resolution and response
local function velocity_response_gamey(body, msv, amount)
	local svx = math.sign(body.vel.x)
	local ssx = math.sign(msv.x)
	if (svx * ssx) ~= 0 and svx ~= ssx then
		body.vel.x = body.vel.x * (1.0 - amount)
	end
	local svy = math.sign(body.vel.y)
	local ssy = math.sign(msv.y)
	if (svy * ssy) ~= 0 and svy ~= ssy then
		body.vel.y = body.vel.y * (1.0 - amount)
	end
end

function box_physics_system.make_response_fn(amount, ratio)
	local amount_a = ratio * amount
	local amount_b = ratio * (1.0 - amount)
	local tmp = vec2:zero()
	--todo: compile out branchless versions? luajit should do a fine job of it tbh
	return function(a, b, col)
		--a offset
		if amount_a > 0 then
			tmp:vset(col):smuli(amount_a)
			a.pos:vaddi(tmp)
			velocity_response_gamey(a, tmp, amount_a)
		end
		--b offset
		if amount_b > 0 then
			tmp:vset(col):smuli(-amount_b)
			b.pos:vaddi(tmp)
			velocity_response_gamey(b, tmp, amount_b)
		end
	end
end

--builtin resolutions
--"a only" resolutions
box_physics_system.response_soft = box_physics_system.make_response_fn(0.5, 1.0)
box_physics_system.response_hard = box_physics_system.make_response_fn(1.0, 1.0)
--"both" resolutions
box_physics_system.response_both_soft = box_physics_system.make_response_fn(0.5, 0.5)
box_physics_system.response_both_hard = box_physics_system.make_response_fn(1.0, 0.5)

--visual inspection
function box_physics_system:debug_draw(scale)
	love.graphics.push("all")
	for i,v in ipairs({
		{self.static_bodies, 0x8000ffff},
		{self.active_bodies, 0x80ff00ff},
	}) do
		love.graphics.setColor(math.getColorARGBHex(v[2]))
		for b in pairs(v[1]) do
			love.graphics.rectangle(
				"fill",
				(b.pos.x - b.halfsize.x) * scale,
				(b.pos.y - b.halfsize.y) * scale,
				b.size.x * scale, b.size.y * scale
			)
		end
	end
	love.graphics.pop()
end

return box_physics_system
