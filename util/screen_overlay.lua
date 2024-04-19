--[[
	a full screen overlay effect
]]

local screen_overlay = class({
	name = "screen_overlay",
})

function screen_overlay:new(size)
	size = size or vec2(love.graphics.getDimensions())
	self.size = size
	self.old_colour = {0, 0, 0, 0}
	self.colour = {0, 0, 0, 0}
	self.timer = timer()
end

function screen_overlay:fade(colour, time)
	colour = self:_decode_colour(colour)
	self.old_colour = {self:current_colour()}
	self.colour = table.copy(colour) --take a copy
	self.timer:reset(time)
end

--flash a colour on the screen, and fade it out to fully transparent
function screen_overlay:flash(colour, time)
	colour = self:_decode_colour(colour)
	self.colour = table.copy(colour)
	self.old_colour = table.copy(colour)
	colour[4] = 0 --fade to zero alpha
	self:fade(colour, time)
end

--check if the overlay is done
function screen_overlay:done()
	return self.timer:expired()
end

--update the overlay
function screen_overlay:update(dt)
	self.timer:update(dt)
end

--get the current lerped colour
function screen_overlay:current_colour()
	--get components
	local r1, g1, b1, a1 = table.unpack4(self.old_colour)
	local r2, g2, b2, a2 = table.unpack4(self.colour)
	--lerp
	local t = self.timer:progress()
	local r = math.lerp(r1, r2, t)
	local g = math.lerp(g1, g2, t)
	local b = math.lerp(b1, b2, t)
	local a = math.lerp(a1, a2, t)
	return r, g, b, a
end

--draw the overlay
function screen_overlay:draw()
	--render
	love.graphics.push("all")
	love.graphics.setColor(self:current_colour())
	love.graphics.origin()
	love.graphics.rectangle("fill", 0, 0, self.size:unpack())
	love.graphics.pop()
end

--internal

--(avoid name collision)
local unpack_argb = colour.unpack_argb
--decode a colour
function screen_overlay:_decode_colour(colour)
	--decode
	if type(colour) == "number" then
		colour = {unpack_argb(colour)}
	end
	--normalise
	if #colour < 4 then
		local r, g, b = table.unpack3(colour)
		colour[2] = g or r
		colour[3] = b or colour[2]
		colour[4] = 1
	end
	return colour
end

return screen_overlay
