package hxcore.flecs.flecs_wrapper.bindings.haxe;

import cpp.Pointer;
import cpp.RawPointer;
import cpp.RawConstPointer;
import cpp.UInt32;
import haxe.ds.IntMap;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper.ComponentId;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper.EntityId;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper.EventId;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper.ObserverId;

class ObserverIter {
  public var entityIds:Pointer<EntityId>;
  public var count:UInt32;
  public var columns:Array<Dynamic>;
  public var columnComponentIds:Array<ComponentId>;
  public var columnSizes:Array<UInt32>;
  public var eventId:EventId;
  public var componentId:ComponentId;
  public var callbackId:UInt32;

  public function new(
    entityIds:Pointer<EntityId>,
    count:UInt32,
    columns:Array<Dynamic>,
    columnComponentIds:Array<ComponentId>,
    columnSizes:Array<UInt32>,
    eventId:EventId,
    componentId:ComponentId,
    callbackId:UInt32
  ) {
    this.entityIds = entityIds;
    this.count = count;
    this.columns = columns;
    this.columnComponentIds = columnComponentIds;
    this.columnSizes = columnSizes;
    this.eventId = eventId;
    this.componentId = componentId;
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

  @:generic public inline function rawColumnPtrTyped<T>(compId:ComponentId):Pointer<T> {
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

  @:generic public inline function rawColumnTyped<T>(compId:ComponentId, i:Int):Pointer<T> {
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

  @:generic public inline function rawComponentColumnTyped<T>(comp:Component, i:Int):Pointer<T> {
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
}

typedef ObserverIterCallback = (it:ObserverIter) -> Void;

typedef ObserverCallback = (
  entityIds:Pointer<EntityId>,
  columns:Array<Dynamic>,
  columnComponentIds:Array<ComponentId>,
  columnSizes:Array<UInt32>,
  count:UInt32,
  eventId:EventId,
  componentId:ComponentId
) -> Void;

@:keep
class Observer {
  static var nextCallbackId:UInt32 = 1;
  static var callbackMap:IntMap<ObserverCallback> = new IntMap();

  static function registerCallback(cb:ObserverCallback, ?id:UInt32):UInt32 {
    if (cb == null) {
      throw "Observer callback is null";
    }
    var realId:UInt32 = id != null ? id : nextCallbackId++;
    if (callbackMap.exists(cast realId)) {
      throw 'callback already registered for id ${realId}';
    }
    callbackMap.set(cast realId, cb);
    return realId;
  }

  public static function removeObserver(id:ObserverId):Void {
    if (callbackMap.exists(cast id)) {
      callbackMap.remove(cast id);
    }
  }

  public static function unregisterObserver(id:ObserverId):Bool {
    removeObserver(id);
    return FlecsWrapper.unregisterObserver(id);
  }

  static function observerTrampoline(
    entityIds:RawConstPointer<EntityId>,
    entityCount:UInt32,
    columns:RawPointer<RawPointer<cpp.Void>>,
    columnComponentIds:RawConstPointer<ComponentId>,
    columnSizes:RawConstPointer<UInt32>,
    columnCount:UInt32,
    eventId:EventId,
    componentId:ComponentId,
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
    cb(entPtr, colPtrs, colIds, colSizes, entityCount, eventId, componentId);
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

  static function validateEventIds(events:Array<EventId>):Void {
    for (ev in events) {
      if (ev < 1) {
        throw 'Invalid event id: ${ev}';
      }
    }
  }

  static function addObserverIdsInternal(
    componentIds:Array<ComponentId>,
    eventIds:Array<EventId>,
    callback:ObserverIterCallback
  ):ObserverId {
    if (componentIds == null || componentIds.length == 0) {
      throw "Observer must include at least one component";
    }
    if (eventIds == null || eventIds.length == 0) {
      throw "Observer must include at least one event";
    }
    if (callback == null) {
      throw "Observer callback is null";
    }
    validateEventIds(eventIds);

    var cbid:UInt32 = 0;
    cbid = registerCallback(function(
      entities:Pointer<EntityId>,
      columns:Array<Dynamic>,
      columnComponentIds:Array<ComponentId>,
      columnSizes:Array<UInt32>,
      count:UInt32,
      eventId:EventId,
      componentId:ComponentId
    ) {
      callback(new ObserverIter(
        entities,
        count,
        columns,
        columnComponentIds,
        columnSizes,
        eventId,
        componentId,
        cbid
      ));
    });

    var compPtr = Pointer.ofArray(componentIds);
    var eventPtr = Pointer.ofArray(eventIds);

    return FlecsWrapper.registerObserver(
      compPtr.raw,
      cast componentIds.length,
      eventPtr.raw,
      cast eventIds.length,
      cpp.Callable.fromStaticFunction(observerTrampoline),
      cbid
    );
  }

  public static function addObserver(components:Array<Component>, events:Array<EventId>, callback:ObserverIterCallback):ObserverId {
    return addObserverIdsInternal(toComponentIds(components), events, callback);
  }

  public static function addObserverIds(componentIds:Array<ComponentId>, events:Array<EventId>, callback:ObserverIterCallback):ObserverId {
    return addObserverIdsInternal(componentIds, events, callback);
  }

  public static function addObserverNames(componentNames:Array<String>, events:Array<EventId>, callback:ObserverIterCallback):ObserverId {
    return addObserverIdsInternal(toComponentIdsFromNames(componentNames), events, callback);
  }

  static function addObserverExIdsInternal(
    includeIds:Array<ComponentId>,
    excludeIds:Array<ComponentId>,
    events:Array<EventId>,
    callback:ObserverIterCallback
  ):ObserverId {
    if (includeIds == null || includeIds.length == 0) {
      throw "Observer must include at least one component";
    }
    if (events == null || events.length == 0) {
      throw "Observer must include at least one event";
    }
    if (callback == null) {
      throw "Observer callback is null";
    }
    validateEventIds(events);

    var cbid:UInt32 = 0;
    cbid = registerCallback(function(
      entities:Pointer<EntityId>,
      columns:Array<Dynamic>,
      columnComponentIds:Array<ComponentId>,
      columnSizes:Array<UInt32>,
      count:UInt32,
      eventId:EventId,
      componentId:ComponentId
    ) {
      callback(new ObserverIter(
        entities,
        count,
        columns,
        columnComponentIds,
        columnSizes,
        eventId,
        componentId,
        cbid
      ));
    });

    var includePtr = Pointer.ofArray(includeIds);
    var excludePtr = (excludeIds != null && excludeIds.length > 0) ? Pointer.ofArray(excludeIds) : null;
    var eventPtr = Pointer.ofArray(events);

    return FlecsWrapper.registerObserverEx(
      includePtr.raw,
      cast includeIds.length,
      excludePtr == null ? null : excludePtr.raw,
      cast (excludeIds == null ? 0 : excludeIds.length),
      eventPtr.raw,
      cast events.length,
      cpp.Callable.fromStaticFunction(observerTrampoline),
      cbid
    );
  }

  public static function addObserverEx(
    includeComponents:Array<Component>,
    excludeComponents:Array<Component>,
    events:Array<EventId>,
    callback:ObserverIterCallback
  ):ObserverId {
    return addObserverExIdsInternal(
      toComponentIds(includeComponents),
      toComponentIds(excludeComponents),
      events,
      callback
    );
  }

  public static function addObserverExIds(
    includeIds:Array<ComponentId>,
    excludeIds:Array<ComponentId>,
    events:Array<EventId>,
    callback:ObserverIterCallback
  ):ObserverId {
    return addObserverExIdsInternal(includeIds, excludeIds, events, callback);
  }

  public static function addObserverExNames(
    includeNames:Array<String>,
    excludeNames:Array<String>,
    events:Array<EventId>,
    callback:ObserverIterCallback
  ):ObserverId {
    return addObserverExIdsInternal(
      toComponentIdsFromNames(includeNames),
      toComponentIdsFromNames(excludeNames),
      events,
      callback
    );
  }
}
