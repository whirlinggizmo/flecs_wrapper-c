// lib/flecs_wrapper/src/flecs_wrapper.c
#define FLECS_OBSERVER

#include <stdlib.h>
#include "flecs.h"
#include "flecs_wrapper.h"
#include "flecs_wrapper_component.h"
#include "flecs_wrapper_components.h"

#include "flecs_wrapper_world.h" // for world access


// there are fixed number of event types, so we'll just add them directly
#define event_ecs_id_count 8
static ecs_entity_t event_ecs_id_table[8];   /* 0..7 */

void init_event_table(void) {
    event_ecs_id_table[0] = 0;
    event_ecs_id_table[1] = EcsOnAdd;
    event_ecs_id_table[2] = EcsOnRemove;
    event_ecs_id_table[3] = EcsOnSet;
    event_ecs_id_table[4] = EcsOnDelete;
    event_ecs_id_table[5] = EcsOnDeleteTarget;
    event_ecs_id_table[6] = EcsOnTableCreate;
    event_ecs_id_table[7] = EcsOnTableDelete;
    printf("Event table initialized\n");
}

uint32_t get_event_id(const ecs_entity_t ecs_id)
{
    // We could use something like hash_u64, but with only 8 events, the hashing is probably slower than a linear search
    for (uint32_t i = 1; i < event_ecs_id_count; ++i)
    {
        if (event_ecs_id_table[i] == ecs_id)
        {
            return i;
        }
    }
    fprintf(stderr, "Unable to get event_id for ecs_id %lu (not found)\n", ecs_id);
    return 0;
}
ecs_entity_t get_event_ecs_id(uint32_t event_id)
{
    if (event_id < 1 || (event_id >= event_ecs_id_count))
    {
        fprintf(stderr, "Unable to get ecs_id for event_id %u (out of range 1..%u)\n", event_id, event_ecs_id_count - 1);
        return 0;
    }
    return event_ecs_id_table[event_id];
}

// observer
// defined in flecs_wrapper_event.h
// typedef void (*ObserverCallback)(const uint32_t *entity_ids, uint32_t entity_count, void **columns,
//     const uint32_t *column_component_ids, const uint32_t *column_sizes, uint32_t column_count,
//     uint32_t event_id, uint32_t component_id, uint32_t callback_id);

typedef struct ObserverCallbackContext
{
    ObserverCallback callback;
    uint32_t callback_id;
    uint32_t field_count;
    ecs_id_t field_ids[FLECS_TERM_COUNT_MAX];
    size_t field_sizes[FLECS_TERM_COUNT_MAX];
    int32_t entity_id_field_index;
    int32_t event_field_index;
    uint32_t column_count;
    component_id_t column_component_ids[FLECS_TERM_COUNT_MAX];
    uint32_t column_sizes[FLECS_TERM_COUNT_MAX];
    int32_t column_term_indices[FLECS_TERM_COUNT_MAX];
} ObserverCallbackContext;

_Static_assert(sizeof(EntityId) == sizeof(uint32_t), "EntityId must be a 32-bit handle");

// A simple static callback that is registered with flecs observers.
static void on_observed_component_changed(ecs_iter_t *it)
{
    const ObserverCallbackContext *ctx = it->callback_ctx;
    if (!ctx) {
        fprintf(stderr, "⚠️ Missing observer context in iterator callback\n");
        return;
    }

    int8_t t = (int8_t)ctx->event_field_index; // fast path for single-term observers
    if (t < 0) {
        // find out which field/term matches the event component
        for (int8_t fi = 0; fi < (int8_t)ctx->field_count; fi++) {
            if (ctx->field_ids[fi] == it->event_id) {
                t = fi;
                break;
            }
        }
    }
    if (t == -1) {
        /* Shouldn’t happen, but bail safely */
        return;
    }

    if (ctx->entity_id_field_index < 0 || ctx->entity_id_field_index >= (int32_t)ctx->field_count) {
        fprintf(stderr, "⚠️ Missing EntityId column in observer callback\n");
        return;
    }
    const EntityId *entity_ids_component = ecs_field_w_size(it, sizeof(EntityId), ctx->entity_id_field_index);
    if (!entity_ids_component) {
        fprintf(stderr, "⚠️ Missing EntityId data in observer callback\n");
        return;
    }
    const entity_id_t *entity_ids = &entity_ids_component[0].value;

    component_id_t component_id = get_component_id(it->event_id);
    uint32_t event_id = get_event_id(it->event);

    //const ComponentInfo *ci = get_component_info(cid);
    //size_t   size = ci->size;
    //void *column = ecs_field_w_size(it, size, 0);   /* term 0 */

    void *column_ptrs[FLECS_TERM_COUNT_MAX] = {0};
    for (uint32_t i = 0; i < ctx->column_count; i++) {
        column_ptrs[i] = ecs_field_w_size(it, (size_t)ctx->column_sizes[i], ctx->column_term_indices[i]);
    }

    if (ctx->callback) {
        ctx->callback(
            entity_ids,
            (uint32_t)it->count,
            column_ptrs,
            ctx->column_component_ids,
            ctx->column_sizes,
            ctx->column_count,
            event_id,
            component_id,
            ctx->callback_id
        );
    }
}

static void free_observer_callback_ctx(void *ctx)
{
    ObserverCallbackContext *cb_ctx = ctx;
    if (!cb_ctx)
        return;

    // val_gc(cb_ctx->callback, false); // pin it?  It's a static function, so no?
    free(cb_ctx);
}

// A wrapper function to register an observer
bool register_observer(
    component_id_t *component_ids,
    uint32_t num_components,
    uint32_t *event_ids,
    uint32_t num_events,
    ObserverCallback callback,
    uint32_t callback_id)
{
    //printf("Registering observer for %d components\n", num_components);

    if (num_components >= FLECS_TERM_COUNT_MAX)
    {
        fprintf(stderr, "Too many terms! Max allowed: %d\n", FLECS_TERM_COUNT_MAX);
        return false;
    }

    ecs_observer_desc_t desc = {0};
    desc.callback = on_observed_component_changed;
    uint32_t entity_id_component = flecs_component_get_id_by_name("EntityId");
    if (entity_id_component == 0) {
        fprintf(stderr, "Unabled to register observer (EntityId component not registered)\n");
        return false;
    }

    bool has_entity_id = false;
    for (uint32_t i = 0; i < num_components; i++) {
        if (component_ids[i] == entity_id_component) {
            has_entity_id = true;
            break;
        }
    }

    uint32_t effective_count = num_components + (has_entity_id ? 0 : 1);
    if (effective_count > FLECS_TERM_COUNT_MAX)
    {
        fprintf(stderr, "Too many terms! Max allowed: %d\n", FLECS_TERM_COUNT_MAX);
        return false;
    }

    uint32_t i = 0;
    for (i = 0; i < num_events; i++)
    {
        desc.events[i] = get_event_ecs_id(event_ids[i]);
        if (desc.events[i] == 0)
        {
            fprintf(stderr, "Unabled to register observer (event_id %u not found)\n", event_ids[i]);
            return false;
        }
    }
    desc.events[i] = 0; // null terminator required

    ObserverCallbackContext *callback_ctx = malloc(sizeof(ObserverCallbackContext));
    if (!callback_ctx) {
        fprintf(stderr, "Failed to allocate observer context\n");
        return false;
    }
    callback_ctx->callback_id = callback_id;
    callback_ctx->callback = callback;
    callback_ctx->field_count = effective_count;
    callback_ctx->entity_id_field_index = -1;
    callback_ctx->event_field_index = -1;

    uint32_t out_term = 0;
    uint32_t out_col = 0;
    for (uint32_t i = 0; i < num_components; i++)
    {
        if (component_ids[i] == entity_id_component) {
            continue;
        }

        const ComponentInfo *component_info = get_component_info(component_ids[i]);
        if (component_info == NULL)
        {
            fprintf(stderr, "Unabled to register observer (component_id %u not found)\n", component_ids[i]);
            free(callback_ctx);
            return false;
        }
        desc.query.terms[out_term].id = component_info->ecs_id;
        callback_ctx->field_ids[out_term] = component_info->ecs_id;
        callback_ctx->field_sizes[out_term] = component_info->size;

        callback_ctx->column_component_ids[out_col] = component_ids[i];
        callback_ctx->column_sizes[out_col] = (uint32_t)component_info->size;
        callback_ctx->column_term_indices[out_col] = (int32_t)out_term;
        out_col++;
        out_term++;
        if (out_term >= FLECS_TERM_COUNT_MAX) {
            fprintf(stderr, "Unabled to register observer (too many terms)\n");
            free(callback_ctx);
            return false;
        }
    }

    callback_ctx->column_count = out_col;
    if (num_components == 1 && component_ids[0] != entity_id_component) {
        callback_ctx->event_field_index = 0;
    }

    const ComponentInfo *entity_id_info = get_component_info(entity_id_component);
    if (!entity_id_info) {
        fprintf(stderr, "Unabled to register observer (EntityId component info missing)\n");
        free(callback_ctx);
        return false;
    }
    desc.query.terms[out_term].id = entity_id_info->ecs_id;
    callback_ctx->field_ids[out_term] = entity_id_info->ecs_id;
    callback_ctx->field_sizes[out_term] = entity_id_info->size;
    callback_ctx->entity_id_field_index = (int32_t)out_term;
    out_term++;

    desc.query.terms[out_term] = (ecs_term_t){0};

    // val_gc(callback_ctx->callback, true); // pin it?  It's a static function, so no?
    desc.callback_ctx = callback_ctx;
    desc.callback_ctx_free = free_observer_callback_ctx;

    ecs_entity_t observer = ecs_observer_init(world, &desc);

    if (observer == 0)
    {
        fprintf(stderr, "Unable to register observer\n");
        return false;
    }

    return true;
}


EXPORT bool flecs_register_observer(component_id_t *component_ids, uint32_t num_components, uint32_t *event_ids, uint32_t num_events, ObserverCallback callback, uint32_t callback_id)
{
    return register_observer(component_ids, num_components, event_ids, num_events, callback, callback_id);
}
