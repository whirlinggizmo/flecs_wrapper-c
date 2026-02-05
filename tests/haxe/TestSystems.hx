package hxcore.flecs.flecs_wrapper.tests.haxe;

import cpp.Float32;
import cpp.Native;
import utest.Test;
import utest.Assert;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Component;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Entity;
import hxcore.flecs.flecs_wrapper.bindings.haxe.System;

@:structAccess
@:structInit
@:nativeGen
@:native("TestSysPos")
class TestSysPos {
  public var x:Float32;
  public var y:Float32;

  public function new() {}
}

@:structAccess
@:structInit
@:nativeGen
@:native("TestSysVel")
class TestSysVel {
  public var x:Float32;
  public var y:Float32;

  public function new() {}
}

class TestSystems extends Test {
  function testSystemUpdatesPosition():Void {
    TestCommon.withFlecs(function() {
      var pos = Component.create("HaxeSysPos", Native.sizeof(TestSysPos));
      var vel = Component.create("HaxeSysVel", Native.sizeof(TestSysVel));

      var e = Entity.create("HaxeSystemEntity");
      var posVal = new TestSysPos();
      posVal.x = 0.0;
      posVal.y = 0.0;
      Assert.isTrue(e.set(pos, posVal));

      var velVal = new TestSysVel();
      velVal.x = 2.0;
      velVal.y = 0.0;
      Assert.isTrue(e.set(vel, velVal));

      var sysSeen = 0;
      var sysId = System.addSystemIds("HaxeMove", [pos.id, vel.id], function(it) {
        var count:Int = cast it.count;
        for (i in 0...count) {
          var p:cpp.Pointer<TestSysPos> = it.colTyped(pos.id, i);
          var v:cpp.Pointer<TestSysVel> = it.colTyped(vel.id, i);
          if (p != null && v != null) {
            p.ref.x += v.ref.x * it.dt;
            sysSeen++;
          }
        }
      });
      Assert.isTrue(sysId != 0);

      hxcore.flecs.flecs_wrapper.bindings.haxe.Flecs.progress(0.5);
      var p2Ptr:cpp.Pointer<TestSysPos> = e.getPtr(pos);
      Assert.isTrue(p2Ptr != null);
      var p2 = p2Ptr.ref;
      Assert.isTrue(Math.abs(p2.x - 1.0) < 1e-6);
      Assert.isTrue(sysSeen >= 1);

      Assert.isTrue(System.unregisterSystem(sysId));
    });
  }
}
