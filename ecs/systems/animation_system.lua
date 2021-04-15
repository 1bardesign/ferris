--[[
	animation system

	animate sprites with frame by frame animations

	todo: refactor naming (animation:set_anim() is repetitive)
]]

local path = (...)
local base = require(path:gsub("animation_system", "base"))

--animation class
animation = class()
--create a new animation for a given sprite
function animation:new(sprite)
	return self:init({
		sprite = sprite,
		time = 0,
		frame = 0,
		animations = {},
		finished = false,
		anim_name = "",
		anim = false,
		enabled = true,
	})
end

--run the animation forward dt seconds
function animation:update(dt)
	local anim = self.anim
	if not anim then return end
	self.time = self.time + dt
	if self.time > anim.time then
		self.time = self.time - anim.time
		self.frame = self.frame + 1
		if self.frame > #anim.frames then
			self.finished = true
			if anim.loops then
				self.frame = 1 --(not reset, we want to keep finished flag)
				--if loops is a string, it's taken as a continuation
				if type(anim.loops) == "string" then
					self:set_anim(anim.loops)
				end
			end
		end
		self:_set_frame()
	end
end

--add a basic frame animation
function animation:add_anim(name, frames, fps, loops)
	self.animations[name] = {
		frames = frames,
		time = (fps <= 0 and 0 or 1 / fps),
		loops = loops,
	}
	return self
end

--add an animation that can also swap the texture and frame size
function animation:add_anim_multitexture(name, asset, frames_x, frames_y, frames, fps, loops)
	self.animations[name] = {
		asset = asset,
		framesize = vec2:xy(1/frames_x, 1/frames_y),
		frames = frames,
		time = (fps <= 0 and 0 or 1 / fps),
		loops = loops,
	}
	return self
end

--set the animation currently playing
function animation:set_anim(name, reset)
	self.anim = self.animations[name] or false
	if not self.anim then
		self.anim_name = ""
	elseif self.anim_name ~= name or reset then
		self.anim_name = name
		if self.anim.asset then
			--multitexture animation
			self.sprite.texture = self.anim.asset
			self.sprite.framesize:vset(self.anim.framesize)
		end
		self:reset_anim()
	end
	return self
end

--reset the currently playing animation
function animation:reset_anim()
	self.frame = 1
	self.time = 0
	self.finished = false
	self:_set_frame()
	return self
end

--alias
animation.reset = animation.reset_anim

--is the named animation playing?
function animation:is_anim(name)
	return self.anim_name == name
end

--is the current animation finished (or looped at least once)?
function animation:is_finished()
	return self.finished
end

--get the current proportional progress through the animation
function animation:progress()
	local anim = self.anim
	if not anim then return 0 end
	return math.clamp01((self.frame - 1 + self.time / anim.time) / #anim.frames)
end

--helper: get the current frame
function animation:_get_frame()
	local anim = self.anim
	if not anim then
		return nil
	end
	local frame = math.clamp(self.frame, 1, #anim.frames)
	return anim.frames[frame]
end

--helper: set the correct frame (or a previously extracted frame)
function animation:_set_frame(frames)
	frames = frames or self:_get_frame()
	if not frames then return end
	self.sprite.frame:sset(frames[1], frames[2])
end

--generate frames for this animation
function animation:generate_frames_ordered_1d(sx, sy, count, frames_x, frames_y)
	--missing frames? automatic from sprite frames
	if frames_x == nil then
		frames_x = math.floor(1 / self.sprite.framesize.x)
	end
	if frames_y == nil then
		frames_y = math.floor(1 / self.sprite.framesize.y)
	end
	--build up the frames array
	local frames = {}
	for i=1,count do
		table.insert(frames, {sx, sy})
		sx = sx + 1
		if sx >= frames_x then
			sx = 0
			sy = sy + 1
			if sy >= frames_y then
				sy = 0
			end
		end
	end
	return frames
end

function animation:generate_frames_ordered_2d(sx, sy, ex, ey, frames_x, frames_y)
	--missing frames? automatic from sprite frames
	if frames_x == nil then
		frames_x = math.floor(1 / self.sprite.framesize.x)
	end
	if frames_y == nil then
		frames_y = math.floor(1 / self.sprite.framesize.y)
	end
	local frames = {}
	--build up the frames array
	while sx ~= ex and sy ~= ey do
		table.insert(frames, {sx, sy})
		sx = sx + 1
		if sx >= frames_x then
			sx = 0
			sy = sy + 1
			if sy >= frames_y then
				sy = 0
			end
		end
	end
	return frames
end

local animation_system = class()

function animation_system:new()
	return self:init({
		--list of animations
		elements = {},
		--debug info
		debug = {
			updated = 0,
			on_screen = 0,
		},
	})
end

function animation_system:add(for_sprite)
	local anim = animation:new(for_sprite)
	table.insert(self.elements, anim)
	return anim
end

function animation_system:remove(a)
	table.remove_value(self.elements, a)
end

function animation_system:update(dt)
	--scale time if needed
	if self.timescale then
		dt = dt * self.timescale:get()
		if dt == 0 then
			return
		end
	end
	--
	local d = self.debug
	d.updated = 0
	d.on_screen = 0
	for _, a in ipairs(self.elements) do
		--only "always update" or on screen sprites
		if a.enabled then
			a:update(dt)
			--all updated
			d.updated = d.updated + 1
			--this many "matter"
			if a.sprite.on_screen then
				d.on_screen = d.on_screen + 1
			end
		end
	end
end

--register tasks for kernel
function animation_system:register(kernel, order)
	base.do_default_register(self, kernel, order)
end

return animation_system

