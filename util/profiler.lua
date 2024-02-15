--measuring the time and memory allocated by a stretch of code

local profiler = class({
	name = "profiler"
})

function profiler:new()
	self._stack = {}
	self._result = {}
	self._hold = false
end

function profiler:push(name)
	if #self._stack == 0 then
		--pushing a new frame
		table.clear(self._result)
	end
	local block = {
		name = name,
		time = love.timer.getTime(),
		memory = (collectgarbage("count") * 1024),
		depth = #self._stack + 1,
	}
	table.insert(self._result, block)
	table.insert(self._stack, block)
end

function profiler:pop(name)
	local block = table.pop(self._stack)
	assert:equal(name, block.name, "profiler block names should match")
	block.time = (love.timer.getTime() - block.time) * 1000
	block.memory = (collectgarbage("count") * 1024) - block.memory
end

function profiler:wrap_system(name, system)
	if system.update then
		system.update = self:wrap_function(name .. "_update", system.update)
	end
	if system.draw then
		system.draw = self:wrap_function(name .. "_draw", system.draw)
	end
	return system
end

function profiler:wrap_function(name, f)
	return function(...)
		self:push(name)
		local result = {f(...)} --capture
		self:pop(name)
		return unpack(result)
	end
end

function profiler:hold_result()
	self._hold = table.copy(self._result)
end

function profiler:drop_hold()
	self._hold = false
end

function profiler:result()
	return table.copy(self._hold or self._result)
end

function profiler:print_result()
	lg.push()
	local f = lg.getFont()
	local line_height = f:getHeight() * f:getLineHeight()
	for _, v in ipairs(self:result()) do
		lg.setColor(0, 0, 0)
		lg.rectangle("fill", -5, 0, 355, line_height)
		lg.setColor(1, 1, 1)
		lg.push()
		lg.translate(v.depth * 10, 0)
		lg.print(v.name, 0, 0)
		lg.print(("%05.2fms"):format(v.time), 150, 0)
		lg.print(("%04.2fmb"):format(v.memory / 1024 / 1024), 250, 0)
		lg.pop()
		lg.translate(0, line_height)
	end
	lg.pop()
end

return profiler
