import 'package:app_update_repository/app_update_repository.dart';
import 'package:test/test.dart';

void main() {
  group('resolveAndroidInstallSource', () {
    test('returns playStore for com.android.vending', () {
      expect(
        resolveAndroidInstallSource('com.android.vending'),
        equals(InstallSource.playStore),
      );
    });

    test('returns zapstore for com.zapstore.app', () {
      expect(
        resolveAndroidInstallSource('com.zapstore.app'),
        equals(InstallSource.zapstore),
      );
    });

    test('returns sideload for unknown installer', () {
      expect(
        resolveAndroidInstallSource('com.other.installer'),
        equals(InstallSource.sideload),
      );
    });

    test('returns sideload for null installer', () {
      expect(
        resolveAndroidInstallSource(null),
        equals(InstallSource.sideload),
      );
    });
  });

  group('resolveIosInstallSource', () {
    test('returns testFlight when sandbox', () {
      expect(
        resolveIosInstallSource(isSandbox: true),
        equals(InstallSource.testFlight),
      );
    });

    test('returns appStore when not sandbox', () {
      expect(
        resolveIosInstallSource(isSandbox: false),
        equals(InstallSource.appStore),
      );
    });
  });
}
