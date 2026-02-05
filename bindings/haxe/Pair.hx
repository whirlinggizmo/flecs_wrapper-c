package hxcore.flecs.flecs_wrapper.bindings.haxe;

import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper.PairId;

class Pair {
  public var id:PairId;

  public function new(id:PairId) {
    this.id = id;
  }

  public static inline function wrap(id:PairId):Pair {
    return new Pair(id);
  }

  static function resolvePairId(relation:Dynamic, object:Dynamic):PairId {
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

  public static function register(relation:Dynamic, object:Dynamic):Pair {
    var id = resolvePairId(relation, object);
    if (id == 0) {
      throw 'pairRegister failed';
    }
    return new Pair(id);
  }

  public static function unregister(pairId:PairId):Bool {
    return FlecsWrapper.pairUnregister(pairId);
  }
}
