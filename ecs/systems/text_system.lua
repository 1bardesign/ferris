--[[
	graphical text system
]]

local path = (...)
local base = require(path:gsub("text_system", "base"))

local text_component = class({
	name = "text_component"
})

function text_component:new(args)
	local font = args.font or love.graphics.getFont()
	self.font = font
	self.text = love.graphics.newText(font, "")
	self.size = vec2()
	self.pos = args.pos or vec2()
	self.colour = args.colour or args.color or {1, 1, 1, 1}
	self.halign = args.halign or args.align or "center"
	self.valign = args.valign or "center"
	self:set(args.text or "")
end

function text_component:set(t)
	self.text:set(t)
	self.size:sset(self.text:getDimensions())
	return self
end

function text_component:draw()
	local x, y = self.pos:unpack()
	local w, h = self.size:unpack()
	--horizontal
	if self.halign == "left" then
		--nothing to do
	elseif self.halign == "right" then
		x = x - w
	elseif self.halign == "center" then
		x = x - w / 2
	end
	if self.valign == "top" then
		--nothing to do
	elseif self.valign == "bottom" then
		y = y - h
	elseif self.valign == "center" then
		y = y - h / 2
	end
	--position
	love.graphics.setColor(self.colour)
	love.graphics.draw(self.text, math.floor(x), math.floor(y))
end

local text_system = class({
	name = "text_system"
})

function text_system:new()
	base.add_deferred_management(self)
end

--build out component; add/remove handled by add_deferred_management
function text_system:create_component(...)
	return text_component(...)
end

function text_system:update(dt)
	--nothing to do currently, maybe some text effects like typewriter etc later?
end

function text_system:draw()
	love.graphics.push("all")
	for _, v in ipairs(self.all) do
		v:draw()
	end
	love.graphics.pop()
end

--register tasks for kernel
function text_system:register(kernel, order)
	base.do_default_register(self, kernel, order)
end

return text_system
