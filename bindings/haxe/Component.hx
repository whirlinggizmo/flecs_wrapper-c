package hxcore.flecs.flecs_wrapper.bindings.haxe;

import cpp.UInt32;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Flecs;

class Component {
  public var name:String;
  public var id:UInt32;
  public var size:UInt32;

  public function new(name:String, id:UInt32, size:UInt32) {
    this.name = name;
    this.id = id;
    this.size = size;
  }

  public inline function isTag():Bool {
    return Flecs.componentIsTag(id);
  }

  public static inline function idByName(name:String):UInt32 {
    return Flecs.componentId(name);
  }

  public static function get(name:String):Component {
    var id = Flecs.componentId(name);
    if (id == 0) {
      return new Component("", 0, 0);
    }
    return new Component(name, id, 0);
  }

  public static function require(name:String):Component {
    var comp = get(name);
    if (comp.id == 0) {
      throw 'Unknown component name: ${name}';
    }
    return comp;
  }

  public static function create(name:String, size:Int):Component {
    var id = Flecs.componentCreate(name, cast size);
    if (id == 0) {
      throw 'componentCreate failed for ${name}';
    }
    return new Component(name, id, cast size);
  }

  public static function createTag(name:String):Component {
    var id = Flecs.componentCreateTag(name);
    if (id == 0) {
      throw 'componentCreateTag failed for ${name}';
    }
    return new Component(name, id, 0);
  }
}
