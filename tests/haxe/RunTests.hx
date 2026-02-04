package hxcore.flecs.flecs_wrapper.tests.haxe;

import utest.Runner;
import utest.ui.Report;

class RunTests {
  static function main() {
    var runner = new Runner();
    runner.addCase(new TestFlecs());
    runner.addCase(new TestComponents());
    runner.addCase(new TestEntities());
    runner.addCase(new TestSystems());
    runner.addCase(new TestObservers());
    Report.create(runner);
    runner.run();
  }
}
