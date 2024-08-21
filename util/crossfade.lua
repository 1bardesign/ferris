--audio lerp manager
--useful for background music and ambient tracks

--helper class for lerping one source to another source over time
local crossfade_lerp = class({
	name = "crossfade_lerp",
})

function crossfade_lerp:new(source, volume, time, stop_source)
	self.source = source
	self.start_volume = source:getVolume()
	self.end_volume = volume
	self.stop_source = stop_source

	self.timer = timer(time, function(f)
		self.source:setVolume(math.lerp(self.start_volume, self.end_volume, f))
	end, function()
		--make sure the volume is set to the right level
		self.source:setVolume(self.end_volume)
		--todo: configurable
		if self.end_volume == 0 then
			if self.stop_source then
				self.source:stop()
			else
				self.source:pause()
			end
		end
	end)
end

function crossfade_lerp:update(dt)
	self.timer:update(dt)
end

function crossfade_lerp:done()
	return self.timer:expired()
end

function crossfade_lerp:match(source)
	return self.source == source
end

-- the actual manager class
local crossfade = class({
	name = "crossfade",
})

--construct a new crossfade object
--args is a table with fields
--	volume - optional, default 1.0
--		the (maximum) volume to set each source to (while still respecting the source's volume limits)
--	transition_time - optional, default 1.0
--		how long to fade for (can be overriden per-transition)
--	keep_playing - optional, default false
--		whether to actually stop the sources at the end, or just pause them
function crossfade:new(args)
	args = args or {}
	self._source = false
	self._lerps = {}
	self._volume = args.volume or 1.0
	self._transition_time = args.transition_time or 1.0
	self._stop_sources = not args.keep_playing
end

--keep everything up to date
function crossfade:update(dt)
	for i, v in ripairs(self._lerps) do
		v:update(dt)
		if v:done() then
			table.remove(self._lerps, i)
		end
	end
end

--transition to a new source, optionally taking a non-default time to do so
function crossfade:transition(source, time)
	if source == self._source then
		--already faded it in
		return
	end

	--allow the argument here to override if given
	time = time or self._transition_time

	--fade out
	if self._source then
		--remove previous fade
		functional.filter_inplace(self._lerps, function(v)
			return not v:match(self._source)
		end)
		--add new fade out
		table.insert(self._lerps, crossfade_lerp(self._source, 0, time, self._stop_sources))
	end

	self._source = source

	if not source then return end

	--remove any matching lerps on the same source
	functional.filter_inplace(self._lerps, function(v)
		return not v:match(source)
	end)

	--fade in
	local _, max = source:getVolumeLimits()
	local volume = math.min(max, self._volume)
	table.insert(self._lerps, crossfade_lerp(source, volume, time))
	source:play()
	
	--update both lerps
	self:update(0)
end

--check if the crossfade is "idling"
function crossfade:done()
	return #self._lerps == 0
end

return crossfade
