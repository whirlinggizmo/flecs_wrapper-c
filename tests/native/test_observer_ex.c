// Minimal smoke test for flecs_register_observer_ex (include + exclude).
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "flecs_wrapper.h"

typedef struct Vec2 {
    float x;
    float y;
} Vec2;

typedef struct ObsState {
    int fired;
    entity_id_t last_entity;
    component_id_t last_component;
} ObsState;

static ObsState g_state = {0};

static void on_observe(
    const entity_id_t *entity_ids,
    uint32_t entity_count,
    void **columns,
    const component_id_t *column_component_ids,
    const uint32_t *column_sizes,
    uint32_t column_count,
    uint32_t event_id,
    component_id_t component_id,
    uint32_t callback_id
) {
    (void)columns;
    (void)column_component_ids;
    (void)column_sizes;
    (void)column_count;
    (void)event_id;
    (void)callback_id;

    if (entity_count > 0) {
        g_state.fired++;
        g_state.last_entity = entity_ids[0];
        g_state.last_component = component_id;
    }
}

static void expect(int cond, const char *msg) {
    if (!cond) {
        fprintf(stderr, "TEST FAILED: %s\n", msg);
        exit(1);
    }
}

int main(void) {
    flecs_init();

    component_id_t pos_id = flecs_component_create("ObsExPos", (uint32_t)sizeof(Vec2));
    component_id_t excl_id = flecs_component_create_tag("ObsExTag");
    expect(pos_id != 0, "component_create ObsExPos failed");
    expect(excl_id != 0, "component_create_tag ObsExTag failed");

    component_id_t includes[1] = {pos_id};
    component_id_t excludes[1] = {excl_id};
    event_id_t events[1] = {FLECS_EVENT_ON_ADD};

    observer_id_t obs_id = flecs_register_observer_ex(
        includes,
        1,
        excludes,
        1,
        events,
        1,
        on_observe,
        42
    );
    expect(obs_id != 0, "observer_ex registration failed");

    Vec2 p = {1, 2};

    entity_id_t e1 = flecs_entity_create("ObsExEntity1");
    expect(e1 != 0, "failed to create entity 1");
    flecs_entity_set_component(e1, pos_id, &p);

    entity_id_t e2 = flecs_entity_create("ObsExEntity2");
    expect(e2 != 0, "failed to create entity 2");
    flecs_entity_set_component(e2, excl_id, NULL);
    flecs_entity_set_component(e2, pos_id, &p);

    flecs_progress(0);

    expect(g_state.fired == 1, "observer should ignore excluded entity");
    expect(g_state.last_entity == e1, "observer reported wrong entity id");
    expect(g_state.last_component == pos_id, "observer reported wrong component id");

    printf("test_observer_ex.c: OK (fired=%d)\n", g_state.fired);
    flecs_fini();
    return 0;
}
