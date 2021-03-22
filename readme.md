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
	- `systems` -  ready-to-go system implementations; currently basically just pulled out of [deepsky](https://cannonbreed.itch.io/deepsky)
		- `event` - pubsub event bus; shared hub and individual channels
		- `behaviour_system` - miscellaneous behaviours, most of your "one off" stuff can go in here. works with `batteries.state_machine`
		- `beat_system` - things that happen on a regular time interval
		- `sprite_system` - 2d sprite rendering
		- `animation_system` - sprite animations
		- `box_physics_system` - physical responses
		- `text_system` - 2d text rendering
		- `base` - functionality often needed in a system (should grow with time as more is discovered)
- `util` - miscellaneous utilities - some might be candiates to be moved to `batteries`
	- `frequency_counter` - count a number of events over some period of time (eg. frames per second)
	- `screen_overlay` - a single colour overlay for the whole screen; useful for fades and flashes
	- `screenshake` - a simple screenshake implementation

# ECS(K) design

_(todo naming that doesn't cause confusion)_

**tl;dr:** it doesn't make sense to have an arbitrary limit of one of each type of component per entity, or to require an entity at all for some components - especially in Lua. It makes even less sense to attach a bunch of "tag" components to facilitate systems that might be operating on only one or two entities.

Ferris' sort-of-ECS dodges these problems and introduces some exciting new ones, ultimately arriving at quite a nice modular middle ground.

## Entities:

- Used for managing the setup and teardown of related components, but often not relevant beyond that. There is no persistent list of entities by default. This is the biggest difference versus most lua ECS systems.
- Creation (`entity:new()`) takes a list of systems - so you can have multiple worlds going at once, or rename systems for different entities.
- Component attachment (`entity:add_component(system, name, ...)`) does what you'd hopefully expect, creating a new component in system, naming it name as far as this entity is concerned, and passing any further args through to the system component constructor.
- Components can be accessed from the entity if needed - `entity:get_component(name)` and `entity:c(n)` are aliases and do what you'd expect. This is less important than in other ECS systems though, as the components have all required references set up ahead of time and most code does not operate on entities directly.

## Components:

- Managed by systems, self-contained as much as possible.
- May have references to components in other systems that they're dependent on (eg a sprite might want a position, though it likely accepts any vector (shared or unshared) for that position).
	- Usually any required references in their constructor and default to own-data if not provided.
- Designed to have a nice method interface, rather than be "just" data. This means they can store whatever is needed internally while still being nice to work with.
	- `sprite:set_frame(fx, fy)` changes the uvs of the quad based on the frame and texture size
	- `animation:reset()` resets timers and changes frames

## Systems:

- Do _stuff_ with their set of components.
- Are where component addition/removal happens - no entity required, strictly. This can be useful in practice for static sprites or physics bodies or one-off behaviours.
- Have "final say" when it comes to those components, including jettisoning them into space. This is most important for stuff like sorting lists of sprites on z, deferring destruction, keeping static bodies in a separate list, etc - and can really help performance.
- There's base system code with support for common system needs, like deferred removal to prevent anything funny happening when removing components mid-iteration, and registration of update/draw with the kernel.

## Kernel:

- Has a list of systems and tasks.
- Systems are as described above but have an ordering (explicit, or implicitly the order they were added). Nothing happens with them automatically, but the table of systems is often passed into entity constructors directly - this is so common there's a `kernel:entity()` method that does exactly that.
- Tasks are single functions in an ordered collection, associated with a name like "update" or "draw".
- When a system is added, it gets a register callback with the kernel
	- Systems generally add tasks for "update" + "draw" here
- Can have "other global stuff" attached as part of its table, as it's technically visible to all systems.

## Benefits:

- Can have more than one of a single component type per entity (eg many sprites or behaviours)
- Can have free-floating components without need for an entity (eg a static sprite, and maybe an animation managing the sprite, or a game rules behaviour)
- Systems can manage their own data to aid improving performance or correctness.
- Most systems can do a nice simple loop over their components to update/draw.
- Those that need it can do threading or be implemented in c++ under the hood or whatever.
- All your throwaway game code can go in the `behaviour_system` while being very easy to port to a dedicated system - animations began their lives here for example.

# Dependencies

Currently requires an up-to-date [batteries](https://github.com/1bardesign/batteries), exported globally.

This should probably be refactored out so you can provide your own path to it or similar, but they are quite tightly integrated and I'm not interested in untangling it all for now or referencing a specific version of `batteries` here.

# Installation

- Use it as a submodule or just extract the files somewhere.
- `require` the base directory.
- Please keep your hands inside, and enjoy the ride.

# License

MIT, see [license.txt](./license.txt)
