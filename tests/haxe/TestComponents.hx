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
@:native("TestPos")
class TestPos {
  public var x:Float32;
  public var y:Float32;

  public function new() {}
}

class TestComponents extends Test {
  function testAddSetComponentAndTag():Void {
    TestCommon.withFlecs(function() {
      var pos = Component.create("HaxeTestPos", Native.sizeof(TestPos));
      var tag = Component.createTag("HaxeTestTag");

      Assert.isTrue(pos.id != 0);
      Assert.isFalse(pos.isTag());
      Assert.isTrue(tag.id != 0);
      Assert.isTrue(tag.isTag());

      var posFetch = Component.require("HaxeTestPos");
      Assert.equals(pos.id, posFetch.id);

      var e = Entity.create("HaxeAddEntity");
      Assert.isFalse(e.has(pos));
      Assert.isTrue(e.add(pos));
      Assert.isTrue(e.has(pos));
      Assert.isTrue(e.add("HaxeTestTag"));
      Assert.isTrue(e.has("HaxeTestTag"));

      var posVal = new TestPos();
      posVal.x = 1.5;
      posVal.y = -2.0;
      Assert.isTrue(e.set(pos, posVal));
      var pPtr:cpp.Pointer<TestPos> = e.getPtr(pos);
      Assert.isTrue(pPtr != null);
      var p = pPtr.ref;
      Assert.isTrue(Math.abs(p.x - 1.5) < 1e-6);
      Assert.isTrue(Math.abs(p.y - -2.0) < 1e-6);

      e.mark(pos);
    });
  }

  function testRemoveTagByName():Void {
    TestCommon.withFlecs(function() {
      var tag = Component.createTag("HaxeRemoveTag");
      var e = Entity.create("HaxeRemoveEntity");
      Assert.isTrue(e.add(tag));
      Assert.isTrue(e.has("HaxeRemoveTag"));
      Assert.isTrue(e.remove("HaxeRemoveTag"));
      Assert.isFalse(e.has("HaxeRemoveTag"));
    });
  }
}
