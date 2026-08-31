import 'package:app_update_repository/app_update_repository.dart';
import 'package:test/test.dart';

void main() {
  group('DownloadUrls', () {
    test('uses the shipped store listing URLs', () {
      expect(
        DownloadUrls.playStore,
        equals('https://play.google.com/store/apps/details?id=co.openvine.app'),
      );
      expect(
        DownloadUrls.appStore,
        equals('https://apps.apple.com/app/id6747959501'),
      );
      expect(
        DownloadUrls.testFlight,
        equals('https://apps.apple.com/app/id6747959501'),
      );
      expect(
        DownloadUrls.zapstore,
        equals('https://zapstore.dev/apps/co.openvine.app'),
      );
      expect(
        DownloadUrls.github,
        equals('https://github.com/divinevideo/divine-mobile/releases/latest'),
      );
    });

    test('maps every install source to its download URL', () {
      const expectedUrls = <InstallSource, String>{
        InstallSource.playStore: DownloadUrls.playStore,
        InstallSource.appStore: DownloadUrls.appStore,
        InstallSource.testFlight: DownloadUrls.testFlight,
        InstallSource.zapstore: DownloadUrls.zapstore,
        InstallSource.sideload: DownloadUrls.github,
      };

      expect(expectedUrls.keys, containsAll(InstallSource.values));
      for (final source in InstallSource.values) {
        expect(DownloadUrls.forSource(source), expectedUrls[source]);
      }
    });
  });
}
