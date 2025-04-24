// lib/flecs_wrapper/src/flecs_wrapper_system.c

#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>

#include "flecs.h"
#include "flecs_wrapper.h"
#include "flecs_wrapper_component.h"
#include "flecs_wrapper_world.h"
//#include "systems/trampoline_system.h" // for TrampolineSystem & TrampolineSystemContext

typedef struct TrampolineSystemContext
{
    SystemCallback callback;
    uint32_t callback_id;
} TrampolineSystemContext;

// --- Cleanup for batch trampoline ---
static void free_trampoline_ctx(void *ctx) {
    if (ctx) free(ctx);
}

// --- ECS callback for batch system ---
static void trampoline_system(ecs_iter_t *it) {
    TrampolineSystemContext *ctx = (TrampolineSystemContext *)it->callback_ctx;
    if (!ctx) {
        fprintf(stderr, "⚠️ Missing system context in iterator callback\n");
        return;
    }

    // Build a temporary ptr array just like before
    void *componentPtrs[FLECS_TERM_COUNT_MAX] = {0};

    for (int i = 0; i < it->field_count; i++) {
        ecs_id_t component_ecs_id = ecs_field_id(it, i);
        size_t component_size = get_component_size_by_ecs_id(component_ecs_id);
        componentPtrs[i] = ecs_field_w_size(it, component_size, i);
    }

    // Now call the stored callback from the context
    if (ctx->callback) {
        ctx->callback(
            it->entities,
            it->count,
            componentPtrs,
            it->field_count,
            it->delta_time,
            ctx->callback_id
        );
    } else {
        fprintf(stderr, "⚠️ Iterator callback was NULL for callback_id=%u\n", ctx->callback_id);
    }
}


// --- Registration for batch-based iterator systems ---
static ecs_entity_t register_system(
    const char* name,
    uint32_t* components,
    uint32_t num_components,
    SystemCallback callback,
    uint32_t callback_id
) {
    ecs_system_desc_t desc = {0};
    desc.callback = trampoline_system;
    desc.entity = ecs_entity(world, {
        .name = name,
        .add = ecs_ids(ecs_dependson(EcsOnUpdate))
    });

    if (num_components > FLECS_TERM_COUNT_MAX) {
        fprintf(stderr, "Too many components! Max allowed: %d\n", FLECS_TERM_COUNT_MAX);
        return 0;
    }

    for (uint32_t i = 0; i < num_components; i++) {
        const ComponentInfo *component_info = get_component_info(components[i]);
        if (!component_info) {
            fprintf(stderr, "Unable to register iter system (component_id %u not found)\n", components[i]);
            return 0;
        }
        desc.query.terms[i].id = component_info->ecs_id;
        desc.query.terms[i].oper = EcsAnd;
    }
    desc.query.terms[num_components] = (ecs_term_t){0};

    TrampolineSystemContext *cb_ctx = malloc(sizeof(TrampolineSystemContext));
    cb_ctx->callback = callback;          
    cb_ctx->callback_id = callback_id;

    desc.callback_ctx = cb_ctx;
    desc.callback_ctx_free = free_trampoline_ctx;

    ecs_entity_t system = ecs_system_init(world, &desc);
    return system;
}


// --- Registration for per-entity systems (original) ---
/*
static ecs_entity_t register_system_old(
    const char* name,
    uint32_t* components,
    uint32_t num_components,
    SystemCallback callback,
    uint32_t callback_id
) {
    ecs_system_desc_t desc = {0};
    desc.callback = TrampolineSystem;
    desc.entity = ecs_entity(world, {
        .name = name,
        .add = ecs_ids(ecs_dependson(EcsOnUpdate))
    });

    if (num_components > FLECS_TERM_COUNT_MAX) {
        fprintf(stderr, "Too many components! Max allowed: %d\n", FLECS_TERM_COUNT_MAX);
        return 0;
    }

    for (uint32_t i = 0; i < num_components; i++) {
        const ComponentInfo *component_info = get_component_info(components[i]);
        if (!component_info) {
            fprintf(stderr, "Unable to register system (component_id %u not found)\n", components[i]);
            return 0;
        }
        desc.query.terms[i].id = component_info->ecs_id;
        desc.query.terms[i].oper = EcsAnd;
    }
    desc.query.terms[num_components] = (ecs_term_t){0};

    TrampolineSystemContext *cb_ctx = malloc(sizeof(TrampolineSystemContext));
    cb_ctx->callback = callback;
    cb_ctx->callback_id = callback_id;

    desc.callback_ctx = cb_ctx;
    desc.callback_ctx_free = free_trampoline_system_ctx;

    ecs_entity_t system = ecs_system_init(world, &desc);
    return system;
}
*/

// --- Exported registration for iterator-based systems ---
EXPORT bool flecs_register_system(
    const char* name,
    uint32_t* components,
    uint32_t num_components,
    SystemCallback callback,
    uint32_t callback_id
) {
    ecs_entity_t result = register_system(name, components, num_components, callback, callback_id);
    printf("Registered iterator system '%s' with id: %ld\n", name, result);
    return result != 0;
}
