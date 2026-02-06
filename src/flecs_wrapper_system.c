// lib/flecs_wrapper/src/flecs_wrapper_system.c

#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#include "flecs.h"
#include "flecs_wrapper.h"
#include "flecs_wrapper_component.h"
#include "flecs_wrapper_components.h"
#include "flecs_wrapper_world.h"
#include "flecs_wrapper_system.h"
#include "flecs_wrapper_pair.h"
#include "flecs_wrapper_id.h"

#define MAX_SYSTEMS 65536
FLECS_STATIC_ASSERT(FLECS_IS_POW2_U32(MAX_SYSTEMS), "MAX_SYSTEMS must be power of two");
static ecs_entity_t system_ecs_id_table[MAX_SYSTEMS] = {0};
static uint32_t system_free_ids[MAX_SYSTEMS] = {0};
static flecs_id_pool_t system_id_pool;
static bool system_pool_inited = false;

void clear_system_info(void)
{
    if (!system_pool_inited) {
        flecs_id_pool_init(&system_id_pool, MAX_SYSTEMS, system_free_ids, MAX_SYSTEMS);
        system_pool_inited = true;
    }
    flecs_id_pool_reset(&system_id_pool);
    memset(system_ecs_id_table, 0, sizeof(system_ecs_id_table));
    memset(system_free_ids, 0, sizeof(system_free_ids));
}

static system_id_t alloc_system_id(void)
{
    if (!system_pool_inited) {
        flecs_id_pool_init(&system_id_pool, MAX_SYSTEMS, system_free_ids, MAX_SYSTEMS);
        system_pool_inited = true;
    }
    uint32_t index = flecs_id_pool_alloc(&system_id_pool);
    if (index == 0) {
        return 0;
    }
    return flecs_id_make(FLECS_ID_SYSTEM, index);
}

static system_id_t register_system_id(ecs_entity_t ecs_id)
{
    system_id_t id = alloc_system_id();
    if (id == 0)
        return 0;
    uint32_t index = flecs_id_index(id);
    system_ecs_id_table[index] = ecs_id;
    return id;
}

typedef struct TrampolineSystemContext
{
    SystemCallback callback;
    uint32_t callback_id;

    // Host-visible columns (requested components only; EntityId excluded)
    uint32_t column_count;
    component_id_t column_component_ids[FLECS_TERM_COUNT_MAX];
    uint32_t column_sizes[FLECS_TERM_COUNT_MAX];

    // Iterator terms = host columns + 1 EntityId term at the end
    uint32_t term_count;
    int32_t entity_id_term_index; // 0-based term index within iterator terms
} TrampolineSystemContext;

static void free_trampoline_ctx(void *ctx) {
    free(ctx);
}

static bool resolve_id_info(component_id_t id, ecs_id_t *ecs_id, uint32_t *size_out)
{
    if (flecs_id_is_type(id, FLECS_ID_PAIR)) {
        const PairInfo *pi = get_pair_info((pair_id_t)id);
        if (!pi) {
            return false;
        }
        if (ecs_id) *ecs_id = pi->ecs_id;
        if (size_out) *size_out = pi->size;
        return true;
    }

    const ComponentInfo *ci = get_component_info(id);
    if (!ci) {
        return false;
    }
    if (ecs_id) *ecs_id = ci->ecs_id;
    if (size_out) *size_out = (uint32_t)ci->size;
    return true;
}

static void trampoline_system(ecs_iter_t *it) {
    TrampolineSystemContext *ctx = (TrampolineSystemContext *)it->callback_ctx;
    if (!ctx) {
        fprintf(stderr, "⚠️ Missing system context in iterator callback\n");
        return;
    }

    void *column_ptrs[FLECS_TERM_COUNT_MAX] = {0};

    // Terms for requested columns are first, in the same order as ctx->column_* arrays.
    // ecs_field_w_size uses 0-based field indices.
    for (uint32_t i = 0; i < ctx->column_count; i++) {
        column_ptrs[i] = ecs_field_w_size(it, (size_t)ctx->column_sizes[i], (int32_t)i);
        if (!column_ptrs[i]) {
            fprintf(stderr, "[flecs_wrapper] column %u pointer is NULL (size=%u)\n",
                i,
                ctx->column_sizes[i]
            );
        }
    }

    if (ctx->entity_id_term_index < 0 || ctx->entity_id_term_index >= (int32_t)ctx->term_count) {
        fprintf(stderr, "⚠️ Missing EntityId term in system callback\n");
        return;
    }

    const EntityId *entity_ids_component =
        (const EntityId *)ecs_field_w_size(it, sizeof(EntityId), ctx->entity_id_term_index);

    if (!entity_ids_component) {
        // This should not happen if EntityId is required/AND'ed, but be defensive.
        fprintf(stderr, "⚠️ EntityId column pointer was NULL\n");
        return;
    }
    const entity_id_t *entity_ids = &entity_ids_component[0].value;

    if (ctx->callback) {
        ctx->callback(
            entity_ids,
            (uint32_t)it->count,

            column_ptrs,
            ctx->column_component_ids,
            ctx->column_sizes,
            ctx->column_count,

            it->delta_time,
            ctx->callback_id
        );
    } else {
        fprintf(stderr, "⚠️ Iterator callback was NULL for callback_id=%u\n", ctx->callback_id);
    }
}

static ecs_entity_t register_system_ex(
    const char* name,
    component_id_t* include_components,
    uint32_t num_include_components,
    component_id_t* exclude_components,
    uint32_t num_exclude_components,
    SystemCallback callback,
    uint32_t callback_id
) {
    FLECS_WRAPPER_ASSERT_WORLD();

    if (!callback) {
        fprintf(stderr, "Unable to register system '%s' (callback is NULL)\n", name);
        return 0;
    }

    if (num_include_components + num_exclude_components + 1 > FLECS_TERM_COUNT_MAX) {
        fprintf(stderr, "Too many components! Max allowed (incl EntityId): %d\n", FLECS_TERM_COUNT_MAX);
        return 0;
    }

    const ComponentInfo *eid_ci = get_component_info_by_name("EntityId");
    if (!eid_ci) {
        fprintf(stderr, "Unable to register system '%s' (EntityId component not registered)\n", name);
        return 0;
    }
    component_id_t entity_id_component = eid_ci->id;

    TrampolineSystemContext *cb_ctx = (TrampolineSystemContext *)calloc(1, sizeof(TrampolineSystemContext));
    if (!cb_ctx) {
        fprintf(stderr, "Failed to allocate system context\n");
        return 0;
    }

    cb_ctx->callback = callback;
    cb_ctx->callback_id = callback_id;

    ecs_system_desc_t desc = {0};
    desc.callback = trampoline_system;
    desc.entity = ecs_entity(world, {
        .name = name,
        .add = ecs_ids(ecs_dependson(EcsOnUpdate))
    });

    // Build terms and host-visible column metadata.
    // If caller includes EntityId, we drop it from columns; we always provide entity_ids separately.
    uint32_t out_col = 0;
    for (uint32_t i = 0; i < num_include_components; i++) {
        if (include_components[i] == entity_id_component) {
            continue;
        }

        ecs_id_t ecs_id = 0;
        uint32_t size = 0;
        if (!resolve_id_info(include_components[i], &ecs_id, &size)) {
            fprintf(stderr, "Unable to register system '%s' (id %u not found)\n", name, include_components[i]);
            free(cb_ctx);
            return 0;
        }

        desc.query.terms[out_col].id = ecs_id;
        desc.query.terms[out_col].oper = EcsAnd;

        cb_ctx->column_component_ids[out_col] = include_components[i];
        cb_ctx->column_sizes[out_col] = size;

        out_col++;
        if (out_col >= FLECS_TERM_COUNT_MAX) {
            fprintf(stderr, "Unable to register system '%s' (too many columns)\n", name);
            free(cb_ctx);
            return 0;
        }
    }

    cb_ctx->column_count = out_col;

    // Append exclude terms after include terms (not part of columns).
    uint32_t out_term = cb_ctx->column_count;
    for (uint32_t i = 0; i < num_exclude_components; i++) {
        if (exclude_components[i] == entity_id_component) {
            fprintf(stderr, "Unable to register system '%s' (EntityId cannot be excluded)\n", name);
            free(cb_ctx);
            return 0;
        }

        ecs_id_t ecs_id = 0;
        if (!resolve_id_info(exclude_components[i], &ecs_id, NULL)) {
            fprintf(stderr, "Unable to register system '%s' (exclude id %u not found)\n", name, exclude_components[i]);
            free(cb_ctx);
            return 0;
        }

        if (out_term >= FLECS_TERM_COUNT_MAX) {
            fprintf(stderr, "Unable to register system '%s' (too many terms)\n", name);
            free(cb_ctx);
            return 0;
        }

        desc.query.terms[out_term].id = ecs_id;
        desc.query.terms[out_term].oper = EcsNot;
        out_term++;
    }

    // Append EntityId as internal required term (always last term).
    uint32_t eid_term = out_term;
    if (eid_term >= FLECS_TERM_COUNT_MAX) {
        fprintf(stderr, "Unable to register system '%s' (too many terms incl EntityId)\n", name);
        free(cb_ctx);
        return 0;
    }

    desc.query.terms[eid_term].id = eid_ci->ecs_id;
    desc.query.terms[eid_term].oper = EcsAnd;

    cb_ctx->entity_id_term_index = (int32_t)eid_term;
    cb_ctx->term_count = eid_term + 1;

    // Terminate terms array
    desc.query.terms[cb_ctx->term_count] = (ecs_term_t){0};

    desc.callback_ctx = cb_ctx;
    desc.callback_ctx_free = free_trampoline_ctx;

    ecs_entity_t sys = ecs_system_init(world, &desc);
    if (!sys) {
        // Be conservative: Flecs may not call callback_ctx_free on init failure.
        free(cb_ctx);
        return 0;
    }

    return sys;
}

EXPORT system_id_t flecs_register_system(
    const char* name,
    component_id_t* components,
    uint32_t num_components,
    SystemCallback callback,
    uint32_t callback_id
) {
    ecs_entity_t result = register_system_ex(name, components, num_components, NULL, 0, callback, callback_id);
    if (!result) {
        return 0;
    }
    system_id_t sys_id = register_system_id(result);
    if (sys_id == 0) {
        fprintf(stderr, "Unable to register system '%s' (system id exhausted)\n", name);
        ecs_delete(world, result);
        return 0;
    }
    printf("Registered iterator system '%s' with id: %u\n", name, sys_id);
    return sys_id;
}

EXPORT system_id_t flecs_register_system_ex(
    const char* name,
    component_id_t* include_components,
    uint32_t num_include_components,
    component_id_t* exclude_components,
    uint32_t num_exclude_components,
    SystemCallback callback,
    uint32_t callback_id
) {
    ecs_entity_t result = register_system_ex(
        name,
        include_components,
        num_include_components,
        exclude_components,
        num_exclude_components,
        callback,
        callback_id
    );
    if (!result) {
        return 0;
    }
    system_id_t sys_id = register_system_id(result);
    if (sys_id == 0) {
        fprintf(stderr, "Unable to register system '%s' (system id exhausted)\n", name);
        ecs_delete(world, result);
        return 0;
    }
    printf("Registered iterator system '%s' with id: %u\n", name, sys_id);
    return sys_id;
}

EXPORT bool flecs_unregister_system(system_id_t system_id)
{
    FLECS_WRAPPER_ASSERT_WORLD();
    if (!flecs_id_is_type(system_id, FLECS_ID_SYSTEM)) {
        return false;
    }
    uint32_t index = flecs_id_index(system_id);
    if (index == 0 || index >= MAX_SYSTEMS) {
        return false;
    }
    ecs_entity_t ecs_id = system_ecs_id_table[index];
    if (!ecs_id) {
        return false;
    }
    system_ecs_id_table[index] = 0;
    ecs_delete(world, ecs_id);
    flecs_id_pool_free(&system_id_pool, index);
    return true;
}
