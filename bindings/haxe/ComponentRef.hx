package hxcore.flecs.flecs_wrapper.bindings.haxe;

/**
 * Typed component handle: preserves the Haxe component struct type at compile time.
 *
 * Values come from `Component.of(SomeComponentClass)`; they coerce to `Component`
 * anywhere the underlying Flecs API expects it (`@:to Component`).
 */
@:generic
@:forward(name, id, size)
abstract ComponentRef<T>(Component) to Component {
  public inline function new(component:Component) {
    this = component;
  }

  private inline function self():Component return this;
}
