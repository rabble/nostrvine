// ABOUTME: Environment indicator widgets for showing current environment
// ABOUTME: Includes badge overlay and bottom banner with tap callback
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Badge showing environment name for non-production environments
/// Returns SizedBox.shrink for production, small badge for dev/staging
class EnvironmentBadge extends ConsumerWidget {
  const EnvironmentBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showIndicator = ref.watch(showEnvironmentIndicatorProvider);
    final environment = ref.watch(currentEnvironmentProvider);

    if (!showIndicator || environment.isProduction) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Color(environment.indicatorColorValue),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _getEnvironmentLabel(environment),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getEnvironmentLabel(EnvironmentConfig environment) {
    switch (environment.environment) {
      case AppEnvironment.staging:
        return 'STG';
      case AppEnvironment.dev:
        return 'DEV';
      case AppEnvironment.production:
      case AppEnvironment.productionNew:
        return '';
    }
  }
}

/// Banner showing environment name at bottom of screen with tap callback
/// Returns SizedBox.shrink for production, tappable banner for dev/staging
class EnvironmentBanner extends ConsumerWidget {
  const EnvironmentBanner({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showIndicator = ref.watch(showEnvironmentIndicatorProvider);
    final environment = ref.watch(currentEnvironmentProvider);

    if (!showIndicator || environment.isProduction) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        color: Color(environment.indicatorColorValue),
        child: Center(
          child: Text(
            'Environment: ${environment.displayName} - Tap for options',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper function to get app bar color based on environment
/// Production uses nav green, other environments use their indicator color
Color getEnvironmentAppBarColor(EnvironmentConfig environment) {
  if (environment.isProduction) {
    return VineTheme.navGreen;
  }
  return Color(environment.indicatorColorValue);
}
