import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// A bundled OFL font: the family name shown on the license page and the asset
/// path to its SIL Open Font License 1.1 text.
typedef _BundledFontLicense = ({String family, String assetPath});

/// The OFL fonts shipped in the app binary under `assets/fonts/`.
///
/// The `google_fonts` package does not register bundled-font licenses (its
/// README leaves that to the app), and Flutter does not register licenses for
/// app-level `fonts:` assets. Without these entries the fonts we distribute
/// would be absent from Settings → Legal → Open Source Licenses. See #3659.
const _bundledFontLicenses = <_BundledFontLicense>[
  (family: 'Inter', assetPath: 'assets/licenses/Inter-OFL.txt'),
  (
    family: 'Bricolage Grotesque',
    assetPath: 'assets/licenses/BricolageGrotesque-OFL.txt',
  ),
  (family: 'Pacifico', assetPath: 'assets/licenses/Pacifico-OFL.txt'),
  // Rendered via GoogleFonts.chivoMono (VineTheme.captionPillFont / codeFont);
  // bundled as assets/fonts/ChivoMono-Light.ttf, so its license ships too.
  (family: 'Chivo Mono', assetPath: 'assets/licenses/ChivoMono-OFL.txt'),
];

/// Yields one [LicenseEntry] per bundled OFL font so [showLicensePage]
/// attributes each family separately.
///
/// [bundle] is injectable so the entries can be exercised in tests without
/// touching the global [LicenseRegistry].
Stream<LicenseEntry> bundledFontLicenseEntries(AssetBundle bundle) async* {
  for (final font in _bundledFontLicenses) {
    final licenseText = await bundle.loadString(font.assetPath);
    yield LicenseEntryWithLineBreaks(<String>[font.family], licenseText);
  }
}

/// Registers the bundled fonts' OFL licenses with the global [LicenseRegistry].
///
/// Call once during startup, before the license page can be opened. The
/// collector is lazy: the license assets load only when the license page
/// enumerates the registry.
void registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() => bundledFontLicenseEntries(rootBundle));
}
