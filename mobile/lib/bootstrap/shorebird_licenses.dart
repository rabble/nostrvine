import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:openvine/bootstrap/bundled_licenses.dart';

const _shorebirdUpdaterPackage = 'Shorebird updater';

/// Shorebird offers its native updater under MIT or Apache-2.0, at the
/// recipient's option. Both documents are shown under one package heading.
const _shorebirdUpdaterLicenses = <BundledLicense>[
  (
    packages: <String>[_shorebirdUpdaterPackage],
    assetPath: 'assets/licenses/Shorebird-MIT.txt',
  ),
  (
    packages: <String>[_shorebirdUpdaterPackage],
    assetPath: 'assets/licenses/Shorebird-APACHE.txt',
  ),
];

/// Yields the license choices for the native updater linked into store builds.
Stream<LicenseEntry> shorebirdLicenseEntries(AssetBundle bundle) =>
    bundledLicenseEntries(bundle, _shorebirdUpdaterLicenses);

/// Registers the native Shorebird updater with the global [LicenseRegistry].
///
/// Registration is lazy: the assets load only when the license page enumerates
/// the registry.
void registerShorebirdLicenses() {
  LicenseRegistry.addLicense(() => shorebirdLicenseEntries(rootBundle));
}
