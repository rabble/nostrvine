/// How the app was installed, used to determine the correct upgrade URL.
enum InstallSource {
  /// Google Play Store.
  playStore,

  /// Apple App Store.
  appStore,

  /// Apple TestFlight.
  testFlight,

  /// Zapstore (Nostr app store).
  zapstore,

  /// Direct APK sideload or unknown source.
  sideload
  ;

  /// The installer package name on Android for Play Store.
  static const playStoreInstaller = 'com.android.vending';

  /// The installer package name on Android for Zapstore.
  static const zapstoreInstaller = 'com.zapstore.app';
}

/// Download URLs for each install source.
abstract class DownloadUrls {
  /// Google Play Store listing.
  static const playStore =
      'https://play.google.com/store/apps/details?id=com.divinevideo.app';

  /// Apple App Store listing.
  static const appStore =
      'https://apps.apple.com/app/divine-human-video/id6740425428';

  /// TestFlight link.
  static const testFlight = 'https://testflight.apple.com/join/divine';

  /// Zapstore listing.
  static const zapstore = 'https://zapstore.dev/app/com.divinevideo.app';

  /// GitHub releases page.
  static const github =
      'https://github.com/divinevideo/divine-mobile/releases/latest';

  /// Returns the download URL for the given [source].
  static String forSource(InstallSource source) {
    return switch (source) {
      InstallSource.playStore => playStore,
      InstallSource.appStore => appStore,
      InstallSource.testFlight => testFlight,
      InstallSource.zapstore => zapstore,
      InstallSource.sideload => github,
    };
  }
}
