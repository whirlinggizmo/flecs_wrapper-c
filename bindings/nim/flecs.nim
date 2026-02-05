# flecs.nim
# Barrel entrypoint for Nim bindings.

import ./flecs_wrapper
import ./component
import ./entity
import ./system
import ./observer
import ./pair

export flecs_wrapper
export component
export entity
export system
export observer
export pair
