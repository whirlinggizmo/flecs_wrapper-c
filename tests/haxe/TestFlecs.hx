package hxcore.flecs.flecs_wrapper.tests.haxe;

import cpp.Float32;
import cpp.Pointer;
import cpp.RawPointer;
import cpp.RawConstPointer;
import cpp.UInt32;
import utest.Test;
import utest.Assert;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Flecs;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Flecs.ComponentId;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Flecs.EntityId;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Flecs.EventId;

class TestFlecs extends Test {
  static var systemSeen:Int = 0;
  static var observerSeen:Int = 0;
  static var observerEvent:EventId = 0;
  static var observerComp:ComponentId = 0;

  static function systemCb(
    entityIds:RawConstPointer<EntityId>,
    entityCount:UInt32,
    columns:RawPointer<RawPointer<cpp.Void>>,
    columnComponentIds:RawConstPointer<ComponentId>,
    columnSizes:RawConstPointer<UInt32>,
    columnCount:UInt32,
    deltaTime:Float32,
    callbackId:UInt32
  ):Void {
    systemSeen++;
  }

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
    observerSeen++;
    observerEvent = eventId;
    observerComp = componentId;
  }

  function testInitComponentEntity():Void {
    TestCommon.withFlecs(function() {
      var compId:ComponentId = Flecs.componentCreate("CorePos", 8);
      Assert.isTrue(compId != 0);
      Assert.equals(compId, Flecs.componentId("CorePos"));

      var tagId:ComponentId = Flecs.componentCreateTag("CoreTag");
      Assert.isTrue(tagId != 0);
      Assert.isTrue(Flecs.componentIsTag(tagId));

      var eId:EntityId = Flecs.entityCreate("CoreEntity");
      Assert.isTrue(eId != 0);
      Assert.isFalse(Flecs.entityHasComponentByName(eId, "CoreTag"));
      Assert.isTrue(Flecs.entityAddComponentByName(eId, "CoreTag"));
      Assert.isTrue(Flecs.entityHasComponentByName(eId, "CoreTag"));
      Assert.isTrue(Flecs.entityRemoveComponentByName(eId, "CoreTag"));
      Assert.isFalse(Flecs.entityHasComponentByName(eId, "CoreTag"));
      Assert.isTrue(Flecs.entityDestroy(eId));
    });
  }

  function testSystemCallbackRuns():Void {
    TestCommon.withFlecs(function() {
      systemSeen = 0;
      var compId:ComponentId = Flecs.componentCreate("CoreSysPos", 8);
      Assert.isTrue(compId != 0);

      var eId:EntityId = Flecs.entityCreate("CoreSysEntity");
      Assert.isTrue(eId != 0);
      Assert.isTrue(Flecs.entityAddComponent(eId, compId));

      var comps = [compId];
      var sysId = Flecs.registerSystem(
        "CoreSys",
        Pointer.ofArray(comps).raw,
        cast comps.length,
        cpp.Callable.fromStaticFunction(systemCb),
        1
      );
      Assert.isTrue(sysId != 0);

      Flecs.progress(0.5);
      Assert.isTrue(systemSeen >= 1);
      Assert.isTrue(Flecs.entityDestroy(eId));
    });
  }

  function testObserverFiresOnAdd():Void {
    TestCommon.withFlecs(function() {
      observerSeen = 0;
      observerEvent = 0;
      observerComp = 0;

      var compId:ComponentId = Flecs.componentCreate("CoreObsPos", 8);
      Assert.isTrue(compId != 0);

      var comps = [compId];
      var events = [Flecs.EcsOnAdd];
      var obsId = Flecs.registerObserver(
        Pointer.ofArray(comps).raw,
        cast comps.length,
        Pointer.ofArray(events).raw,
        cast events.length,
        cpp.Callable.fromStaticFunction(observerCb),
        1
      );
      Assert.isTrue(obsId != 0);

      var eId:EntityId = Flecs.entityCreate("CoreObsEntity");
      Assert.isTrue(eId != 0);
      Assert.isTrue(Flecs.entityAddComponent(eId, compId));

      Flecs.progress(0);
      Assert.isTrue(observerSeen >= 1);
      Assert.equals(Flecs.EcsOnAdd, observerEvent);
      Assert.equals(compId, observerComp);
      Assert.isTrue(Flecs.entityDestroy(eId));
    });
  }
}
