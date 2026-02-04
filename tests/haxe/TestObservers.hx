package hxcore.flecs.flecs_wrapper.tests.haxe;

import cpp.Float32;
import cpp.Native;
import cpp.UInt32;
import utest.Test;
import utest.Assert;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Component;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Entity;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Flecs;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Observer;

@:structAccess
@:structInit
@:nativeGen
@:native("TestObsPos")
class TestObsPos {
  public var x:Float32;
  public var y:Float32;

  public function new() {}
}

class TestObservers extends Test {
  function testOnAddObserverAndExclusions():Void {
    TestCommon.withFlecs(function() {
      var pos = Component.create("HaxeObsPos", Native.sizeof(TestObsPos));
      var tag = Component.createTag("HaxeObsTag");

      var obsSeen = 0;
      var lastEntity:UInt32 = 0;
      var lastComponent:UInt32 = 0;

      var obsId = Observer.addObserverIds([pos.id], [Flecs.EcsOnAdd], function(it) {
        obsSeen++;
        lastEntity = it.entity(0);
        lastComponent = it.componentId;
      });
      Assert.isTrue(obsId != 0);

      var e = Entity.create("ObsEntity");
      var posVal = new TestObsPos();
      posVal.x = 3.0;
      posVal.y = 4.0;
      e.set(pos, posVal);

      Flecs.progress(0);
      Assert.isTrue(obsSeen >= 1);
      Assert.equals(e.id, lastEntity);
      Assert.equals(pos.id, lastComponent);

      var obsExSeen = 0;
      var obsExId = Observer.addObserverExIds([pos.id], [tag.id], [Flecs.EcsOnAdd], function(it) {
        obsExSeen++;
      });
      Assert.isTrue(obsExId != 0);

      var e4 = Entity.create("ObsExEntity1");
      var posVal4 = new TestObsPos();
      posVal4.x = 1.0;
      posVal4.y = 1.0;
      e4.set(pos, posVal4);
      var e5 = Entity.create("ObsExEntity2");
      e5.add(tag);
      var posVal5 = new TestObsPos();
      posVal5.x = 2.0;
      posVal5.y = 2.0;
      e5.set(pos, posVal5);

      Flecs.progress(0);
      Assert.equals(1, obsExSeen);

      var threw = false;
      try {
        Observer.addObserverIds([pos.id], [0], function(it) {});
      } catch (e:Dynamic) {
        threw = true;
      }
      Assert.isTrue(threw);
    });
  }
}
