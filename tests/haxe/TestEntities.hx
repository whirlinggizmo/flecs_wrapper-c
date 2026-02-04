package hxcore.flecs.flecs_wrapper.tests.haxe;

import cpp.Float32;
import cpp.Native;
import utest.Test;
import utest.Assert;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Component;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Entity;

@:structAccess
@:structInit
@:nativeGen
@:native("TestEntPos")
class TestEntPos {
  public var x:Float32;
  public var y:Float32;

  public function new() {}
}

class TestEntities extends Test {
  function testCreateAddRemoveSetGet():Void {
    TestCommon.withFlecs(function() {
      var pos = Component.create("HaxeEntPos", Native.sizeof(TestEntPos));
      var tag = Component.createTag("HaxeEntTag");

      var e = Entity.create("HaxeEntity");
      Assert.isTrue(e.id != 0);
      Assert.isFalse(e.has("HaxeEntTag"));
      Assert.isTrue(e.add("HaxeEntTag"));
      Assert.isTrue(e.has("HaxeEntTag"));
      Assert.isTrue(e.remove("HaxeEntTag"));
      Assert.isFalse(e.has("HaxeEntTag"));

      var posVal = new TestEntPos();
      posVal.x = 2.0;
      posVal.y = -1.0;
      Assert.isTrue(e.set(pos, posVal));
      var pPtr:cpp.Pointer<TestEntPos> = e.getPtr(pos);
      Assert.isTrue(pPtr != null);
      var p = pPtr.ref;
      Assert.isTrue(Math.abs(p.x - 2.0) < 1e-6);
      Assert.isTrue(Math.abs(p.y - -1.0) < 1e-6);

      Assert.isTrue(e.destroy());
    });
  }
}
