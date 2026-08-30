import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A license bundled as an app asset and the package names it covers.
typedef BundledLicense = ({List<String> packages, String assetPath});

/// Loads bundled license assets as entries understood by [LicenseRegistry].
Stream<LicenseEntry> bundledLicenseEntries(
  AssetBundle bundle,
  Iterable<BundledLicense> licenses,
) async* {
  for (final license in licenses) {
    final licenseText = await bundle.loadString(license.assetPath);
    yield LicenseEntryWithLineBreaks(license.packages, licenseText);
  }
}
