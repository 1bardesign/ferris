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
			--alias
			or args.image
			or args.sheet
	else
		--legacy: just provided with a texture and everything else will be set up later
		texture = args
		args = sprite_default_args
	end

	--
	assert:some(texture, "missing texture for sprite")

	--xy
	if args.pos_link then
		self.pos = args.pos_link
	elseif args.pos then
		self.pos = args.pos:copy()
	else
		self.pos = vec2(0, 0)
	end

	if args.offset_link then
		self.offset = args.offset_link
	elseif args.offset then
		self.offset = args.offset:copy()
	else
		self.offset = vec2(0, 0)
	end

	--layout
	if args.framesize_link then
		self.framesize = args.framesize_link
	elseif args.framesize then
		self.framesize = args.framesize:copy()
	else
		self.framesize = vec2(texture:getDimensions())
		if args.layout then
			self.framesize:vector_div_inplace(args.layout)
		end
	end
	if args.frame_link then
		self.frame = args.frame_link
	elseif args.frame then
		self.frame = args.frame:copy()
	else
		self.frame = vec2(0, 0)
	end

	--sprite size
	if args.size_link then
		self.size = args.size_link
	elseif args.size then
		self.size = args.size:copy()
	else
		self.size = self.framesize:copy()
	end

	--z ordering
	self.z = args.z or 0
	--rotation
	self.rot = args.rot or 0
	--enable/disable
	self.visible = true
	--track if we were on screen last frame
	self.on_screen = true
	--scale
	if args.scale_link then
		self.scale = args.scale_link
	elseif args.scale then
		self.scale = args.scale:copy()
	else
		self.scale = vec2(1, 1)
	end
	--mirror orientation (can just use scale, but sometimes this is convenient)
	self.x_flipped = false
	if args.x_flipped then
		self.x_flipped = args.x_flipped
	end
	self.y_flipped = false
	if args.y_flipped then
		self.y_flipped = args.y_flipped
	end
	--blend config
	self.alpha = args.alpha or 1
	self.blend = args.blend or "alpha"
	self.alpha_blend = args.alpha_blend or "alphamultiply"
	--shader config
	self.shader = args.shader or nil
	--tex
	self.texture = texture
	--screenspace cache
	self._screenpos = vec2()
	self._screen_rotation = 0
end

local _sprite_draw_temp_pos = vec2()
local _sprite_draw_quad = love.graphics.newQuad(0,0,0,0,1,1)
function sprite:draw(use_screenpos)
	local pos
	local rot

	if use_screenpos then
		--position in screenspace
		pos = self._screenpos:pooled_copy()
		rot = self._screen_rotation
	else
		pos = self.pos:pooled_copy()
		rot = self.rot
	end

	local size = self.size
	local frame = self.frame
	local framesize = self.framesize
	local offset = self.offset

	_sprite_draw_quad:setViewport(
		frame.x * framesize.x, frame.y * framesize.y,
		framesize.x, framesize.y,
		self.texture:getDimensions()
	)

	local scale_x = (size.x / framesize.x)
		--account for scale
		* self.scale.x
		--account for flip
		* (self.x_flipped and -1 or 1)
	local scale_y = (size.y / framesize.y)
		--account for scale
		* self.scale.y
		--account for flip
		* (self.y_flipped and -1 or 1)

	--add transformed offset into position
	local transformed_offset = self.offset
		:pooled_copy()
		:vector_mul_inplace(self.scale)
		:rotate_inplace(rot)
	pos:vector_add_inplace(transformed_offset)
	transformed_offset:release()

	--set colour and blend (shader set externally)
	love.graphics.setColor(1, 1, 1, self.alpha)
	love.graphics.setBlendMode(self.blend, self.alpha_blend)

	love.graphics.draw(
		self.texture, _sprite_draw_quad,
		pos.x, pos.y,
		rot,
		scale_x, scale_y,
		--centred
		0.5 * framesize.x,
		0.5 * framesize.y,
		--no shear
		0, 0
	)
	pos:release()
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
	self.cull_screen = args.cull_screen == true
	self.draw_screen = args.draw_screen == true
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

function sprite_system:draw(camera)
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

	local function filter_sprite(s)
		if s.visible == false then
			return false
		end
		if camera then
			local pos = s.pos
			if self.cull_screen then
				pos = s._screenpos
			end

			--add in the offset
			--todo: refactor with the same thing above
			local transformed_offset = s.offset
				:pooled_copy()
				:vector_mul_inplace(s.scale)
				:rotate_inplace(s.rot)
			pos = pos:pooled_copy()
			pos:vector_add_inplace(transformed_offset)
			transformed_offset:release()

			local hit = true --if the others fail, draw the sprite
			local hs = s.size
				:pooled_copy()
				:scalar_mul_inplace(0.5 + math.abs(math.sin(s.rot * 2)) * 0.25)
			if camera.aabb_onscreen then
				hit = camera:aabb_onscreen(pos, hs)
			elseif camera.pos and camera.halfsize then
				hit = intersect.aabb_aabb_overlap(
					camera.pos, camera.halfsize,
					pos, hs
				)
			end
			hs:release()
			return hit
		end

		return true
	end
	local function write_filter_result(s)
		local result = filter_sprite(s)
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

	--actually draw
	love.graphics.push("all")
	for _, s in ipairs(self.sprites_to_render) do
		love.graphics.setShader(s.shader or self.shader)
		s:draw(self.draw_screen)
	end
	love.graphics.pop()

	--update debug info
	self.debug.sprites = #self.sprites
	self.debug.rendered = #self.sprites_to_render
end

--register tasks for kernel
function sprite_system:register(kernel, order)
	kernel:add_task("draw", function(k)
		local use_cam
		if self.camera == true then
			--grab the kernel cam
			use_cam = kernel.camera
		else
			--(handles the nil, table, and false cases)
			use_cam = self.camera
		end

		if use_cam then
			--cull to kernel cam
			self:draw(use_cam)
		else
			--no visibility culling
			self:draw()
		end
	end, order)
end

return sprite_system
