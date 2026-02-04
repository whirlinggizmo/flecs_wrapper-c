package hxcore.flecs.flecs_wrapper.bindings.haxe;

import cpp.Pointer;
import cpp.UInt32;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Flecs;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Flecs.ComponentId;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Flecs.EntityId;

class Entity {
  public var id:EntityId;

  public function new(id:EntityId) {
    this.id = id;
  }

  public static function create(name:String):Entity {
    var id = Flecs.entityCreate(name);
    if (id == 0) {
      throw 'entityCreate failed for ${name}';
    }
    return new Entity(id);
  }

  public static inline function wrap(id:EntityId):Entity {
    return new Entity(id);
  }

  public inline function destroy():Bool {
    return Flecs.entityDestroy(id);
  }

  public function add(comp:Dynamic):Bool {
    if (Std.isOfType(comp, Component)) {
      return Flecs.entityAddComponent(id, cast(comp, Component).id);
    }
    if (Std.isOfType(comp, String)) {
      return Flecs.entityAddComponentByName(id, cast comp);
    }
    return Flecs.entityAddComponent(id, cast comp);
  }

  public function remove(comp:Dynamic):Bool {
    if (Std.isOfType(comp, Component)) {
      return Flecs.entityRemoveComponent(id, cast(comp, Component).id);
    }
    if (Std.isOfType(comp, String)) {
      return Flecs.entityRemoveComponentByName(id, cast comp);
    }
    return Flecs.entityRemoveComponent(id, cast comp);
  }

  public function has(comp:Dynamic):Bool {
    if (Std.isOfType(comp, Component)) {
      return Flecs.entityHasComponent(id, cast(comp, Component).id);
    }
    if (Std.isOfType(comp, String)) {
      return Flecs.entityHasComponentByName(id, cast comp);
    }
    return Flecs.entityHasComponent(id, cast comp);
  }

  @:generic
  public function set<T>(comp:Component, value:T):Bool {
    var tmp = value;
    var ptr = Pointer.addressOf(tmp);
    return Flecs.entitySetComponent(id, comp.id, cast ptr);
  }

  @:generic
  public function setPtr<T>(comp:Component, value:Pointer<T>):Bool {
    return Flecs.entitySetComponent(id, comp.id, cast value);
  }

  @:generic
  public function getPtr<T>(comp:Component):Pointer<T> {
    return cast Flecs.entityGetComponent(id, comp.id);
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
      Flecs.entityMarkComponent(id, cast(comp, Component).id);
      return;
    }
    if (Std.isOfType(comp, String)) {
      var compId:ComponentId = Flecs.componentId(cast comp);
      if (compId == 0) {
        throw 'Unknown component name: ${comp}';
      }
      Flecs.entityMarkComponent(id, compId);
      return;
    }
    Flecs.entityMarkComponent(id, cast comp);
  }
}
