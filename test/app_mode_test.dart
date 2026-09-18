import 'package:flutter_test/flutter_test.dart';
import 'package:trailwire/features/tracking/models/app_mode.dart';

void main() {
  group('AppMode Enum Tests', () {
    test('contains exactly basecamp and activeTracking states', () {
      expect(AppMode.values.length, 2);
      expect(AppMode.values, contains(AppMode.basecamp));
      expect(AppMode.values, contains(AppMode.activeTracking));
    });

    test('has correct names and string representations', () {
      expect(AppMode.basecamp.name, 'basecamp');
      expect(AppMode.activeTracking.name, 'activeTracking');
    });
  });
}
