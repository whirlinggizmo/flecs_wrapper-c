#ifndef FLECS_WRAPPER_WORLD_H
#define FLECS_WRAPPER_WORLD_H

#include "flecs.h"


#ifdef __cplusplus
extern "C" {
#endif

extern ecs_world_t *world;

#define FLECS_WRAPPER_ASSERT_WORLD() ecs_assert(world != NULL, ECS_INVALID_PARAMETER, "world is NULL")

ecs_world_t *init_world();


#ifdef __cplusplus
}
#endif

#endif // FLECS_WRAPPER_WORLD_H
