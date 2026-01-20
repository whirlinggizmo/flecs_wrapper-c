// lib/flecs_wrapper/src/flecs_wrapper_entity.c
#define FLECS_OBSERVER

#include <string.h>

#include "flecs.h"
#include "flecs_wrapper.h"

#include "flecs_wrapper_components.h"
#include "flecs_wrapper_world.h" // for world access
#include "flecs_wrapper_entity.h"

// components

// entity
// Entity id mapping:
// - Forward: entity_id -> ecs_entity_t via entity_ecs_id_table.
// - Reverse: ecs_entity_t -> entity_id via EntityId component on the entity.
// Requirements: EntityId must be registered in init_world and set on creation;
// lookups assume the ecs_entity_t is alive (guarded in get_entity_id).
// Rationale: expose stable 32-bit handles across APIs (e.g., Lua) and for
// serialization without leaking Flecs-owned ecs_entity_t values.
#define MAX_ENTITIES 65536
static ecs_entity_t entity_ecs_id_table[MAX_ENTITIES] = {0};
static uint32_t entity_ecs_id_count = 1; // reserved index 0 for unknown
static uint32_t free_entity_ids[MAX_ENTITIES] = {0};
static uint32_t free_entity_ids_count = 0;
static bool entity_id_in_free_list[MAX_ENTITIES] = {false};

static entity_id_t alloc_entity_id(void)
{
    if (free_entity_ids_count > 0)
    {
        uint32_t id = free_entity_ids[--free_entity_ids_count];
        entity_id_in_free_list[id] = false;
        return id;
    }
    if (entity_ecs_id_count >= MAX_ENTITIES)
        return 0;
    return entity_ecs_id_count++;
}

static void free_entity_id(entity_id_t id)
{
    if (id == 0 || id >= MAX_ENTITIES)
        return;
    if (entity_ecs_id_table[id] != 0)
        return;
    if (entity_id_in_free_list[id])
        return;
    if (free_entity_ids_count < MAX_ENTITIES)
    {
        free_entity_ids[free_entity_ids_count++] = id;
        entity_id_in_free_list[id] = true;
    }
    else
    {
        fprintf(stderr, "Free entity id list overflow (id %u)\n", id);
    }
}

void clear_entity_info(void)
{
    entity_ecs_id_count = 1;
    free_entity_ids_count = 0;
    memset(entity_ecs_id_table, 0, sizeof(entity_ecs_id_table));
    memset(free_entity_ids, 0, sizeof(free_entity_ids));
    memset(entity_id_in_free_list, 0, sizeof(entity_id_in_free_list));
}

entity_id_t get_entity_id(ecs_entity_t ecs_id)
{
    FLECS_WRAPPER_ASSERT_WORLD();
    if (!ecs_is_alive(world, ecs_id))
        return 0;
    const EntityId *entity_id = ecs_get(world, ecs_id, EntityId);
    if (entity_id)
        return entity_id->value;
    return 0;
}

ecs_entity_t get_entity_ecs_id(entity_id_t id)
{
    FLECS_WRAPPER_ASSERT_WORLD();
    if ((uint32_t)id < entity_ecs_id_count)
        return entity_ecs_id_table[id];
    return 0;
}

/*
// TODO: Investicate if we need this.  Maybe for reconstituting the world after a save/load? */
/*
uint32_t set_entity_id(entity_id_t entity_id, ecs_entity_t entity_ecs_id)
{
    if ((entity_id < 1) || (entity_id >= MAX_ENTITIES))
    {
        fprintf(stderr, "Unable to set ecs_id for entity_id, (out of range 1..%u) %u\n", MAX_ENTITIES - 1, entity_id);
        return 0;
    }
    if (entity_ecs_id_table[entity_id] != 0)
    {
        fprintf(stderr, "Unable to set ecs_id for entity_id %u, already set (currently %lu)\n", entity_id, entity_ecs_id_table[entity_id]);
        return 0;
    }
    entity_ecs_id_table[entity_id] = entity_ecs_id;
    ecs_set(world, entity_ecs_id, EntityId, {entity_id});
    return entity_id;
}
*/

static entity_id_t create_entity(const char *name)
{
    FLECS_WRAPPER_ASSERT_WORLD();
    entity_id_t id = alloc_entity_id();
    if (id == 0)
    {
        fprintf(stderr, "Could not create entity (max entities reached: %u)\n", MAX_ENTITIES);
        return 0;
    }

    // Sanity check
    if (entity_ecs_id_table[id] != 0)
    {
        fprintf(stderr, "The current entity index (%u) is not empty. This shouldn't happen!\n", id);
        free_entity_id(id);
        return 0;
    }

    ecs_entity_t entity_ecs_id = ecs_entity(world, {.name = name});
    if (entity_ecs_id == 0)
    {
        fprintf(stderr, "Could not create entity (ecs_entity returned 0)\n");
        free_entity_id(id);
        return 0;
    }

    entity_ecs_id_table[id] = entity_ecs_id;        // forward mapping
    ecs_set(world, entity_ecs_id, EntityId, {id});

    return id;
}

static bool destroy_entity(entity_id_t entity_id)
{
    FLECS_WRAPPER_ASSERT_WORLD();
    ecs_entity_t entity_ecs_id = get_entity_ecs_id(entity_id);
    if (entity_ecs_id == 0)
    {
        fprintf(stderr, "Could not destroy entity_id %u (entity does not exist)\n", entity_id);
        return false;
    }
    ecs_delete(world, entity_ecs_id);
    entity_ecs_id_table[entity_id] = 0;
    free_entity_id(entity_id);
    return true;
}

// exposed functions

EXPORT entity_id_t flecs_entity_create(const char *name)
{
    return create_entity(name);
}

EXPORT bool flecs_entity_destroy(entity_id_t entity_id)
{
    return destroy_entity(entity_id);
}


// removed export for now, not needed/encouraged
/*
EXPORT entity_id_t flecs_entity_get_id(uint64_t entity_ecs_id) 
{
    return get_entity_id(entity_ecs_id);
}
*/
