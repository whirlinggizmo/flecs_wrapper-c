// flecs_wrapper.h
#ifndef FLECS_WRAPPER_H
#define FLECS_WRAPPER_H

#include <stdbool.h>

#include "flecs_wrapper_types.h"
#include "flecs_wrapper_entity.h"
#include "flecs_wrapper_component.h"
#include "flecs_wrapper_event.h"
#include "flecs_wrapper_system.h"

#define EXPORT __attribute__((visibility("default")))

#ifdef __cplusplus
extern "C"
{
#endif

    // Note: wrapper IDs are not Flecs ecs_entity_t values.
    // - entity_id_t is a stable 32-bit handle for entities.
    // - component_id_t is a wrapper registry index for components.

    // Component management
    component_id_t flecs_component_get_id_by_name(const char *name);
    bool flecs_component_is_tag(component_id_t component_id);
    void flecs_component_print_registry(void);
    component_id_t flecs_component_create(const char *name, uint32_t size);
    component_id_t flecs_component_create_tag(const char *name);

    // Entity component inspection
    void flecs_entity_print_components(entity_id_t entity_id);
    bool flecs_entity_has_component(entity_id_t entity_id, component_id_t component_id);
    bool flecs_entity_has_component_by_name(entity_id_t entity_id, const char *component_name);

    // Entity component modification
    bool flecs_entity_add_component(entity_id_t entity_id, component_id_t component_id);
    bool flecs_entity_add_component_by_name(entity_id_t entity_id, const char *component_name);
    bool flecs_entity_remove_component(entity_id_t entity_id, component_id_t component_id);
    bool flecs_entity_remove_component_by_name(entity_id_t entity_id, const char *component_name);
    bool flecs_entity_set_component(entity_id_t entity_id, component_id_t component_id, const void *component_data_ptr);
    const void *flecs_entity_get_component(entity_id_t entity_id, component_id_t component_id);
    void flecs_entity_mark_component(entity_id_t entity_id, component_id_t component_id);

    // Entity lifecycle
    entity_id_t flecs_entity_create(const char *name);
    bool flecs_entity_destroy(entity_id_t entity_id);
    // removed export for now, not needed/encouraged
    // entity_id_t flecs_entity_get_id(uint64_t entity_ecs_id);

    // Observer registration
    typedef void (*ObserverCallback)(
        const entity_id_t *entity_ids, // stable 32-bit handles
        uint32_t entity_count,      // number of entities in this iteration

        void **columns,                       // component columns for requested components ONLY
        const component_id_t *column_component_ids, // wrapper component ids matching columns[]
        const uint32_t *column_sizes,         // bytes per element in each column
        uint32_t column_count,                // number of columns (EntityId excluded)

        uint32_t event_id,            // event type (OnAdd/OnRemove/OnSet/etc)
        component_id_t component_id,  // component that triggered the observer
        uint32_t callback_id     // user-defined callback ID
    );
    observer_id_t flecs_register_observer(component_id_t *component_ids, uint32_t num_components, event_id_t *event_ids, uint32_t num_events, ObserverCallback callback, uint32_t callback_id);
    observer_id_t flecs_register_observer_ex(
        component_id_t *include_component_ids,
        uint32_t num_include_components,
        component_id_t *exclude_component_ids,
        uint32_t num_exclude_components,
        event_id_t *event_ids,
        uint32_t num_events,
        ObserverCallback callback,
        uint32_t callback_id);

    // System registration
    typedef void (*SystemCallback)(
        const entity_id_t *entity_ids, // stable 32-bit handles
        uint32_t entity_count,      // number of entities in this iteration

        void **columns,                       // component columns for requested components ONLY
        const component_id_t *column_component_ids, // wrapper component ids matching columns[]
        const uint32_t *column_sizes,         // bytes per element in each column
        uint32_t column_count,                // number of columns (EntityId excluded)

        float delta_time,    // delta time since last frame
        uint32_t callback_id // user-defined callback ID (host-side dispatch)
    );

    system_id_t flecs_register_system(
        const char *name,
        component_id_t *component_ids,
        uint32_t num_components,
        SystemCallback callback,
        uint32_t callback_id);
    system_id_t flecs_register_system_ex(
        const char *name,
        component_id_t *include_component_ids,
        uint32_t num_include_components,
        component_id_t *exclude_component_ids,
        uint32_t num_exclude_components,
        SystemCallback callback,
        uint32_t callback_id);
    // Lifecycle management
    void flecs_init(void);
    void flecs_progress(float delta_time);
    void flecs_fini(void);
    void flecs_set_threads(int32_t threads);

    // Version
    const char *flecs_version(void);

#ifdef __cplusplus
}
#endif

#endif // FLECS_WRAPPER_H
