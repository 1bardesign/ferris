# Ferris - Keeping Everything Spinning in Love

A messy grab bag of "good stuff".

Lockstep 60fps main loop, sort-of-ecs framework, common system implementations, and various utilities.

# Goals

- To help getting an extensible, maintainable game up and running in no time.
- To collect working implementations of commonly-needed things in one place.
- To fill the gap in ECS systems between idealistic perfection and pragmatic reality.

## Non-Goals

- To be as widely used or applicable as `batteries`
- To be "pure" ECS
- To be particularly "clean"

# Tour

- `main_loop` - A 60fps lockstep main loop which replaces `love.run`. Based on ideas from Tyler Glaiel's [Article](https://medium.com/@tglaiel/how-to-make-your-game-run-at-60fps-24c61210fe75).
- `ecs` - sort-of-ecs system
	- `kernel` - a central kernel for grouping systems and tasks together
	- `entity` - a container for components and a way of interacting with them
	- `base_system` - functionality often needed in a system (should grow with time as more is discovered)
	- `systems` -  ready-to-go system implementations; currently basically just pulled out of [deepsky](https://cannonbreed.itch.io/deepsky)
		- `animation_system` - sprite animations
		- `beat_system` - things that happen on a regular time interval
		- `behaviour_system` - miscellaneous behaviours, most of your "one off" stuff can go in here
		- `physics_system` - physical responses
		- `sprite_system` - 2d sprite rendering
- `util` - miscellaneous utilities - some might be candiates to be moved to `batteries`
	- `frequency_counter` - count a number of events over some period of time (eg. frames per second)
	- `pubsub` - a simple message bus, should be refactored into a system or attached to each entity probably to replace `entity`'s events.
	- `screenshake` - a simple screenshake implementation

# ECS design

(todo explain this)

tl;dr is that it doesn't make sense to have an arbitrary limit of one of each type of component per entity, or to require an entity at all for some components. Ferris' sort-of-ECS dodges both problems; introduces some new ones, but ultimately arrives at quite a nice modular middle ground.

# Dependencies

Currently requires [batteries](https://github.com/1bardesign/batteries) exported globally.

This should probably be refactored out so you can provide your own path to it or similar, but they are quite tightly integrated and I'm not interested in untangling it for now.

# Installation

- Use it as a submodule or just extract the files somewhere.
- `require` the base directory.
- Please keep your hands inside, and enjoy the ride.

# License

MIT, see [license.txt](./license.txt)
