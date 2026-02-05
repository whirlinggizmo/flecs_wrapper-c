#define FLECS_OBSERVER

#include <string.h>
#include "flecs_wrapper_pair.h"
#include "flecs_wrapper_component.h"
#include "flecs_wrapper_entity.h"
#include "flecs_wrapper_world.h"

#define PAIR_HASH_SIZE (MAX_PAIRS * 2)

static PairInfo pair_info_table[MAX_PAIRS] = {0};
static uint32_t pair_free_ids[MAX_PAIRS] = {0};
static flecs_id_pool_t pair_id_pool;
static bool pair_pool_inited = false;

static ecs_id_t pair_ecs_id_keys[PAIR_HASH_SIZE] = {0};
static uint32_t pair_ecs_id_values[PAIR_HASH_SIZE] = {0};

static uint32_t hash_u64(uint64_t val)
{
    return (uint32_t)(val * 2654435761u);
}

static inline pair_id_t make_pair_id(uint32_t index)
{
    return (pair_id_t)flecs_id_make(FLECS_ID_PAIR, index);
}

static inline uint32_t pair_id_index(pair_id_t pair_id)
{
    return flecs_id_index(pair_id);
}

static inline bool is_pair_id(pair_id_t pair_id)
{
    return flecs_id_is_type(pair_id, FLECS_ID_PAIR);
}

static void pair_ecs_hash_insert(ecs_id_t ecs_id, uint32_t index)
{
    uint32_t i = hash_u64(ecs_id) & (PAIR_HASH_SIZE - 1);
    while (pair_ecs_id_keys[i] != 0)
    {
        i = (i + 1) & (PAIR_HASH_SIZE - 1);
    }
    pair_ecs_id_keys[i] = ecs_id;
    pair_ecs_id_values[i] = index;
}

static uint32_t pair_ecs_hash_lookup(ecs_id_t ecs_id)
{
    uint32_t i = hash_u64(ecs_id) & (PAIR_HASH_SIZE - 1);
    while (pair_ecs_id_keys[i] != 0)
    {
        if (pair_ecs_id_keys[i] == ecs_id)
            return pair_ecs_id_values[i];
        i = (i + 1) & (PAIR_HASH_SIZE - 1);
    }
    return 0;
}

static void pair_ecs_hash_remove(ecs_id_t ecs_id)
{
    uint32_t i = hash_u64(ecs_id) & (PAIR_HASH_SIZE - 1);
    while (pair_ecs_id_keys[i] != 0)
    {
        if (pair_ecs_id_keys[i] == ecs_id) {
            pair_ecs_id_keys[i] = 0;
            pair_ecs_id_values[i] = 0;

            // rehash cluster
            uint32_t j = (i + 1) & (PAIR_HASH_SIZE - 1);
            while (pair_ecs_id_keys[j] != 0) {
                ecs_id_t rekey = pair_ecs_id_keys[j];
                uint32_t reval = pair_ecs_id_values[j];
                pair_ecs_id_keys[j] = 0;
                pair_ecs_id_values[j] = 0;
                pair_ecs_hash_insert(rekey, reval);
                j = (j + 1) & (PAIR_HASH_SIZE - 1);
            }
            return;
        }
        i = (i + 1) & (PAIR_HASH_SIZE - 1);
    }
}

void clear_pair_info(void)
{
    if (!pair_pool_inited) {
        flecs_id_pool_init(&pair_id_pool, MAX_PAIRS, pair_free_ids, MAX_PAIRS);
        pair_pool_inited = true;
    }
    flecs_id_pool_reset(&pair_id_pool);
    memset(pair_info_table, 0, sizeof(pair_info_table));
    memset(pair_ecs_id_keys, 0, sizeof(pair_ecs_id_keys));
    memset(pair_ecs_id_values, 0, sizeof(pair_ecs_id_values));
    memset(pair_free_ids, 0, sizeof(pair_free_ids));
}

static pair_id_t register_pair(ecs_entity_t relation_ecs_id, ecs_entity_t object_ecs_id)
{
    if (relation_ecs_id == 0 || object_ecs_id == 0)
    {
        fprintf(stderr, "Unable to register pair (relation or object is 0)\n");
        return 0;
    }

    ecs_id_t pair_ecs_id = ecs_make_pair(relation_ecs_id, object_ecs_id);
    if (pair_ecs_id == 0)
    {
        fprintf(stderr, "Unable to make pair (relation %lu, object %lu)\n", relation_ecs_id, object_ecs_id);
        return 0;
    }

    uint32_t existing = pair_ecs_hash_lookup(pair_ecs_id);
    if (existing != 0)
    {
        return make_pair_id(existing);
    }

    if (!pair_pool_inited) {
        flecs_id_pool_init(&pair_id_pool, MAX_PAIRS, pair_free_ids, MAX_PAIRS);
        pair_pool_inited = true;
    }

    uint32_t index = flecs_id_pool_alloc(&pair_id_pool);
    if (index == 0)
    {
        fprintf(stderr, "Unable to register pair (Reached MAX_PAIRS)\n");
        return 0;
    }

    pair_info_table[index].ecs_id = pair_ecs_id;
    pair_info_table[index].id = make_pair_id(index);
    pair_info_table[index].relation = relation_ecs_id;
    pair_info_table[index].object = object_ecs_id;

    uint32_t size = 0;
    if (world != NULL)
    {
        const ecs_type_info_t *ti = ecs_get_type_info(world, pair_ecs_id);
        if (ti)
        {
            size = (uint32_t)ti->size;
        }
    }
    pair_info_table[index].size = size;

    pair_ecs_hash_insert(pair_ecs_id, index);

    return pair_info_table[index].id;
}

const PairInfo *get_pair_info(pair_id_t pair_id)
{
    if (!is_pair_id(pair_id))
    {
        fprintf(stderr, "Invalid pair_id %u (invalid type)\n", pair_id);
        return NULL;
    }

    uint32_t index = pair_id_index(pair_id);
    if (index == 0 || index >= MAX_PAIRS || pair_info_table[index].ecs_id == 0)
    {
        fprintf(stderr, "Unable to get pair_info for pair_id %u (out of range 1..%u)\n", pair_id, MAX_PAIRS - 1);
        return NULL;
    }
    return &pair_info_table[index];
}

pair_id_t flecs_pair_register(component_id_t relation_component_id, entity_id_t object_entity_id)
{
    ecs_entity_t rel_ecs = get_component_ecs_id(relation_component_id);
    ecs_entity_t obj_ecs = get_entity_ecs_id(object_entity_id);
    if (rel_ecs == 0 || obj_ecs == 0)
    {
        fprintf(stderr, "Unable to make pair (invalid relation or object)\n");
        return 0;
    }
    return register_pair(rel_ecs, obj_ecs);
}

pair_id_t flecs_pair_register_entity(entity_id_t relation_entity_id, entity_id_t object_entity_id)
{
    ecs_entity_t rel_ecs = get_entity_ecs_id(relation_entity_id);
    ecs_entity_t obj_ecs = get_entity_ecs_id(object_entity_id);
    if (rel_ecs == 0 || obj_ecs == 0)
    {
        fprintf(stderr, "Unable to make pair (invalid relation or object entity)\n");
        return 0;
    }
    return register_pair(rel_ecs, obj_ecs);
}

pair_id_t flecs_pair_register_by_name(const char *relation_name, const char *object_name)
{
    if (!world)
    {
        fprintf(stderr, "Unable to make pair by name (world not initialized)\n");
        return 0;
    }

    if (!relation_name || !object_name)
    {
        fprintf(stderr, "Unable to make pair by name (null name)\n");
        return 0;
    }

    ecs_entity_t rel_ecs = ecs_lookup(world, relation_name);
    ecs_entity_t obj_ecs = ecs_lookup(world, object_name);
    if (rel_ecs == 0 || obj_ecs == 0)
    {
        fprintf(stderr, "Unable to make pair by name (%s, %s)\n", relation_name, object_name);
        return 0;
    }

    return register_pair(rel_ecs, obj_ecs);
}

bool flecs_pair_unregister(pair_id_t pair_id)
{
    if (!is_pair_id(pair_id))
    {
        return false;
    }

    uint32_t index = pair_id_index(pair_id);
    if (index == 0 || index >= MAX_PAIRS)
    {
        return false;
    }

    PairInfo *info = &pair_info_table[index];
    if (info->ecs_id == 0)
    {
        return false;
    }

    pair_ecs_hash_remove(info->ecs_id);
    memset(info, 0, sizeof(PairInfo));
    flecs_id_pool_free(&pair_id_pool, index);
    return true;
}

bool flecs_entity_add_pair(entity_id_t entity_id, pair_id_t pair_id)
{
    const PairInfo *pair_info = get_pair_info(pair_id);
    if (!pair_info)
        return false;

    ecs_entity_t entity_ecs_id = get_entity_ecs_id(entity_id);
    if (entity_ecs_id == 0)
    {
        fprintf(stderr, "Unable to add pair (invalid entity_id %u)\n", entity_id);
        return false;
    }

    ecs_add_id(world, entity_ecs_id, pair_info->ecs_id);
    return true;
}

bool flecs_entity_remove_pair(entity_id_t entity_id, pair_id_t pair_id)
{
    const PairInfo *pair_info = get_pair_info(pair_id);
    if (!pair_info)
        return false;

    ecs_entity_t entity_ecs_id = get_entity_ecs_id(entity_id);
    if (entity_ecs_id == 0)
    {
        fprintf(stderr, "Unable to remove pair (invalid entity_id %u)\n", entity_id);
        return false;
    }

    ecs_remove_id(world, entity_ecs_id, pair_info->ecs_id);
    return true;
}

bool flecs_entity_has_pair(entity_id_t entity_id, pair_id_t pair_id)
{
    const PairInfo *pair_info = get_pair_info(pair_id);
    if (!pair_info)
        return false;

    ecs_entity_t entity_ecs_id = get_entity_ecs_id(entity_id);
    if (entity_ecs_id == 0)
    {
        fprintf(stderr, "Unable to check pair (invalid entity_id %u)\n", entity_id);
        return false;
    }

    return ecs_has_id(world, entity_ecs_id, pair_info->ecs_id);
}

bool flecs_entity_set_pair(entity_id_t entity_id, pair_id_t pair_id, const void *pair_data_ptr)
{
    const PairInfo *pair_info = get_pair_info(pair_id);
    if (!pair_info)
        return false;

    ecs_entity_t entity_ecs_id = get_entity_ecs_id(entity_id);
    if (entity_ecs_id == 0)
    {
        fprintf(stderr, "Unable to set pair (invalid entity_id %u)\n", entity_id);
        return false;
    }

    if (pair_info->size == 0)
    {
        if (pair_data_ptr != NULL)
        {
            fprintf(stderr, "Warning: pair %u has no data (ignoring pointer)\n", pair_id);
        }
        ecs_add_id(world, entity_ecs_id, pair_info->ecs_id);
        return true;
    }

    ecs_set_id(world, entity_ecs_id, pair_info->ecs_id, pair_info->size, pair_data_ptr);
    return true;
}

const void *flecs_entity_get_pair(entity_id_t entity_id, pair_id_t pair_id)
{
    const PairInfo *pair_info = get_pair_info(pair_id);
    if (!pair_info)
        return NULL;

    ecs_entity_t entity_ecs_id = get_entity_ecs_id(entity_id);
    if (entity_ecs_id == 0)
    {
        fprintf(stderr, "Unable to get pair (invalid entity_id %u)\n", entity_id);
        return NULL;
    }

    return ecs_get_id(world, entity_ecs_id, pair_info->ecs_id);
}
