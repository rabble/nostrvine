// ABOUTME: Widget tests for VerifierWebViewScreen — title + WebView mount.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/verifier_webview_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class _FakeWebViewControllerPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return _FakePlatformWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return _FakePlatformWebViewWidget(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return _FakePlatformNavigationDelegate(params);
  }
}

class _FakePlatformWebViewController extends PlatformWebViewController {
  _FakePlatformWebViewController(super.params) : super.implementation();

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}
}

class _FakePlatformNavigationDelegate extends PlatformNavigationDelegate {
  _FakePlatformNavigationDelegate(super.params) : super.implementation();
}

class _FakePlatformWebViewWidget extends PlatformWebViewWidget {
  _FakePlatformWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) =>
      const SizedBox.shrink(key: Key('fake-webview'));
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  setUpAll(() {
    WebViewPlatform.instance = _FakeWebViewControllerPlatform();
  });

  group(VerifierWebViewScreen, () {
    testWidgets('mounts a WebViewWidget', (tester) async {
      await tester.pumpWidget(
        _wrap(
          VerifierWebViewScreen(
            url: Uri.parse('https://verifier.divine.video'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(WebViewWidget), findsOneWidget);
    });

    testWidgets('shows the localized verifier title in the app bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          VerifierWebViewScreen(
            url: Uri.parse('https://verifier.divine.video'),
          ),
        ),
      );
      await tester.pump();
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.verifierWebViewTitle), findsOneWidget);
    });
  });
}
