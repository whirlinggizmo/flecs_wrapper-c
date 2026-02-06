#ifndef FLECS_WRAPPER_ID_H
#define FLECS_WRAPPER_ID_H

#include <stdint.h>
#include <stdbool.h>
#include "flecs_wrapper_types.h"

// ID format (32-bit, unsigned):
// [31..29] = type tag (3 bits)
// [28..0]  = index (29 bits)
// This keeps Lua-friendly 32-bit IDs while allowing type discrimination.
// Note: some tagged IDs will have the sign bit set. Treat IDs as unsigned
// 32-bit values in all bindings (do not rely on signed comparisons).

#define FLECS_ID_TYPE_SHIFT 29u
#define FLECS_ID_TYPE_MASK  0xE0000000u
#define FLECS_ID_INDEX_MASK 0x1FFFFFFFu

#define FLECS_IS_POW2_U32(x) (((x) != 0u) && (((x) & ((x) - 1u)) == 0u))

#ifdef __cplusplus
#define FLECS_STATIC_ASSERT(cond, msg) static_assert(cond, msg)
#else
#define FLECS_STATIC_ASSERT(cond, msg) _Static_assert(cond, msg)
#endif

typedef enum flecs_id_type_e {
    FLECS_ID_ENTITY   = 1,
    FLECS_ID_COMPONENT= 2,
    FLECS_ID_SYSTEM   = 3,
    FLECS_ID_OBSERVER = 4,
    FLECS_ID_PAIR     = 5,
} flecs_id_type_t;

static inline uint32_t flecs_id_make(flecs_id_type_t type, uint32_t index) {
    return ((uint32_t)type << FLECS_ID_TYPE_SHIFT) | (index & FLECS_ID_INDEX_MASK);
}

static inline flecs_id_type_t flecs_id_type(uint32_t id) {
    return (flecs_id_type_t)((id & FLECS_ID_TYPE_MASK) >> FLECS_ID_TYPE_SHIFT);
}

static inline uint32_t flecs_id_index(uint32_t id) {
    return id & FLECS_ID_INDEX_MASK;
}

static inline bool flecs_id_is_type(uint32_t id, flecs_id_type_t type) {
    return flecs_id_type(id) == type;
}

// FIFO pool for reusable indices (per ID kind).
typedef struct flecs_id_pool_s {
    uint32_t max;
    uint32_t next_id; // next fresh index if free list empty

    uint32_t *free_ids;
    uint32_t free_capacity;
    uint32_t free_mask; // free_capacity - 1 (requires power-of-two capacity)
    uint32_t free_count;
    uint32_t free_head; // FIFO head
    uint32_t free_tail; // FIFO tail
} flecs_id_pool_t;

void flecs_id_pool_init(flecs_id_pool_t *pool, uint32_t max, uint32_t *free_buffer, uint32_t capacity);
void flecs_id_pool_reset(flecs_id_pool_t *pool);
uint32_t flecs_id_pool_alloc(flecs_id_pool_t *pool);
void flecs_id_pool_free(flecs_id_pool_t *pool, uint32_t index);

#endif // FLECS_WRAPPER_ID_H
