#include "flecs.h"

//#include "systems/destination_system.h"
//#include "systems/move_system.h"
#include "flecs_wrapper_component.h"
#include "flecs_wrapper_components.h"
#include "flecs_wrapper_world.h" 


ecs_world_t *world = NULL;


ecs_world_t *init_world() {
    world = ecs_init();

    REGISTER_COMPONENT(world, EntityId);

    // NOTE: these are not included in the build so as to not collide with user versions
    // REGISTER_COMPONENT(world, Position);
    // REGISTER_COMPONENT(world, Velocity);
    // REGISTER_COMPONENT(world, Destination);

    // Keep only wrapper-internal bookkeeping component registration here.
    // Gameplay components/systems should be registered explicitly by the host.

    return world;
}
    
