--[[
	sprite ecs
]]

local path = (...)
local base = require(path:gsub("sprite_system", "base"))

--sprite type
local sprite = class({
	name = "sprite"
})

local sprite_default_args = {}
function sprite:new(args)
	local texture
	if type(args) == "table" then
		texture = args.texture
	else
		--legacy: just provided with a texture and everything else will be set up later
		texture = args
		args = sprite_default_args
	end
	--xy
	self.pos = args.pos and args.pos:copy() or vec2(0, 0)
	self.size = args.size and args.size:copy() or vec2(1, 1)
	self.offset = args.offset and args.offset:copy() or vec2(0, 0)
	--uv
	if args.framesize then
		self.framesize = args.framesize:copy()
	elseif args.layout then
		self.framesize = vec2(1, 1):vector_div_inplace(args.layout)
	else
		self.framesize = vec2(1, 1)
	end
	self.frame = args.frame and args.frame:copy() or vec2(0, 0)
	--z ordering
	self.z = args.z or 0
	--rotation
	self.rot = args.rot or 0
	--enable/disable
	self.visible = true
	--track if we were on screen last frame
	self.on_screen = true
	--mirror orientation (should just be scale...)
	self.x_flipped = false
	self.y_flipped = false
	--blend config
	self.alpha = args.alpha or 1
	self.blend = args.blend or "alpha"
	self.alpha_blend = args.alpha_blend or "alphamultiply"
	--shader config
	self.shader = args.shader or nil
	--tex
	self.texture = texture
	if self.texture then
		self.size
			:scalar_set(self.texture:getDimensions())
			:vector_mul_inplace(self.framesize)
	end
	--worldspace cache
	self._screenpos = vec2:zero()
	self._screen_rotation = 0
end

local _sprite_draw_temp_pos = vec2:zero()
function sprite:draw(quad, use_screenpos)
	local pos
	local rot

	if use_screenpos then
		--position in screenspace
		pos = self._screenpos
		rot = self._screen_rotation
	else
		pos = _sprite_draw_temp_pos:vset(self.pos)
		rot = self.rot
	end

	local size = self.size
	local frame = self.frame
	local framesize = self.framesize
	local offset = self.offset
	quad:setViewport(
		frame.x * framesize.x, frame.y * framesize.y,
		framesize.x, framesize.y
	)
	local scale_x = (size.x / framesize.x)
	local scale_y = (size.y / framesize.y)
	love.graphics.draw(
		self.texture, quad,
		pos.x, pos.y,
		rot,
		--TODO: just have scale here rather than flipped bools
		(self.x_flipped and -1 or 1) * scale_x,
		(self.y_flipped and -1 or 1) * scale_y,
		--centred
		0.5 * framesize.x - (offset.x / scale_x),
		0.5 * framesize.y - (offset.y / scale_y),
		--no shear
		0, 0
	)
end

local sprite_system = class({
	name = "sprite_system"
})

function sprite_system:new(args)
	args = args or {}
	--function for getting the screen pos
	self.transform_fn = args.transform_fn
	--the camera to use for culling, or true to use kernel cam,
	--or false/nil to use nothing
	self.camera = args.camera
	--whether to cull or draw on screen or untransformed
	self.cull_screen = type(args.cull_screen) == "boolean"
		and args.cull_screen
		or true
	self.draw_screen = type(args.draw_screen) == "boolean"
		and args.draw_screen
		or true
	self.shader = args.shader
	--texture ordering
	self.texture_order_mapping = unique_mapping:new()
	--list of sprites
	self.sprites = {}
	--filtered list
	self.sprites_to_render = {}
	--debug info
	self.debug = {
		sprites = 0,
		rendered = 0,
	}
end

function sprite_system:add(texture)
	local s = sprite(texture)
	table.insert(self.sprites, s)
	return s
end

function sprite_system:remove(s)
	table.remove_value(self.sprites, s)
end

function sprite_system:flush(camera)
	if type(self.transform_fn) == "function" then
		--apply transformation function
		for _, s in ipairs(self.sprites) do
			local tx, ty, rot = self.transform_fn(s)
			if tx then s._screenpos.x = tx end
			if ty then s._screenpos.y = ty end
			if rot then s._screen_rotation = rot + s.rot end
		end
	else
		--copy
		for _, s in ipairs(self.sprites) do
			s._screenpos:vset(s.pos)
			s._screen_rotation = s.rot
		end
	end

	--collect on screen to render
	--todo: cache this first draw run, have a flush() call for settings changes

	local filter_function = nil
	if camera == nil then
		filter_function = function(s)
			return s.visible
		end
	else
		if self.cull_screen then
			filter_function = function(s)
				return s.visible and camera:aabb_on_screen(s._screenpos, s.size)
			end
		else
			filter_function = function(s)
				return s.visible and camera:aabb_on_screen(s.pos, s.size)
			end
		end
	end
	local function write_filter_result(s)
		local result = filter_function(s)
		s.on_screen = result
		return result
	end
	self.sprites_to_render = functional.filter(self.sprites, write_filter_result)

	--sort to render
	local _torder = self.texture_order_mapping
	local function _texture_order(tex)
		return _torder:map(tex)
	end
	table.stable_sort(self.sprites_to_render, function(a, b)
		if a.z == b.z then
			--secondary sort on texture within z level for batching
			return _texture_order(a.texture) < _texture_order(b.texture)
		end
		return a.z < b.z
	end)

	--update debug info
	self.debug.sprites = #self.sprites
	self.debug.rendered = #self.sprites_to_render

end

--draw all the sprites
function sprite_system:draw()
	local q = love.graphics.newQuad(0, 0, 1, 1, 1, 1)

	love.graphics.push("all")
	for _, s in ipairs(self.sprites_to_render) do
		love.graphics.setColor(1, 1, 1, s.alpha)
		love.graphics.setBlendMode(s.blend, s.alpha_blend)
		love.graphics.setShader(s.shader or self.shader)
		s:draw(q, self.draw_screen)
	end
	love.graphics.pop()
end

--register tasks for kernel
function sprite_system:register(kernel, order)
	kernel:add_task("update", function(k, dt)
		local use_cam
		if type(self.camera) == "boolean" and self.camera then
			--grab the kernel cam
			use_cam = kernel.camera
		else
			--(handles the nil, table, and false cases)
			use_cam = self.camera
		end

		if use_cam then
			--cull to kernel cam
			self:flush(use_cam)
		else
			--no visibility culling
			self:flush()
		end
	end, order + 1000)
	kernel:add_task("draw", function(k)
		self:draw()
	end, order)
end

return sprite_system
