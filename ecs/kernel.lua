--[[
	system coordination kernel
]]

--[[
	--example code

	local k = kernel:new({
			kernel_local = vars
		})
		--add systems
		--they may register tasks for themselves
		:add_system("name", ctor())
		:add_system("name", ctor())
		:add_system("name", ctor())
		--
		:add_task("task name", func(self, ...), order)

	local systems = k.systems

	k:call("task name", ...)
]]

kernel = class()

function kernel:new(vars)
	return self:init(vars or {}):reset()
end

function kernel:reset()
	--nuke the tasks and systems
	self.systems = {}
	self.tasks = {}
	--return self
	return self
end

--add a system to the kernel
function kernel:add_system(name, sys, order)
	if self.systems[name] then
		error("already added system")
	end
	self.systems[name] = sys
	--allow the system to perform some registration if relevant
	if type(sys.register) == "function" then
		sys:register(self, order or 0)
	end
	return self
end

--add a task to the kernel
function kernel:add_task(name, func, order)
	local tasks = self.tasks[name]
	if not tasks then
		tasks = {}
		self.tasks[name] = tasks
	end
	table.insert(tasks, {order or #tasks, func})
	table.stable_sort(tasks, function(a, b)
		return a[1] < b[1]
	end)
	return self
end

--run a set of tasks from the kernel
function kernel:run_task(name, ...)
	--check if we actually have tasks
	local tasks = self.tasks[name]
	if tasks ~= nil then
		--iterate if so
		for _,task in ipairs(tasks) do
			local func = task[2]
			local ret = func(self, ...)
			if ret then
				return ret
			end
		end
	end
	return nil
end

--run the update task
function kernel:update(dt)
	return self:run_task("update", dt)
end

--run the draw task
function kernel:draw()
	return self:run_task("draw")
end

return kernel
