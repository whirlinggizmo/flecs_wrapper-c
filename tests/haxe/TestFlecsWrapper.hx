package hxcore.flecs.flecs_wrapper.tests.haxe;

import cpp.Float32;
import cpp.Pointer;
import cpp.RawPointer;
import cpp.RawConstPointer;
import cpp.UInt32;
import cpp.Native;
import utest.Test;
import utest.Assert;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Flecs;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper.ComponentId;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper.EntityId;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper.EventId;

@:structAccess
@:structInit
@:nativeGen
class Vec2 {
  public var x:Float32;
  public var y:Float32;

  public function new(x:Float32 = 0, y:Float32 = 0) {
    this.x = x;
    this.y = y;
  }
}

class TestFlecsWrapper extends Test {
  static var seenAdd:Int = 0;
  static var seenSet:Int = 0;
  static var lastEvent:EventId = 0;
  static var lastComp:ComponentId = 0;
  static var lastEntity:EntityId = 0;
  static var lastX:Float32 = 0;
  static var lastY:Float32 = 0;

  static function observerCb(
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
    if (callbackId != 123) {
      return;
    }

    if (entityCount == 0 || columnCount == 0) {
      return;
    }

    lastEvent = eventId;
    lastComp = componentId;

    var entPtr:Pointer<EntityId> = Pointer.fromRaw(cast entityIds);
    lastEntity = entPtr.ref;

    var compPtr:Pointer<ComponentId> = Pointer.fromRaw(cast columnComponentIds);
    var sizePtr:Pointer<UInt32> = Pointer.fromRaw(cast columnSizes);

    var colsPtr:Pointer<RawPointer<cpp.Void>> = Pointer.fromRaw(columns);
    var col0:RawPointer<cpp.Void> = colsPtr.ref;
    if (col0 != null) {
      var vecPtr:Pointer<Vec2> = Pointer.fromRaw(cast col0);
      lastX = vecPtr.ref.x;
      lastY = vecPtr.ref.y;
    }

    if (eventId == Flecs.EcsOnAdd) {
      seenAdd++;
    } else if (eventId == Flecs.EcsOnSet) {
      seenSet++;
    }
  }

  function testLowLevelWrapper():Void {
    TestCommon.withFlecs(function() {
      seenAdd = 0;
      seenSet = 0;
      lastEvent = 0;
      lastComp = 0;
      lastEntity = 0;
      lastX = 0;
      lastY = 0;

      var vecSize:UInt32 = cast Native.sizeof(Vec2);
      var compId:ComponentId = Flecs.componentCreate("CoreVec2", vecSize);
      Assert.isTrue(compId != 0);
      Assert.equals(compId, Flecs.componentId("CoreVec2"));
      Assert.isFalse(Flecs.componentIsTag(compId));

      var eId:EntityId = Flecs.entityCreate("CoreEntity");
      Assert.isTrue(eId != 0);
      Assert.isFalse(Flecs.entityHasComponent(eId, compId));

      var v1 = new Vec2(1, 2);
      Assert.isTrue(Flecs.entitySetComponent(eId, compId, cast Pointer.addressOf(v1)));
      Assert.isTrue(Flecs.entityHasComponent(eId, compId));

      var ptr = Flecs.entityGetComponent(eId, compId);
      Assert.notNull(ptr);
      var vPtr:Pointer<Vec2> = Pointer.fromRaw(cast ptr);
      Assert.equals(1, vPtr.ref.x);
      Assert.equals(2, vPtr.ref.y);

      var objId:EntityId = Flecs.entityCreate("CorePairObj");
      Assert.isTrue(objId != 0);

      var pairId = Flecs.pairRegister(compId, objId);
      Assert.isTrue(pairId != 0);
      Assert.isFalse(Flecs.entityHasPair(eId, pairId));
      Assert.isTrue(Flecs.entityAddPair(eId, pairId));
      Assert.isTrue(Flecs.entityHasPair(eId, pairId));

      var p1 = new Vec2(7, 8);
      Assert.isTrue(Flecs.entitySetPair(eId, pairId, cast Pointer.addressOf(p1)));
      var pPtr = Flecs.entityGetPair(eId, pairId);
      Assert.notNull(pPtr);
      var pv:Pointer<Vec2> = Pointer.fromRaw(cast pPtr);
      Assert.equals(7, pv.ref.x);
      Assert.equals(8, pv.ref.y);

      Assert.isTrue(Flecs.entityRemovePair(eId, pairId));
      Assert.isFalse(Flecs.entityHasPair(eId, pairId));

      Assert.isTrue(Flecs.pairUnregister(pairId));
      Assert.isFalse(Flecs.entityAddPair(eId, pairId));
      var pairId2 = Flecs.pairRegister(compId, objId);
      Assert.isTrue(pairId2 != 0);
      Assert.isTrue(Flecs.entityAddPair(eId, pairId2));

      var comps = [compId];
      var events = [Flecs.EcsOnAdd, Flecs.EcsOnSet];
      var obsId = Flecs.registerObserver(
        Pointer.ofArray(comps).raw,
        cast comps.length,
        Pointer.ofArray(events).raw,
        cast events.length,
        cpp.Callable.fromStaticFunction(observerCb),
        123
      );
      Assert.isTrue(obsId != 0);

      var v2 = new Vec2(3, 4);
      Assert.isTrue(Flecs.entitySetComponent(eId, compId, cast Pointer.addressOf(v2)));

      var v3 = new Vec2(5, 6);
      Assert.isTrue(Flecs.entitySetComponent(eId, compId, cast Pointer.addressOf(v3)));

      Flecs.progress(0);

      Assert.equals(compId, lastComp);
      Assert.equals(eId, lastEntity);
      Assert.isTrue(seenSet >= 1);
      Assert.equals(5, lastX);
      Assert.equals(6, lastY);

      Assert.isTrue(Flecs.unregisterObserver(obsId));

      var badEvents = [cast 99];
      var badObs = Flecs.registerObserver(
        Pointer.ofArray(comps).raw,
        cast comps.length,
        Pointer.ofArray(badEvents).raw,
        cast badEvents.length,
        cpp.Callable.fromStaticFunction(observerCb),
        999
      );
      Assert.equals(0, badObs);

      Assert.isTrue(Flecs.entityDestroy(objId));
      Assert.isTrue(Flecs.entityDestroy(eId));
    });
  }
}
