// Smoke test for observer_id_t registry behavior.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "flecs_wrapper.h"

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
    (void)entity_ids;
    (void)entity_count;
    (void)columns;
    (void)column_component_ids;
    (void)column_sizes;
    (void)column_count;
    (void)event_id;
    (void)component_id;
    (void)callback_id;
}

static void expect(int cond, const char *msg) {
    if (!cond) {
        fprintf(stderr, "TEST FAILED: %s\n", msg);
        exit(1);
    }
}

static observer_id_t register_simple_observer(component_id_t comp_id) {
    event_id_t events[1] = {FLECS_EVENT_ON_ADD};
    return flecs_register_observer(&comp_id, 1, events, 1, on_observe, 0);
}

int main(void) {
    flecs_init();

    component_id_t comp_id = flecs_component_create_tag("ObsIdTag");
    expect(comp_id != 0, "component_create_tag ObsIdTag failed");

    observer_id_t id1 = register_simple_observer(comp_id);
    observer_id_t id2 = register_simple_observer(comp_id);
    expect(id1 != 0 && id2 != 0, "observer ids should be non-zero");
    expect(id1 != id2, "observer ids should be unique");

    flecs_fini();
    flecs_init();

    comp_id = flecs_component_create_tag("ObsIdTag2");
    expect(comp_id != 0, "component_create_tag ObsIdTag2 failed");

    observer_id_t id3 = register_simple_observer(comp_id);
    expect(flecs_id_index(id3) == 1, "observer id should reset after flecs_fini");

    printf("test_observer_ids.c: OK (id1=%u id2=%u id3=%u)\n", id1, id2, id3);
    flecs_fini();
    return 0;
}
