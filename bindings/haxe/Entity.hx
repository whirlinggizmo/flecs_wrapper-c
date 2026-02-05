package hxcore.flecs.flecs_wrapper.bindings.haxe;

import cpp.Pointer;
import cpp.UInt32;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper.ComponentId;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper.EntityId;

class Entity {
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
  public function set<T>(comp:Component, value:T):Bool {
    var tmp = value;
    var ptr = Pointer.addressOf(tmp);
    return FlecsWrapper.entitySetComponent(id, comp.id, cast ptr);
  }

  @:generic
  public function setPtr<T>(comp:Component, value:Pointer<T>):Bool {
    return FlecsWrapper.entitySetComponent(id, comp.id, cast value);
  }

  @:generic
  public function getPtr<T>(comp:Component):Pointer<T> {
    return cast FlecsWrapper.entityGetComponent(id, comp.id);
  }

  @:generic
  public function get<T>(comp:Component):T {
    var ptr:Pointer<T> = getPtr(comp);
    if (ptr == null) {
      throw 'Component not found for entity ${id} and component ${comp.id}';
    }
    return ptr.ref;
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
}
