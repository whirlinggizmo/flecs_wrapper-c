#ifndef FLECS_WRAPPER_PAIR_H
#define FLECS_WRAPPER_PAIR_H

#include <stdio.h>
#include <stdbool.h>
#include <flecs.h>
#include "flecs_wrapper_types.h"
#include "flecs_wrapper_id.h"

#ifdef __cplusplus
extern "C"
{
#endif

#define MAX_PAIRS 1024

    typedef struct PairInfo
    {
        ecs_id_t ecs_id;
        pair_id_t id;
        ecs_entity_t relation;
        ecs_entity_t object;
        uint32_t size;
    } PairInfo;

    void clear_pair_info(void);

    const PairInfo *get_pair_info(pair_id_t pair_id);

    pair_id_t flecs_pair_register(component_id_t relation_component_id, entity_id_t object_entity_id);
    pair_id_t flecs_pair_register_entity(entity_id_t relation_entity_id, entity_id_t object_entity_id);
    pair_id_t flecs_pair_register_by_name(const char *relation_name, const char *object_name);
    bool flecs_pair_unregister(pair_id_t pair_id);

    bool flecs_entity_add_pair(entity_id_t entity_id, pair_id_t pair_id);
    bool flecs_entity_remove_pair(entity_id_t entity_id, pair_id_t pair_id);
    bool flecs_entity_has_pair(entity_id_t entity_id, pair_id_t pair_id);
    bool flecs_entity_set_pair(entity_id_t entity_id, pair_id_t pair_id, const void *pair_data_ptr);
    const void *flecs_entity_get_pair(entity_id_t entity_id, pair_id_t pair_id);

#ifdef __cplusplus
}
#endif

#endif // FLECS_WRAPPER_PAIR_H
