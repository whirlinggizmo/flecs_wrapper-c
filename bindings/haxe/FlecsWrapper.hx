package hxcore.flecs.flecs_wrapper.bindings.haxe;

import cpp.Float32;
import cpp.UInt32;
import cpp.ConstCharStar;
import cpp.RawPointer;
import cpp.RawConstPointer;
import cpp.Pointer;
import cpp.ConstPointer;

// Type alias for pointer-sized unsigned integer
#if cpp_64
typedef UIntPtr = cpp.UInt64;
#else
typedef UIntPtr = cpp.UInt32;
#end

// Wrapper ID types (stable handles, not ecs_entity_t)
typedef EntityId = UInt32;
typedef ComponentId = UInt32;
typedef EventId = UInt32;
typedef ObserverId = UInt32;
typedef SystemId = UInt32;
typedef PairId = UInt32;

// Native callback signatures (match flecs_wrapper.h)
typedef SystemCallbackNative = cpp.Callable<
  (
    entityIds:RawConstPointer<EntityId>,
    entityCount:UInt32,
    columns:RawPointer<RawPointer<cpp.Void>>,
    columnComponentIds:RawConstPointer<ComponentId>,
    columnSizes:RawConstPointer<UInt32>,
    columnCount:UInt32,
    deltaTime:Float32,
    callbackId:UInt32
  ) -> Void
>;

typedef ObserverCallbackNative = cpp.Callable<
  (
    entityIds:RawConstPointer<EntityId>,
    entityCount:UInt32,
    columns:RawPointer<RawPointer<cpp.Void>>,
    columnComponentIds:RawConstPointer<ComponentId>,
    columnSizes:RawConstPointer<UInt32>,
    columnCount:UInt32,
    eventId:EventId,
    componentId:ComponentId,
    callbackId:UInt32
  ) -> Void
>;

@:buildXml('
<echo value="Compiling Flecs (wrapper)..." />
<echo value="hxlib path: ${haxelib:hxcore}" />
<files id="haxe">
  <compilerflag value="-I${haxelib:hxcore}/src/hxcore/flecs/flecs_wrapper/include"/>
  <file name="${haxelib:hxcore}/src/hxcore/flecs/flecs_wrapper/src/flecs.c" />
  <file name="${haxelib:hxcore}/src/hxcore/flecs/flecs_wrapper/src/flecs_wrapper.c" />
  <file name="${haxelib:hxcore}/src/hxcore/flecs/flecs_wrapper/src/flecs_wrapper_component.c" />
  <file name="${haxelib:hxcore}/src/hxcore/flecs/flecs_wrapper/src/flecs_wrapper_components.c" />
  <file name="${haxelib:hxcore}/src/hxcore/flecs/flecs_wrapper/src/flecs_wrapper_id.c" />
  <file name="${haxelib:hxcore}/src/hxcore/flecs/flecs_wrapper/src/flecs_wrapper_pair.c" />
  <file name="${haxelib:hxcore}/src/hxcore/flecs/flecs_wrapper/src/flecs_wrapper_world.c" />
  <file name="${haxelib:hxcore}/src/hxcore/flecs/flecs_wrapper/src/flecs_wrapper_entity.c" />
  <file name="${haxelib:hxcore}/src/hxcore/flecs/flecs_wrapper/src/flecs_wrapper_event.c" />
  <file name="${haxelib:hxcore}/src/hxcore/flecs/flecs_wrapper/src/flecs_wrapper_system.c" />
  <file name="${haxelib:hxcore}/src/hxcore/flecs/flecs_wrapper/src/systems/destination_system.c" />
  <file name="${haxelib:hxcore}/src/hxcore/flecs/flecs_wrapper/src/systems/move_system.c" />
</files>
')
@:headerInclude('flecs_wrapper.h')
@:keep
@:expose
class FlecsWrapper {
  // event types
  public static final EcsUnknownEvent:UInt32 = 0;
  public static final EcsOnAdd:UInt32 = 1;
  public static final EcsOnRemove:UInt32 = 2;
  public static final EcsOnSet:UInt32 = 3;
  public static final EcsOnDelete:UInt32 = 4;
  public static final EcsOnDeleteTarget:UInt32 = 5;
  public static final EcsOnTableCreate:UInt32 = 6;
  public static final EcsOnTableDelete:UInt32 = 7;

  // Component management
  @:native("flecs_component_get_id_by_name")
  extern public static function componentId(name:String):ComponentId;

  @:native("flecs_component_is_tag")
  extern public static function componentIsTag(componentId:ComponentId):Bool;

  @:native("flecs_component_print_registry")
  extern public static function componentPrintRegistry():Void;

  @:native("flecs_component_create")
  extern public static function componentCreate(name:String, size:UInt32):ComponentId;

  @:native("flecs_component_create_tag")
  extern public static function componentCreateTag(name:String):ComponentId;

  // Entity inspection
  @:native("flecs_entity_print_components")
  extern public static function entityPrintComponents(entityId:EntityId):Void;

  @:native("flecs_entity_has_component")
  extern public static function entityHasComponent(entityId:EntityId, componentId:ComponentId):Bool;

  @:native("flecs_entity_has_component_by_name")
  extern public static function entityHasComponentByName(entityId:EntityId, name:String):Bool;

  // Entity modification
  @:native("flecs_entity_add_component")
  extern public static function entityAddComponent(entityId:EntityId, componentId:ComponentId):Bool;

  @:native("flecs_entity_add_component_by_name")
  extern public static function entityAddComponentByName(entityId:EntityId, name:String):Bool;

  @:native("flecs_entity_remove_component")
  extern public static function entityRemoveComponent(entityId:EntityId, componentId:ComponentId):Bool;

  @:native("flecs_entity_remove_component_by_name")
  extern public static function entityRemoveComponentByName(entityId:EntityId, name:String):Bool;

  @:native("flecs_entity_set_component")
  extern public static function entitySetComponent(entityId:EntityId, componentId:ComponentId, componentPtr:Pointer<cpp.Void>):Bool;

  @:native("flecs_entity_get_component")
  extern public static function entityGetComponent(entityId:EntityId, componentId:ComponentId):Pointer<cpp.Void>;

  @:native("flecs_entity_mark_component")
  extern public static function entityMarkComponent(entityId:EntityId, componentId:ComponentId):Void;

  // Pair management
  @:native("flecs_pair_register")
  extern public static function pairRegister(relationComponentId:ComponentId, objectEntityId:EntityId):PairId;

  @:native("flecs_pair_register_entity")
  extern public static function pairRegisterEntity(relationEntityId:EntityId, objectEntityId:EntityId):PairId;

  @:native("flecs_pair_register_by_name")
  extern public static function pairRegisterByName(relationName:String, objectName:String):PairId;

  @:native("flecs_pair_unregister")
  extern public static function pairUnregister(pairId:PairId):Bool;

  @:native("flecs_entity_add_pair")
  extern public static function entityAddPair(entityId:EntityId, pairId:PairId):Bool;

  @:native("flecs_entity_remove_pair")
  extern public static function entityRemovePair(entityId:EntityId, pairId:PairId):Bool;

  @:native("flecs_entity_has_pair")
  extern public static function entityHasPair(entityId:EntityId, pairId:PairId):Bool;

  @:native("flecs_entity_set_pair")
  extern public static function entitySetPair(entityId:EntityId, pairId:PairId, pairPtr:Pointer<cpp.Void>):Bool;

  @:native("flecs_entity_get_pair")
  extern public static function entityGetPair(entityId:EntityId, pairId:PairId):Pointer<cpp.Void>;

  // Entity lifecycle
  @:native("flecs_entity_create")
  extern public static function entityCreate(name:String):EntityId;

  @:native("flecs_entity_destroy")
  extern public static function entityDestroy(entityId:EntityId):Bool;

  // Observer registration
  @:native("flecs_register_observer")
  extern public static function registerObserver(
    componentIds:RawPointer<ComponentId>,
    numComponents:UInt32,
    eventIds:RawPointer<EventId>,
    numEvents:UInt32,
    callback:ObserverCallbackNative,
    callbackId:UInt32
  ):ObserverId;

  @:native("flecs_register_observer_ex")
  extern public static function registerObserverEx(
    includeComponentIds:RawPointer<ComponentId>,
    numIncludeComponents:UInt32,
    excludeComponentIds:RawPointer<ComponentId>,
    numExcludeComponents:UInt32,
    eventIds:RawPointer<EventId>,
    numEvents:UInt32,
    callback:ObserverCallbackNative,
    callbackId:UInt32
  ):ObserverId;

  @:native("flecs_unregister_observer")
  extern public static function unregisterObserver(observerId:ObserverId):Bool;

  // System registration
  @:native("flecs_register_system")
  extern public static function registerSystem(
    name:String,
    componentIds:RawPointer<ComponentId>,
    numComponents:UInt32,
    callback:SystemCallbackNative,
    callbackId:UInt32
  ):SystemId;

  @:native("flecs_register_system_ex")
  extern public static function registerSystemEx(
    name:String,
    includeComponentIds:RawPointer<ComponentId>,
    numIncludeComponents:UInt32,
    excludeComponentIds:RawPointer<ComponentId>,
    numExcludeComponents:UInt32,
    callback:SystemCallbackNative,
    callbackId:UInt32
  ):SystemId;

  @:native("flecs_unregister_system")
  extern public static function unregisterSystem(systemId:SystemId):Bool;

  // Lifecycle
  @:native("flecs_init")
  extern public static function init():Void;

  @:native("flecs_progress")
  extern public static function progress(delta:Float32):Void;

  @:native("flecs_fini")
  extern public static function fini():Void;

  @:native("flecs_set_threads")
  extern public static function setThreads(threads:Int):Void;

  // Version
  @:native("flecs_version")
  extern public static function flecs_version():ConstCharStar;

  public static function version():String {
    return cast flecs_version();
  }
}


// Known components (from flecs_wrapper_components.h)
@:structAccess
@:structInit
@:nativeGen
@:keep
@:native("EntityId")
class EntityIdComponent {
  public var value:UInt32;
}


// NOTE: These are currently disabled because we removed them from flecs_wrapper_components.h to avoid collisions with user-defined components
// User has to define them themselves.
/*
@:structAccess
@:structInit
@:nativeGen
@:native("Position")
class Position {
  public var x:Float32;
  public var y:Float32;
  public var z:Float32;

  public function new(x:Float32 = 0, y:Float32 = 0, z:Float32 = 0) {
    this.x = x;
    this.y = y;
    this.z = z;
  }
}

@:structAccess
@:structInit
@:nativeGen
@:native("Velocity")
class Velocity {
  public var x:Float32;
  public var y:Float32;
  public var z:Float32;

  public function new(x:Float32 = 0, y:Float32 = 0, z:Float32 = 0) {
    this.x = x;
    this.y = y;
    this.z = z;
  }
}

@:structAccess
@:structInit
@:nativeGen
@:keep
@:native("Destination")
class Destination {
  public var x:Float32;
  public var y:Float32;
  public var z:Float32;
  public var speed:Float32;

  public function new(x:Float32 = 0, y:Float32 = 0, z:Float32 = 0, speed:Float32 = 0) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.speed = speed;
  }
}
*/
