--a pool of items to be randomly selected without repeating
local random_pool = class({
	name = "random_pool",
})

--create a new random pool object
function random_pool:new(items, replenish_count)
	self.items = items
	self.replenish_count = replenish_count or 1
	self.pool = {}
end

--get the next item
function random_pool:next()
	if #self.pool <= self.replenish_count then
		--select all the items that aren't already in the pool
		local available = functional.filter(self.items, function(v)
			return not table.contains(self.pool, v)
		end)
		--randomise the order
		table.shuffle(available)
		--stick em at the back
		table.append_inplace(self.pool, available)
	end
	return table.shift(self.pool)
end

return random_pool
