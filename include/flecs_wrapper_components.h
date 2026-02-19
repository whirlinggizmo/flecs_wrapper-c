#ifndef FLECS_WRAPPER_COMPONENTS_H
#define FLECS_WRAPPER_COMPONENTS_H

#include "flecs.h"

//
// NOTE:Don't forget to update flecs_wrapper_components.c for the actual component declarations
//

typedef struct Destination {
    float x;
    float y;
    float z;
    float speed;
} Destination;
extern ECS_COMPONENT_DECLARE(Destination);

typedef struct EntityId {
    uint32_t value;
} EntityId;
extern ECS_COMPONENT_DECLARE(EntityId);

typedef struct Position {
    float x;
    float y;
    float z;
} Position;
extern ECS_COMPONENT_DECLARE(Position);

typedef struct Velocity {
    float x;
    float y;
    float z;
} Velocity;
extern ECS_COMPONENT_DECLARE(Velocity);

#endif // FLECS_WRAPPER_COMPONENTS_H
