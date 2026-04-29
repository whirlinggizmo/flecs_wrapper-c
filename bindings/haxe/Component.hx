package hxcore.flecs.flecs_wrapper.bindings.haxe;

#if !macro
import cpp.UInt32;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper;
#end

class Component {
  public var name:String;
  #if !macro
  public var id:cpp.UInt32;
  public var size:cpp.UInt32;
  #else
  public var id:Int;
  public var size:Int;
  #end

  #if !macro
  public function new(name:String, id:cpp.UInt32, size:cpp.UInt32) {
  #else
  public function new(name:String, id:Int, size:Int) {
  #end
    this.name = name;
    this.id = id;
    this.size = size;
  }

  public inline function isTag():Bool {
    return FlecsWrapper.componentIsTag(id);
  }

  #if !macro
  public static inline function idByName(name:String):cpp.UInt32 {
  #else
  public static inline function idByName(name:String):Int {
  #end
    return FlecsWrapper.componentId(name);
  }

  public static function get(name:String):Component {
    var id = FlecsWrapper.componentId(name);
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
    var id = FlecsWrapper.componentCreate(name, cast size);
    if (id == 0) {
      throw 'componentCreate failed for ${name}';
    }
    return new Component(name, id, cast size);
  }

  public static function createTag(name:String):Component {
    var id = FlecsWrapper.componentCreateTag(name);
    if (id == 0) {
      throw 'componentCreateTag failed for ${name}';
    }
    return new Component(name, id, 0);
  }

  public static macro function of(typeExpr:haxe.macro.Expr):haxe.macro.Expr {
    return hxcore.flecs.flecs_wrapper.bindings.haxe.ComponentMacro.ofType(typeExpr);
  }

}
