// move_system.c

#include "flecs.h"
#include "flecs_wrapper_components.h"
#include "systems/move_system.h"

void MoveSystem(ecs_iter_t *it) {
    // Use runtime sizes so we tolerate both 2D and 3D component layouts.
    void *p_field = ecs_field_w_size(it, 0, 0);
    void *v_field = ecs_field_w_size(it, 0, 1);
    size_t p_size = ecs_field_size(it, 0);
    size_t v_size = ecs_field_size(it, 1);

    if (!p_field || !v_field || p_size < sizeof(float) * 2 || v_size < sizeof(float) * 2) {
        return;
    }

    for (int i = 0; i < it->count; i++) {
        float *p = (float *)((char *)p_field + (size_t)i * p_size);
        float *v = (float *)((char *)v_field + (size_t)i * v_size);

        const float vx = v[0];
        const float vy = v[1];
        const float vz = (v_size >= sizeof(float) * 3) ? v[2] : 0.0f;

        if (vx == 0.0f && vy == 0.0f && vz == 0.0f) {
            continue; // no movement
        }

        p[0] += vx * it->delta_time;
        p[1] += vy * it->delta_time;
        if (p_size >= sizeof(float) * 3) {
            p[2] += vz * it->delta_time;
        }
    }
}
