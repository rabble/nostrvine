// ABOUTME: Decides whether a directory app opens in the system browser or the
// ABOUTME: in-app sandbox, and launches it accordingly.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Slugs of first-party apps that perform cross-origin login / OAuth
/// hand-offs and therefore cannot run inside the locked-down in-app
/// WebView sandbox — its origin allowlist blocks those navigations
/// (the verifyer dead-ends at `login.divine.video` and the OAuth
/// providers). These open in the system browser instead.
///
/// Keyed by slug because the directory merges remote/cached entries over
/// preloaded ones by slug (see
/// `NostrAppDirectoryService._mergeWithPreloadedApps`), so the slug is the
/// identity that survives a remote override — a server-sent flag on the
/// preloaded entry would not. If the verifyer slug changes, update this set.
const Set<String> kSystemBrowserAppSlugs = {'verifyer'};

/// Whether [app] must be opened in the system browser rather than the
/// in-app sandbox.
bool appRequiresSystemBrowser(NostrAppDirectoryEntry app) =>
    kSystemBrowserAppSlugs.contains(app.slug);

/// Opens [app] from the directory.
///
/// Apps that need cross-origin login/OAuth ([appRequiresSystemBrowser])
/// launch in the system browser, where cookies and provider redirects
/// work; everything else opens in the in-app sandbox. Shows a snackbar
/// when a system-browser launch fails.
Future<void> launchNostrApp(
  BuildContext context,
  NostrAppDirectoryEntry app,
) async {
  if (!appRequiresSystemBrowser(app)) {
    await context.push(
      NostrAppSandboxScreen.pathForAppId(app.id),
      extra: app,
    );
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  final errorText = context.l10n.relaySettingsCouldNotOpenBrowser;
  final launched = await launchUrl(
    Uri.parse(app.launchUrl),
    mode: LaunchMode.externalApplication,
  );
  if (!launched) {
    messenger.showSnackBar(
      SnackBar(content: Text(errorText), backgroundColor: VineTheme.error),
    );
  }
}
