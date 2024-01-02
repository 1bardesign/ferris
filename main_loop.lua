local path = (...):gsub(".main_loop", "")
local frequency_counter = require(path..".util.frequency_counter")

local main_loop = class({
	name = "main_loop",
})
function main_loop:new(interpolate_render)
	self.frametime = 1 / 60
	self.ticks_per_second = frequency_counter()
	self.frames_per_second = frequency_counter()
	self.interpolate_render = interpolate_render or false

	--redefine main loop
	function love.run()
		if love.load then
			love.load(love.arg.parseGameArguments(arg), arg)
		end

		--(dont count love.load time)
		love.timer.step()

		--accumulator
		local frametimer = 0

		-- Main loop time.
		return function()
			-- process and handle events
			if love.event then
				love.event.pump()
				for name, a,b,c,d,e,f in love.event.poll() do
					if name == "quit" then
						if not love.quit or not love.quit() then
							return a or 0
						end
					end
					love.handlers[name](a,b,c,d,e,f)
				end
			end

			-- get time passed, and accumulate
			local dt = love.timer.step()
			-- fuzzy timing snapping
			for _, v in ipairs {1/2, 1, 2} do
				v = self.frametime * v
				if math.abs(dt - v) < 0.002 then
					dt = v
				end
			end
			-- dt clamping
			dt = math.clamp(dt, 0, 2 * self.frametime)
	 		frametimer = frametimer + dt
	 		-- accumulater clamping
			frametimer = math.clamp(frametimer, 0, 8 * self.frametime)

			local ticked = false

	 		--spin updates if we're ready
	 		while frametimer > self.frametime do
	 			frametimer = frametimer - self.frametime
	 			love.update(self.frametime) --pass consistent dt
	 			self.ticks_per_second:add()
	 			ticked = true
	 		end

	 		--render if we need to
			if
				love.graphics
				and love.graphics.isActive()
				and (ticked or self.interpolate_render)
			then
				love.graphics.origin()
				love.graphics.clear(love.graphics.getBackgroundColor())

				love.draw(frametimer / self.frametime) --pass interpolant

				love.graphics.present()
	 			self.frames_per_second:add()
			end

			--sweep garbage always
			manual_gc(1e-3)

			--give the cpu a break
			love.timer.sleep(0.001)
		end
	end
end

return main_loop
