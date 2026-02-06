// Smoke test for system_id_t registry behavior.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "flecs_wrapper.h"

typedef struct Vec2 {
    float x;
    float y;
} Vec2;

static void on_system(
    const entity_id_t *entity_ids,
    uint32_t entity_count,
    void **columns,
    const component_id_t *column_component_ids,
    const uint32_t *column_sizes,
    uint32_t column_count,
    float delta_time,
    uint32_t callback_id
) {
    (void)entity_ids;
    (void)entity_count;
    (void)columns;
    (void)column_component_ids;
    (void)column_sizes;
    (void)column_count;
    (void)delta_time;
    (void)callback_id;
}

static void expect(int cond, const char *msg) {
    if (!cond) {
        fprintf(stderr, "TEST FAILED: %s\n", msg);
        exit(1);
    }
}

static system_id_t register_simple_system(component_id_t pos_id, component_id_t vel_id, const char *name) {
    component_id_t includes[2] = {pos_id, vel_id};
    return flecs_register_system(name, includes, 2, on_system, 0);
}

int main(void) {
    flecs_init();

    component_id_t pos_id = flecs_component_create("SysIdPos", (uint32_t)sizeof(Vec2));
    component_id_t vel_id = flecs_component_create("SysIdVel", (uint32_t)sizeof(Vec2));
    expect(pos_id != 0 && vel_id != 0, "component_create failed");

    system_id_t id1 = register_simple_system(pos_id, vel_id, "SysIdA");
    system_id_t id2 = register_simple_system(pos_id, vel_id, "SysIdB");
    expect(id1 != 0 && id2 != 0, "system ids should be non-zero");
    expect(id1 != id2, "system ids should be unique");

    flecs_fini();
    flecs_init();

    pos_id = flecs_component_create("SysIdPos2", (uint32_t)sizeof(Vec2));
    vel_id = flecs_component_create("SysIdVel2", (uint32_t)sizeof(Vec2));
    expect(pos_id != 0 && vel_id != 0, "component_create failed after reset");

    system_id_t id3 = register_simple_system(pos_id, vel_id, "SysIdC");
    expect(flecs_id_index(id3) == 1, "system id should reset after flecs_fini");

    printf("test_system_ids.c: OK (id1=%u id2=%u id3=%u)\n", id1, id2, id3);
    flecs_fini();
    return 0;
}
