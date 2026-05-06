import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Recorded call from `launchUrl(...)` made by the production code under test.
class LaunchedCall {
  LaunchedCall({required this.url, required this.useExternalApplication});

  final String url;
  final bool useExternalApplication;
}

/// Test double for `UrlLauncherPlatform` that records URL launch calls.
///
/// Install with:
/// ```dart
/// UrlLauncherPlatform.instance = UrlLauncherTestDouble();
/// ```
/// then assert against [launched] after the action under test runs.
class UrlLauncherTestDouble extends UrlLauncherPlatform {
  /// Calls captured in order of arrival.
  final List<LaunchedCall> launched = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launched.add(
      LaunchedCall(url: url, useExternalApplication: !useSafariVC),
    );
    return true;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(
      LaunchedCall(
        url: url,
        useExternalApplication:
            options.mode == PreferredLaunchMode.externalApplication,
      ),
    );
    return true;
  }
}
