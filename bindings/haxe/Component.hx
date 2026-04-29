package hxcore.flecs.flecs_wrapper.bindings.haxe;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
#end

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

  public function new(name:String, id:#if !macro cpp.UInt32 #else Int #end, size:#if !macro cpp.UInt32 #else Int #end) {
    this.name = name;
    this.id = id;
    this.size = size;
  }

  public static macro function of(typeExpr:Expr):Expr {
    var typePath = switch (typeExpr.expr) {
      case EConst(CIdent(name)): name;
      case EField(_, name): name;
      default: null;
    };
    if (typePath == null) {
      Context.error("Component.of() requires a class type name", Context.currentPos());
    }

    var classType = switch (Context.getType(typePath)) {
      case TInst(r, _): r.get();
      default: null;
    };
    if (classType == null) {
      Context.error('Component.of() requires a class type, got: ${typePath}', Context.currentPos());
    }

    var nativeName:String = null;
    for (meta in classType.meta.get()) {
      if (meta.name == ":component" && meta.params != null && meta.params.length > 0) {
        switch (meta.params[0].expr) {
          case EConst(CString(s)): nativeName = s;
          default:
        }
        break;
      }
    }

    if (nativeName == null) {
      Context.error('Component.of() requires a class annotated with @:component (got: ${typePath})', Context.currentPos());
    }

    var structCt = Context.toComplexType(Context.getType(typePath));

    return macro new hxcore.flecs.flecs_wrapper.bindings.haxe.ComponentRef<$structCt>(
      hxcore.flecs.flecs_wrapper.bindings.haxe.Component.create($v{nativeName}, cpp.Native.sizeof($typeExpr))
    );
  }
  #if !macro
  public inline function isTag():Bool {
    return FlecsWrapper.componentIsTag(id);
  }

  public static inline function idByName(name:String):cpp.UInt32 {
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
  #end

}
