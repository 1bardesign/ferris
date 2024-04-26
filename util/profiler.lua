--measuring the time and memory allocated by a stretch of code

local profiler = class({
	name = "profiler"
})

function profiler:new()
	self._stack = {}
	self._result = {}
	self._worst = {}
	--todo arguments?
	self._worst_count = 3
	self._worst_period = 10 --seconds
	self._hold = false
end

function profiler:push(name)
	if self._hold then
		return
	end
	if #self._stack == 0 then
		--pushing a new frame
		table.clear(self._result)
	end
	local block = {
		name = name,
		time = love.timer.getTime(),
		memory = (collectgarbage("count") * 1024),
		depth = #self._stack + 1,
		duration = 0,
	}
	table.insert(self._result, block)
	table.insert(self._stack, block)
end

function profiler:pop(name)
	if self._hold then
		return
	end

	local block = table.pop(self._stack)
	local now = love.timer.getTime()
	assert:equal(name, block.name, "profiler block names should match")
	block.duration = (now - block.time) * 1000
	block.memory = (collectgarbage("count") * 1024) - block.memory

	if #self._stack == 0 then
		--manage worst list
		--put in right position
		table.insert_sorted(self._worst, table.copy(self._result), function(a, b)
			return a[1].duration > b[1].duration
		end)
		--trim based on expiry time
		for i, v in ripairs(self._worst) do
			if now - v[1].time > self._worst_period then
				table.remove(self._worst, i)
			end
		end
		--trim too many
		if #self._worst > self._worst_count then
			table.remove(self._worst)
		end
	end
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
	self._hold = true
end

function profiler:drop_hold()
	self._hold = false
end

function profiler:clear_worst()
	table.clear(self._worst)
end

function profiler:result()
	return table.copy(self._result)
end

function profiler:format(r)
	if not r then r = self._result end
	local t = {}
	for _, v in ipairs(r) do
		if v.duration and v.memory then
			table.insert(t, (("%s% -30s %5.2fms %4.2fmb"):format(
				("| "):rep(math.max(0, v.depth-2))..("+-"):rep(v.depth > 1 and 1 or 0),
				v.name..":",
				v.duration,
				v.memory / 1024 / 1024
			)))
		end
	end
	return table.concat(t, "\n")
end

function profiler:print_result(r)
	print(self:format(r))
end

function profiler:draw_result()
	lg.push()
	local f = lg.getFont()
	local line_height = f:getHeight() * f:getLineHeight()
	local list_width = 355
	local labels = {
		"current",
		"worst",
	}
	for list_i, list in ipairs(table.append_inplace({self:result()}, self._worst)) do
		lg.push()
		for _, v in ipairs(
			table.append_inplace({
				{
					name = labels[list_i] or "",
					depth = 0,
				}
			}, list)
		) do
			lg.setColor(0, 0, 0)
			lg.rectangle("fill", -5, 0, list_width, line_height)
			lg.setColor(1, 1, 1)
			lg.push()
			lg.translate(v.depth * 10, 0)
			lg.print(v.name, 0, 0)
			if v.duration and v.memory then
				lg.printf(("%5.2fms"):format(v.duration), 100, 0, 80, "right")
				lg.printf(("%4.2fmb"):format(v.memory / 1024 / 1024), 180, 0, 80, "right")
			end
			lg.pop()
			lg.translate(0, line_height)
		end
		lg.pop()
		lg.translate(list_width + 2, 0)
	end
	lg.pop()
end

return profiler
