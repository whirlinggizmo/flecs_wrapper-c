// Minimal smoke test for flecs_register_system_ex (include + exclude).
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "flecs_wrapper.h"
#include "flecs_wrapper_components.h"

typedef struct Vec2 {
    float x;
    float y;
} Vec2;

typedef struct TestCase {
    const char *name;
    component_id_t pos_id;
    component_id_t vel_id;
    component_id_t excl_id;
    entity_id_t e1;
    entity_id_t e2;
    int processed_e1;
    int processed_e2;
    int expect_e1_moved;
    int expect_e2_moved;
} TestCase;

static TestCase g_cases[8];
static uint32_t g_case_count = 0;

static void MoveSystemExTest(
    const entity_id_t *entity_ids,
    uint32_t entity_count,
    void **columns,
    const component_id_t *column_component_ids,
    const uint32_t *column_sizes,
    uint32_t column_count,
    float delta_time,
    uint32_t callback_id
) {
    TestCase *tc = &g_cases[callback_id];
    (void)column_component_ids;
    (void)column_sizes;
    (void)column_count;

    Vec2 *pos = (Vec2 *)columns[0];
    Vec2 *vel = (Vec2 *)columns[1];

    for (uint32_t i = 0; i < entity_count; i++) {
        pos[i].x += vel[i].x * delta_time;
        pos[i].y += vel[i].y * delta_time;

        if (entity_ids[i] == tc->e1) {
            tc->processed_e1++;
        } else if (entity_ids[i] == tc->e2) {
            tc->processed_e2++;
        }
    }
}

static void expect(int cond, const char *msg) {
    if (!cond) {
        fprintf(stderr, "TEST FAILED: %s\n", msg);
        exit(1);
    }
}

static TestCase *add_case(const char *name) {
    TestCase *tc = &g_cases[g_case_count++];
    memset(tc, 0, sizeof(*tc));
    tc->name = name;
    return tc;
}

static component_id_t create_component_or_fail(const char *name, size_t size) {
    component_id_t id = flecs_component_create(name, (uint32_t)size);
    expect(id != 0, "component_create failed");
    return id;
}

int main(void) {
    flecs_init();

    Vec2 p = {0, 0};
    Vec2 v = {1, 0};
    int32_t flag = 1;

    // Case 1: exclude matches entity 1 only.
    {
        TestCase *tc = add_case("exclude_match");
        tc->pos_id = create_component_or_fail("TestPosA", sizeof(Vec2));
        tc->vel_id = create_component_or_fail("TestVelA", sizeof(Vec2));
        tc->excl_id = create_component_or_fail("TestExclA", sizeof(int32_t));
        tc->expect_e1_moved = 0;
        tc->expect_e2_moved = 1;

        tc->e1 = flecs_entity_create("WithExcludeA");
        tc->e2 = flecs_entity_create("NoExcludeA");
        expect(tc->e1 && tc->e2, "failed to create entities");

        flecs_entity_set_component(tc->e1, tc->pos_id, &p);
        flecs_entity_set_component(tc->e1, tc->vel_id, &v);
        flecs_entity_set_component(tc->e1, tc->excl_id, &flag);

        flecs_entity_set_component(tc->e2, tc->pos_id, &p);
        flecs_entity_set_component(tc->e2, tc->vel_id, &v);

        component_id_t includes[2] = {tc->pos_id, tc->vel_id};
        component_id_t excludes[1] = {tc->excl_id};
        uint32_t sys_id = flecs_register_system_ex(
            "MoveSystemExTestA",
            includes,
            2,
            excludes,
            1,
            MoveSystemExTest,
            g_case_count - 1
        );
        expect(sys_id != 0, "failed to register system_ex A");
    }

    // Case 2: exclude list empty (behaves like include-only).
    {
        TestCase *tc = add_case("exclude_empty");
        tc->pos_id = create_component_or_fail("TestPosB", sizeof(Vec2));
        tc->vel_id = create_component_or_fail("TestVelB", sizeof(Vec2));
        tc->expect_e1_moved = 1;
        tc->expect_e2_moved = 1;

        tc->e1 = flecs_entity_create("IncludeOnlyB1");
        tc->e2 = flecs_entity_create("IncludeOnlyB2");
        expect(tc->e1 && tc->e2, "failed to create entities");

        flecs_entity_set_component(tc->e1, tc->pos_id, &p);
        flecs_entity_set_component(tc->e1, tc->vel_id, &v);
        flecs_entity_set_component(tc->e2, tc->pos_id, &p);
        flecs_entity_set_component(tc->e2, tc->vel_id, &v);

        component_id_t includes[2] = {tc->pos_id, tc->vel_id};
        uint32_t sys_id = flecs_register_system_ex(
            "MoveSystemExTestB",
            includes,
            2,
            NULL,
            0,
            MoveSystemExTest,
            g_case_count - 1
        );
        expect(sys_id != 0, "failed to register system_ex B");
    }

    // Case 3: exclude component not present on any entity (no effect).
    {
        TestCase *tc = add_case("exclude_missing");
        tc->pos_id = create_component_or_fail("TestPosC", sizeof(Vec2));
        tc->vel_id = create_component_or_fail("TestVelC", sizeof(Vec2));
        tc->excl_id = create_component_or_fail("TestExclC", sizeof(int32_t));
        tc->expect_e1_moved = 1;
        tc->expect_e2_moved = 1;

        tc->e1 = flecs_entity_create("ExcludeMissingC1");
        tc->e2 = flecs_entity_create("ExcludeMissingC2");
        expect(tc->e1 && tc->e2, "failed to create entities");

        flecs_entity_set_component(tc->e1, tc->pos_id, &p);
        flecs_entity_set_component(tc->e1, tc->vel_id, &v);
        flecs_entity_set_component(tc->e2, tc->pos_id, &p);
        flecs_entity_set_component(tc->e2, tc->vel_id, &v);

        component_id_t includes[2] = {tc->pos_id, tc->vel_id};
        component_id_t excludes[1] = {tc->excl_id};
        uint32_t sys_id = flecs_register_system_ex(
            "MoveSystemExTestC",
            includes,
            2,
            excludes,
            1,
            MoveSystemExTest,
            g_case_count - 1
        );
        expect(sys_id != 0, "failed to register system_ex C");
    }

    // Case 4: multiple excludes.
    {
        TestCase *tc = add_case("exclude_multiple");
        tc->pos_id = create_component_or_fail("TestPosD", sizeof(Vec2));
        tc->vel_id = create_component_or_fail("TestVelD", sizeof(Vec2));
        component_id_t excl1 = create_component_or_fail("TestExclD1", sizeof(int32_t));
        component_id_t excl2 = create_component_or_fail("TestExclD2", sizeof(int32_t));
        tc->excl_id = excl1;
        tc->expect_e1_moved = 0;
        tc->expect_e2_moved = 1;

        tc->e1 = flecs_entity_create("ExcludeMultiD1");
        tc->e2 = flecs_entity_create("ExcludeMultiD2");
        expect(tc->e1 && tc->e2, "failed to create entities");

        flecs_entity_set_component(tc->e1, tc->pos_id, &p);
        flecs_entity_set_component(tc->e1, tc->vel_id, &v);
        flecs_entity_set_component(tc->e1, excl1, &flag);

        flecs_entity_set_component(tc->e2, tc->pos_id, &p);
        flecs_entity_set_component(tc->e2, tc->vel_id, &v);

        component_id_t includes[2] = {tc->pos_id, tc->vel_id};
        component_id_t excludes[2] = {excl1, excl2};
        uint32_t sys_id = flecs_register_system_ex(
            "MoveSystemExTestD",
            includes,
            2,
            excludes,
            2,
            MoveSystemExTest,
            g_case_count - 1
        );
        expect(sys_id != 0, "failed to register system_ex D");
    }

    flecs_progress(1.0f);

    for (uint32_t i = 0; i < g_case_count; i++) {
        TestCase *tc = &g_cases[i];
        const Vec2 *p1 = (const Vec2 *)flecs_entity_get_component(tc->e1, tc->pos_id);
        const Vec2 *p2 = (const Vec2 *)flecs_entity_get_component(tc->e2, tc->pos_id);
        expect(p1 != NULL && p2 != NULL, "failed to get Position data");

        if (tc->expect_e1_moved) {
            expect(p1->x == 1.0f && p1->y == 0.0f, "expected e1 moved");
        } else {
            expect(p1->x == 0.0f && p1->y == 0.0f, "expected e1 not moved");
        }

        if (tc->expect_e2_moved) {
            expect(p2->x == 1.0f && p2->y == 0.0f, "expected e2 moved");
        } else {
            expect(p2->x == 0.0f && p2->y == 0.0f, "expected e2 not moved");
        }

        if (tc->expect_e1_moved) {
            expect(tc->processed_e1 > 0, "expected e1 processed");
        } else {
            expect(tc->processed_e1 == 0, "expected e1 not processed");
        }
        if (tc->expect_e2_moved) {
            expect(tc->processed_e2 > 0, "expected e2 processed");
        } else {
            expect(tc->processed_e2 == 0, "expected e2 not processed");
        }
    }

    printf("test_system_ex: OK (%u cases)\n", g_case_count);
    flecs_fini();
    return 0;
}
