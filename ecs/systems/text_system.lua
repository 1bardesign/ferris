--[[
	"lazy" behaviour system, for stuff that's too specialised to be bothered
	with its own separate system
]]

local path = (...):gsub("systems.text_system", "")
local base = require(path .. "base_system")

local text_component = class()

function text_component:new(args)
	local font = args.font or love.graphics.getFont()
	self = self:init({
		font = font,
		text = love.graphics.newText(font, args.text or ""),
		pos = args.pos or vec2(),
		halign = args.halign or args.align or "center",
		valign = args.valign or "center",
	})
	return self
end

function text_component:set(t)
	self.text:set(t)
end

function text_component:draw()
	local x, y = self.pos:unpack()
	local w, h = self.text:getDimensions()
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
	lg.push()
	lg.translate(math.floor(x), math.floor(y))
	lg.draw(self.text)
	lg.pop()
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
	for _, v in ipairs(self.elements) do
		v:draw()
	end
end

--register tasks for kernel
function text_system:register(kernel, order)
	base.do_default_register(self, kernel, order)
end

return text_system
