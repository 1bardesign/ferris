--[[
	sprite ecs
]]

local path = (...)
local base = require(path:gsub("sprite_system", "base"))
local unique_mapping = require(path:gsub("ecs.systems.sprite_system", "util.unique_mapping"))

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
	self.colour = {1, 1, 1}
	self.alpha = args.alpha or 1
	self.blend = args.blend or "alpha"
	self.alpha_blend = args.alpha_blend or "alphamultiply"
	--shader config
	self.shader = args.shader or false
	self.shader_uniforms = args.shader_uniforms or false
	--tex
	self.texture = texture
	--screenspace cache
	self._screenpos = vec2()
	self._screen_rotation = 0
end

local _sprite_draw_temp_pos = vec2()
local _sprite_draw_quad = love.graphics.newQuad(0,0,0,0,1,1)
function sprite:draw()
	--positioned beforehand
	local pos = self._screenpos:pooled_copy()
	local rot = self._screen_rotation

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
	love.graphics.setColor(self.colour[1], self.colour[2], self.colour[3], self.colour[4] or self.alpha)
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
	--preserve z ordering of sprites dynamically
	self.z_order = true
	--whether to cull sprites based on the camera
	self.cull = args.cull == true
	--the shader to use
	self.shader = args.shader
	--list of sprites
	self.sprites = {}
	--filtered list
	self.sprites_to_render = {}
	--debug info
	self.debug = {
		sprites = 0,
		rendered = 0,
	}
	--texture ordering
	local _order = unique_mapping()
	self.sprite_order = function(a, b)
		local a_order = a.z
		local b_order = b.z
		if not args.preserve_order then
			if a_order == b_order then
				--secondary sort on texture within z level for batching
				a_order = _order:map(a.texture)
				b_order = _order:map(b.texture)
				if a_order == b_order then
					--final sort on shader
					a_order = _order:map(a.shader or 0)
					b_order = _order:map(b.shader or 0)
				end
			end
		end
		return a_order < b_order
	end

	local function filter_sprite(s)
		if s.visible == false then
			return false
		end
		local camera = self.camera
		if camera then
			local pos = s._screenpos

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
			pos:release()
			hs:release()
			return hit
		end

		return true
	end
	self.filter_and_store = function(s)
		local result = filter_sprite(s)
		s.on_screen = result
		return result
	end
end

function sprite_system:add(texture)
	local s = sprite(texture)
	table.insert(self.sprites, s)
	return s
end

function sprite_system:remove(s)
	table.remove_value(self.sprites, s)
end

function sprite_system:_cache_pos(sprites)
	--cache the screen position
	if type(self.transform_fn) == "function" then
		--draw in screenspace
		self.draw_screen = true
		--apply transformation function
		for _, s in ipairs(sprites) do
			local tx, ty, rot = self.transform_fn(s)
			if tx then s._screenpos.x = tx end
			if ty then s._screenpos.y = ty end
			if rot then s._screen_rotation = rot end
		end
	else
		--copy
		for _, s in ipairs(sprites) do
			s._screenpos:vset(s.pos)
			s._screen_rotation = s.rot
		end
	end
end

function sprite_system:draw(camera)
	--
	self.camera = camera

	--
	self:_cache_pos(self.sprites)

	--sort whole list (insertion is adaptive so as long as the z orders are fairly consistent, it'll be faster over time than anything else)
	if self.z_order then
		table.insertion_sort(self.sprites, self.sprite_order)
	end

	--collect on screen to render
	self.sprites_to_render = functional.filter(self.sprites, self.filter_and_store)

	--temporary (immediate mode) sprites
	if self.immediate_sprites then
		--dump them in (no culling)
		self:_cache_pos(self.immediate_sprites)
		table.append_inplace(self.sprites_to_render, self.immediate_sprites)
		--sort again
		table.insertion_sort(self.sprites_to_render, self.sprite_order)
		--clear for next frame
		table.clear(self.immediate_sprites)
	end

	--actually draw
	love.graphics.push("all")
	for _, s in ipairs(self.sprites_to_render) do
		--figure out the shader we're talking about
		local shader = nil
		if self.shader then shader = self.shader end
		if s.shader then shader = s.shader end
		love.graphics.setShader(shader)
		--if there's uniforms, send them (slow)
		if s.shader_uniforms and shader then
			for _, v in ipairs(s.shader_uniforms) do
				shader:send(v[1], v[2])
			end
		end
		s:draw()
	end
	love.graphics.pop()

	--update debug info
	self.debug.sprites = #self.sprites
	self.debug.rendered = #self.sprites_to_render
end

--draw a sprite in immediate mode
--	it'll be dropped after being drawn
--	wasteful but helpful to be able to eg inject ui elements into the sprite list without managing long-lived components
function sprite_system:immediate_mode(args)
	--init
	if not self.immediate_sprites then self.immediate_sprites = {} end
	--construct
	local s = sprite(args)
	table.insert(self.immediate_sprites, s)
	--return in case we want to tweak it
	return s
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
