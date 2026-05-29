import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/toy_category_registry.dart';
import 'package:toyvision_realtime/business/toy_counting_service.dart';
import 'package:toyvision_realtime/business/toy_detection_rules.dart';
import 'package:toyvision_realtime/core/config/realtime_detection_config.dart';
import 'package:toyvision_realtime/testing/scenario_builders.dart';
import 'package:toyvision_realtime/tracking/toy_tracking_engine.dart';

/// Runs a scenario through the full business pipeline (validate → track → count)
/// and returns the final total count. This mirrors what the live controller does
/// each frame, minus the camera and UI.
int runScenario(Scenario scenario, {RealtimeDetectionConfig? config}) {
  final cfg = config ?? const RealtimeDetectionConfig();
  final rules = ToyDetectionRules(ToyCategoryRegistry.standard());
  final engine = ToyTrackingEngine(config: cfg);
  final counting = ToyCountingService(config: cfg);

  var total = 0;
  for (final frame in scenario) {
    final validated = rules.validate(frame);
    final tracked = engine.update(validated);
    total = counting.update(tracked).total;
  }
  return total;
}

void main() {
  test('one toy visible for several seconds is counted exactly once', () {
    expect(runScenario(ScenarioBuilders.oneToyVisible(frames: 8)), 1);
  });

  test('a toy seen alongside a person counts only the toy', () {
    expect(runScenario(ScenarioBuilders.toyWithPerson(frames: 8)), 1);
  });

  test('a toy that briefly disappears is still counted only once', () {
    expect(
      runScenario(ScenarioBuilders.toyDisappearsBriefly()),
      1,
    );
  });

  test('multiple distinct toys are each counted once', () {
    expect(runScenario(ScenarioBuilders.multipleToys(frames: 8)), 2);
  });

  test('an empty scene counts nothing', () {
    expect(runScenario(List.generate(10, (_) => const [])), 0);
  });
}
