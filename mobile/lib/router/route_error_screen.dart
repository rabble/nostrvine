// ABOUTME: Shared full-screen layout for route validation failures and not-found UI.
// ABOUTME: Keeps DiVineAppBar + body copy consistent before wiring GoRouter.errorBuilder.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';

/// Full-screen error state for bad route parameters and (later) unmatched paths.
///
/// Matches the previous inline pattern in [GoRoute] builders: [DiVineAppBar] with
/// [AppLocalizations.routeErrorTitle] and a short [message] in the body.
class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({
    required this.message,
    this.title,
    this.showBackButton = false,
    this.onBackPressed,
    super.key,
  });

  /// User-visible explanation, usually from [AppLocalizations] route-related getters.
  final String message;

  /// App bar title; defaults to [AppLocalizations.routeErrorTitle].
  final String? title;

  /// When true, shows the leading back control (defaults to [GoRouter.pop] if
  /// [onBackPressed] is omitted).
  final bool showBackButton;

  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? backHandler = !showBackButton
        ? null
        : (onBackPressed ?? () => context.pop<void>());

    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: DiVineAppBar(
        title: title ?? context.l10n.routeErrorTitle,
        showBackButton: showBackButton,
        onBackPressed: backHandler,
      ),
      body: Center(child: Text(message)),
    );
  }
}
