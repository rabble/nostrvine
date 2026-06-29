import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/screens/apps/web_iframe_sandbox_screen.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

typedef VerifierRoutePusher =
    Future<void> Function(String location, {Object? extra});

/// Opens the Divine verifier.
///
/// Native in-app WebViews cannot complete the verifier's login flow because it
/// leaves `verifier.divine.video` for `login.divine.video` and OAuth providers.
/// Those hand-offs need real browser tabs, cookies, and redirects, so native
/// platforms launch the system browser. Flutter web keeps the existing iframe
/// signer bridge because it runs in the browser and does not use
/// `webview_flutter`. Web refreshes after the iframe route returns; native
/// refreshes from the screen's app-resume callback.
Future<bool> launchVerifierFlow({
  required ProfileEditorBloc editorBloc,
  required MyProfileBloc myProfileBloc,
  VerifierRoutePusher? pushVerifierRoute,
  bool isWeb = kIsWeb,
}) async {
  final verifier = preloadedNostrApps.firstWhere(
    (app) => app.slug == 'verifier',
  );

  var launched = false;
  try {
    if (isWeb && pushVerifierRoute != null) {
      await pushVerifierRoute(
        WebIframeSandboxScreen.pathForAppId(verifier.id),
        extra: verifier,
      );
      launched = true;
    } else {
      launched = await launchUrl(
        Uri.parse(verifier.launchUrl),
        mode: LaunchMode.externalApplication,
      );
    }
  } catch (error) {
    UnifiedLogger.warning(
      'Failed to open Divine verifier: $error',
      name: 'ProfileSetupScreen',
    );
  }

  editorBloc.add(const VerifierLaunchHandled());
  if (launched && isWeb) {
    myProfileBloc.add(const MyProfileFetchRequested());
  }
  return launched;
}
