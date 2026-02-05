package hxcore.flecs.flecs_wrapper.bindings.haxe;

import cpp.Float32;
import cpp.Pointer;
import cpp.RawPointer;
import cpp.RawConstPointer;
import cpp.UInt32;
import haxe.ds.IntMap;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper.ComponentId;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper.EntityId;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper.SystemId;

class SystemIter {
  public var entityIds:Pointer<EntityId>;
  public var count:UInt32;
  public var columns:Array<Dynamic>;
  public var columnComponentIds:Array<ComponentId>;
  public var columnSizes:Array<UInt32>;
  public var dt:Float32;
  public var callbackId:UInt32;

  public function new(
    entityIds:Pointer<EntityId>,
    count:UInt32,
    columns:Array<Dynamic>,
    columnComponentIds:Array<ComponentId>,
    columnSizes:Array<UInt32>,
    dt:Float32,
    callbackId:UInt32
  ) {
    this.entityIds = entityIds;
    this.count = count;
    this.columns = columns;
    this.columnComponentIds = columnComponentIds;
    this.columnSizes = columnSizes;
    this.dt = dt;
    this.callbackId = callbackId;
  }

  public function entity(i:Int):EntityId {
    var c:Int = cast count;
    if (i < 0 || i >= c) {
      throw "entity index out of bounds";
    }
    return entityIds.add(i).ref;
  }

  public function colIndex(compId:ComponentId):Int {
    for (i in 0...columnComponentIds.length) {
      if (columnComponentIds[i] == compId) {
        return i;
      }
    }
    return -1;
  }

  public function colPtr(compId:ComponentId):Pointer<cpp.Void> {
    var idx = colIndex(compId);
    if (idx < 0) {
      return null;
    }
    if (columns[idx] == null) {
      return null;
    }
    return cast columns[idx];
  }

  @:generic
  public inline function colPtrTyped<T>(compId:ComponentId):Pointer<T> {
    var idx = colIndex(compId);
    if (idx < 0) {
      return null;
    }
    if (columns[idx] == null) {
      return null;
    }
    return cast columns[idx];
  }

  public function colPtrByComponent(comp:Component):Pointer<cpp.Void> {
    return colPtr(comp.id);
  }

  @:generic
  public inline function colPtrByComponentTyped<T>(comp:Component):Pointer<T> {
    return colPtrTyped(comp.id);
  }

  public function col(compId:ComponentId, i:Int):Pointer<cpp.Void> {
    var ptrs:Pointer<cpp.Void> = colPtr(compId);
    if (ptrs == null) {
      return null;
    }
    var c:Int = cast count;
    if (i < 0 || i >= c) {
      throw "column index out of bounds";
    }
    return cast ptrs.add(i);
  }

  @:generic
  public inline function colTyped<T>(compId:ComponentId, i:Int):Pointer<T> {
    var ptrs:Pointer<T> = colPtrTyped(compId);
    if (ptrs == null) {
      return null;
    }
    var c:Int = cast count;
    if (i < 0 || i >= c) {
      throw "column index out of bounds";
    }
    return cast ptrs.add(i);
  }

  public function colByComponent(comp:Component, i:Int):Pointer<cpp.Void> {
    return col(comp.id, i);
  }

  @:generic
  public inline function colByComponentTyped<T>(comp:Component, i:Int):Pointer<T> {
    return colTyped(comp.id, i);
  }
}

typedef SystemIterCallback = (it:SystemIter) -> Void;

typedef SystemCallback = (
  entityIds:Pointer<EntityId>,
  columns:Array<Dynamic>,
  columnComponentIds:Array<ComponentId>,
  columnSizes:Array<UInt32>,
  count:UInt32,
  deltaTime:Float32
) -> Void;

@:keep
class System {
  static var nextCallbackId:UInt32 = 1;
  static var callbackMap:IntMap<SystemCallback> = new IntMap();

  static function registerCallback(cb:SystemCallback, ?id:UInt32):UInt32 {
    if (cb == null) {
      throw "System callback is null";
    }
    var realId:UInt32 = id != null ? id : nextCallbackId++;
    if (callbackMap.exists(cast realId)) {
      throw 'callback already registered for id ${realId}';
    }
    callbackMap.set(cast realId, cb);
    return realId;
  }

  public static function removeSystem(id:SystemId):Void {
    if (callbackMap.exists(cast id)) {
      callbackMap.remove(cast id);
    }
  }

  public static function unregisterSystem(id:SystemId):Bool {
    removeSystem(id);
    return FlecsWrapper.unregisterSystem(id);
  }

  static function systemTrampoline(
    entityIds:RawConstPointer<EntityId>,
    entityCount:UInt32,
    columns:RawPointer<RawPointer<cpp.Void>>,
    columnComponentIds:RawConstPointer<ComponentId>,
    columnSizes:RawConstPointer<UInt32>,
    columnCount:UInt32,
    deltaTime:Float32,
    callbackId:UInt32
  ):Void {
    var cb = callbackMap.get(cast callbackId);
    if (cb == null) {
      return;
    }

    var colPtrs = new Array<Dynamic>();
    var colIds = new Array<ComponentId>();
    var colSizes = new Array<UInt32>();

    for (i in 0...columnCount) {
      var raw = columns[i];
      colPtrs.push(raw == null ? null : cast Pointer.fromRaw(raw));
      colIds.push(columnComponentIds[i]);
      colSizes.push(columnSizes[i]);
    }

    var entRaw:RawPointer<EntityId> = untyped __cpp__('(uint32_t*){0}', entityIds);
    var entPtr:Pointer<EntityId> = Pointer.fromRaw(entRaw);
    cb(entPtr, colPtrs, colIds, colSizes, entityCount, deltaTime);
  }

  static function toComponentIds(components:Array<Component>):Array<ComponentId> {
    var result = new Array<ComponentId>();
    if (components != null) {
      for (comp in components) {
        result.push(comp.id);
      }
    }
    return result;
  }

  static function toComponentIdsFromNames(names:Array<String>):Array<ComponentId> {
    var result = new Array<ComponentId>();
    if (names != null) {
      for (name in names) {
        var id = FlecsWrapper.componentId(name);
        if (id == 0) {
          throw 'Unknown component name: ${name}';
        }
        result.push(id);
      }
    }
    return result;
  }

  static function addSystemIdsInternal(name:String, componentIds:Array<ComponentId>, callback:SystemIterCallback):SystemId {
    if (componentIds == null || componentIds.length == 0) {
      throw "System must include at least one component";
    }
    if (callback == null) {
      throw "System callback is null";
    }

    var cbid:UInt32 = 0;
    cbid = registerCallback(function(
      entities:Pointer<EntityId>,
      columns:Array<Dynamic>,
      columnComponentIds:Array<ComponentId>,
      columnSizes:Array<UInt32>,
      count:UInt32,
      deltaTime:Float32
    ) {
      callback(new SystemIter(
        entities,
        count,
        columns,
        columnComponentIds,
        columnSizes,
        deltaTime,
        cbid
      ));
    });

    var compPtr = Pointer.ofArray(componentIds);
    return FlecsWrapper.registerSystem(
      name,
      compPtr.raw,
      cast componentIds.length,
      cpp.Callable.fromStaticFunction(systemTrampoline),
      cbid
    );
  }

  public static function addSystem(name:String, components:Array<Component>, callback:SystemIterCallback):SystemId {
    return addSystemIdsInternal(name, toComponentIds(components), callback);
  }

  public static function addSystemIds(name:String, componentIds:Array<ComponentId>, callback:SystemIterCallback):SystemId {
    return addSystemIdsInternal(name, componentIds, callback);
  }

  public static function addSystemNames(name:String, componentNames:Array<String>, callback:SystemIterCallback):SystemId {
    return addSystemIdsInternal(name, toComponentIdsFromNames(componentNames), callback);
  }

  public static function addTask(name:String, callback:SystemIterCallback):SystemId {
    if (callback == null) {
      throw "System callback is null";
    }

    var cbid:UInt32 = 0;
    cbid = registerCallback(function(
      entities:Pointer<EntityId>,
      columns:Array<Dynamic>,
      columnComponentIds:Array<ComponentId>,
      columnSizes:Array<UInt32>,
      count:UInt32,
      deltaTime:Float32
    ) {
      callback(new SystemIter(
        entities,
        count,
        columns,
        columnComponentIds,
        columnSizes,
        deltaTime,
        cbid
      ));
    });

    return FlecsWrapper.registerSystem(
      name,
      null,
      0,
      cpp.Callable.fromStaticFunction(systemTrampoline),
      cbid
    );
  }

  static function addSystemExIdsInternal(
    name:String,
    includeIds:Array<ComponentId>,
    excludeIds:Array<ComponentId>,
    callback:SystemIterCallback
  ):SystemId {
    if (includeIds == null || includeIds.length == 0) {
      throw "System must include at least one component";
    }
    if (callback == null) {
      throw "System callback is null";
    }

    var cbid:UInt32 = 0;
    cbid = registerCallback(function(
      entities:Pointer<EntityId>,
      columns:Array<Dynamic>,
      columnComponentIds:Array<ComponentId>,
      columnSizes:Array<UInt32>,
      count:UInt32,
      deltaTime:Float32
    ) {
      callback(new SystemIter(
        entities,
        count,
        columns,
        columnComponentIds,
        columnSizes,
        deltaTime,
        cbid
      ));
    });

    var includePtr = Pointer.ofArray(includeIds);
    var excludePtr = (excludeIds != null && excludeIds.length > 0) ? Pointer.ofArray(excludeIds) : null;

    return FlecsWrapper.registerSystemEx(
      name,
      includePtr.raw,
      cast includeIds.length,
      excludePtr == null ? null : excludePtr.raw,
      cast (excludeIds == null ? 0 : excludeIds.length),
      cpp.Callable.fromStaticFunction(systemTrampoline),
      cbid
    );
  }

  public static function addSystemEx(
    name:String,
    includeComponents:Array<Component>,
    excludeComponents:Array<Component>,
    callback:SystemIterCallback
  ):SystemId {
    return addSystemExIdsInternal(
      name,
      toComponentIds(includeComponents),
      toComponentIds(excludeComponents),
      callback
    );
  }

  public static function addSystemExIds(
    name:String,
    includeIds:Array<ComponentId>,
    excludeIds:Array<ComponentId>,
    callback:SystemIterCallback
  ):SystemId {
    return addSystemExIdsInternal(name, includeIds, excludeIds, callback);
  }

  public static function addSystemExNames(
    name:String,
    includeNames:Array<String>,
    excludeNames:Array<String>,
    callback:SystemIterCallback
  ):SystemId {
    return addSystemExIdsInternal(
      name,
      toComponentIdsFromNames(includeNames),
      toComponentIdsFromNames(excludeNames),
      callback
    );
  }
}
