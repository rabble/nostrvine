# App Update Prompt Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nudge users running outdated app versions to upgrade, with escalating urgency and one-tap deep-links to the correct install source.

**Architecture:** Two new packages (`app_version_client`, `app_update_repository`) following the existing layered pattern. An `AppUpdateBloc` at the app level checks the GitHub Releases API on launch (cached 24h), determines escalation level (gentle/moderate/urgent), and drives a banner or dialog in the `AppShell`. Install source is detected per-platform and cached to resolve the correct upgrade URL.

**Tech Stack:** `flutter_bloc`, `http`, `package_info_plus`, `shared_preferences`, GitHub Releases API

**Spec:** `docs/superpowers/specs/2026-04-06-app-update-prompt-design.md`

---

## Chunk 1: Data Layer — AppVersionClient Package

### Task 1: Create app_version_client package scaffold

**Files:**
- Create: `mobile/packages/app_version_client/pubspec.yaml`
- Create: `mobile/packages/app_version_client/lib/app_version_client.dart`
- Create: `mobile/packages/app_version_client/lib/src/app_version_client.dart`
- Create: `mobile/packages/app_version_client/lib/src/models/app_version_info.dart`
- Create: `mobile/packages/app_version_client/lib/src/app_version_constants.dart`
- Create: `mobile/packages/app_version_client/analysis_options.yaml`
- Modify: `mobile/pubspec.yaml` (add to workspace list)

- [ ] **Step 1: Create pubspec.yaml**

```yaml
name: app_version_client
description: Fetches latest app version info from GitHub Releases API
version: 0.1.0+1
publish_to: none

environment:
  sdk: ^3.11.0

resolution: workspace

dependencies:
  equatable: ^2.0.7
  http: ^1.4.0
  meta: ^1.17.0

dev_dependencies:
  mocktail: ^1.0.4
  test: ^1.26.3
  very_good_analysis: ^10.0.0
```

- [ ] **Step 2: Create analysis_options.yaml**

```yaml
include: package:very_good_analysis/analysis_options.yaml
```

- [ ] **Step 3: Create AppVersionConstants**

File: `lib/src/app_version_constants.dart`

```dart
/// Constants for the GitHub Releases API integration.
abstract class AppVersionConstants {
  /// GitHub repository owner.
  static const repoOwner = 'divinevideo';

  /// GitHub repository name.
  static const repoName = 'divine-mobile';

  /// Duration to cache the GitHub API response.
  static const cacheTtl = Duration(hours: 24);

  /// Regex to extract minimum_version from release body HTML comment.
  static final minimumVersionPattern =
      RegExp(r'<!--\s*minimum_version:\s*([\d.]+)\s*-->');

  /// Regex to extract bold items from Markdown bullet points.
  /// Matches lines like: `- **Resumable uploads** — description`
  static final highlightPattern =
      RegExp(r'^\s*[-*]\s+\*\*([^*]+)\*\*', multiLine: true);
}
```

- [ ] **Step 4: Create AppVersionInfo model**

File: `lib/src/models/app_version_info.dart`

```dart
import 'package:equatable/equatable.dart';

/// Version information parsed from the GitHub Releases API.
class AppVersionInfo extends Equatable {
  const AppVersionInfo({
    required this.latestVersion,
    required this.publishedAt,
    required this.releaseNotesUrl,
    required this.releaseHighlights,
    this.minimumVersion,
  });

  /// The latest release version tag (e.g. "1.0.8").
  final String latestVersion;

  /// When the latest release was published.
  final DateTime publishedAt;

  /// URL to the release notes page on GitHub.
  final String releaseNotesUrl;

  /// Short feature names extracted from the release body.
  final List<String> releaseHighlights;

  /// Optional minimum supported version, parsed from
  /// `<!-- minimum_version: X.Y.Z -->` in the release body.
  final String? minimumVersion;

  @override
  List<Object?> get props => [
        latestVersion,
        publishedAt,
        releaseNotesUrl,
        releaseHighlights,
        minimumVersion,
      ];
}
```

- [ ] **Step 5: Create barrel file**

File: `lib/app_version_client.dart`

```dart
library;

export 'src/app_version_client.dart';
export 'src/app_version_constants.dart';
export 'src/models/app_version_info.dart';
```

- [ ] **Step 6: Create empty AppVersionClient class**

File: `lib/src/app_version_client.dart`

```dart
import 'dart:convert';

import 'package:app_version_client/app_version_client.dart';
import 'package:http/http.dart' as http;

/// Fetches the latest release info from the GitHub Releases API.
class AppVersionClient {
  /// Creates an [AppVersionClient].
  ///
  /// An optional [httpClient] can be provided for testing.
  AppVersionClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null;

  final http.Client _httpClient;
  final bool _ownsHttpClient;

  /// Fetches the latest release from GitHub.
  ///
  /// Throws [AppVersionFetchException] on network or parsing errors.
  Future<AppVersionInfo> fetchLatestRelease() async {
    // Will be implemented after tests are written.
    throw UnimplementedError();
  }

  /// Disposes the HTTP client if it was created internally.
  void dispose() {
    if (_ownsHttpClient) _httpClient.close();
  }
}

/// Thrown when fetching version info fails.
class AppVersionFetchException implements Exception {
  const AppVersionFetchException(this.message);
  final String message;

  @override
  String toString() => 'AppVersionFetchException: $message';
}
```

- [ ] **Step 7: Register package in workspace**

Modify `mobile/pubspec.yaml` — add `- packages/app_version_client` to the workspace list (alphabetically, after the `workspace:` key).

- [ ] **Step 8: Run pub get to verify**

Run from `mobile/`:
```bash
flutter pub get
```
Expected: resolves successfully with no errors.

- [ ] **Step 9: Commit**

```bash
git add mobile/packages/app_version_client/ mobile/pubspec.yaml mobile/pubspec.lock
git commit -m "feat(update): scaffold app_version_client package"
```

---

### Task 2: TDD — AppVersionClient.fetchLatestRelease

**Files:**
- Create: `mobile/packages/app_version_client/test/src/app_version_client_test.dart`
- Modify: `mobile/packages/app_version_client/lib/src/app_version_client.dart`

- [ ] **Step 1: Write failing tests**

File: `test/src/app_version_client_test.dart`

```dart
import 'dart:convert';

import 'package:app_version_client/app_version_client.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  group(AppVersionClient, () {
    late _MockHttpClient httpClient;
    late AppVersionClient client;

    setUp(() {
      httpClient = _MockHttpClient();
      client = AppVersionClient(httpClient: httpClient);
    });

    tearDown(() {
      client.dispose();
    });

    final expectedUri = Uri.parse(
          'https://api.github.com/repos/'
          '${AppVersionConstants.repoOwner}/'
          '${AppVersionConstants.repoName}/'
          'releases/latest',
        );

    group('fetchLatestRelease', () {
      test('returns AppVersionInfo on valid response', () async {
        when(() => httpClient.get(expectedUri, headers: any(named: 'headers')))
            .thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'tag_name': '1.0.8',
              'published_at': '2026-04-02T02:04:42Z',
              'html_url':
                  'https://github.com/divinevideo/divine-mobile/releases/tag/1.0.8',
              'body': '# 1.0.8\n\n'
                  '- **Resumable uploads** — your loops survive bad signal\n'
                  '- **Double-tap to like** — you know the move\n'
                  '- **DMs leveled up** — clickable URLs and more\n',
            }),
            200,
          ),
        );

        final result = await client.fetchLatestRelease();

        expect(result.latestVersion, equals('1.0.8'));
        expect(
          result.publishedAt,
          equals(DateTime.parse('2026-04-02T02:04:42Z')),
        );
        expect(
          result.releaseNotesUrl,
          equals(
            'https://github.com/divinevideo/divine-mobile/releases/tag/1.0.8',
          ),
        );
        expect(
          result.releaseHighlights,
          equals([
            'Resumable uploads',
            'Double-tap to like',
            'DMs leveled up',
          ]),
        );
        expect(result.minimumVersion, isNull);
      });

      test('parses minimum_version from HTML comment in body', () async {
        when(() => httpClient.get(expectedUri, headers: any(named: 'headers')))
            .thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'tag_name': '1.0.9',
              'published_at': '2026-04-10T00:00:00Z',
              'html_url':
                  'https://github.com/divinevideo/divine-mobile/releases/tag/1.0.9',
              'body': '<!-- minimum_version: 1.0.6 -->\n'
                  '# 1.0.9\n- **Security fix** — important patch\n',
            }),
            200,
          ),
        );

        final result = await client.fetchLatestRelease();

        expect(result.minimumVersion, equals('1.0.6'));
        expect(result.releaseHighlights, equals(['Security fix']));
      });

      test('returns empty highlights when body has no bold items', () async {
        when(() => httpClient.get(expectedUri, headers: any(named: 'headers')))
            .thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'tag_name': '1.0.7',
              'published_at': '2026-03-01T00:00:00Z',
              'html_url':
                  'https://github.com/divinevideo/divine-mobile/releases/tag/1.0.7',
              'body': 'Just a plain release with no highlights.',
            }),
            200,
          ),
        );

        final result = await client.fetchLatestRelease();

        expect(result.releaseHighlights, isEmpty);
      });

      test('throws AppVersionFetchException on non-200 status', () async {
        when(() => httpClient.get(expectedUri, headers: any(named: 'headers')))
            .thenAnswer((_) async => http.Response('Not Found', 404));

        expect(
          () => client.fetchLatestRelease(),
          throwsA(isA<AppVersionFetchException>()),
        );
      });

      test('throws AppVersionFetchException on network error', () async {
        when(() => httpClient.get(expectedUri, headers: any(named: 'headers')))
            .thenThrow(Exception('no internet'));

        expect(
          () => client.fetchLatestRelease(),
          throwsA(isA<AppVersionFetchException>()),
        );
      });

      test('throws AppVersionFetchException on malformed JSON', () async {
        when(() => httpClient.get(expectedUri, headers: any(named: 'headers')))
            .thenAnswer((_) async => http.Response('not json', 200));

        expect(
          () => client.fetchLatestRelease(),
          throwsA(isA<AppVersionFetchException>()),
        );
      });
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd mobile/packages/app_version_client && dart test
```
Expected: Tests fail with `UnimplementedError`.

- [ ] **Step 3: Implement fetchLatestRelease**

Replace the `fetchLatestRelease` method in `lib/src/app_version_client.dart`:

```dart
  /// Fetches the latest release from GitHub.
  ///
  /// Throws [AppVersionFetchException] on network or parsing errors.
  Future<AppVersionInfo> fetchLatestRelease() async {
    final uri = Uri.parse(
      'https://api.github.com/repos/'
      '${AppVersionConstants.repoOwner}/'
      '${AppVersionConstants.repoName}/'
      'releases/latest',
    );

    try {
      final response = await _httpClient.get(
        uri,
        headers: {'Accept': 'application/vnd.github+json'},
      );

      if (response.statusCode != 200) {
        throw AppVersionFetchException(
          'GitHub API returned ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final body = json['body'] as String? ?? '';

      return AppVersionInfo(
        latestVersion: json['tag_name'] as String,
        publishedAt: DateTime.parse(json['published_at'] as String),
        releaseNotesUrl: json['html_url'] as String,
        minimumVersion: _parseMinimumVersion(body),
        releaseHighlights: _parseHighlights(body),
      );
    } on AppVersionFetchException {
      rethrow;
    } catch (e) {
      throw AppVersionFetchException('Failed to fetch release info: $e');
    }
  }

  String? _parseMinimumVersion(String body) {
    final match = AppVersionConstants.minimumVersionPattern.firstMatch(body);
    return match?.group(1);
  }

  List<String> _parseHighlights(String body) {
    return AppVersionConstants.highlightPattern
        .allMatches(body)
        .map((m) => m.group(1)!.trim())
        .take(5)
        .toList();
  }
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd mobile/packages/app_version_client && dart test
```
Expected: All 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/app_version_client/
git commit -m "feat(update): implement AppVersionClient with GitHub Releases API"
```

---

### Task 3: TDD — AppVersionConstants parsing helpers

**Files:**
- Create: `mobile/packages/app_version_client/test/src/app_version_constants_test.dart`

- [ ] **Step 1: Write tests for regex patterns**

```dart
import 'package:app_version_client/app_version_client.dart';
import 'package:test/test.dart';

void main() {
  group(AppVersionConstants, () {
    group('minimumVersionPattern', () {
      test('matches standard comment', () {
        const body = '<!-- minimum_version: 1.0.6 -->';
        final match =
            AppVersionConstants.minimumVersionPattern.firstMatch(body);
        expect(match?.group(1), equals('1.0.6'));
      });

      test('matches with extra whitespace', () {
        const body = '<!--   minimum_version:   1.2.3   -->';
        final match =
            AppVersionConstants.minimumVersionPattern.firstMatch(body);
        expect(match?.group(1), equals('1.2.3'));
      });

      test('returns null when not present', () {
        const body = '# Just a release\nSome text.';
        final match =
            AppVersionConstants.minimumVersionPattern.firstMatch(body);
        expect(match, isNull);
      });
    });

    group('highlightPattern', () {
      test('extracts bold items from bullet points', () {
        const body = '- **Resumable uploads** — survives bad signal\n'
            '- **Double-tap to like** — you know the move\n'
            '- Regular item without bold\n'
            '* **Asterisk bullet** — also works\n';
        final highlights = AppVersionConstants.highlightPattern
            .allMatches(body)
            .map((m) => m.group(1)!.trim())
            .toList();
        expect(
          highlights,
          equals(['Resumable uploads', 'Double-tap to like', 'Asterisk bullet']),
        );
      });

      test('returns empty for plain text body', () {
        const body = 'No highlights here, just plain text.';
        final highlights =
            AppVersionConstants.highlightPattern.allMatches(body).toList();
        expect(highlights, isEmpty);
      });
    });
  });
}
```

- [ ] **Step 2: Run tests**

```bash
cd mobile/packages/app_version_client && dart test
```
Expected: All pass (these test existing code).

- [ ] **Step 3: Commit**

```bash
git add mobile/packages/app_version_client/test/
git commit -m "test(update): add AppVersionConstants regex tests"
```

---

## Chunk 2: Repository Layer — AppUpdateRepository Package

### Task 4: Create app_update_repository package scaffold

**Files:**
- Create: `mobile/packages/app_update_repository/pubspec.yaml`
- Create: `mobile/packages/app_update_repository/lib/app_update_repository.dart`
- Create: `mobile/packages/app_update_repository/lib/src/app_update_repository.dart`
- Create: `mobile/packages/app_update_repository/lib/src/models/update_check_result.dart`
- Create: `mobile/packages/app_update_repository/lib/src/models/install_source.dart`
- Create: `mobile/packages/app_update_repository/lib/src/version_comparator.dart`
- Create: `mobile/packages/app_update_repository/analysis_options.yaml`
- Modify: `mobile/pubspec.yaml` (add to workspace list)

- [ ] **Step 1: Create pubspec.yaml**

```yaml
name: app_update_repository
description: Determines update urgency by comparing app version against latest release
version: 0.1.0+1
publish_to: none

environment:
  sdk: ^3.11.0

resolution: workspace

dependencies:
  app_version_client:
  equatable: ^2.0.7
  meta: ^1.17.0
  package_info_plus: ^9.0.0
  shared_preferences: ^2.2.3

dev_dependencies:
  mocktail: ^1.0.4
  test: ^1.26.3
  very_good_analysis: ^10.0.0
```

- [ ] **Step 2: Create analysis_options.yaml**

```yaml
include: package:very_good_analysis/analysis_options.yaml
```

- [ ] **Step 3: Create InstallSource enum and download URL resolver**

File: `lib/src/models/install_source.dart`

```dart
/// How the app was installed, used to determine the correct upgrade URL.
enum InstallSource {
  /// Google Play Store.
  playStore,

  /// Apple App Store.
  appStore,

  /// Apple TestFlight.
  testFlight,

  /// Zapstore (Nostr app store).
  zapstore,

  /// Direct APK sideload or unknown source.
  sideload;

  /// The installer package name on Android that maps to this source.
  static const playStoreInstaller = 'com.android.vending';
  static const zapstoreInstaller = 'com.zapstore.app';
}

/// Download URLs for each install source.
abstract class DownloadUrls {
  static const playStore =
      'https://play.google.com/store/apps/details?id=com.divinevideo.app';
  static const appStore =
      'https://apps.apple.com/app/divine-human-video/id6740425428';
  static const testFlight = 'https://testflight.apple.com/join/divine';
  static const zapstore = 'https://zapstore.dev/app/com.divinevideo.app';
  static const github =
      'https://github.com/divinevideo/divine-mobile/releases/latest';

  /// Returns the download URL for the given [source].
  static String forSource(InstallSource source) {
    return switch (source) {
      InstallSource.playStore => playStore,
      InstallSource.appStore => appStore,
      InstallSource.testFlight => testFlight,
      InstallSource.zapstore => zapstore,
      InstallSource.sideload => github,
    };
  }
}
```

- [ ] **Step 4: Create UpdateUrgency and UpdateCheckResult**

File: `lib/src/models/update_check_result.dart`

```dart
import 'package:equatable/equatable.dart';

/// How urgently we should nudge the user to update.
enum UpdateUrgency {
  /// App is up to date, or check hasn't run yet.
  none,

  /// New version exists, released < 2 weeks ago.
  gentle,

  /// New version exists, released >= 2 weeks ago.
  moderate,

  /// User's version is below the minimum supported version.
  urgent,
}

/// Result of comparing the current app version against the latest release.
class UpdateCheckResult extends Equatable {
  const UpdateCheckResult({
    required this.urgency,
    required this.downloadUrl,
    this.latestVersion,
    this.releaseHighlights = const [],
    this.releaseNotesUrl,
  });

  /// No update needed.
  const UpdateCheckResult.none()
      : this(urgency: UpdateUrgency.none, downloadUrl: '');

  final UpdateUrgency urgency;
  final String downloadUrl;
  final String? latestVersion;
  final List<String> releaseHighlights;
  final String? releaseNotesUrl;

  @override
  List<Object?> get props => [
        urgency,
        downloadUrl,
        latestVersion,
        releaseHighlights,
        releaseNotesUrl,
      ];
}
```

- [ ] **Step 5: Create VersionComparator utility**

File: `lib/src/version_comparator.dart`

```dart
/// Compares semantic version strings.
///
/// Returns:
/// - negative if [a] < [b]
/// - zero if [a] == [b]
/// - positive if [a] > [b]
int compareVersions(String a, String b) {
  final aParts = a.split('.').map(int.tryParse).toList();
  final bParts = b.split('.').map(int.tryParse).toList();

  for (var i = 0; i < 3; i++) {
    final aVal = i < aParts.length ? (aParts[i] ?? 0) : 0;
    final bVal = i < bParts.length ? (bParts[i] ?? 0) : 0;
    if (aVal != bVal) return aVal.compareTo(bVal);
  }
  return 0;
}

/// Returns true if [current] is older than [latest].
bool isOlderThan(String current, String latest) =>
    compareVersions(current, latest) < 0;

/// Returns true if [current] is below [minimum].
bool isBelowMinimum(String current, String minimum) =>
    compareVersions(current, minimum) < 0;
```

- [ ] **Step 6: Create barrel file**

File: `lib/app_update_repository.dart`

```dart
library;

export 'src/app_update_repository.dart';
export 'src/models/install_source.dart';
export 'src/models/update_check_result.dart';
export 'src/version_comparator.dart';
```

- [ ] **Step 7: Create empty AppUpdateRepository class**

File: `lib/src/app_update_repository.dart`

```dart
import 'package:app_update_repository/app_update_repository.dart';
import 'package:app_version_client/app_version_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences keys for caching and dismissal tracking.
abstract class UpdatePrefsKeys {
  static const dismissedVersion = 'update_dismissed_version';
  static const dismissedAt = 'update_dismissed_at';
  static const lastChecked = 'update_last_checked';
}

/// Cooldown before showing the moderate dialog again after dismissal.
const moderateCooldown = Duration(days: 3);

/// Compares the current app version against the latest release,
/// manages caching, and determines the update urgency.
class AppUpdateRepository {
  AppUpdateRepository({
    required AppVersionClient appVersionClient,
    required SharedPreferences sharedPreferences,
    required String currentVersion,
    required InstallSource installSource,
  })  : _client = appVersionClient,
        _prefs = sharedPreferences,
        _currentVersion = currentVersion,
        _installSource = installSource;

  final AppVersionClient _client;
  final SharedPreferences _prefs;
  final String _currentVersion;
  final InstallSource _installSource;

  /// Checks for updates, respecting the 24h cache TTL.
  /// Returns null if the check should be skipped (first install, within TTL).
  Future<UpdateCheckResult?> checkForUpdate() async {
    throw UnimplementedError();
  }

  /// Records that the user dismissed the nudge for the given version.
  Future<void> dismissUpdate(String version) async {
    throw UnimplementedError();
  }
}
```

- [ ] **Step 8: Register in workspace and run pub get**

Add `- packages/app_update_repository` to `mobile/pubspec.yaml` workspace list.

```bash
cd mobile && flutter pub get
```

- [ ] **Step 9: Commit**

```bash
git add mobile/packages/app_update_repository/ mobile/pubspec.yaml mobile/pubspec.lock
git commit -m "feat(update): scaffold app_update_repository package"
```

---

### Task 5: TDD — VersionComparator

**Files:**
- Create: `mobile/packages/app_update_repository/test/src/version_comparator_test.dart`

- [ ] **Step 1: Write tests**

```dart
import 'package:app_update_repository/app_update_repository.dart';
import 'package:test/test.dart';

void main() {
  group('compareVersions', () {
    test('equal versions return 0', () {
      expect(compareVersions('1.0.8', '1.0.8'), equals(0));
    });

    test('older version returns negative', () {
      expect(compareVersions('1.0.4', '1.0.8'), isNegative);
    });

    test('newer version returns positive', () {
      expect(compareVersions('1.0.9', '1.0.8'), isPositive);
    });

    test('compares major version', () {
      expect(compareVersions('2.0.0', '1.9.9'), isPositive);
    });

    test('compares minor version', () {
      expect(compareVersions('1.1.0', '1.0.9'), isPositive);
    });

    test('handles two-part versions', () {
      expect(compareVersions('1.1', '1.0.9'), isPositive);
    });
  });

  group('isOlderThan', () {
    test('returns true when current is older', () {
      expect(isOlderThan('1.0.4', '1.0.8'), isTrue);
    });

    test('returns false when current is equal', () {
      expect(isOlderThan('1.0.8', '1.0.8'), isFalse);
    });

    test('returns false when current is newer', () {
      expect(isOlderThan('1.0.9', '1.0.8'), isFalse);
    });
  });

  group('isBelowMinimum', () {
    test('returns true when below minimum', () {
      expect(isBelowMinimum('1.0.4', '1.0.6'), isTrue);
    });

    test('returns false when at minimum', () {
      expect(isBelowMinimum('1.0.6', '1.0.6'), isFalse);
    });

    test('returns false when above minimum', () {
      expect(isBelowMinimum('1.0.8', '1.0.6'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run tests**

```bash
cd mobile/packages/app_update_repository && dart test test/src/version_comparator_test.dart
```
Expected: All pass.

- [ ] **Step 3: Commit**

```bash
git add mobile/packages/app_update_repository/test/
git commit -m "test(update): add VersionComparator tests"
```

---

### Task 6: TDD — AppUpdateRepository.checkForUpdate

**Files:**
- Create: `mobile/packages/app_update_repository/test/src/app_update_repository_test.dart`
- Modify: `mobile/packages/app_update_repository/lib/src/app_update_repository.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:app_update_repository/app_update_repository.dart';
import 'package:app_version_client/app_version_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

class _MockAppVersionClient extends Mock implements AppVersionClient {}

void main() {
  group(AppUpdateRepository, () {
    late _MockAppVersionClient client;
    late SharedPreferences prefs;

    setUp(() async {
      client = _MockAppVersionClient();
      SharedPreferences.setMockInitialValues({
        // Simulate a prior check > 24h ago so tests don't get skipped.
        UpdatePrefsKeys.lastChecked:
            DateTime.now()
                .subtract(const Duration(hours: 25))
                .toIso8601String(),
      });
      prefs = await SharedPreferences.getInstance();
    });

    AppUpdateRepository buildRepo({
      String currentVersion = '1.0.4',
      InstallSource installSource = InstallSource.sideload,
    }) {
      return AppUpdateRepository(
        appVersionClient: client,
        sharedPreferences: prefs,
        currentVersion: currentVersion,
        installSource: installSource,
      );
    }

    AppVersionInfo buildInfo({
      String version = '1.0.8',
      DateTime? publishedAt,
      String? minimumVersion,
      List<String> highlights = const ['New feature'],
    }) {
      return AppVersionInfo(
        latestVersion: version,
        publishedAt: publishedAt ?? DateTime.now(),
        releaseNotesUrl:
            'https://github.com/divinevideo/divine-mobile/releases/tag/$version',
        minimumVersion: minimumVersion,
        releaseHighlights: highlights,
      );
    }

    group('checkForUpdate', () {
      test('returns none when on latest version', () async {
        when(() => client.fetchLatestRelease())
            .thenAnswer((_) async => buildInfo(version: '1.0.8'));

        final repo = buildRepo(currentVersion: '1.0.8');
        final result = await repo.checkForUpdate();

        expect(result.urgency, equals(UpdateUrgency.none));
      });

      test('returns none when ahead of latest (pre-release build)', () async {
        when(() => client.fetchLatestRelease())
            .thenAnswer((_) async => buildInfo(version: '1.0.8'));

        final repo = buildRepo(currentVersion: '1.0.9');
        final result = await repo.checkForUpdate();

        expect(result.urgency, equals(UpdateUrgency.none));
      });

      test('returns gentle when update is < 2 weeks old', () async {
        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            publishedAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
        );

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result.urgency, equals(UpdateUrgency.gentle));
      });

      test('returns moderate when update is >= 2 weeks old', () async {
        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            publishedAt: DateTime.now().subtract(const Duration(days: 15)),
          ),
        );

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result.urgency, equals(UpdateUrgency.moderate));
      });

      test('returns urgent when below minimum_version', () async {
        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(minimumVersion: '1.0.6'),
        );

        final repo = buildRepo(currentVersion: '1.0.4');
        final result = await repo.checkForUpdate();

        expect(result.urgency, equals(UpdateUrgency.urgent));
      });

      test('urgent overrides moderate when below minimum', () async {
        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            publishedAt: DateTime.now().subtract(const Duration(days: 30)),
            minimumVersion: '1.0.6',
          ),
        );

        final repo = buildRepo(currentVersion: '1.0.4');
        final result = await repo.checkForUpdate();

        expect(result.urgency, equals(UpdateUrgency.urgent));
      });

      test('resolves correct download URL for install source', () async {
        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            publishedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        );

        final repo = buildRepo(installSource: InstallSource.playStore);
        final result = await repo.checkForUpdate();

        expect(result.downloadUrl, equals(DownloadUrls.playStore));
      });

      test('resolves GitHub URL for sideload source', () async {
        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            publishedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        );

        final repo = buildRepo(installSource: InstallSource.sideload);
        final result = await repo.checkForUpdate();

        expect(result.downloadUrl, equals(DownloadUrls.github));
      });

      test('includes release highlights in result', () async {
        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            publishedAt: DateTime.now().subtract(const Duration(days: 1)),
            highlights: ['Feature A', 'Feature B'],
          ),
        );

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result.releaseHighlights, equals(['Feature A', 'Feature B']));
      });

      test('returns none on fetch failure', () async {
        when(() => client.fetchLatestRelease())
            .thenThrow(const AppVersionFetchException('no network'));

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result!.urgency, equals(UpdateUrgency.none));
      });

      test('returns null on first install (no prior check)', () async {
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result, isNull);
        expect(prefs.getString(UpdatePrefsKeys.lastChecked), isNotNull);
      });

      test('returns null when within 24h TTL', () async {
        SharedPreferences.setMockInitialValues({
          UpdatePrefsKeys.lastChecked:
              DateTime.now()
                  .subtract(const Duration(hours: 1))
                  .toIso8601String(),
        });
        prefs = await SharedPreferences.getInstance();

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result, isNull);
        verifyNever(() => client.fetchLatestRelease());
      });

      test('gentle dismissed hides until next version', () async {
        prefs.setString(UpdatePrefsKeys.dismissedVersion, '1.0.8');
        prefs.setString(
          UpdatePrefsKeys.dismissedAt,
          DateTime.now().toIso8601String(),
        );

        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            publishedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        );

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result!.urgency, equals(UpdateUrgency.none));
      });

      test('moderate reappears after 3-day cooldown', () async {
        prefs.setString(UpdatePrefsKeys.dismissedVersion, '1.0.8');
        prefs.setString(
          UpdatePrefsKeys.dismissedAt,
          DateTime.now()
              .subtract(const Duration(days: 4))
              .toIso8601String(),
        );

        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            publishedAt: DateTime.now().subtract(const Duration(days: 20)),
          ),
        );

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result!.urgency, equals(UpdateUrgency.moderate));
      });

      test('new version resets dismissal', () async {
        prefs.setString(UpdatePrefsKeys.dismissedVersion, '1.0.7');
        prefs.setString(
          UpdatePrefsKeys.dismissedAt,
          DateTime.now().toIso8601String(),
        );

        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            version: '1.0.8',
            publishedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        );

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result!.urgency, equals(UpdateUrgency.gentle));
      });
    });

    group('dismissUpdate', () {
      test('persists version and timestamp', () async {
        final repo = buildRepo();
        await repo.dismissUpdate('1.0.8');

        expect(
          prefs.getString(UpdatePrefsKeys.dismissedVersion),
          equals('1.0.8'),
        );
        expect(prefs.getString(UpdatePrefsKeys.dismissedAt), isNotNull);
      });
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd mobile/packages/app_update_repository && dart test
```
Expected: Fail with `UnimplementedError`.

- [ ] **Step 3: Implement checkForUpdate and dismissUpdate**

Replace the full file `lib/src/app_update_repository.dart`:

```dart
import 'package:app_update_repository/app_update_repository.dart';
import 'package:app_version_client/app_version_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences keys for caching and dismissal tracking.
abstract class UpdatePrefsKeys {
  static const dismissedVersion = 'update_dismissed_version';
  static const dismissedAt = 'update_dismissed_at';
  static const lastChecked = 'update_last_checked';
}

/// Cooldown before showing the moderate dialog again after dismissal.
const moderateCooldown = Duration(days: 3);

/// Duration after which a release escalates from gentle to moderate.
const _moderateThreshold = Duration(days: 14);

/// Compares the current app version against the latest release,
/// manages caching, dismissal, and determines the update urgency.
class AppUpdateRepository {
  AppUpdateRepository({
    required AppVersionClient appVersionClient,
    required SharedPreferences sharedPreferences,
    required String currentVersion,
    required InstallSource installSource,
  })  : _client = appVersionClient,
        _prefs = sharedPreferences,
        _currentVersion = currentVersion,
        _installSource = installSource;

  final AppVersionClient _client;
  final SharedPreferences _prefs;
  final String _currentVersion;
  final InstallSource _installSource;

  /// Checks for updates, respecting the 24h cache TTL.
  ///
  /// Returns `null` if the check should be skipped:
  /// - First install (no prior check recorded)
  /// - Within the 24h TTL window
  ///
  /// Returns [UpdateCheckResult] with the appropriate urgency otherwise.
  /// Returns [UpdateCheckResult.none] on network failures (silent skip).
  Future<UpdateCheckResult?> checkForUpdate() async {
    // Skip on first install.
    final lastChecked = _prefs.getString(UpdatePrefsKeys.lastChecked);
    if (lastChecked == null) {
      await _prefs.setString(
        UpdatePrefsKeys.lastChecked,
        DateTime.now().toIso8601String(),
      );
      return null;
    }

    // Respect 24h cache TTL.
    final lastCheckedAt = DateTime.tryParse(lastChecked);
    if (lastCheckedAt != null &&
        DateTime.now().difference(lastCheckedAt) <
            AppVersionConstants.cacheTtl) {
      return null;
    }

    final AppVersionInfo info;
    try {
      info = await _client.fetchLatestRelease();
    } on AppVersionFetchException {
      return const UpdateCheckResult.none();
    }

    await _prefs.setString(
      UpdatePrefsKeys.lastChecked,
      DateTime.now().toIso8601String(),
    );

    if (!isOlderThan(_currentVersion, info.latestVersion)) {
      return const UpdateCheckResult.none();
    }

    final downloadUrl = DownloadUrls.forSource(_installSource);
    final age = DateTime.now().difference(info.publishedAt);
    final rawUrgency = _determineUrgency(info, age);
    final urgency = _applyDismissalRules(rawUrgency, info.latestVersion);

    return UpdateCheckResult(
      urgency: urgency,
      downloadUrl: downloadUrl,
      latestVersion: info.latestVersion,
      releaseHighlights: info.releaseHighlights,
      releaseNotesUrl: info.releaseNotesUrl,
    );
  }

  /// Records that the user dismissed the nudge for [version].
  Future<void> dismissUpdate(String version) async {
    await _prefs.setString(UpdatePrefsKeys.dismissedVersion, version);
    await _prefs.setString(
      UpdatePrefsKeys.dismissedAt,
      DateTime.now().toIso8601String(),
    );
  }

  UpdateUrgency _determineUrgency(AppVersionInfo info, Duration age) {
    if (info.minimumVersion != null &&
        isBelowMinimum(_currentVersion, info.minimumVersion!)) {
      return UpdateUrgency.urgent;
    }
    if (age >= _moderateThreshold) {
      return UpdateUrgency.moderate;
    }
    return UpdateUrgency.gentle;
  }

  UpdateUrgency _applyDismissalRules(
    UpdateUrgency urgency,
    String latestVersion,
  ) {
    // Urgent: always show, ignore dismissal.
    if (urgency == UpdateUrgency.urgent) return urgency;

    final dismissedVersion = _prefs.getString(UpdatePrefsKeys.dismissedVersion);
    final dismissedAtStr = _prefs.getString(UpdatePrefsKeys.dismissedAt);

    // Different version: reset, show nudge.
    if (dismissedVersion != latestVersion) return urgency;

    // Same version was dismissed.
    final dismissedAt =
        dismissedAtStr != null ? DateTime.tryParse(dismissedAtStr) : null;

    // Gentle: once per version.
    if (urgency == UpdateUrgency.gentle) return UpdateUrgency.none;

    // Moderate: 3-day cooldown.
    if (urgency == UpdateUrgency.moderate && dismissedAt != null) {
      if (DateTime.now().difference(dismissedAt) < moderateCooldown) {
        return UpdateUrgency.none;
      }
    }

    return urgency;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd mobile/packages/app_update_repository && dart test
```
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/app_update_repository/
git commit -m "feat(update): implement AppUpdateRepository with escalation logic"
```

---

## Chunk 3: Business Logic Layer — AppUpdateBloc

### Task 7: Create AppUpdateBloc

**Files:**
- Create: `mobile/lib/app_update/bloc/app_update_bloc.dart`
- Create: `mobile/lib/app_update/bloc/app_update_event.dart`
- Create: `mobile/lib/app_update/bloc/app_update_state.dart`
- Create: `mobile/lib/app_update/app_update.dart` (barrel)

- [ ] **Step 0: Create update_copy.dart for l10n-ready copy constants**

File: `mobile/lib/app_update/update_copy.dart`

```dart
/// User-facing copy for update nudges.
/// English only for v1. Structured for future l10n extraction.
abstract class UpdateCopy {
  static const gentle = UpdateCopy.gentle;
  static const moderateTitle =
      "There's been an update since you last checked";
  static const urgentTitle = "You're missing important fixes";
  static const notNow = 'Not now';
  static const update = 'Update';

  static String newIn(String version) => 'New in $version:';
}
```

- [ ] **Step 1: Create app_update_event.dart**

File: `mobile/lib/app_update/bloc/app_update_event.dart`

```dart
part of 'app_update_bloc.dart';

sealed class AppUpdateEvent {
  const AppUpdateEvent();
}

/// Triggers a version check against the GitHub Releases API.
final class AppUpdateCheckRequested extends AppUpdateEvent {
  const AppUpdateCheckRequested();
}

/// User dismissed the update nudge.
final class AppUpdateDismissed extends AppUpdateEvent {
  const AppUpdateDismissed();
}
```

- [ ] **Step 2: Create app_update_state.dart**

File: `mobile/lib/app_update/bloc/app_update_state.dart`

```dart
part of 'app_update_bloc.dart';

enum AppUpdateStatus { initial, checking, resolved, error }

class AppUpdateState extends Equatable {
  const AppUpdateState({
    this.status = AppUpdateStatus.initial,
    this.urgency = UpdateUrgency.none,
    this.latestVersion,
    this.downloadUrl,
    this.releaseHighlights = const [],
    this.releaseNotesUrl,
  });

  final AppUpdateStatus status;
  final UpdateUrgency urgency;
  final String? latestVersion;
  final String? downloadUrl;
  final List<String> releaseHighlights;
  final String? releaseNotesUrl;

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    UpdateUrgency? urgency,
    String? latestVersion,
    String? downloadUrl,
    List<String>? releaseHighlights,
    String? releaseNotesUrl,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      urgency: urgency ?? this.urgency,
      latestVersion: latestVersion ?? this.latestVersion,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      releaseHighlights: releaseHighlights ?? this.releaseHighlights,
      releaseNotesUrl: releaseNotesUrl ?? this.releaseNotesUrl,
    );
  }

  @override
  List<Object?> get props => [
        status,
        urgency,
        latestVersion,
        downloadUrl,
        releaseHighlights,
        releaseNotesUrl,
      ];
}
```

- [ ] **Step 3: Create app_update_bloc.dart**

The BLoC is thin — it delegates caching, dismissal, and escalation logic to the repository. It only manages the UI state lifecycle.

File: `mobile/lib/app_update/bloc/app_update_bloc.dart`

```dart
import 'package:app_update_repository/app_update_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'app_update_event.dart';
part 'app_update_state.dart';

class AppUpdateBloc extends Bloc<AppUpdateEvent, AppUpdateState> {
  AppUpdateBloc({
    required AppUpdateRepository repository,
  })  : _repository = repository,
        super(const AppUpdateState()) {
    on<AppUpdateCheckRequested>(_onCheckRequested);
    on<AppUpdateDismissed>(_onDismissed);
  }

  final AppUpdateRepository _repository;

  Future<void> _onCheckRequested(
    AppUpdateCheckRequested event,
    Emitter<AppUpdateState> emit,
  ) async {
    emit(state.copyWith(status: AppUpdateStatus.checking));

    final result = await _repository.checkForUpdate();

    // null means check was skipped (first install or within 24h TTL).
    if (result == null) {
      emit(state.copyWith(status: AppUpdateStatus.initial));
      return;
    }

    emit(AppUpdateState(
      status: AppUpdateStatus.resolved,
      urgency: result.urgency,
      latestVersion: result.latestVersion,
      downloadUrl: result.downloadUrl,
      releaseHighlights: result.releaseHighlights,
      releaseNotesUrl: result.releaseNotesUrl,
    ));
  }

  Future<void> _onDismissed(
    AppUpdateDismissed event,
    Emitter<AppUpdateState> emit,
  ) async {
    if (state.latestVersion != null) {
      await _repository.dismissUpdate(state.latestVersion!);
    }
    emit(state.copyWith(urgency: UpdateUrgency.none));
  }
}
```

- [ ] **Step 4: Create barrel file**

File: `mobile/lib/app_update/app_update.dart`

```dart
export 'bloc/app_update_bloc.dart';
```

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/app_update/
git commit -m "feat(update): add AppUpdateBloc with escalation and dismissal logic"
```

---

### Task 8: TDD — AppUpdateBloc tests

**Files:**
- Create: `mobile/test/app_update/bloc/app_update_bloc_test.dart`

- [ ] **Step 1: Write bloc tests**

The BLoC is thin — caching, dismissal, and escalation are tested in the repository tests. BLoC tests focus on state lifecycle and delegation.

```dart
import 'package:app_update_repository/app_update_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/app_update/app_update.dart';

class _MockAppUpdateRepository extends Mock implements AppUpdateRepository {}

void main() {
  group(AppUpdateBloc, () {
    late _MockAppUpdateRepository repository;

    setUp(() {
      repository = _MockAppUpdateRepository();
    });

    AppUpdateBloc buildBloc() => AppUpdateBloc(repository: repository);

    final gentleResult = UpdateCheckResult(
      urgency: UpdateUrgency.gentle,
      downloadUrl: DownloadUrls.github,
      latestVersion: '1.0.8',
      releaseHighlights: const ['New feature'],
      releaseNotesUrl:
          'https://github.com/divinevideo/divine-mobile/releases/tag/1.0.8',
    );

    group('CheckRequested', () {
      blocTest<AppUpdateBloc, AppUpdateState>(
        'emits resolved with result when repository returns update',
        build: buildBloc,
        setUp: () {
          when(() => repository.checkForUpdate())
              .thenAnswer((_) async => gentleResult);
        },
        act: (bloc) => bloc.add(const AppUpdateCheckRequested()),
        expect: () => [
          const AppUpdateState(status: AppUpdateStatus.checking),
          AppUpdateState(
            status: AppUpdateStatus.resolved,
            urgency: UpdateUrgency.gentle,
            latestVersion: '1.0.8',
            downloadUrl: DownloadUrls.github,
            releaseHighlights: const ['New feature'],
            releaseNotesUrl:
                'https://github.com/divinevideo/divine-mobile/releases/tag/1.0.8',
          ),
        ],
      );

      blocTest<AppUpdateBloc, AppUpdateState>(
        'emits resolved none when no update available',
        build: buildBloc,
        setUp: () {
          when(() => repository.checkForUpdate())
              .thenAnswer((_) async => const UpdateCheckResult.none());
        },
        act: (bloc) => bloc.add(const AppUpdateCheckRequested()),
        expect: () => [
          const AppUpdateState(status: AppUpdateStatus.checking),
          const AppUpdateState(
            status: AppUpdateStatus.resolved,
            urgency: UpdateUrgency.none,
          ),
        ],
      );

      blocTest<AppUpdateBloc, AppUpdateState>(
        'reverts to initial when repository returns null (skipped check)',
        build: buildBloc,
        setUp: () {
          when(() => repository.checkForUpdate())
              .thenAnswer((_) async => null);
        },
        act: (bloc) => bloc.add(const AppUpdateCheckRequested()),
        expect: () => [
          const AppUpdateState(status: AppUpdateStatus.checking),
          const AppUpdateState(status: AppUpdateStatus.initial),
        ],
      );

      blocTest<AppUpdateBloc, AppUpdateState>(
        'emits urgent when repository returns urgent',
        build: buildBloc,
        setUp: () {
          when(() => repository.checkForUpdate()).thenAnswer(
            (_) async => UpdateCheckResult(
              urgency: UpdateUrgency.urgent,
              downloadUrl: DownloadUrls.github,
              latestVersion: '1.0.8',
              releaseHighlights: const ['Security fix'],
            ),
          );
        },
        act: (bloc) => bloc.add(const AppUpdateCheckRequested()),
        expect: () => [
          const AppUpdateState(status: AppUpdateStatus.checking),
          isA<AppUpdateState>()
              .having((s) => s.urgency, 'urgency', UpdateUrgency.urgent),
        ],
      );
    });

    group('Dismissed', () {
      blocTest<AppUpdateBloc, AppUpdateState>(
        'calls repository.dismissUpdate and sets urgency to none',
        build: buildBloc,
        seed: () => AppUpdateState(
          status: AppUpdateStatus.resolved,
          urgency: UpdateUrgency.gentle,
          latestVersion: '1.0.8',
          downloadUrl: DownloadUrls.github,
        ),
        setUp: () {
          when(() => repository.dismissUpdate(any()))
              .thenAnswer((_) async {});
        },
        act: (bloc) => bloc.add(const AppUpdateDismissed()),
        expect: () => [
          isA<AppUpdateState>()
              .having((s) => s.urgency, 'urgency', UpdateUrgency.none),
        ],
        verify: (_) {
          verify(() => repository.dismissUpdate('1.0.8')).called(1);
        },
      );
    });
  });
}
```

- [ ] **Step 2: Run tests**

```bash
cd mobile && flutter test test/app_update/bloc/app_update_bloc_test.dart
```
Expected: All pass.

- [ ] **Step 3: Commit**

```bash
git add mobile/test/app_update/
git commit -m "test(update): add AppUpdateBloc tests for escalation and dismissal"
```

---

## Chunk 4: Install Source Detection

### Task 9: Add install source detection to AppUpdateRepository

**Files:**
- Create: `mobile/packages/app_update_repository/lib/src/install_source_detector.dart`
- Create: `mobile/packages/app_update_repository/test/src/install_source_detector_test.dart`
- Modify: `mobile/packages/app_update_repository/lib/app_update_repository.dart` (barrel)

- [ ] **Step 1: Write tests for install source detection**

File: `test/src/install_source_detector_test.dart`

```dart
import 'package:app_update_repository/src/install_source_detector.dart';
import 'package:app_update_repository/app_update_repository.dart';
import 'package:test/test.dart';

void main() {
  group('resolveAndroidInstallSource', () {
    test('returns playStore for com.android.vending', () {
      expect(
        resolveAndroidInstallSource('com.android.vending'),
        equals(InstallSource.playStore),
      );
    });

    test('returns zapstore for com.zapstore.app', () {
      expect(
        resolveAndroidInstallSource('com.zapstore.app'),
        equals(InstallSource.zapstore),
      );
    });

    test('returns sideload for unknown installer', () {
      expect(
        resolveAndroidInstallSource('com.other.installer'),
        equals(InstallSource.sideload),
      );
    });

    test('returns sideload for null installer', () {
      expect(
        resolveAndroidInstallSource(null),
        equals(InstallSource.sideload),
      );
    });
  });

  group('resolveIosInstallSource', () {
    test('returns testFlight when sandbox', () {
      expect(
        resolveIosInstallSource(isSandbox: true),
        equals(InstallSource.testFlight),
      );
    });

    test('returns appStore when not sandbox', () {
      expect(
        resolveIosInstallSource(isSandbox: false),
        equals(InstallSource.appStore),
      );
    });
  });
}
```

- [ ] **Step 2: Implement install source detection**

File: `lib/src/install_source_detector.dart`

```dart
import 'package:app_update_repository/app_update_repository.dart';

/// Resolves the install source on Android from the installer package name.
InstallSource resolveAndroidInstallSource(String? installerPackageName) {
  return switch (installerPackageName) {
    InstallSource.playStoreInstaller => InstallSource.playStore,
    InstallSource.zapstoreInstaller => InstallSource.zapstore,
    _ => InstallSource.sideload,
  };
}

/// Resolves the install source on iOS from the receipt environment.
InstallSource resolveIosInstallSource({required bool isSandbox}) {
  return isSandbox ? InstallSource.testFlight : InstallSource.appStore;
}
```

- [ ] **Step 3: Update barrel file**

Add to `lib/app_update_repository.dart`:
```dart
export 'src/install_source_detector.dart';
```

- [ ] **Step 4: Run tests**

```bash
cd mobile/packages/app_update_repository && dart test
```
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/app_update_repository/
git commit -m "feat(update): add install source detection for Android and iOS"
```

---

## Chunk 5: Presentation Layer — UI Widgets

### Task 10: Create update banner widget

**Files:**
- Create: `mobile/lib/app_update/view/update_banner.dart`
- Create: `mobile/lib/app_update/view/view.dart` (barrel)
- Modify: `mobile/lib/app_update/app_update.dart` (barrel)

- [ ] **Step 1: Create the banner widget**

File: `mobile/lib/app_update/view/update_banner.dart`

```dart
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:url_launcher/url_launcher.dart';

/// A slim dismissible banner shown at the bottom of the home feed
/// when a gentle update is available.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<AppUpdateBloc, AppUpdateState, _BannerData?>(
      selector: (state) {
        if (state.status != AppUpdateStatus.resolved) return null;
        if (state.urgency != UpdateUrgency.gentle) return null;
        return _BannerData(downloadUrl: state.downloadUrl ?? '');
      },
      builder: (context, data) {
        if (data == null) return const SizedBox.shrink();
        return _BannerContent(downloadUrl: data.downloadUrl);
      },
    );
  }
}

class _BannerData {
  const _BannerData({required this.downloadUrl});
  final String downloadUrl;
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({required this.downloadUrl});

  final String downloadUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: VineTheme.vineGreen.withValues(alpha: 0.15),
        border: Border(
          top: BorderSide(
            color: VineTheme.vineGreen.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _launchUpdate(downloadUrl),
              child: Text(
                UpdateCopy.gentle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: VineTheme.vineGreen,
                    ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 18,
              color: VineTheme.lightText.withValues(alpha: 0.6),
            ),
            onPressed: () {
              context.read<AppUpdateBloc>().add(const AppUpdateDismissed());
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUpdate(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
```

- [ ] **Step 2: Create barrel files**

File: `mobile/lib/app_update/view/view.dart`
```dart
export 'update_banner.dart';
export 'update_dialog.dart';
```

Update `mobile/lib/app_update/app_update.dart`:
```dart
export 'bloc/app_update_bloc.dart';
export 'view/view.dart';
```

- [ ] **Step 3: Commit (dialog in next task)**

Wait for Task 11 to complete the dialog widget before committing the view barrel.

---

### Task 11: Create update dialog widget

**Files:**
- Create: `mobile/lib/app_update/view/update_dialog.dart`

- [ ] **Step 1: Create the dialog widget**

File: `mobile/lib/app_update/view/update_dialog.dart`

```dart
import 'package:app_update_repository/app_update_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows a dialog when the update urgency is moderate or urgent.
///
/// Place this as a [BlocListener] in the widget tree — it shows the dialog
/// imperatively when the BLoC emits a moderate/urgent state.
class UpdateDialogListener extends StatelessWidget {
  const UpdateDialogListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppUpdateBloc, AppUpdateState>(
      listenWhen: (prev, curr) =>
          curr.status == AppUpdateStatus.resolved &&
          (curr.urgency == UpdateUrgency.moderate ||
              curr.urgency == UpdateUrgency.urgent) &&
          prev.urgency != curr.urgency,
      listener: (context, state) {
        showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => _UpdateDialog(
            urgency: state.urgency,
            latestVersion: state.latestVersion ?? '',
            downloadUrl: state.downloadUrl ?? '',
            highlights: state.releaseHighlights,
            onDismiss: () {
              context.read<AppUpdateBloc>().add(const AppUpdateDismissed());
              Navigator.of(context).pop();
            },
          ),
        );
      },
      child: child,
    );
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({
    required this.urgency,
    required this.latestVersion,
    required this.downloadUrl,
    required this.highlights,
    required this.onDismiss,
  });

  final UpdateUrgency urgency;
  final String latestVersion;
  final String downloadUrl;
  final List<String> highlights;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isUrgent = urgency == UpdateUrgency.urgent;

    return AlertDialog(
      backgroundColor: VineTheme.surfaceBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        isUrgent
            ? "You're missing important fixes"
            : "There's been an update since you last checked",
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: VineTheme.primaryText,
            ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlights.isNotEmpty) ...[
            Text(
              'New in $latestVersion:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: VineTheme.lightText.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 8),
            for (final highlight in highlights.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(color: VineTheme.vineGreen),
                    ),
                    Expanded(
                      child: Text(
                        highlight,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: VineTheme.primaryText,
                                ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: Text(
            'Not now',
            style: TextStyle(
              color: VineTheme.lightText.withValues(alpha: 0.6),
            ),
          ),
        ),
        FilledButton(
          onPressed: () async {
            final uri = Uri.tryParse(downloadUrl);
            if (uri != null) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: VineTheme.vineGreen,
          ),
          child: const Text('Update'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit UI widgets**

```bash
git add mobile/lib/app_update/
git commit -m "feat(update): add update banner and dialog widgets"
```

---

### Task 12: Widget tests for UpdateBanner and UpdateDialogListener

**Files:**
- Create: `mobile/test/app_update/view/update_banner_test.dart`
- Create: `mobile/test/app_update/view/update_dialog_test.dart`

- [ ] **Step 1: Write UpdateBanner test**

File: `mobile/test/app_update/view/update_banner_test.dart`

```dart
import 'package:app_update_repository/app_update_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/app_update/app_update.dart';

class _MockAppUpdateBloc extends MockBloc<AppUpdateEvent, AppUpdateState>
    implements AppUpdateBloc {}

void main() {
  group(UpdateBanner, () {
    late _MockAppUpdateBloc bloc;

    setUp(() {
      bloc = _MockAppUpdateBloc();
    });

    Widget buildSubject() {
      return MaterialApp(
        home: BlocProvider<AppUpdateBloc>.value(
          value: bloc,
          child: const Scaffold(body: UpdateBanner()),
        ),
      );
    }

    testWidgets('renders nothing when urgency is none', (tester) async {
      when(() => bloc.state).thenReturn(const AppUpdateState(
        status: AppUpdateStatus.resolved,
        urgency: UpdateUrgency.none,
      ));

      await tester.pumpWidget(buildSubject());

      expect(find.text(UpdateCopy.gentle),
          findsNothing);
    });

    testWidgets('renders banner when urgency is gentle', (tester) async {
      when(() => bloc.state).thenReturn(AppUpdateState(
        status: AppUpdateStatus.resolved,
        urgency: UpdateUrgency.gentle,
        downloadUrl: DownloadUrls.github,
      ));

      await tester.pumpWidget(buildSubject());

      expect(find.text(UpdateCopy.gentle),
          findsOneWidget);
    });

    testWidgets('dismiss button dispatches AppUpdateDismissed',
        (tester) async {
      when(() => bloc.state).thenReturn(AppUpdateState(
        status: AppUpdateStatus.resolved,
        urgency: UpdateUrgency.gentle,
        downloadUrl: DownloadUrls.github,
      ));

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byIcon(Icons.close));

      verify(() => bloc.add(const AppUpdateDismissed())).called(1);
    });

    testWidgets('renders nothing for moderate urgency', (tester) async {
      when(() => bloc.state).thenReturn(AppUpdateState(
        status: AppUpdateStatus.resolved,
        urgency: UpdateUrgency.moderate,
        downloadUrl: DownloadUrls.github,
      ));

      await tester.pumpWidget(buildSubject());

      expect(find.text(UpdateCopy.gentle),
          findsNothing);
    });
  });
}
```

- [ ] **Step 2: Write UpdateDialogListener test**

File: `mobile/test/app_update/view/update_dialog_test.dart`

```dart
import 'package:app_update_repository/app_update_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/app_update/app_update.dart';

class _MockAppUpdateBloc extends MockBloc<AppUpdateEvent, AppUpdateState>
    implements AppUpdateBloc {}

void main() {
  group(UpdateDialogListener, () {
    late _MockAppUpdateBloc bloc;

    setUp(() {
      bloc = _MockAppUpdateBloc();
    });

    Widget buildSubject() {
      return MaterialApp(
        home: BlocProvider<AppUpdateBloc>.value(
          value: bloc,
          child: const UpdateDialogListener(
            child: Scaffold(body: Text('Home')),
          ),
        ),
      );
    }

    testWidgets('shows dialog when urgency transitions to moderate',
        (tester) async {
      when(() => bloc.state).thenReturn(const AppUpdateState(
        status: AppUpdateStatus.resolved,
        urgency: UpdateUrgency.none,
      ));

      await tester.pumpWidget(buildSubject());

      // Simulate state change to moderate.
      whenListen(
        bloc,
        Stream.value(AppUpdateState(
          status: AppUpdateStatus.resolved,
          urgency: UpdateUrgency.moderate,
          latestVersion: '1.0.8',
          downloadUrl: DownloadUrls.github,
          releaseHighlights: const ['New feature'],
        )),
        initialState: const AppUpdateState(
          status: AppUpdateStatus.resolved,
          urgency: UpdateUrgency.none,
        ),
      );

      // Rebuild with new stream.
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.text("There's been an update since you last checked"),
        findsOneWidget,
      );
      expect(find.text('New feature'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('shows urgent copy when urgency is urgent', (tester) async {
      whenListen(
        bloc,
        Stream.value(AppUpdateState(
          status: AppUpdateStatus.resolved,
          urgency: UpdateUrgency.urgent,
          latestVersion: '1.0.9',
          downloadUrl: DownloadUrls.github,
          releaseHighlights: const ['Security fix'],
        )),
        initialState: const AppUpdateState(
          status: AppUpdateStatus.resolved,
          urgency: UpdateUrgency.none,
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.text("You're missing important fixes"),
        findsOneWidget,
      );
    });

    testWidgets('Not now button dispatches dismiss', (tester) async {
      whenListen(
        bloc,
        Stream.value(AppUpdateState(
          status: AppUpdateStatus.resolved,
          urgency: UpdateUrgency.moderate,
          latestVersion: '1.0.8',
          downloadUrl: DownloadUrls.github,
        )),
        initialState: const AppUpdateState(
          status: AppUpdateStatus.resolved,
          urgency: UpdateUrgency.none,
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));

      verify(() => bloc.add(const AppUpdateDismissed())).called(1);
    });
  });
}
```

- [ ] **Step 3: Run tests**

```bash
cd mobile && flutter test test/app_update/
```
Expected: All pass.

- [ ] **Step 4: Commit**

```bash
git add mobile/test/app_update/
git commit -m "test(update): add widget tests for banner and dialog"
```

---

## Chunk 6: Integration — Wire Into App

### Task 13: Wire AppUpdateBloc into main.dart and AppShell

**Files:**
- Modify: `mobile/lib/main.dart` (~line 1348, MultiBlocProvider)
- Modify: `mobile/lib/router/app_shell.dart` (~line 335, Scaffold body)
- Modify: `mobile/pubspec.yaml` (add app_update_repository and app_version_client to dependencies)

- [ ] **Step 1: Add packages to main app dependencies**

In `mobile/pubspec.yaml`, add under `dependencies:`:

```yaml
  app_version_client:
  app_update_repository:
```

Run: `cd mobile && flutter pub get`

- [ ] **Step 2: Create install source detection in main.dart**

Add a helper function near the top of main.dart (or in a separate file if preferred) that detects the install source at startup using platform channels. This will use `package_info_plus` for Android's installer package name and `dart:io` for platform detection.

The exact implementation depends on available platform APIs. For v1, a simple approach:

```dart
import 'dart:io';
import 'package:app_update_repository/app_update_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<InstallSource> detectInstallSource() async {
  if (Platform.isAndroid) {
    // On Android, we can check the installer package name.
    // package_info_plus doesn't expose this directly,
    // so for v1 we default to sideload and refine later.
    return InstallSource.sideload;
  }
  if (Platform.isIOS) {
    // For v1, default to App Store. TestFlight detection
    // requires receipt inspection (refine in v2).
    return InstallSource.appStore;
  }
  return InstallSource.sideload;
}
```

Note: Full installer detection (Android `getInstallerPackageName`, iOS receipt sandbox check) can be added in a follow-up task. The architecture supports it — the `InstallSource` is injected into the repository.

- [ ] **Step 3: Add AppUpdateBloc to MultiBlocProvider**

In `mobile/lib/main.dart`, add to the `MultiBlocProvider.providers` list (around line 1350):

```dart
BlocProvider(
  create: (_) {
    final packageInfo = /* already available from startup */;
    return AppUpdateBloc(
      repository: AppUpdateRepository(
        appVersionClient: AppVersionClient(),
        sharedPreferences: prefs, // already available from startup
        currentVersion: packageInfo.version,
        installSource: installSource, // detected at startup
      ),
    )..add(const AppUpdateCheckRequested());
  },
),
```

The exact wiring depends on how `PackageInfo` and `SharedPreferences` are available in the `_buildApp` method. Follow the existing pattern (e.g. how `EmailVerificationCubit` is created at line 1367).

- [ ] **Step 4: Add UpdateDialogListener to the listener chain**

In `main.dart`, wrap the existing `BlocListener<EmailVerificationCubit>` (around line 1376) with the `UpdateDialogListener`:

```dart
child: UpdateDialogListener(
  child: BlocListener<EmailVerificationCubit, EmailVerificationState>(
    // ... existing code
  ),
),
```

- [ ] **Step 5: Add UpdateBanner to AppShell**

In `mobile/lib/router/app_shell.dart`, modify the Scaffold body (around line 335) to include the banner below the content on the home tab:

```dart
return Scaffold(
  appBar: currentIndex == 0 || isInbox
      ? null
      : DiVineAppBar(/* ... */),
  body: Column(
    children: [
      Expanded(child: child),
      if (currentIndex == 0) const UpdateBanner(),
    ],
  ),
);
```

The banner only shows on the home tab (index 0) and only when the BLoC state has `urgency == gentle`.

- [ ] **Step 6: Run the full test suite**

```bash
cd mobile && flutter test
```
Expected: All existing tests still pass. New tests pass.

- [ ] **Step 7: Run flutter analyze**

```bash
cd mobile && flutter analyze lib test
```
Expected: No issues.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/ mobile/pubspec.yaml mobile/pubspec.lock
git commit -m "feat(update): wire AppUpdateBloc into app shell with banner and dialog"
```

---

### Task 14: Manual testing checklist

This is not automated — verify these manually before the PR.

- [ ] **Step 1: Verify banner appears**

Temporarily set `update_last_checked` to 25h ago in SharedPreferences (or clear app data), and point the client at a mock response with a version newer than the running app. Confirm the gentle banner appears at the bottom of the home feed.

- [ ] **Step 2: Verify dialog appears**

Same setup but with `published_at` set to 15+ days ago. Confirm the moderate dialog appears on launch.

- [ ] **Step 3: Verify dismiss behavior**

Dismiss the banner → confirm it doesn't reappear on next launch within the same version.
Dismiss the dialog → confirm it reappears after 3 days (simulate by adjusting SharedPreferences timestamp).

- [ ] **Step 4: Verify upgrade link**

Tap "Update" or the banner text → confirm it opens the correct URL (GitHub releases for sideload, Play Store deep-link for Play Store, etc.).

- [ ] **Step 5: Verify no impact on startup time**

The version check is fire-and-forget. Confirm the app doesn't block on startup waiting for the GitHub API response.

---

## Summary

| Task | What | Package/Location |
|------|------|-----------------|
| 1-3 | AppVersionClient (GitHub API, parsing) | `packages/app_version_client/` |
| 4-6 | AppUpdateRepository (version comparison, escalation) | `packages/app_update_repository/` |
| 7-8 | AppUpdateBloc (dismissal, caching, state) | `lib/app_update/bloc/` |
| 9 | Install source detection | `packages/app_update_repository/` |
| 10-12 | UI widgets (banner, dialog) + tests | `lib/app_update/view/` |
| 13 | Wire everything into main.dart + AppShell | `lib/main.dart`, `lib/router/app_shell.dart` |
| 14 | Manual testing | N/A |

## Deferred to Follow-Up

- **Store-native update APIs** (iOS `SKStoreProductViewController`, Android In-App Updates) — the spec calls for these as a secondary signal. The architecture supports it (just add another data source to the repository), but v1 uses only the GitHub API to keep scope small.
- **Full Android installer detection** — requires a platform channel to call `PackageManager.getInstallerPackageName()`. Task 13 stubs this with defaults. Follow-up task to add the platform channel.
- **iOS TestFlight detection** — requires receipt environment inspection. Stubbed as App Store for v1.
