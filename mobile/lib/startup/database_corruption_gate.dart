// ABOUTME: Replaces the app UI with a restart prompt once the local database
// ABOUTME: reports on-disk corruption, so the next launch can salvage it.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/database_corruption_provider.dart';

/// Swaps [child] for [DatabaseCorruptionScreen] once corruption surfaces.
///
/// Installed as `MaterialApp.builder`, so it covers every route with one gate
/// rather than each screen having to handle a dead database itself.
///
/// The takeover is total on purpose. `DatabaseCorruptionService.isCorrupted`
/// only ever flips once, and nothing repairs the open database in place: from
/// that point on every read against the damaged pages throws, so leaving the
/// user in the app only trades one broken screen for the next. Recovery needs a
/// restart (see the service for why it cannot happen in-session), so the honest
/// move is to say so immediately.
class DatabaseCorruptionGate extends ConsumerWidget {
  /// Creates a gate wrapping [child].
  const DatabaseCorruptionGate({required this.child, super.key});

  /// The normal app UI, shown while the database is healthy.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(databaseCorruptionServiceProvider);
    // Null in widget tests and on web, where no interceptor reports corruption.
    if (service == null) return child;

    return ValueListenableBuilder<bool>(
      valueListenable: service.isCorrupted,
      builder: (context, isCorrupted, healthyChild) =>
          isCorrupted ? const DatabaseCorruptionScreen() : healthyChild!,
      child: child,
    );
  }
}

/// Tells the user their local database is damaged and a restart repairs it.
///
/// The sibling of `DatabaseBootstrapFailureApp`, for corruption that surfaces
/// *after* startup. It closes the app rather than restarting it because Flutter
/// cannot relaunch its own process; `SystemNavigator.pop` is the same affordance
/// the startup failure screen offers.
class DatabaseCorruptionScreen extends StatelessWidget {
  /// Creates the screen. [onCloseApp] is injected for tests.
  const DatabaseCorruptionScreen({
    this.onCloseApp = SystemNavigator.pop,
    super.key,
  });

  /// Invoked by the close button.
  final VoidCallback onCloseApp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  const ExcludeSemantics(
                    child: DivineIcon(
                      icon: DivineIconName.warningCircle,
                      color: VineTheme.accentOrange,
                      size: 48,
                    ),
                  ),
                  Text(
                    l10n.databaseCorruptionTitle,
                    textAlign: TextAlign.center,
                    style: VineTheme.titleLargeFont(),
                  ),
                  Text(
                    l10n.databaseCorruptionBody,
                    textAlign: TextAlign.center,
                    style: VineTheme.bodyMediumFont(
                      color: VineTheme.onSurfaceVariant,
                    ),
                  ),
                  DivineButton(
                    label: l10n.databaseCorruptionCloseButton,
                    onPressed: onCloseApp,
                    type: DivineButtonType.secondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
