// lib/flecs_wrapper/src/flecs_wrapper.c
#define FLECS_OBSERVER

#include "flecs.h"
#include "flecs_wrapper.h"
#include "flecs_wrapper_world.h"
#include "flecs_wrapper_component.h"
#include "flecs_wrapper_entity.h"
#include "flecs_wrapper_event.h"
#include "flecs_wrapper_system.h"
#include "flecs_wrapper_pair.h"
#include <inttypes.h>

static void flecs_wrapper_reset_state(void)
{
    clear_component_info();
    clear_pair_info();
    clear_entity_info();
    clear_event_table();
    clear_observer_info();
    clear_system_info();
}

EXPORT const char *flecs_version(void)
{
    return FLECS_VERSION;
}

EXPORT void flecs_init()
{
    // Ensure clean wrapper state even if the previous shutdown was partial.
    flecs_wrapper_reset_state();

    init_event_table();

    world = init_world();
    if (world == NULL)
    {
        fprintf(stderr, "Unable to initialize world\n");
        return;
    }
    ecs_set_threads(world, 1);
}

EXPORT void flecs_progress(float delta_time)
{
    if (world == NULL)
    {
        fprintf(stderr, "Unable to progress world (not initialized)\n");
        return;
    }
    ecs_progress(world, delta_time);
}

EXPORT void flecs_fini()
{
    if (world == NULL)
    {
        fprintf(stderr, "Unable to finalize world (not initialized)\n");
        return;
    }
    ecs_fini(world);
    world = NULL;

    // Clear wrapper registries that outlive the Flecs world.
    flecs_wrapper_reset_state();
}

EXPORT void flecs_set_threads(int32_t threads)
{
    if (world == NULL)
    {
        fprintf(stderr, "Unable to set threads (world not initialized)\n");
        return;
    }
    ecs_set_threads(world, threads);
}
