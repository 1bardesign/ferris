--[[
	graphical text system
]]

local path = (...)
local base = require(path:gsub("systems.text_system", "base_system"))

local text_component = class()

function text_component:new(args)
	local font = args.font or love.graphics.getFont()
	self = self:init({
		font = font,
		text = love.graphics.newText(font, ""),
		size = vec2(),
		pos = args.pos or vec2(),
		colour = args.colour or args.color or {1, 1, 1, 1},
		halign = args.halign or args.align or "center",
		valign = args.valign or "center",
	}):set(args.text or "")
	return self
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
	love.graphics.push()
	love.graphics.translate(math.floor(x), math.floor(y))
	love.graphics.setColor(self.colour)
	love.graphics.draw(self.text)
	love.graphics.pop()
end

local text_system = class()

function text_system:new()
	return base.add_deferred_removal(
		self:init({
			--list of text elements
			elements = {},
		})
	)
end

--add a behaviour to the system
function text_system:add(args)
	local e = text_component(args)
	table.insert(self.elements, e)
	return e
end

--remove a behaviour from the system
function text_system:remove(e)
	table.remove_value(self.elements, b)
end

function text_system:update(dt)
	--nothing to do currently, maybe some text effects like typewriter etc later?
end

function text_system:draw()
	love.graphics.push("all")
	for _, v in ipairs(self.elements) do
		v:draw()
	end
	love.graphics.pop()
end

--register tasks for kernel
function text_system:register(kernel, order)
	base.do_default_register(self, kernel, order)
end

return text_system
