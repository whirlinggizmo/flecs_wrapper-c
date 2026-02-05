#include "flecs_wrapper_id.h"

void flecs_id_pool_init(flecs_id_pool_t *pool, uint32_t max, uint32_t *free_buffer, uint32_t capacity)
{
    pool->max = max;
    pool->next_id = 1; // reserve 0 as invalid
    pool->free_ids = free_buffer;
    pool->free_capacity = capacity;
    pool->free_count = 0;
    pool->free_head = 0;
    pool->free_tail = 0;
}

void flecs_id_pool_reset(flecs_id_pool_t *pool)
{
    pool->next_id = 1;
    pool->free_count = 0;
    pool->free_head = 0;
    pool->free_tail = 0;
}

uint32_t flecs_id_pool_alloc(flecs_id_pool_t *pool)
{
    if (pool->free_count > 0) {
        uint32_t index = pool->free_ids[pool->free_head];
        pool->free_head = (pool->free_head + 1) % pool->free_capacity;
        pool->free_count--;
        return index;
    }

    if (pool->next_id >= pool->max) {
        return 0;
    }

    return pool->next_id++;
}

void flecs_id_pool_free(flecs_id_pool_t *pool, uint32_t index)
{
    if (index == 0 || index >= pool->max) {
        return;
    }

    if (pool->free_count >= pool->free_capacity) {
        // drop if pool is full
        return;
    }

    pool->free_ids[pool->free_tail] = index;
    pool->free_tail = (pool->free_tail + 1) % pool->free_capacity;
    pool->free_count++;
}
