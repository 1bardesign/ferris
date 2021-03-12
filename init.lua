local path = (...)
local function relative_require(module)
	return require(path .. "." .. module)
end

return {
	--ecs
	kernel = relative_require("ecs.kernel"),
	entity = relative_require("ecs.entity"),
	base_system = relative_require("ecs.base_system"),
	systems = {
		animation_system = relative_require("ecs.systems.animation_system"),
		beat_system = relative_require("ecs.systems.beat_system"),
		behaviour_system = relative_require("ecs.systems.behaviour_system"),
		event_system = relative_require("ecs.systems.event_system"),
		sprite_system = relative_require("ecs.systems.sprite_system"),
		text_system = relative_require("ecs.systems.text_system"),
		box_physics_system = relative_require("ecs.systems.box_physics_system"),
	},

	--utility
	frequency_counter = relative_require("util.frequency_counter"),
	screenshake = relative_require("util.screenshake"),
	screen_overlay = relative_require("util.screen_overlay"),

	--input
	keyboard = relative_require("input.keyboard"),

	--important bits
	main_loop = relative_require("main_loop"),
}
