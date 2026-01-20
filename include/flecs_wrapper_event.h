// flecs_wrapper_event.h
#ifndef FLECS_WRAPPER_EVENT_H
#define FLECS_WRAPPER_EVENT_H

#include <stdint.h>
#include <flecs.h>

#ifdef __cplusplus
extern "C"
{
#endif

typedef uint32_t event_id_t;

enum event_id
{
    FLECS_EVENT_ON_ADD = 1,
    FLECS_EVENT_ON_REMOVE = 2,
    FLECS_EVENT_ON_SET = 3,
    FLECS_EVENT_ON_DELETE = 4,
    FLECS_EVENT_ON_DELETE_TARGET = 5,
    FLECS_EVENT_ON_TABLE_CREATE = 6,
    FLECS_EVENT_ON_TABLE_DELETE = 7
};

void init_event_table(void);
void clear_event_table(void);
#ifdef __cplusplus
}
#endif

#endif // FLECS_WRAPPER_EVENT_H
