package hxcore.flecs.flecs_wrapper.tests.haxe;

import utest.Test;
import utest.Assert;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Component;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Entity;
import hxcore.flecs.flecs_wrapper.bindings.haxe.Pair;
import hxcore.flecs.flecs_wrapper.bindings.haxe.FlecsWrapper;

class TestPairs extends Test {
  function testPairRegisterAndUnregister():Void {
    TestCommon.withFlecs(function() {
      var rel = Component.create("PairRelHaxe", 8);
      var obj = Entity.create("PairObjHaxe");
      var host = Entity.create("PairHostHaxe");

      var pair = Pair.register(rel, obj);
      Assert.isTrue(pair.id != 0);

      Assert.isFalse(FlecsWrapper.entityHasPair(host.id, pair.id));
      Assert.isTrue(FlecsWrapper.entityAddPair(host.id, pair.id));
      Assert.isTrue(FlecsWrapper.entityHasPair(host.id, pair.id));
      Assert.isTrue(FlecsWrapper.entityRemovePair(host.id, pair.id));
      Assert.isFalse(FlecsWrapper.entityHasPair(host.id, pair.id));

      Assert.isTrue(Pair.unregister(pair.id));
      Assert.isFalse(FlecsWrapper.entityAddPair(host.id, pair.id));
    });
  }
}
