import 'package:flutter_test/flutter_test.dart';
import 'package:mwavuli/core/update/app_update_checker.dart';

void main() {
  group('AppUpdateChecker.isVersionHigher', () {
    test('returns true when latest is higher than current', () {
      expect(AppUpdateChecker.isVersionHigher('0.1.2', '0.1.1'), isTrue);
      expect(AppUpdateChecker.isVersionHigher('0.2.0', '0.1.9'), isTrue);
      expect(AppUpdateChecker.isVersionHigher('1.0.0', '0.9.9'), isTrue);
      expect(AppUpdateChecker.isVersionHigher('0.1.10', '0.1.2'), isTrue);
      expect(AppUpdateChecker.isVersionHigher('v0.1.2+5', '0.1.1'), isTrue);
    });

    test('returns false when latest is equal or lower than current', () {
      expect(AppUpdateChecker.isVersionHigher('0.1.1', '0.1.1'), isFalse);
      expect(AppUpdateChecker.isVersionHigher('0.1.1', '0.1.2'), isFalse);
      expect(AppUpdateChecker.isVersionHigher('0.1.0', '0.2.0'), isFalse);
      expect(AppUpdateChecker.isVersionHigher('', '0.1.1'), isFalse);
      expect(AppUpdateChecker.isVersionHigher('v0.1.1', '0.1.2'), isFalse);
    });
  });
}
