--[[
	unique mapping

	generate a mapping from unique values to plain numbers
	useful for arbitrarily ordering things that don't have
	a natural ordering in lua (eg textures for batching)
]]

local unique_mapping = class({
	name = "unique_mapping",

})

--create a new unique mapping
function unique_mapping:new()
	self.vars = {}
	self.current_index = 0
end

--private;
--get the next index for this mapping
function unique_mapping:_increment()
	self.current_index = self.current_index + 1
	return self.current_index
end

--get or build a mapping for a passed value
function unique_mapping:map(value)
	local val = self[value]
	if val then
		return val
	end
	local i = self:_increment()
	self[value] = i
	return i
end

--get a function representing an a < b comparision that can be used
--with table.sort and friends, like `table.sort(values, mapping:compare())`
function unique_mapping:compare()
	--	memoised so it doesn't generate garbage, but also doesn't
	--	allocate until it's actually used
	if not self._compare then
		self._compare = function(a, b)
			return self:map(a) < self:map(b)
		end
	end
	return self._compare
end

return unique_mapping
