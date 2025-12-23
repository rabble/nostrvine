# Environment Switcher Implementation Plan (v2)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow developers to switch between Production, Staging, and Dev/POC relay environments via a hidden developer options menu.

**Architecture:** A new `EnvironmentService` manages the current environment config, persisted via SharedPreferences. The service provides a single relay URL to the NostrClient initialization. Visual indicators (app bar badge, bottom banner, status bar tint) show non-production environments. Developer mode is unlocked by tapping the version number 7 times.

**Tech Stack:** Flutter, Riverpod, SharedPreferences, GoRouter

**Key Simplification:** Each environment maps to exactly ONE relay (no multi-relay mode).

---

## Task 1: Create Environment Model and Enums

**Files:**
- Create: `lib/models/environment_config.dart`
- Test: `test/models/environment_config_test.dart`

**Step 1: Write the failing test**

```dart
// test/models/environment_config_test.dart
// ABOUTME: Tests for environment configuration model
// ABOUTME: Verifies relay URL generation for each environment

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/environment_config.dart';

void main() {
  group('AppEnvironment', () {
    test('has three values', () {
      expect(AppEnvironment.values.length, 3);
      expect(AppEnvironment.values, contains(AppEnvironment.production));
      expect(AppEnvironment.values, contains(AppEnvironment.staging));
      expect(AppEnvironment.values, contains(AppEnvironment.dev));
    });
  });

  group('DevRelay', () {
    test('has two values (umbra and shugur)', () {
      expect(DevRelay.values.length, 2);
      expect(DevRelay.values, contains(DevRelay.umbra));
      expect(DevRelay.values, contains(DevRelay.shugur));
    });
  });

  group('EnvironmentConfig', () {
    test('production returns divine.video relay', () {
      final config = EnvironmentConfig(environment: AppEnvironment.production);
      expect(config.relayUrl, 'wss://relay.divine.video');
    });

    test('staging returns staging-relay', () {
      final config = EnvironmentConfig(environment: AppEnvironment.staging);
      expect(config.relayUrl, 'wss://staging-relay.divine.video');
    });

    test('dev with umbra returns poc relay', () {
      final config = EnvironmentConfig(
        environment: AppEnvironment.dev,
        devRelay: DevRelay.umbra,
      );
      expect(config.relayUrl, 'wss://relay.poc.dvines.org');
    });

    test('dev with shugur returns shugur relay', () {
      final config = EnvironmentConfig(
        environment: AppEnvironment.dev,
        devRelay: DevRelay.shugur,
      );
      expect(config.relayUrl, 'wss://shugur.poc.dvines.org');
    });

    test('dev without devRelay defaults to umbra', () {
      final config = EnvironmentConfig(environment: AppEnvironment.dev);
      expect(config.relayUrl, 'wss://relay.poc.dvines.org');
    });

    test('blossomUrl is same for all environments', () {
      final prod = EnvironmentConfig(environment: AppEnvironment.production);
      final staging = EnvironmentConfig(environment: AppEnvironment.staging);
      final dev = EnvironmentConfig(environment: AppEnvironment.dev);

      expect(prod.blossomUrl, 'https://media.divine.video');
      expect(staging.blossomUrl, 'https://media.divine.video');
      expect(dev.blossomUrl, 'https://media.divine.video');
    });

    test('isProduction returns true only for production', () {
      expect(
        EnvironmentConfig(environment: AppEnvironment.production).isProduction,
        true,
      );
      expect(
        EnvironmentConfig(environment: AppEnvironment.staging).isProduction,
        false,
      );
      expect(
        EnvironmentConfig(environment: AppEnvironment.dev).isProduction,
        false,
      );
    });

    test('displayName returns human readable name', () {
      expect(
        EnvironmentConfig(environment: AppEnvironment.production).displayName,
        'Production',
      );
      expect(
        EnvironmentConfig(environment: AppEnvironment.staging).displayName,
        'Staging',
      );
      expect(
        EnvironmentConfig(
          environment: AppEnvironment.dev,
          devRelay: DevRelay.umbra,
        ).displayName,
        'Dev - Umbra',
      );
      expect(
        EnvironmentConfig(
          environment: AppEnvironment.dev,
          devRelay: DevRelay.shugur,
        ).displayName,
        'Dev - Shugur',
      );
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/models/environment_config_test.dart`
Expected: FAIL with "Target of URI doesn't exist"

**Step 3: Write minimal implementation**

```dart
// lib/models/environment_config.dart
// ABOUTME: Environment configuration model for dev/staging/production switching
// ABOUTME: Each environment maps to exactly one relay URL

/// Available app environments
enum AppEnvironment {
  production,
  staging,
  dev,
}

/// Dev environment relay options
enum DevRelay {
  umbra,
  shugur,
}

/// Configuration for the current app environment
class EnvironmentConfig {
  const EnvironmentConfig({
    required this.environment,
    this.devRelay,
  });

  final AppEnvironment environment;
  final DevRelay? devRelay;

  /// Default production configuration
  static const production = EnvironmentConfig(
    environment: AppEnvironment.production,
  );

  /// Get relay URL for current environment (always exactly one)
  String get relayUrl {
    switch (environment) {
      case AppEnvironment.production:
        return 'wss://relay.divine.video';
      case AppEnvironment.staging:
        return 'wss://staging-relay.divine.video';
      case AppEnvironment.dev:
        switch (devRelay) {
          case DevRelay.umbra:
          case null:
            return 'wss://relay.poc.dvines.org';
          case DevRelay.shugur:
            return 'wss://shugur.poc.dvines.org';
        }
    }
  }

  /// Get blossom media server URL (same for all environments currently)
  String get blossomUrl => 'https://media.divine.video';

  /// Whether this is production environment
  bool get isProduction => environment == AppEnvironment.production;

  /// Human readable display name
  String get displayName {
    switch (environment) {
      case AppEnvironment.production:
        return 'Production';
      case AppEnvironment.staging:
        return 'Staging';
      case AppEnvironment.dev:
        switch (devRelay) {
          case DevRelay.umbra:
          case null:
            return 'Dev - Umbra';
          case DevRelay.shugur:
            return 'Dev - Shugur';
        }
    }
  }

  /// Color for environment indicator (as int for const constructor)
  int get indicatorColorValue {
    switch (environment) {
      case AppEnvironment.production:
        return 0xFF4CAF50; // Green
      case AppEnvironment.staging:
        return 0xFFFFC107; // Yellow/Amber
      case AppEnvironment.dev:
        return 0xFFFF9800; // Orange
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnvironmentConfig &&
          environment == other.environment &&
          devRelay == other.devRelay;

  @override
  int get hashCode => Object.hash(environment, devRelay);
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/models/environment_config_test.dart`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add lib/models/environment_config.dart test/models/environment_config_test.dart
git commit -m "feat: add environment config model with single relay per environment"
```

---

## Task 2: Create Environment Service with Persistence

**Files:**
- Create: `lib/services/environment_service.dart`
- Test: `test/services/environment_service_test.dart`

**Step 1: Write the failing test**

```dart
// test/services/environment_service_test.dart
// ABOUTME: Tests for environment service persistence and state management
// ABOUTME: Uses mock SharedPreferences for isolation

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/services/environment_service.dart';

void main() {
  group('EnvironmentService', () {
    late EnvironmentService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to production when no saved state', () async {
      service = EnvironmentService();
      await service.initialize();

      expect(service.currentConfig.environment, AppEnvironment.production);
      expect(service.isDeveloperModeEnabled, false);
    });

    test('loads saved environment from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'developer_mode_enabled': true,
        'app_environment': 'staging',
      });

      service = EnvironmentService();
      await service.initialize();

      expect(service.isDeveloperModeEnabled, true);
      expect(service.currentConfig.environment, AppEnvironment.staging);
    });

    test('loads dev environment with relay selection', () async {
      SharedPreferences.setMockInitialValues({
        'developer_mode_enabled': true,
        'app_environment': 'dev',
        'dev_relay_selection': 'shugur',
      });

      service = EnvironmentService();
      await service.initialize();

      expect(service.currentConfig.environment, AppEnvironment.dev);
      expect(service.currentConfig.devRelay, DevRelay.shugur);
    });

    test('enableDeveloperMode persists state', () async {
      service = EnvironmentService();
      await service.initialize();

      await service.enableDeveloperMode();

      expect(service.isDeveloperModeEnabled, true);

      // Verify persisted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('developer_mode_enabled'), true);
    });

    test('setEnvironment persists and notifies', () async {
      service = EnvironmentService();
      await service.initialize();
      await service.enableDeveloperMode();

      var notified = false;
      service.addListener(() => notified = true);

      await service.setEnvironment(AppEnvironment.staging);

      expect(service.currentConfig.environment, AppEnvironment.staging);
      expect(notified, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_environment'), 'staging');
    });

    test('setDevRelay persists selection', () async {
      service = EnvironmentService();
      await service.initialize();
      await service.enableDeveloperMode();
      await service.setEnvironment(AppEnvironment.dev);

      await service.setDevRelay(DevRelay.shugur);

      expect(service.currentConfig.devRelay, DevRelay.shugur);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('dev_relay_selection'), 'shugur');
    });

    test('cannot change environment without developer mode', () async {
      service = EnvironmentService();
      await service.initialize();

      expect(
        () => service.setEnvironment(AppEnvironment.staging),
        throwsA(isA<StateError>()),
      );
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/environment_service_test.dart`
Expected: FAIL with "Target of URI doesn't exist"

**Step 3: Write minimal implementation**

```dart
// lib/services/environment_service.dart
// ABOUTME: Manages app environment (prod/staging/dev) with persistence
// ABOUTME: Handles developer mode unlock and environment switching

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/models/environment_config.dart';

/// Service for managing app environment configuration
class EnvironmentService extends ChangeNotifier {
  static const _keyDeveloperMode = 'developer_mode_enabled';
  static const _keyEnvironment = 'app_environment';
  static const _keyDevRelay = 'dev_relay_selection';

  SharedPreferences? _prefs;
  bool _developerModeEnabled = false;
  EnvironmentConfig _currentConfig = EnvironmentConfig.production;
  bool _initialized = false;

  /// Whether developer mode has been unlocked
  bool get isDeveloperModeEnabled => _developerModeEnabled;

  /// Current environment configuration
  EnvironmentConfig get currentConfig => _currentConfig;

  /// Whether service has been initialized
  bool get isInitialized => _initialized;

  /// Initialize the service and load persisted state
  Future<void> initialize() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();
    _developerModeEnabled = _prefs!.getBool(_keyDeveloperMode) ?? false;

    final envString = _prefs!.getString(_keyEnvironment);
    final devRelayString = _prefs!.getString(_keyDevRelay);

    final environment = _parseEnvironment(envString);
    final devRelay = _parseDevRelay(devRelayString);

    _currentConfig = EnvironmentConfig(
      environment: environment,
      devRelay: devRelay,
    );

    _initialized = true;
    notifyListeners();
  }

  /// Enable developer mode (called after 7 taps on version)
  Future<void> enableDeveloperMode() async {
    _ensureInitialized();
    _developerModeEnabled = true;
    await _prefs!.setBool(_keyDeveloperMode, true);
    notifyListeners();
  }

  /// Set the app environment (requires developer mode)
  Future<void> setEnvironment(AppEnvironment environment) async {
    _ensureInitialized();
    if (!_developerModeEnabled) {
      throw StateError('Developer mode must be enabled to change environment');
    }

    _currentConfig = EnvironmentConfig(
      environment: environment,
      devRelay: environment == AppEnvironment.dev
          ? (_currentConfig.devRelay ?? DevRelay.umbra)
          : null,
    );

    await _prefs!.setString(_keyEnvironment, environment.name);
    notifyListeners();
  }

  /// Set the dev relay selection (only applies when in dev environment)
  Future<void> setDevRelay(DevRelay relay) async {
    _ensureInitialized();
    if (!_developerModeEnabled) {
      throw StateError('Developer mode must be enabled to change dev relay');
    }

    _currentConfig = EnvironmentConfig(
      environment: _currentConfig.environment,
      devRelay: relay,
    );

    await _prefs!.setString(_keyDevRelay, relay.name);
    notifyListeners();
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('EnvironmentService must be initialized first');
    }
  }

  AppEnvironment _parseEnvironment(String? value) {
    if (value == null) return AppEnvironment.production;
    return AppEnvironment.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppEnvironment.production,
    );
  }

  DevRelay? _parseDevRelay(String? value) {
    if (value == null) return null;
    return DevRelay.values.cast<DevRelay?>().firstWhere(
          (e) => e?.name == value,
          orElse: () => null,
        );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/environment_service_test.dart`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add lib/services/environment_service.dart test/services/environment_service_test.dart
git commit -m "feat: add environment service with persistence"
```

---

## Task 3: Create Environment Provider (Riverpod)

**Files:**
- Create: `lib/providers/environment_provider.dart`

**Step 1: Write the provider with proper listener cleanup**

```dart
// lib/providers/environment_provider.dart
// ABOUTME: Riverpod provider for environment service
// ABOUTME: Exposes environment config and developer mode state to widgets

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/services/environment_service.dart';

part 'environment_provider.g.dart';

/// Provider for the environment service singleton
@Riverpod(keepAlive: true)
EnvironmentService environmentService(EnvironmentServiceRef ref) {
  final service = EnvironmentService();
  // Note: initialize() must be called during app startup
  return service;
}

/// Provider for current environment config (reactive)
@riverpod
EnvironmentConfig currentEnvironment(CurrentEnvironmentRef ref) {
  final service = ref.watch(environmentServiceProvider);

  // Proper listener management with cleanup
  void listener() => ref.invalidateSelf();
  service.addListener(listener);
  ref.onDispose(() => service.removeListener(listener));

  return service.currentConfig;
}

/// Provider for developer mode enabled state
@riverpod
bool isDeveloperModeEnabled(IsDeveloperModeEnabledRef ref) {
  final service = ref.watch(environmentServiceProvider);

  // Proper listener management with cleanup
  void listener() => ref.invalidateSelf();
  service.addListener(listener);
  ref.onDispose(() => service.removeListener(listener));

  return service.isDeveloperModeEnabled;
}

/// Provider to check if showing environment indicator
@riverpod
bool showEnvironmentIndicator(ShowEnvironmentIndicatorRef ref) {
  final config = ref.watch(currentEnvironmentProvider);
  return !config.isProduction;
}
```

**Step 2: Generate Riverpod code**

Run: `dart run build_runner build --delete-conflicting-outputs`

**Step 3: Commit**

```bash
git add lib/providers/environment_provider.dart lib/providers/environment_provider.g.dart
git commit -m "feat: add environment riverpod providers with proper listener cleanup"
```

---

## Task 4: Create Environment Indicator Widget

**Files:**
- Create: `lib/widgets/environment_indicator.dart`
- Test: `test/widgets/environment_indicator_test.dart`

**Step 1: Write the widget**

```dart
// lib/widgets/environment_indicator.dart
// ABOUTME: Visual indicators showing non-production environment
// ABOUTME: Includes app bar badge, bottom banner, and tappable quick-switch

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/environment_provider.dart';

/// Badge to show in app bar for non-production environments
class EnvironmentBadge extends ConsumerWidget {
  const EnvironmentBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showIndicator = ref.watch(showEnvironmentIndicatorProvider);
    if (!showIndicator) return const SizedBox.shrink();

    final config = ref.watch(currentEnvironmentProvider);

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Color(config.indicatorColorValue),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        config.environment == AppEnvironment.staging ? 'STG' : 'DEV',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Bottom banner showing current environment with tap to switch
class EnvironmentBanner extends ConsumerWidget {
  const EnvironmentBanner({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showIndicator = ref.watch(showEnvironmentIndicatorProvider);
    if (!showIndicator) return const SizedBox.shrink();

    final config = ref.watch(currentEnvironmentProvider);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4),
        color: Color(config.indicatorColorValue),
        child: Text(
          '${config.displayName.toUpperCase()} ENVIRONMENT',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

/// Get app bar background color with environment tint
Color? getEnvironmentAppBarColor(WidgetRef ref) {
  final showIndicator = ref.watch(showEnvironmentIndicatorProvider);
  if (!showIndicator) return null;

  final config = ref.watch(currentEnvironmentProvider);
  return Color(config.indicatorColorValue).withOpacity(0.15);
}
```

**Step 2: Write basic widget test**

```dart
// test/widgets/environment_indicator_test.dart
// ABOUTME: Tests for environment indicator widgets
// ABOUTME: Verifies visibility and styling for each environment

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/widgets/environment_indicator.dart';

void main() {
  group('EnvironmentBadge', () {
    testWidgets('shows nothing in production', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            showEnvironmentIndicatorProvider.overrideWith((_) => false),
          ],
          child: const MaterialApp(
            home: Scaffold(body: EnvironmentBadge()),
          ),
        ),
      );

      expect(find.text('STG'), findsNothing);
      expect(find.text('DEV'), findsNothing);
    });

    testWidgets('shows STG badge in staging', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            showEnvironmentIndicatorProvider.overrideWith((_) => true),
            currentEnvironmentProvider.overrideWith(
              (_) => const EnvironmentConfig(environment: AppEnvironment.staging),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: EnvironmentBadge()),
          ),
        ),
      );

      expect(find.text('STG'), findsOneWidget);
    });

    testWidgets('shows DEV badge in dev', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            showEnvironmentIndicatorProvider.overrideWith((_) => true),
            currentEnvironmentProvider.overrideWith(
              (_) => const EnvironmentConfig(
                environment: AppEnvironment.dev,
                devRelay: DevRelay.umbra,
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: EnvironmentBadge()),
          ),
        ),
      );

      expect(find.text('DEV'), findsOneWidget);
    });
  });

  group('EnvironmentBanner', () {
    testWidgets('shows nothing in production', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            showEnvironmentIndicatorProvider.overrideWith((_) => false),
          ],
          child: const MaterialApp(
            home: Scaffold(body: EnvironmentBanner()),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('shows environment name in banner', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            showEnvironmentIndicatorProvider.overrideWith((_) => true),
            currentEnvironmentProvider.overrideWith(
              (_) => const EnvironmentConfig(environment: AppEnvironment.staging),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: EnvironmentBanner()),
          ),
        ),
      );

      expect(find.text('STAGING ENVIRONMENT'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            showEnvironmentIndicatorProvider.overrideWith((_) => true),
            currentEnvironmentProvider.overrideWith(
              (_) => const EnvironmentConfig(environment: AppEnvironment.staging),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EnvironmentBanner(onTap: () => tapped = true),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      expect(tapped, true);
    });
  });
}
```

**Step 3: Run tests**

Run: `flutter test test/widgets/environment_indicator_test.dart`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add lib/widgets/environment_indicator.dart test/widgets/environment_indicator_test.dart
git commit -m "feat: add environment indicator widgets (badge, banner)"
```

---

## Task 5: Create Developer Options Screen

**Files:**
- Create: `lib/screens/developer_options_screen.dart`

**Step 1: Write the screen**

```dart
// lib/screens/developer_options_screen.dart
// ABOUTME: Developer options screen for environment switching
// ABOUTME: Accessible after tapping version number 7 times

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/theme/vine_theme.dart';

class DeveloperOptionsScreen extends ConsumerWidget {
  const DeveloperOptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(currentEnvironmentProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Developer Options'),
        backgroundColor: Colors.black,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Environment'),
          _buildEnvironmentTile(
            context,
            ref,
            'Production',
            'wss://relay.divine.video',
            AppEnvironment.production,
            config,
            Colors.green,
          ),
          _buildEnvironmentTile(
            context,
            ref,
            'Staging',
            'wss://staging-relay.divine.video',
            AppEnvironment.staging,
            config,
            Colors.amber,
          ),
          _buildEnvironmentTile(
            context,
            ref,
            'Dev - Umbra',
            'wss://relay.poc.dvines.org',
            AppEnvironment.dev,
            config,
            Colors.orange,
            devRelay: DevRelay.umbra,
          ),
          _buildEnvironmentTile(
            context,
            ref,
            'Dev - Shugur',
            'wss://shugur.poc.dvines.org',
            AppEnvironment.dev,
            config,
            Colors.orange,
            devRelay: DevRelay.shugur,
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Current relay: ${config.relayUrl}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: VineTheme.vineGreen,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEnvironmentTile(
    BuildContext context,
    WidgetRef ref,
    String title,
    String subtitle,
    AppEnvironment environment,
    EnvironmentConfig currentConfig,
    Color color, {
    DevRelay? devRelay,
  }) {
    final isSelected = currentConfig.environment == environment &&
        (environment != AppEnvironment.dev || currentConfig.devRelay == devRelay);

    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[500])),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.green)
          : null,
      onTap: () => _switchEnvironment(context, ref, environment, devRelay),
    );
  }

  Future<void> _switchEnvironment(
    BuildContext context,
    WidgetRef ref,
    AppEnvironment environment,
    DevRelay? devRelay,
  ) async {
    final currentConfig = ref.read(currentEnvironmentProvider);

    // Check if already selected
    if (currentConfig.environment == environment &&
        (environment != AppEnvironment.dev || currentConfig.devRelay == devRelay)) {
      return;
    }

    final envName = environment == AppEnvironment.dev
        ? 'Dev - ${devRelay?.name ?? 'Umbra'}'
        : environment.name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Switch Environment?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Switching to $envName will clear your video cache and subscriptions. '
          'Your account will remain logged in.\n\n'
          'The app will restart to apply changes.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Switch & Restart',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final service = ref.read(environmentServiceProvider);

      // Set environment
      await service.setEnvironment(environment);
      if (environment == AppEnvironment.dev && devRelay != null) {
        await service.setDevRelay(devRelay);
      }

      // TODO: Task 11 will add cache clearing here

      // Force app restart
      exit(0);
    }
  }
}
```

**Step 2: Commit**

```bash
git add lib/screens/developer_options_screen.dart
git commit -m "feat: add developer options screen with environment picker"
```

---

## Task 6: Add Route for Developer Options

**Files:**
- Modify: `lib/router/app_router.dart`
- Modify: `lib/router/route_utils.dart`

**Step 1: Add RouteType for developer options**

In `lib/router/route_utils.dart`, add to `RouteType` enum:
```dart
developerOptions,
```

In `parseRoute` function, add case:
```dart
case 'developer-options':
  return const RouteContext(type: RouteType.developerOptions);
```

**Step 2: Add route in app_router.dart**

Add import:
```dart
import 'package:openvine/screens/developer_options_screen.dart';
```

Add route (near other settings routes):
```dart
GoRoute(
  path: '/developer-options',
  pageBuilder: (context, state) => CustomTransitionPage(
    key: state.pageKey,
    child: const DeveloperOptionsScreen(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      );
    },
  ),
),
```

**Step 3: Add to route_coverage_test.dart**

Add test case:
```dart
test('/developer-options parses to RouteType.developerOptions', () {
  final context = parseRoute('/developer-options');
  expect(context.type, RouteType.developerOptions);
});
```

**Step 4: Commit**

```bash
git add lib/router/app_router.dart lib/router/route_utils.dart test/router/route_coverage_test.dart
git commit -m "feat: add developer options route"
```

---

## Task 7: Add Version Tap Counter to Settings Screen

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Create: `lib/providers/developer_mode_tap_provider.dart`

**Step 1: Create tap counter provider**

```dart
// lib/providers/developer_mode_tap_provider.dart
// ABOUTME: State provider for version tap counter
// ABOUTME: Tracks taps to unlock developer mode (7 taps)

import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'developer_mode_tap_provider.g.dart';

@riverpod
class DeveloperModeTapCounter extends _$DeveloperModeTapCounter {
  Timer? _resetTimer;

  @override
  int build() => 0;

  void tap() {
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      state = 0;
    });
    state++;
  }

  void reset() {
    _resetTimer?.cancel();
    state = 0;
  }
}
```

**Step 2: Generate Riverpod code**

Run: `dart run build_runner build --delete-conflicting-outputs`

**Step 3: Modify settings_screen.dart**

Find the version display widget and wrap in GestureDetector:

```dart
// Add imports
import 'package:openvine/providers/developer_mode_tap_provider.dart';
import 'package:openvine/providers/environment_provider.dart';

// In the version display section, wrap with GestureDetector:
GestureDetector(
  onTap: () {
    ref.read(developerModeTapCounterProvider.notifier).tap();
    final count = ref.read(developerModeTapCounterProvider);

    if (count >= 7) {
      ref.read(developerModeTapCounterProvider.notifier).reset();
      ref.read(environmentServiceProvider).enableDeveloperMode();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Developer options enabled'),
          backgroundColor: Colors.orange,
        ),
      );
    } else if (count >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${7 - count} taps to enable developer options'),
          duration: const Duration(milliseconds: 500),
        ),
      );
    }
  },
  child: // existing version Text widget
),

// Add developer options row when enabled (in the ListView):
if (ref.watch(isDeveloperModeEnabledProvider))
  ListTile(
    leading: const Icon(Icons.developer_mode, color: Colors.orange),
    title: const Text('Developer Options', style: TextStyle(color: Colors.white)),
    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    onTap: () => context.push('/developer-options'),
  ),
```

**Step 4: Commit**

```bash
git add lib/providers/developer_mode_tap_provider.dart lib/providers/developer_mode_tap_provider.g.dart lib/screens/settings_screen.dart
git commit -m "feat: add version tap counter to unlock developer mode"
```

---

## Task 8: Integrate Environment Indicators into AppShell

**Files:**
- Modify: `lib/router/app_shell.dart`

**Step 1: Add environment indicators**

Add imports:
```dart
import 'package:openvine/widgets/environment_indicator.dart';
import 'package:openvine/providers/environment_provider.dart';
```

Modify AppBar title to include badge:
```dart
title: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    _buildTappableTitle(context, ref, title),
    const EnvironmentBadge(),
  ],
),
```

Add app bar background color tint:
```dart
appBar: AppBar(
  backgroundColor: getEnvironmentAppBarColor(ref),
  // ... rest of AppBar
),
```

Wrap body with Column to add banner:
```dart
body: Column(
  children: [
    Expanded(child: child),
    EnvironmentBanner(
      onTap: () => context.push('/developer-options'),
    ),
  ],
),
```

**Step 2: Commit**

```bash
git add lib/router/app_shell.dart
git commit -m "feat: integrate environment indicators into app shell"
```

---

## Task 9: Wire Environment Config to NostrClient Initialization

**Files:**
- Modify: `lib/services/nostr_service_factory.dart`

**Step 1: Update NostrClient to use environment config**

Add import:
```dart
import 'package:openvine/providers/environment_provider.dart';
```

In `NostrServiceFactory.create()`, change:
```dart
// OLD:
final relayManagerConfig = RelayManagerConfig(
  defaultRelayUrl: AppConstants.defaultRelayUrl,
  storage: SharedPreferencesRelayStorage(),
);

// NEW:
final envConfig = container.read(currentEnvironmentProvider);
final relayManagerConfig = RelayManagerConfig(
  defaultRelayUrl: envConfig.relayUrl,
  storage: SharedPreferencesRelayStorage(),
);
```

**Step 2: Commit**

```bash
git add lib/services/nostr_service_factory.dart
git commit -m "feat: wire environment config to nostr client initialization"
```

---

## Task 10: Initialize Environment Service at App Startup

**Files:**
- Modify: `lib/main.dart`

**Step 1: Add environment service initialization**

In `_startOpenVineApp()`, after SharedPreferences is loaded and container is created, add:

```dart
// After line ~433 where container is created:
final container = ProviderContainer(
  overrides: [sharedPreferencesProvider.overrideWithValue(sharedPreferences)],
);

// ADD THIS: Initialize environment service FIRST (before other services that depend on relay config)
await container.read(environmentServiceProvider).initialize();
Log.info(
  '[INIT] ✅ EnvironmentService initialized: ${container.read(currentEnvironmentProvider).displayName}',
  name: 'Main',
  category: LogCategory.system,
);

// Then continue with existing _initializeCoreServices call
```

**Step 2: Commit**

```bash
git add lib/main.dart
git commit -m "feat: initialize environment service at app startup"
```

---

## Task 11: Add Cache Clearing on Environment Switch

**Files:**
- Modify: `lib/screens/developer_options_screen.dart`

**Step 1: Add required imports at top of file**

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:openvine/providers/subscription_manager_provider.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/providers/seen_videos_provider.dart';
import 'package:openvine/providers/profile_cache_provider.dart';
import 'package:openvine/utils/unified_logger.dart';
```

**Step 2: Add cache clearing before restart**

In `_switchEnvironment()`, before `exit(0)`, add:

```dart
// Clear caches (keep auth intact)
try {
  // Cancel active subscriptions
  final subscriptionManager = ref.read(subscriptionManagerProvider);
  await subscriptionManager.cancelAll();

  // Clear video event service
  final videoEventService = ref.read(videoEventServiceProvider);
  videoEventService.clearAllCaches();

  // Clear seen videos
  final seenVideosService = ref.read(seenVideosServiceProvider);
  await seenVideosService.clearAll();

  // Clear profile cache
  ref.read(profileCacheServiceProvider).clearCache();

  // Clear video file cache
  final cacheDir = await getTemporaryDirectory();
  final videoCacheDir = Directory('${cacheDir.path}/video_cache');
  if (await videoCacheDir.exists()) {
    await videoCacheDir.delete(recursive: true);
  }

  Log.info(
    'Cleared caches for environment switch',
    name: 'DeveloperOptions',
    category: LogCategory.system,
  );
} catch (e) {
  Log.error(
    'Error clearing caches: $e',
    name: 'DeveloperOptions',
    category: LogCategory.system,
  );
}

// Force app restart
exit(0);
```

**Step 3: Add clearAllCaches method to VideoEventService if needed**

Check if `VideoEventService` has a `clearAllCaches()` method. If not, add:

```dart
/// Clear all cached video events (used when switching environments)
void clearAllCaches() {
  for (final type in SubscriptionType.values) {
    _eventLists[type]?.clear();
    _paginationStates[type]?.reset();
  }
  notifyListeners();
}
```

**Step 4: Commit**

```bash
git add lib/screens/developer_options_screen.dart lib/services/video_event_service.dart
git commit -m "feat: clear caches on environment switch"
```

---

## Summary

**Files Created (8):**
- `lib/models/environment_config.dart`
- `lib/services/environment_service.dart`
- `lib/providers/environment_provider.dart` + `.g.dart`
- `lib/providers/developer_mode_tap_provider.dart` + `.g.dart`
- `lib/widgets/environment_indicator.dart`
- `lib/screens/developer_options_screen.dart`
- `test/models/environment_config_test.dart`
- `test/services/environment_service_test.dart`
- `test/widgets/environment_indicator_test.dart`

**Files Modified (6):**
- `lib/router/app_router.dart`
- `lib/router/route_utils.dart`
- `lib/router/app_shell.dart`
- `lib/screens/settings_screen.dart`
- `lib/services/nostr_service_factory.dart`
- `lib/main.dart`
- `lib/services/video_event_service.dart` (if clearAllCaches needed)
- `test/router/route_coverage_test.dart`

**Total: 11 tasks, ~15 commits**

**Key Simplifications from v1:**
- Removed "both" relay option - each environment = exactly one relay
- Fixed provider memory leaks with proper listener cleanup
- Integrated with existing main.dart ProviderContainer
- Added complete cache clearing implementation
- Force restart instead of optional restart dialog
