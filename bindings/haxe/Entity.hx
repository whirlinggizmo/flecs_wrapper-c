package hxcore.flecs.flecs_wrapper.bindings.haxe;

#if !macro
import cpp.Pointer;
import cpp.UInt32;
import hxcore.flecs.NativePtr;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper.ComponentId;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper.EntityId;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper.PairId;
#end

class Entity {
#if !macro
  public var id:EntityId;

  public function new(id:EntityId) {
    this.id = id;
  }

  public static function create(name:String):Entity {
    var id = FlecsWrapper.entityCreate(name);
    if (id == 0) {
      throw 'entityCreate failed for ${name}';
    }
    return new Entity(id);
  }

  public static inline function wrap(id:EntityId):Entity {
    return new Entity(id);
  }

  public inline function destroy():Bool {
    return FlecsWrapper.entityDestroy(id);
  }

  public function add(comp:Dynamic):Bool {
    if (Std.isOfType(comp, Component)) {
      return FlecsWrapper.entityAddComponent(id, cast(comp, Component).id);
    }
    if (Std.isOfType(comp, String)) {
      return FlecsWrapper.entityAddComponentByName(id, cast comp);
    }
    return FlecsWrapper.entityAddComponent(id, cast comp);
  }

  public function remove(comp:Dynamic):Bool {
    if (Std.isOfType(comp, Component)) {
      return FlecsWrapper.entityRemoveComponent(id, cast(comp, Component).id);
    }
    if (Std.isOfType(comp, String)) {
      return FlecsWrapper.entityRemoveComponentByName(id, cast comp);
    }
    return FlecsWrapper.entityRemoveComponent(id, cast comp);
  }

  public function has(comp:Dynamic):Bool {
    if (Std.isOfType(comp, Component)) {
      return FlecsWrapper.entityHasComponent(id, cast(comp, Component).id);
    }
    if (Std.isOfType(comp, String)) {
      return FlecsWrapper.entityHasComponentByName(id, cast comp);
    }
    return FlecsWrapper.entityHasComponent(id, cast comp);
  }

  @:generic
  public function setValue<T>(comp:Component, value:T):Bool {
    var tmp:T = value;
    var dataPtr:Pointer<cpp.Void> = untyped __cpp__("::cpp::Pointer<void>((void*)&{0})", tmp);
    return FlecsWrapper.entitySetComponent(id, comp.id, dataPtr);
  }

  @:generic
  public function rawSet<T>(comp:Component, value:Pointer<T>):Bool {
    return FlecsWrapper.entitySetComponent(id, comp.id, cast value);
  }

  @:generic
  public function rawGet<T>(comp:Component):Pointer<T> {
    return cast FlecsWrapper.entityGetComponent(id, comp.id);
  }

  @:generic
  public function get<T>(comp:Component):T {
    var ptr:Pointer<T> = cast FlecsWrapper.entityGetComponent(id, comp.id);
    if (ptr == null) {
      throw 'Component not found for entity ${id} and component ${comp.id}';
    }
    return ptr.ref;
  }

  /**
   * Optional component access without throwing.
   *
   * Flecs/C semantics are naturally pointer-like (`ecs_get` returns NULL).
   * On cpp targets with `@:component` backing structs, returning `null` *values*
   * for missing components is awkward for hxcpp compared to nullable pointers.
   *
   * Prefer `has(comp)` + `get<T>(comp)` if you want value semantics without pointers.
   */
  @:generic
  public function tryGet<T>(comp:Component):NativePtr<T> {
    return cast FlecsWrapper.entityGetComponent(id, comp.id);
  }

  public function mark(comp:Dynamic):Void {
    if (Std.isOfType(comp, Component)) {
      FlecsWrapper.entityMarkComponent(id, cast(comp, Component).id);
      return;
    }
    if (Std.isOfType(comp, String)) {
      var compId:ComponentId = FlecsWrapper.componentId(cast comp);
      if (compId == 0) {
        throw 'Unknown component name: ${comp}';
      }
      FlecsWrapper.entityMarkComponent(id, compId);
      return;
    }
    FlecsWrapper.entityMarkComponent(id, cast comp);
  }

  private function resolvePairId(relation:Dynamic, object:Dynamic):PairId {
    if (Std.isOfType(relation, Component)) {
      var relComp:Component = cast relation;
      if (Std.isOfType(object, Entity)) {
        return FlecsWrapper.pairRegister(relComp.id, cast(object, Entity).id);
      }
      return FlecsWrapper.pairRegister(relComp.id, cast object);
    }
    if (Std.isOfType(relation, Entity)) {
      var relEnt:Entity = cast relation;
      if (Std.isOfType(object, Entity)) {
        return FlecsWrapper.pairRegisterEntity(relEnt.id, cast(object, Entity).id);
      }
      return FlecsWrapper.pairRegisterEntity(relEnt.id, cast object);
    }
    if (Std.isOfType(relation, String) && Std.isOfType(object, String)) {
      return FlecsWrapper.pairRegisterByName(cast relation, cast object);
    }
    throw 'Unsupported pair relation/object types';
  }

  public function addPair(relation:Dynamic, object:Dynamic):Bool {
    var pairId = resolvePairId(relation, object);
    return FlecsWrapper.entityAddPair(id, pairId);
  }

  public function removePair(relation:Dynamic, object:Dynamic):Bool {
    var pairId = resolvePairId(relation, object);
    return FlecsWrapper.entityRemovePair(id, pairId);
  }

  public function hasPair(relation:Dynamic, object:Dynamic):Bool {
    var pairId = resolvePairId(relation, object);
    return FlecsWrapper.entityHasPair(id, pairId);
  }

  public function rawSetPair(relation:Dynamic, object:Dynamic, value:Pointer<cpp.Void>):Bool {
    var pairId = resolvePairId(relation, object);
    return FlecsWrapper.entitySetPair(id, pairId, value);
  }

  public function rawGetPair(relation:Dynamic, object:Dynamic):Pointer<cpp.Void> {
    var pairId = resolvePairId(relation, object);
    return FlecsWrapper.entityGetPair(id, pairId);
  }

  @:generic
  public function rawGetPairTyped<T>(relation:Dynamic, object:Dynamic):Pointer<T> {
    return cast rawGetPair(relation, object);
  }
#end

  /**
   * Upsert / set component data.
   *
   * - `{ field: value, ... }` object literals: expanded at compile time into direct
   *   field writes on the Flecs-backed struct (requires `ComponentRef<T>` from
   *   `Component.of(...)` so `T` is known).
   * - `new MyComponent(...)`: copies bytes into Flecs storage (native upsert).
   */
  @:overload(function(selfExpr:haxe.macro.Expr, compExpr:haxe.macro.Expr, valueExpr:haxe.macro.Expr):haxe.macro.Expr {})
  public macro function set(
    selfExpr:haxe.macro.Expr,
    compExpr:haxe.macro.Expr,
    valueExpr:haxe.macro.Expr,
    ?notifyExpr:haxe.macro.Expr
  ):haxe.macro.Expr {
    return EntityMacros.buildSet(selfExpr, compExpr, valueExpr, notifyExpr);
  }
}
