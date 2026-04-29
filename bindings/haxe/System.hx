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

  public function rawColumnPtr(compId:ComponentId):Pointer<cpp.Void> {
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
  public inline function rawColumnPtrTyped<T>(compId:ComponentId):Pointer<T> {
    var idx = colIndex(compId);
    if (idx < 0) {
      return null;
    }
    if (columns[idx] == null) {
      return null;
    }
    return cast columns[idx];
  }

  public function rawColumn(compId:ComponentId, i:Int):Pointer<cpp.Void> {
    var ptrs:Pointer<cpp.Void> = rawColumnPtr(compId);
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
  public inline function rawColumnTyped<T>(compId:ComponentId, i:Int):Pointer<T> {
    var ptrs:Pointer<T> = rawColumnPtrTyped(compId);
    if (ptrs == null) {
      return null;
    }
    var c:Int = cast count;
    if (i < 0 || i >= c) {
      throw "column index out of bounds";
    }
    return cast ptrs.add(i);
  }

  public function rawComponentColumn(comp:Component, i:Int):Pointer<cpp.Void> {
    return rawColumn(comp.id, i);
  }

  @:generic
  public inline function rawComponentColumnTyped<T>(comp:Component, i:Int):Pointer<T> {
    return rawColumnTyped(comp.id, i);
  }

  public inline function tryColumn(comp:Component, i:Int):Dynamic {
    var ptr:Pointer<cpp.Void> = rawComponentColumn(comp, i);
    if (ptr == null) {
      return null;
    }
    return cast(cast ptr, Pointer<Dynamic>).ref;
  }

  public inline function column(comp:Component, i:Int):Dynamic {
    var value:Dynamic = tryColumn(comp, i);
    if (value == null) {
      throw 'Column value not found for component ${comp.name}';
    }
    return value;
  }

  @:generic
  public inline function each1<A>(
    a:Component,
    cb:(a:A) -> Void
  ):Void {
    var n:Int = cast count;
    var pa:Pointer<A> = rawColumnPtrTyped(a.id);
    if (pa == null) {
      return;
    }
    for (i in 0...n) {
      var av = pa.add(i).ref;
      cb(cast av);
      pa.add(i).ref = av;
    }
  }

  @:generic
  public inline function each2<A, B>(
    a:Component, b:Component,
    cb:(a:A, b:B) -> Void
  ):Void {
    var n:Int = cast count;
    var pa:Pointer<A> = rawColumnPtrTyped(a.id);
    var pb:Pointer<B> = rawColumnPtrTyped(b.id);
    if (pa == null || pb == null) {
      return;
    }
    for (i in 0...n) {
      var av = pa.add(i).ref;
      var bv = pb.add(i).ref;
      cb(cast av, cast bv);
      pa.add(i).ref = av;
      pb.add(i).ref = bv;
    }
  }

  @:generic
  public inline function each3<A, B, C>(
    a:Component, b:Component, c:Component,
    cb:(a:A, b:B, c:C) -> Void
  ):Void {
    var n:Int = cast count;
    var pa:Pointer<A> = rawColumnPtrTyped(a.id);
    var pb:Pointer<B> = rawColumnPtrTyped(b.id);
    var pc:Pointer<C> = rawColumnPtrTyped(c.id);
    if (pa == null || pb == null || pc == null) {
      return;
    }
    for (i in 0...n) {
      var av = pa.add(i).ref;
      var bv = pb.add(i).ref;
      var cv = pc.add(i).ref;
      cb(cast av, cast bv, cast cv);
      pa.add(i).ref = av;
      pb.add(i).ref = bv;
      pc.add(i).ref = cv;
    }
  }

  #if display
  // LSP/display mode fallback for it.each([...], cb) when extension macros
  // are not fully resolved by the language server.
  public inline function each(components:Array<Component>, cb:Dynamic):Void {
    if (components == null) {
      return;
    }
    switch (components.length) {
      case 0:
        var n:Int = cast count;
        for (_ in 0...n) {
          cb();
        }
      case 1:
        each1(components[0], cb);
      case 2:
        each2(components[0], components[1], cb);
      case 3:
        each3(components[0], components[1], components[2], cb);
      default:
        throw "it.each currently supports 0-3 components";
    }
  }
  #end

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
