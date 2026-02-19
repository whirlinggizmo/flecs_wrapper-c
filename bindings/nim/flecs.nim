# flecs.nim
# Barrel entrypoint for Nim bindings.

import ./flecs_wrapper
import ./flecs_component
import ./flecs_entity
import ./flecs_system
import ./flecs_observer
import ./flecs_pair

export flecs_wrapper
export flecs_component
export flecs_entity
export flecs_system
export flecs_observer
export flecs_pair
