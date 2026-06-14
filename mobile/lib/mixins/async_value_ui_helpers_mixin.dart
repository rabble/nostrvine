// ABOUTME: Reusable AsyncValue UI helpers mixin for consistent loading/error states
// ABOUTME: Eliminates .when() boilerplate across 6+ router and feed screens

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';

/// Mixin that provides consistent AsyncValue UI handling with default loading/error widgets.
///
/// This eliminates the repeated `.when(data:, loading:, error:)` pattern across screens.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends ConsumerState<MyScreen> with AsyncValueUIHelpersMixin {
///   @override
///   Widget build(BuildContext context) {
///     final dataAsync = ref.watch(someProvider);
///
///     return buildAsyncUI(
///       dataAsync,
///       onData: (data) => MyDataWidget(data),
///       // Optional custom loading/error widgets
///       onLoading: () => MyCustomLoadingWidget(),
///       onError: (error, stack) => MyCustomErrorWidget(error),
///     );
///   }
/// }
/// ```
mixin AsyncValueUIHelpersMixin {
  /// Build a widget that handles AsyncValue states uniformly.
  ///
  /// Provides default loading and error widgets that match OpenVine's dark theme.
  /// Custom loading/error widgets can be provided via optional parameters.
  ///
  /// Parameters:
  /// - `asyncValue`: The AsyncValue to handle (data, loading, or error state)
  /// - `onData`: Builder function for the data state (required)
  /// - `onLoading`: Optional custom loading widget builder
  /// - `onError`: Optional custom error widget builder
  Widget buildAsyncUI<T>(
    AsyncValue<T> asyncValue, {
    required Widget Function(T data) onData,
    Widget Function()? onLoading,
    Widget Function(Object error, StackTrace stack)? onError,
  }) {
    return asyncValue.when(
      data: onData,
      loading: onLoading ?? _buildDefaultLoading,
      error: onError ?? _buildDefaultError,
    );
  }

  /// Default loading widget - centered spinner with vine green color on dark background
  Widget _buildDefaultLoading() {
    return const ColoredBox(
      color: VineTheme.backgroundColor,
      child: Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
    );
  }

  /// Default error widget - centered error icon with an intentional,
  /// localized message.
  ///
  /// The raw [error] is deliberately not shown to the user (see the
  /// per-layer failure contract in `rules/error_handling.md`); it stays in
  /// the [AsyncValue] for logging at the provider layer. Wrapped in a
  /// [Builder] so the message can resolve `context.l10n` without changing
  /// this mixin's public API.
  Widget _buildDefaultError(Object error, StackTrace stack) {
    return Builder(
      builder: (context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DivineIcon(
              icon: DivineIconName.warningCircle,
              color: VineTheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                context.l10n.commonSomethingWentWrong,
                style: const TextStyle(color: VineTheme.whiteText),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
