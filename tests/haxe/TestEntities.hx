package hxcore.flecs.flecs_wrapper.tests.haxe;

import cpp.Float32;
import cpp.Native;
import cpp.Pointer;
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
      var pPtr:cpp.Pointer<TestEntPos> = e.rawGet(pos);
      Assert.isTrue(pPtr != null);
      var p = pPtr.ref;
      Assert.isTrue(Math.abs(p.x - 2.0) < 1e-6);
      Assert.isTrue(Math.abs(p.y - -1.0) < 1e-6);

      var rel = Component.create("HaxePairRel", Native.sizeof(TestEntPos));
      var obj = Entity.create("HaxePairObj");
      Assert.isFalse(e.hasPair(rel, obj));
      Assert.isTrue(e.addPair(rel, obj));
      Assert.isTrue(e.hasPair(rel, obj));

      var relVal = new TestEntPos();
      relVal.x = 7.0;
      relVal.y = 8.0;
      Assert.isTrue(e.rawSetPair(rel, obj, cast Pointer.addressOf(relVal)));
      var pairPtr:cpp.Pointer<TestEntPos> = e.rawGetPairTyped(rel, obj);
      Assert.isTrue(pairPtr != null);
      Assert.isTrue(Math.abs(pairPtr.ref.x - 7.0) < 1e-6);
      Assert.isTrue(Math.abs(pairPtr.ref.y - 8.0) < 1e-6);

      Assert.isTrue(e.removePair(rel, obj));
      Assert.isFalse(e.hasPair(rel, obj));

      Assert.isTrue(obj.destroy());
      Assert.isTrue(e.destroy());
    });
  }
}
