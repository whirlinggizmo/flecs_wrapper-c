package hxcore.flecs.flecs_wrapper.tests.haxe;

import hxcore.flecs.flecs_wrapper.bindings.haxe.Flecs;

class TestCommon {
  public static function withFlecs(fn:Void->Void):Void {
    Flecs.init();
    Flecs.setThreads(1);
    var err:Dynamic = null;
    try {
      fn();
    } catch (e:Dynamic) {
      err = e;
    }
    Flecs.fini();
    if (err != null) {
      throw err;
    }
  }
}
