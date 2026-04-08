# C2PA Verified Video Import Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to import externally-created videos (from Adobe Fresco, Premiere Pro, etc.) into diVine via the OS share sheet, gated by C2PA Content Credentials verification -- only verified human-made content is accepted.

**Architecture:** iOS Share Extension (native Swift) receives video files from the share sheet, saves them to an App Group shared container, and deep-links into the main Flutter app. The Flutter app validates the C2PA manifest, shows verification status, and on success creates a clip + draft in the library, landing the user on the metadata screen to publish. Android uses intent filters for the same flow with no extension needed.

**Tech Stack:** `share_handler` (Flutter package for receiving shared files), `c2pa_flutter` (Guardian Project's C2PA library, already in project), native iOS Share Extension (Swift), GoRouter deep linking, existing `ClipLibraryService`/`DraftStorageService` for persistence.

---

## Research Summary

### C2PA Ecosystem

The `c2pa_flutter` package (ref `0.0.3` from `guardianproject/c2pa-flutter`) already supports:
- **Reading manifests**: `C2pa.readManifestFromFile(path)` returns `ManifestStoreInfo` with validation status, claim generator, digital source type, signature info, and assertions
- **Performance**: Manifest reading parses JUMBF metadata boxes from the file header -- does NOT hash the entire file. Sub-second on mobile, even for 100MB+ videos
- **Digital source types available in enum** (`c2pa_flutter` `DigitalSourceType`):
  - `digitalCapture` -- camera recording (currently hardcoded in our signing)
  - `digitalCreation` -- human-made digital art (Adobe Fresco)
  - `trainedAlgorithmicMedia` -- AI-generated content
  - `compositeWithTrainedAlgorithmicMedia` -- human + AI composite
  - `composite`, `compositeCapture`, `compositeSynthetic` -- various composites
  - `humanEdits` -- human-edited content

### Adobe Integration

- **No SDK needed.** Adobe Fresco (iPad) and Premiere Pro use standard OS share sheets
- **Adobe Creative SDK was discontinued in 2020** -- no direct app-to-app API exists
- **Fresco exports MP4 with C2PA** using `digitalCreation` or `trainedAlgorithmicMedia` (when Firefly features are used)
- **Premiere Pro exports MP4 with C2PA** using `c2pa.edited` action assertion
- diVine registers as a share target for `video/mp4` -- appears in Fresco/Premiere's share sheet automatically

### iOS Share Extension Architecture

- **Approach**: Native Swift Share Extension (NOT Flutter engine in extension)
- **Why**: Flutter debug engine exceeds iOS's 120MB extension memory limit. Release mode uses 60-80MB leaving dangerously thin headroom. Native extension + App Group handoff is the standard, safe approach
- **Communication**: App Groups shared container. Extension writes file path + metadata to `UserDefaults(suiteName:)`, opens main app via `divine://` URL scheme (already registered)
- **Package**: `share_handler` v0.0.25 -- actively maintained, handles both iOS + Android, uses this exact native-extension-to-Flutter-app architecture

### Android Share Target

- Standard intent filter in `AndroidManifest.xml` -- no extension needed
- `share_handler` package handles this transparently
- No memory constraints to worry about

### Existing Publish Pipeline Entry Points

- **Clip creation**: `ClipLibraryService.saveClip(DivineVideoClip)` saves to clips table
- **Draft creation**: `DraftStorageService.saveDraft(DivineVideoDraft)` saves to drafts table
- **Thumbnail extraction**: `VideoThumbnailService.extractThumbnail(videoPath:)` returns `ThumbnailFileResult?`
- **Video metadata**: `ProVideoEditor.instance.getMetadata()` for duration/dimensions
- **Navigation**: `VideoMetadataScreen` at route `/video-metadata`, uses providers from context

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `lib/services/c2pa_import_validation_service.dart` | Reads C2PA manifest from imported file, classifies source type, returns structured result |
| `lib/services/video_import_service.dart` | Orchestrates import flow: copy file to app storage, extract thumbnail, create clip + draft |
| `lib/models/c2pa_import_result.dart` | Data class for C2PA validation results (status, source type, claim generator, etc.) |
| `lib/screens/import_verification/import_verification_page.dart` | Page (provides BLoC) + View (UI) for C2PA verification result |
| `lib/blocs/video_import/video_import_bloc.dart` | BLoC managing import state: receiving -> validating -> verified/rejected |
| `lib/blocs/video_import/video_import_event.dart` | Events: VideoReceived, ValidationCompleted |
| `lib/blocs/video_import/video_import_state.dart` | States: initial, validating, verified, rejected, error |
| `test/services/c2pa_import_validation_service_test.dart` | Unit tests for validation logic |
| `test/services/video_import_service_test.dart` | Unit tests for import orchestration |
| `test/models/c2pa_import_result_test.dart` | Unit tests for data model |
| `test/blocs/video_import/video_import_bloc_test.dart` | BLoC tests for state transitions |
| `test/screens/import_verification/import_verification_screen_test.dart` | Widget tests for verification UI |

### Modified Files

| File | Change |
|------|--------|
| `pubspec.yaml:133` | Add `share_handler` package alongside existing `share_plus` |
| `lib/router/app_router.dart` | Add route for `ImportVerificationScreen`, handle `divine://import` deep link |
| `lib/main.dart` | Initialize `share_handler` listener for incoming shared files |
| `lib/services/c2pa_signing_service.dart:91` | Accept `DigitalSourceType` parameter instead of hardcoding `digitalCapture` |
| `ios/Runner/Info.plist` | Add App Group capability reference |
| `android/app/src/main/AndroidManifest.xml` | Add `SEND` intent filter for `video/*` |

### New Native Files (iOS Share Extension)

| File | Responsibility |
|------|---------------|
| `ios/ShareExtension/ShareViewController.swift` | Native share extension: receive file, save to App Group, open main app |
| `ios/ShareExtension/Info.plist` | Extension configuration: activation rules, supported types |
| `ios/ShareExtension/ShareExtension.entitlements` | App Group entitlement |
| `ios/Runner/Runner.entitlements` | Add App Group entitlement to main app target |
| `codemagic.yaml` | Add Share Extension bundle identifier to iOS signing config |

### Platform Constants

| Constant | Value | Source |
|----------|-------|--------|
| App Group ID | `group.co.openvine.app` | `ios/Runner/Runner.entitlements` (existing) |
| Bundle ID (main) | `co.openvine.app` | `codemagic.yaml` |
| Bundle ID (share ext) | `co.openvine.app.ShareExtension` | New target |
| URL Scheme | `divine://` | `ios/Runner/Info.plist` (existing) |

### VineTheme Constants Reference

| Plan usage | Actual constant | Value |
|------------|----------------|-------|
| Background | `VineTheme.surfaceBackground` | `Color(0xFF00150D)` |
| Primary/accent | `VineTheme.primary` | `Color(0xFF27C58B)` |
| Body text | `VineTheme.lightText` | `Color(0xFF888888)` |
| Muted text | `VineTheme.onSurfaceMuted` | `Color(0x80FFFFFF)` |
| Font styles | `VineTheme.titleLargeFont()`, `VineTheme.bodyLargeFont()`, etc. | Factory methods |

### Testing Convention

This project uses `mocktail` (not `mockito`). All mocks use:
```dart
class _MockFoo extends Mock implements Foo {}
// with: when(() => mock.method(any())).thenAnswer(...)
```

Do NOT use `@GenerateMocks`, `mockito`, or codegen-based mocking.

### Design Decisions

- **Page/View pattern required**: All screens must split into a `Page` (provides BLoC via `BlocProvider`) and a `View` (marked `@visibleForTesting`, contains UI). See `ui_theming.md`.
- **Event transformers**: Use `droppable()` from `bloc_concurrency` on all async event handlers to prevent duplicate processing.
- **GoRouter navigation only**: Use `context.go()` / `context.pop()` -- never `Navigator.of(context).pop()`.
- **Route isolation**: Import verification route needs `parentNavigatorKey: NavigatorKeys.root` to render outside the tab shell.
- **Custom Share Extension + share_handler for Flutter-side listening**: The custom Swift Share Extension handles iOS file receipt and App Group handoff. `share_handler` is used ONLY on the Flutter/Android side for listening to shared media via intent filters. The custom extension replaces `share_handler`'s built-in iOS extension -- do NOT use both. On Android, `share_handler` handles everything.
- **Codemagic signing**: The current `codemagic.yaml` uses `bundle_identifier: $BUNDLE_ID` (single string). Since the recent revert (`ae7a8d3e6`) explicitly went back to a single string, do NOT change it to a list. Instead, use Codemagic's `BUNDLE_ID` env var with a wildcard provisioning profile (`co.openvine.app.*`) or add a separate `ios_signing` entry for the Share Extension target.

### Known Blockers to Resolve During Implementation

1. **VideoMetadataScreen draft loading**: The metadata screen currently loads draft data from providers populated during the recording flow. Imported videos bypass recording, so an alternative entry point is needed. Options:
   - Add `draftId` query parameter to the route and load from `DraftStorageService` on init
   - Create a dedicated `ImportMetadataScreen` that handles the import-specific flow
   - Use a shared Cubit at a higher scope that both flows write to
   The implementing engineer MUST resolve this before Task 10.

2. **Unauthenticated share**: If the user shares a video while not logged in, the router redirect will send them to the welcome screen and the shared file path will be lost. Consider saving the pending import path and resuming after auth.

3. **Large video files**: The Share Extension has ~120MB memory. Copying a 2GB 4K video inside the extension may fail. Consider using hard links or coordinated file access instead of copying.

---

## Chunk 1: C2PA Validation Foundation

### Task 1: C2PA Import Result Model

**Files:**
- Create: `lib/models/c2pa_import_result.dart`
- Test: `test/models/c2pa_import_result_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/models/c2pa_import_result_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/c2pa_import_result.dart';

void main() {
  group(C2paImportResult, () {
    group('factory constructors', () {
      test('creates verified result with all fields', () {
        final result = C2paImportResult.verified(
          claimGenerator: 'Adobe Fresco/5.0',
          digitalSourceType: C2paSourceClassification.humanCreated,
          digitalSourceTypeRaw: 'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCreation',
          signatureIssuer: 'Adobe Inc.',
          signedAt: DateTime.utc(2026, 4, 8),
          title: 'My Animation',
        );

        expect(result.status, equals(C2paImportStatus.verified));
        expect(result.claimGenerator, equals('Adobe Fresco/5.0'));
        expect(result.digitalSourceType, equals(C2paSourceClassification.humanCreated));
        expect(result.signatureIssuer, equals('Adobe Inc.'));
        expect(result.title, equals('My Animation'));
        expect(result.rejectionReason, isNull);
      });

      test('creates noCredentials result', () {
        final result = C2paImportResult.noCredentials();

        expect(result.status, equals(C2paImportStatus.noCredentials));
        expect(result.claimGenerator, isNull);
        expect(result.digitalSourceType, isNull);
      });

      test('creates aiGenerated result', () {
        final result = C2paImportResult.aiGenerated(
          claimGenerator: 'Adobe Photoshop/25.0',
          digitalSourceTypeRaw: 'http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia',
        );

        expect(result.status, equals(C2paImportStatus.aiGenerated));
        expect(result.claimGenerator, equals('Adobe Photoshop/25.0'));
        expect(result.digitalSourceType, equals(C2paSourceClassification.aiGenerated));
      });

      test('creates invalidSignature result', () {
        final result = C2paImportResult.invalidSignature();

        expect(result.status, equals(C2paImportStatus.invalidSignature));
      });

      test('creates error result with rejection reason', () {
        final result = C2paImportResult.error('corrupt file');

        expect(result.status, equals(C2paImportStatus.error));
        expect(result.rejectionReason, equals('corrupt file'));
      });
    });

    group('computed properties', () {
      test('isAccepted returns true only for verified status', () {
        expect(
          C2paImportResult.verified(
            claimGenerator: 'Test/1.0',
            digitalSourceType: C2paSourceClassification.humanCreated,
            digitalSourceTypeRaw: 'http://example.com',
          ).isAccepted,
          isTrue,
        );
        expect(C2paImportResult.noCredentials().isAccepted, isFalse);
        expect(C2paImportResult.aiGenerated().isAccepted, isFalse);
        expect(C2paImportResult.invalidSignature().isAccepted, isFalse);
        expect(C2paImportResult.error('test').isAccepted, isFalse);
      });

      test('sourceAppName extracts app name before slash', () {
        final result = C2paImportResult.verified(
          claimGenerator: 'Adobe Fresco/5.0',
          digitalSourceType: C2paSourceClassification.humanCreated,
          digitalSourceTypeRaw: 'http://example.com',
        );
        expect(result.sourceAppName, equals('Adobe Fresco'));
      });

      test('sourceAppName returns null when claimGenerator is null', () {
        expect(C2paImportResult.noCredentials().sourceAppName, isNull);
      });
    });
  });

  group(C2paSourceClassification, () {
    test('classifies human-created source types', () {
      expect(
        C2paSourceClassification.fromDigitalSourceTypeUrl(
          'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCapture',
        ),
        equals(C2paSourceClassification.humanCreated),
      );
      expect(
        C2paSourceClassification.fromDigitalSourceTypeUrl(
          'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCreation',
        ),
        equals(C2paSourceClassification.humanCreated),
      );
      expect(
        C2paSourceClassification.fromDigitalSourceTypeUrl(
          'http://cv.iptc.org/newscodes/digitalsourcetype/humanEdits',
        ),
        equals(C2paSourceClassification.humanCreated),
      );
    });

    test('classifies AI-generated source types', () {
      expect(
        C2paSourceClassification.fromDigitalSourceTypeUrl(
          'http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia',
        ),
        equals(C2paSourceClassification.aiGenerated),
      );
      expect(
        C2paSourceClassification.fromDigitalSourceTypeUrl(
          'http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicData',
        ),
        equals(C2paSourceClassification.aiGenerated),
      );
    });

    test('classifies composite source types', () {
      expect(
        C2paSourceClassification.fromDigitalSourceTypeUrl(
          'http://cv.iptc.org/newscodes/digitalsourcetype/compositeWithTrainedAlgorithmicMedia',
        ),
        equals(C2paSourceClassification.compositeWithAi),
      );
    });

    test('returns unknown for unrecognized URLs', () {
      expect(
        C2paSourceClassification.fromDigitalSourceTypeUrl(
          'http://example.com/unknown',
        ),
        equals(C2paSourceClassification.unknown),
      );
    });

    test('returns unknown for null URL', () {
      expect(
        C2paSourceClassification.fromDigitalSourceTypeUrl(null),
        equals(C2paSourceClassification.unknown),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target/mobile && flutter test test/models/c2pa_import_result_test.dart`
Expected: FAIL with compilation errors (classes don't exist yet)

- [ ] **Step 3: Write the model**

```dart
// lib/models/c2pa_import_result.dart
import 'package:equatable/equatable.dart';

/// Classification of a C2PA digital source type into categories
/// relevant to diVine's human-content-only policy.
enum C2paSourceClassification {
  /// Content created by a human (digitalCapture, digitalCreation, humanEdits,
  /// compositeCapture, screenCapture, virtualRecording, negativeFilm,
  /// positiveFilm, print)
  humanCreated,

  /// Content generated by AI/ML (trainedAlgorithmicMedia,
  /// trainedAlgorithmicData, algorithmicMedia)
  aiGenerated,

  /// Composite containing AI-generated elements
  /// (compositeWithTrainedAlgorithmicMedia, compositeSynthetic)
  compositeWithAi,

  /// Source type not recognized
  unknown;

  static const _humanSourceTypes = {
    'digitalCapture',
    'digitalCreation',
    'humanEdits',
    'compositeCapture',
    'screenCapture',
    'virtualRecording',
    'negativeFilm',
    'positiveFilm',
    'print',
    'composite',
    'dataDrivenMedia',
    'digitalArt',
  };

  static const _aiSourceTypes = {
    'trainedAlgorithmicMedia',
    'trainedAlgorithmicData',
    'algorithmicMedia',
    'algorithmicallyEnhanced',
  };

  static const _compositeAiSourceTypes = {
    'compositeWithTrainedAlgorithmicMedia',
    'compositeSynthetic',
  };

  /// Classifies an IPTC digital source type URL into a diVine-relevant
  /// category.
  ///
  /// URLs follow the pattern:
  /// `http://cv.iptc.org/newscodes/digitalsourcetype/<type>`
  static C2paSourceClassification fromDigitalSourceTypeUrl(String? url) {
    if (url == null) return unknown;
    final type = url.split('/').last;

    if (_humanSourceTypes.contains(type)) return humanCreated;
    if (_aiSourceTypes.contains(type)) return aiGenerated;
    if (_compositeAiSourceTypes.contains(type)) return compositeWithAi;
    return unknown;
  }
}

/// Status of C2PA import validation.
enum C2paImportStatus {
  /// Valid C2PA credentials with acceptable human-made source type.
  verified,

  /// No C2PA manifest found in the file.
  noCredentials,

  /// C2PA manifest present but source type indicates AI generation.
  aiGenerated,

  /// C2PA manifest present but signature validation failed.
  invalidSignature,

  /// Unexpected error during validation.
  error,
}

/// Result of validating a C2PA manifest on an imported video file.
class C2paImportResult extends Equatable {
  const C2paImportResult._({
    required this.status,
    this.claimGenerator,
    this.digitalSourceType,
    this.digitalSourceTypeRaw,
    this.signatureIssuer,
    this.signedAt,
    this.title,
    this.rejectionReason,
  });

  factory C2paImportResult.verified({
    required String claimGenerator,
    required C2paSourceClassification digitalSourceType,
    required String digitalSourceTypeRaw,
    String? signatureIssuer,
    DateTime? signedAt,
    String? title,
  }) {
    return C2paImportResult._(
      status: C2paImportStatus.verified,
      claimGenerator: claimGenerator,
      digitalSourceType: digitalSourceType,
      digitalSourceTypeRaw: digitalSourceTypeRaw,
      signatureIssuer: signatureIssuer,
      signedAt: signedAt,
      title: title,
    );
  }

  factory C2paImportResult.noCredentials() {
    return const C2paImportResult._(status: C2paImportStatus.noCredentials);
  }

  factory C2paImportResult.aiGenerated({
    String? claimGenerator,
    String? digitalSourceTypeRaw,
  }) {
    return C2paImportResult._(
      status: C2paImportStatus.aiGenerated,
      claimGenerator: claimGenerator,
      digitalSourceType: C2paSourceClassification.aiGenerated,
      digitalSourceTypeRaw: digitalSourceTypeRaw,
    );
  }

  factory C2paImportResult.invalidSignature() {
    return const C2paImportResult._(
      status: C2paImportStatus.invalidSignature,
    );
  }

  factory C2paImportResult.error(String reason) {
    return C2paImportResult._(
      status: C2paImportStatus.error,
      rejectionReason: reason,
    );
  }

  /// Overall validation status.
  final C2paImportStatus status;

  /// Software that created the content (e.g., "Adobe Fresco/5.0").
  final String? claimGenerator;

  /// Classified source type for diVine's policy decisions.
  final C2paSourceClassification? digitalSourceType;

  /// Raw IPTC digital source type URL from the manifest.
  final String? digitalSourceTypeRaw;

  /// Certificate issuer from the C2PA signature.
  final String? signatureIssuer;

  /// When the content was signed.
  final DateTime? signedAt;

  /// Title from the C2PA manifest (can pre-fill metadata form).
  final String? title;

  /// Human-readable reason for rejection (error status only).
  final String? rejectionReason;

  /// Whether this result allows publishing on diVine.
  bool get isAccepted => status == C2paImportStatus.verified;

  /// Human-readable label for the source application.
  String? get sourceAppName {
    if (claimGenerator == null) return null;
    final parts = claimGenerator!.split('/');
    return parts.first;
  }

  @override
  List<Object?> get props => [
    status,
    claimGenerator,
    digitalSourceType,
    digitalSourceTypeRaw,
    signatureIssuer,
    signedAt,
    title,
    rejectionReason,
  ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target/mobile && flutter test test/models/c2pa_import_result_test.dart`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target
git add mobile/lib/models/c2pa_import_result.dart mobile/test/models/c2pa_import_result_test.dart
git commit -m "feat: add C2PA import result model with source type classification"
```

---

### Task 2: C2PA Import Validation Service

**Files:**
- Create: `lib/services/c2pa_import_validation_service.dart`
- Test: `test/services/c2pa_import_validation_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/services/c2pa_import_validation_service_test.dart
import 'package:c2pa_flutter/c2pa.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/c2pa_import_result.dart';
import 'package:openvine/services/c2pa_import_validation_service.dart';
import 'package:openvine/services/c2pa_signing_service.dart';

class _MockC2paSigningService extends Mock implements C2paSigningService {}

void main() {
  late C2paImportValidationService service;
  late _MockC2paSigningService mockC2paSigningService;

  setUp(() {
    mockC2paSigningService = _MockC2paSigningService();
    service = C2paImportValidationService(
      c2paSigningService: mockC2paSigningService,
    );
  });

  group(C2paImportValidationService, () {
    group('validateFile', () {
      test('returns noCredentials when manifest is null', () async {
        when(() => mockC2paSigningService.readManifest(any()))
            .thenAnswer((_) async => null);

        final result = await service.validateFile('/path/to/video.mp4');

        expect(result.status, equals(C2paImportStatus.noCredentials));
      });

      test('returns verified for digitalCapture source type', () async {
        final manifestInfo = _buildManifestStoreInfo(
          claimGenerator: 'diVine/2.0',
          digitalSourceTypeUrl:
              'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCapture',
          validationStatus: ValidationStatus.valid,
          issuer: 'Guardian Project',
        );
        when(() => mockC2paSigningService.readManifest(any()))
            .thenAnswer((_) async => manifestInfo);

        final result = await service.validateFile('/path/to/video.mp4');

        expect(result.status, equals(C2paImportStatus.verified));
        expect(result.claimGenerator, equals('diVine/2.0'));
        expect(
          result.digitalSourceType,
          equals(C2paSourceClassification.humanCreated),
        );
        expect(result.signatureIssuer, equals('Guardian Project'));
      });

      test('returns verified for digitalCreation source type', () async {
        final manifestInfo = _buildManifestStoreInfo(
          claimGenerator: 'Adobe Fresco/5.0',
          digitalSourceTypeUrl:
              'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCreation',
          validationStatus: ValidationStatus.valid,
          issuer: 'Adobe Inc.',
          title: 'My Animation',
        );
        when(() => mockC2paSigningService.readManifest(any()))
            .thenAnswer((_) async => manifestInfo);

        final result = await service.validateFile('/path/to/video.mp4');

        expect(result.status, equals(C2paImportStatus.verified));
        expect(result.sourceAppName, equals('Adobe Fresco'));
        expect(result.title, equals('My Animation'));
      });

      test('returns aiGenerated for trainedAlgorithmicMedia', () async {
        final manifestInfo = _buildManifestStoreInfo(
          claimGenerator: 'Adobe Photoshop/25.0',
          digitalSourceTypeUrl:
              'http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia',
          validationStatus: ValidationStatus.valid,
        );
        when(() => mockC2paSigningService.readManifest(any()))
            .thenAnswer((_) async => manifestInfo);

        final result = await service.validateFile('/path/to/video.mp4');

        expect(result.status, equals(C2paImportStatus.aiGenerated));
      });

      test('returns aiGenerated for compositeWithTrainedAlgorithmicMedia',
          () async {
        final manifestInfo = _buildManifestStoreInfo(
          claimGenerator: 'Adobe Fresco/5.0',
          digitalSourceTypeUrl:
              'http://cv.iptc.org/newscodes/digitalsourcetype/compositeWithTrainedAlgorithmicMedia',
          validationStatus: ValidationStatus.valid,
        );
        when(() => mockC2paSigningService.readManifest(any()))
            .thenAnswer((_) async => manifestInfo);

        final result = await service.validateFile('/path/to/video.mp4');

        expect(result.status, equals(C2paImportStatus.aiGenerated));
      });

      test('returns invalidSignature when validation fails', () async {
        final manifestInfo = _buildManifestStoreInfo(
          claimGenerator: 'SomeApp/1.0',
          digitalSourceTypeUrl:
              'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCapture',
          validationStatus: ValidationStatus.invalid,
        );
        when(() => mockC2paSigningService.readManifest(any()))
            .thenAnswer((_) async => manifestInfo);

        final result = await service.validateFile('/path/to/video.mp4');

        expect(result.status, equals(C2paImportStatus.invalidSignature));
      });

      test('returns error when readManifest throws', () async {
        when(() => mockC2paSigningService.readManifest(any()))
            .thenThrow(Exception('corrupt file'));

        final result = await service.validateFile('/path/to/video.mp4');

        expect(result.status, equals(C2paImportStatus.error));
        expect(result.rejectionReason, contains('corrupt file'));
      });
    });
  });
}

/// Builds a ManifestStoreInfo for testing.
/// ManifestStoreInfo has a public const constructor in c2pa_flutter.
ManifestStoreInfo _buildManifestStoreInfo({
  required String claimGenerator,
  required String digitalSourceTypeUrl,
  required ValidationStatus validationStatus,
  String? issuer,
  String? title,
}) {
  const manifestLabel = 'test:manifest';
  return ManifestStoreInfo(
    activeManifest: manifestLabel,
    validationStatus: validationStatus,
    manifests: {
      manifestLabel: ManifestInfo(
        label: manifestLabel,
        claimGenerator: claimGenerator,
        title: title,
        signature: SignatureInfo(issuer: issuer),
        assertions: [
          AssertionInfo(
            label: 'c2pa.actions',
            data: {
              'actions': [
                {'digitalSourceType': digitalSourceTypeUrl},
              ],
            },
          ),
        ],
      ),
    },
  );
}
```

- [ ] **Step 3: Write the service**

```dart
// lib/services/c2pa_import_validation_service.dart
import 'package:c2pa_flutter/c2pa.dart';
import 'package:openvine/models/c2pa_import_result.dart';
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Validates C2PA Content Credentials on imported video files.
///
/// Used to gate video imports: only files with valid C2PA manifests
/// and human-made digital source types are accepted for publishing.
class C2paImportValidationService {
  C2paImportValidationService({required C2paSigningService c2paSigningService})
    : _c2paSigningService = c2paSigningService;

  final C2paSigningService _c2paSigningService;

  /// Validates a video file's C2PA manifest and returns a structured result.
  ///
  /// Returns [C2paImportResult.verified] if the file has valid Content
  /// Credentials with a human-made digital source type.
  Future<C2paImportResult> validateFile(String filePath) async {
    try {
      Log.info(
        'Validating C2PA manifest for import: $filePath',
        name: 'C2paImportValidationService',
        category: LogCategory.video,
      );

      final manifestStore = await _c2paSigningService.readManifest(filePath);

      if (manifestStore == null) {
        Log.info(
          'No C2PA manifest found in file',
          name: 'C2paImportValidationService',
          category: LogCategory.video,
        );
        return C2paImportResult.noCredentials();
      }

      // Check signature validation
      if (manifestStore.validationStatus == ValidationStatus.invalid) {
        Log.warning(
          'C2PA manifest has invalid signature',
          name: 'C2paImportValidationService',
          category: LogCategory.video,
        );
        return C2paImportResult.invalidSignature();
      }

      // Extract fields from active manifest
      final active = manifestStore.active;
      if (active == null) {
        return C2paImportResult.noCredentials();
      }

      final claimGenerator = active.claimGenerator ?? 'Unknown';
      final title = active.title;
      final issuer = active.signature?.issuer;
      final signedAt = active.signature?.signedAt;

      // Extract digital source type from c2pa.actions assertion
      final sourceTypeUrl = _extractDigitalSourceType(active.assertions);
      final classification =
          C2paSourceClassification.fromDigitalSourceTypeUrl(sourceTypeUrl);

      Log.info(
        'C2PA validation complete: generator=$claimGenerator, '
        'sourceType=$classification, issuer=$issuer',
        name: 'C2paImportValidationService',
        category: LogCategory.video,
      );

      // Reject AI-generated or composite-with-AI content
      if (classification == C2paSourceClassification.aiGenerated ||
          classification == C2paSourceClassification.compositeWithAi) {
        return C2paImportResult.aiGenerated(
          claimGenerator: claimGenerator,
          digitalSourceTypeRaw: sourceTypeUrl,
        );
      }

      return C2paImportResult.verified(
        claimGenerator: claimGenerator,
        digitalSourceType: classification,
        digitalSourceTypeRaw: sourceTypeUrl ?? '',
        signatureIssuer: issuer,
        signedAt: signedAt,
        title: title,
      );
    } catch (e, stackTrace) {
      Log.error(
        'C2PA import validation failed: $e',
        name: 'C2paImportValidationService',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return C2paImportResult.error(e.toString());
    }
  }

  /// Extracts the digitalSourceType URL from the c2pa.actions assertion.
  String? _extractDigitalSourceType(List<AssertionInfo> assertions) {
    for (final assertion in assertions) {
      if (assertion.label != 'c2pa.actions' &&
          assertion.label != 'c2pa.actions.v2') {
        continue;
      }
      final actions = assertion.data['actions'];
      if (actions is! List) continue;

      for (final action in actions) {
        if (action is! Map<String, dynamic>) continue;
        final sourceType = action['digitalSourceType'] as String?;
        if (sourceType != null) return sourceType;
      }
    }
    return null;
  }
}
```

- [ ] **Step 4: Run tests**

Run: `cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target/mobile && flutter test test/services/c2pa_import_validation_service_test.dart`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target
git add mobile/lib/services/c2pa_import_validation_service.dart mobile/test/services/c2pa_import_validation_service_test.dart
git commit -m "feat: add C2PA import validation service for verifying imported videos"
```

---

### Task 3: Parameterize DigitalSourceType in C2paSigningService

**Files:**
- Modify: `lib/services/c2pa_signing_service.dart:54-96`
- Modify: `test/services/c2pa_identity_manifest_service_test.dart` (existing tests should still pass)

- [ ] **Step 1: Add sourceType parameter to signVideo()**

In `lib/services/c2pa_signing_service.dart`, change the `signVideo` method signature (line 54) to accept an optional `DigitalSourceType`:

```dart
  Future<C2paSigningResult> signVideo({
    required String videoPath,
    DigitalSourceType sourceType = DigitalSourceType.digitalCapture,
    bool aiTrainingOptOut = true,
    NostrCreatorBindingAssertion? creatorBindingAssertion,
    Map<String, dynamic>? cawgIdentityAssertion,
    bool enableAdvancedCawgEmbedding = false,
  }) async {
```

And update line 91 to use the parameter:

```dart
        sourceType: sourceType,
```

- [ ] **Step 2: Run existing tests to verify nothing breaks**

Run: `cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target/mobile && flutter test test/services/c2pa_identity_manifest_service_test.dart test/services/c2pa_signing_service_test.dart`
Expected: ALL PASS (default value preserves existing behavior)

- [ ] **Step 3: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target
git add mobile/lib/services/c2pa_signing_service.dart
git commit -m "refactor: parameterize DigitalSourceType in C2paSigningService.signVideo"
```

---

## Chunk 2: Video Import BLoC and Service

### Task 4: Video Import BLoC

**Files:**
- Create: `lib/blocs/video_import/video_import_bloc.dart`
- Create: `lib/blocs/video_import/video_import_event.dart`
- Create: `lib/blocs/video_import/video_import_state.dart`
- Test: `test/blocs/video_import/video_import_bloc_test.dart`

- [ ] **Step 1: Write the state**

```dart
// lib/blocs/video_import/video_import_state.dart
part of 'video_import_bloc.dart';

enum VideoImportStatus {
  initial,
  validating,
  verified,
  rejected,
  importing,
  imported,
  error,
}

class VideoImportState extends Equatable {
  const VideoImportState({
    this.status = VideoImportStatus.initial,
    this.filePath,
    this.validationResult,
    this.draftId,
  });

  final VideoImportStatus status;
  final String? filePath;
  final C2paImportResult? validationResult;
  final String? draftId;

  VideoImportState copyWith({
    VideoImportStatus? status,
    String? filePath,
    C2paImportResult? validationResult,
    String? draftId,
  }) {
    return VideoImportState(
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      validationResult: validationResult ?? this.validationResult,
      draftId: draftId ?? this.draftId,
    );
  }

  @override
  List<Object?> get props => [status, filePath, validationResult, draftId];
}
```

- [ ] **Step 2: Write the events**

```dart
// lib/blocs/video_import/video_import_event.dart
part of 'video_import_bloc.dart';

sealed class VideoImportEvent extends Equatable {
  const VideoImportEvent();

  @override
  List<Object?> get props => [];
}

/// A video file was received from the OS share sheet.
final class VideoImportReceived extends VideoImportEvent {
  const VideoImportReceived({required this.filePath});

  final String filePath;

  @override
  List<Object?> get props => [filePath];
}

/// User confirmed they want to import a verified video.
final class VideoImportConfirmed extends VideoImportEvent {
  const VideoImportConfirmed();
}

/// User dismissed the import flow.
final class VideoImportDismissed extends VideoImportEvent {
  const VideoImportDismissed();
}
```

- [ ] **Step 3: Write the BLoC**

```dart
// lib/blocs/video_import/video_import_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/models/c2pa_import_result.dart';
import 'package:openvine/services/c2pa_import_validation_service.dart';
import 'package:openvine/services/video_import_service.dart';

part 'video_import_event.dart';
part 'video_import_state.dart';

class VideoImportBloc extends Bloc<VideoImportEvent, VideoImportState> {
  VideoImportBloc({
    required C2paImportValidationService validationService,
    required VideoImportService importService,
  }) : _validationService = validationService,
       _importService = importService,
       super(const VideoImportState()) {
    on<VideoImportReceived>(_onReceived, transformer: droppable());
    on<VideoImportConfirmed>(_onConfirmed, transformer: droppable());
    on<VideoImportDismissed>(_onDismissed);
  }

  final C2paImportValidationService _validationService;
  final VideoImportService _importService;

  Future<void> _onReceived(
    VideoImportReceived event,
    Emitter<VideoImportState> emit,
  ) async {
    emit(state.copyWith(
      status: VideoImportStatus.validating,
      filePath: event.filePath,
    ));

    final result = await _validationService.validateFile(event.filePath);

    if (result.isAccepted) {
      emit(state.copyWith(
        status: VideoImportStatus.verified,
        validationResult: result,
      ));
    } else {
      emit(state.copyWith(
        status: VideoImportStatus.rejected,
        validationResult: result,
      ));
    }
  }

  Future<void> _onConfirmed(
    VideoImportConfirmed event,
    Emitter<VideoImportState> emit,
  ) async {
    if (state.status != VideoImportStatus.verified ||
        state.filePath == null ||
        state.validationResult == null) {
      return;
    }

    emit(state.copyWith(status: VideoImportStatus.importing));

    try {
      final draftId = await _importService.importVerifiedVideo(
        filePath: state.filePath!,
        validationResult: state.validationResult!,
      );

      emit(state.copyWith(
        status: VideoImportStatus.imported,
        draftId: draftId,
      ));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: VideoImportStatus.error));
    }
  }

  void _onDismissed(
    VideoImportDismissed event,
    Emitter<VideoImportState> emit,
  ) {
    emit(const VideoImportState());
  }
}
```

- [ ] **Step 4: Write the BLoC tests**

```dart
// test/blocs/video_import/video_import_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_import/video_import_bloc.dart';
import 'package:openvine/models/c2pa_import_result.dart';
import 'package:openvine/services/c2pa_import_validation_service.dart';
import 'package:openvine/services/video_import_service.dart';

class _MockC2paImportValidationService extends Mock
    implements C2paImportValidationService {}

class _MockVideoImportService extends Mock implements VideoImportService {}

void main() {
  late _MockC2paImportValidationService mockValidationService;
  late _MockVideoImportService mockImportService;

  setUpAll(() {
    registerFallbackValue(C2paImportResult.noCredentials());
  });

  setUp(() {
    mockValidationService = _MockC2paImportValidationService();
    mockImportService = _MockVideoImportService();
  });

  VideoImportBloc buildBloc() => VideoImportBloc(
    validationService: mockValidationService,
    importService: mockImportService,
  );

  group(VideoImportBloc, () {
    group('VideoImportReceived', () {
      final verifiedResult = C2paImportResult.verified(
        claimGenerator: 'Adobe Fresco/5.0',
        digitalSourceType: C2paSourceClassification.humanCreated,
        digitalSourceTypeRaw:
            'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCreation',
        signatureIssuer: 'Adobe Inc.',
        title: 'My Animation',
      );

      blocTest<VideoImportBloc, VideoImportState>(
        'emits [validating, verified] when C2PA validation succeeds',
        setUp: () {
          when(() => mockValidationService.validateFile(any()))
              .thenAnswer((_) async => verifiedResult);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoImportReceived(filePath: '/path/to/video.mp4'),
        ),
        expect: () => [
          const VideoImportState(
            status: VideoImportStatus.validating,
            filePath: '/path/to/video.mp4',
          ),
          VideoImportState(
            status: VideoImportStatus.verified,
            filePath: '/path/to/video.mp4',
            validationResult: verifiedResult,
          ),
        ],
      );

      blocTest<VideoImportBloc, VideoImportState>(
        'emits [validating, rejected] when no C2PA credentials',
        setUp: () {
          when(() => mockValidationService.validateFile(any()))
              .thenAnswer((_) async => C2paImportResult.noCredentials());
        },
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoImportReceived(filePath: '/path/to/video.mp4'),
        ),
        expect: () => [
          const VideoImportState(
            status: VideoImportStatus.validating,
            filePath: '/path/to/video.mp4',
          ),
          VideoImportState(
            status: VideoImportStatus.rejected,
            filePath: '/path/to/video.mp4',
            validationResult: C2paImportResult.noCredentials(),
          ),
        ],
      );

      blocTest<VideoImportBloc, VideoImportState>(
        'emits [validating, rejected] when AI-generated',
        setUp: () {
          when(() => mockValidationService.validateFile(any())).thenAnswer(
            (_) async => C2paImportResult.aiGenerated(
              claimGenerator: 'Adobe Photoshop/25.0',
            ),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoImportReceived(filePath: '/path/to/video.mp4'),
        ),
        expect: () => [
          const VideoImportState(
            status: VideoImportStatus.validating,
            filePath: '/path/to/video.mp4',
          ),
          VideoImportState(
            status: VideoImportStatus.rejected,
            filePath: '/path/to/video.mp4',
            validationResult: C2paImportResult.aiGenerated(
              claimGenerator: 'Adobe Photoshop/25.0',
            ),
          ),
        ],
      );
    });

    group('VideoImportConfirmed', () {
      final verifiedResult = C2paImportResult.verified(
        claimGenerator: 'Adobe Fresco/5.0',
        digitalSourceType: C2paSourceClassification.humanCreated,
        digitalSourceTypeRaw:
            'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCreation',
      );

      blocTest<VideoImportBloc, VideoImportState>(
        'emits [importing, imported] when import succeeds',
        setUp: () {
          when(() => mockImportService.importVerifiedVideo(
            filePath: any(named: 'filePath'),
            validationResult: any(named: 'validationResult'),
          )).thenAnswer((_) async => 'draft-123');
        },
        build: buildBloc,
        seed: () => VideoImportState(
          status: VideoImportStatus.verified,
          filePath: '/path/to/video.mp4',
          validationResult: verifiedResult,
        ),
        act: (bloc) => bloc.add(const VideoImportConfirmed()),
        expect: () => [
          VideoImportState(
            status: VideoImportStatus.importing,
            filePath: '/path/to/video.mp4',
            validationResult: verifiedResult,
          ),
          VideoImportState(
            status: VideoImportStatus.imported,
            filePath: '/path/to/video.mp4',
            validationResult: verifiedResult,
            draftId: 'draft-123',
          ),
        ],
      );

      blocTest<VideoImportBloc, VideoImportState>(
        'does nothing when not in verified state',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoImportConfirmed()),
        expect: () => <VideoImportState>[],
      );

      blocTest<VideoImportBloc, VideoImportState>(
        'emits [importing, error] when import throws',
        setUp: () {
          when(() => mockImportService.importVerifiedVideo(
            filePath: any(named: 'filePath'),
            validationResult: any(named: 'validationResult'),
          )).thenThrow(Exception('disk full'));
        },
        build: buildBloc,
        seed: () => VideoImportState(
          status: VideoImportStatus.verified,
          filePath: '/path/to/video.mp4',
          validationResult: verifiedResult,
        ),
        act: (bloc) => bloc.add(const VideoImportConfirmed()),
        expect: () => [
          VideoImportState(
            status: VideoImportStatus.importing,
            filePath: '/path/to/video.mp4',
            validationResult: verifiedResult,
          ),
          VideoImportState(
            status: VideoImportStatus.error,
            filePath: '/path/to/video.mp4',
            validationResult: verifiedResult,
          ),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('VideoImportDismissed', () {
      blocTest<VideoImportBloc, VideoImportState>(
        'resets to initial state',
        build: buildBloc,
        seed: () => const VideoImportState(
          status: VideoImportStatus.rejected,
          filePath: '/path/to/video.mp4',
        ),
        act: (bloc) => bloc.add(const VideoImportDismissed()),
        expect: () => [const VideoImportState()],
      );
    });
  });
}
```

- [ ] **Step 5: Run tests**

Run: `cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target/mobile && flutter test test/blocs/video_import/video_import_bloc_test.dart`
Expected: ALL PASS

- [ ] **Step 6: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target
git add mobile/lib/blocs/video_import/ mobile/test/blocs/video_import/
git commit -m "feat: add VideoImportBloc for managing C2PA-gated import flow"
```

---

### Task 5: Video Import Service

**Files:**
- Create: `lib/services/video_import_service.dart`
- Test: `test/services/video_import_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/services/video_import_service_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/c2pa_import_result.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_import_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

void main() {
  late VideoImportService service;
  late _MockClipLibraryService mockClipLibraryService;
  late _MockDraftStorageService mockDraftStorageService;
  late Directory tempDir;

  setUpAll(() {
    registerFallbackValue(
      DivineVideoClip(
        id: '',
        video: EditorVideo.file('/dev/null'),
        duration: Duration.zero,
        recordedAt: DateTime(0),
        targetAspectRatio: model.AspectRatio.square,
        originalAspectRatio: 1,
      ),
    );
    registerFallbackValue(
      DivineVideoDraft.create(
        clips: const [],
        title: '',
        description: '',
        hashtags: const {},
        selectedApproach: '',
      ),
    );
  });

  setUp(() async {
    mockClipLibraryService = _MockClipLibraryService();
    mockDraftStorageService = _MockDraftStorageService();
    tempDir = await Directory.systemTemp.createTemp('import_test_');

    service = VideoImportService(
      clipLibraryService: mockClipLibraryService,
      draftStorageService: mockDraftStorageService,
      appDocumentsPath: tempDir.path,
    );

    when(() => mockClipLibraryService.saveClip(any())).thenAnswer((_) async {});
    when(() => mockDraftStorageService.saveDraft(any())).thenAnswer((_) async {});
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group(VideoImportService, () {
    group('importVerifiedVideo', () {
      test('copies file to app storage and creates draft', () async {
        // Create a temp video file to import
        final sourceFile = File('${tempDir.path}/source_video.mp4');
        sourceFile.writeAsBytesSync([0, 0, 0, 1]); // minimal content

        final result = C2paImportResult.verified(
          claimGenerator: 'Adobe Fresco/5.0',
          digitalSourceType: C2paSourceClassification.humanCreated,
          digitalSourceTypeRaw:
              'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCreation',
          title: 'My Animation',
        );

        final draftId = await service.importVerifiedVideo(
          filePath: sourceFile.path,
          validationResult: result,
        );

        expect(draftId, isNotEmpty);
        verify(() => mockClipLibraryService.saveClip(any())).called(1);
        verify(() => mockDraftStorageService.saveDraft(any())).called(1);
      });

      test('returns a non-empty draft ID', () async {
        final sourceFile = File('${tempDir.path}/source_video.mp4');
        sourceFile.writeAsBytesSync([0, 0, 0, 1]);

        final result = C2paImportResult.verified(
          claimGenerator: 'Adobe Fresco/5.0',
          digitalSourceType: C2paSourceClassification.humanCreated,
          digitalSourceTypeRaw:
              'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCreation',
        );

        final draftId = await service.importVerifiedVideo(
          filePath: sourceFile.path,
          validationResult: result,
        );

        expect(draftId, isNotNull);
        expect(draftId, isNotEmpty);
      });
    });
  });
}
```

- [ ] **Step 2: Write the service**

```dart
// lib/services/video_import_service.dart
import 'dart:io';

import 'package:models/models.dart' as model;
import 'package:openvine/models/c2pa_import_result.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:uuid/uuid.dart';

/// Orchestrates importing a C2PA-verified video into the diVine library.
///
/// Copies the shared file into app storage, extracts metadata
/// (thumbnail, duration, aspect ratio), creates a clip and draft,
/// and returns the draft ID for navigation to the metadata screen.
class VideoImportService {
  VideoImportService({
    required ClipLibraryService clipLibraryService,
    required DraftStorageService draftStorageService,
    required String appDocumentsPath,
  }) : _clipLibraryService = clipLibraryService,
       _draftStorageService = draftStorageService,
       _appDocumentsPath = appDocumentsPath;

  final ClipLibraryService _clipLibraryService;
  final DraftStorageService _draftStorageService;
  final String _appDocumentsPath;

  static const _uuid = Uuid();

  /// Imports a verified video file into the library.
  ///
  /// 1. Copies the file from the shared location to app storage
  /// 2. Extracts thumbnail and video metadata
  /// 3. Creates a [DivineVideoClip] and saves to clips library
  /// 4. Creates a [DivineVideoDraft] pre-populated with C2PA metadata
  /// 5. Returns the draft ID for navigation to the metadata screen
  Future<String> importVerifiedVideo({
    required String filePath,
    required C2paImportResult validationResult,
  }) async {
    Log.info(
      'Importing verified video: $filePath '
      '(from ${validationResult.sourceAppName})',
      name: 'VideoImportService',
      category: LogCategory.video,
    );

    // Copy file to app storage (shared files may be temporary)
    final clipId = _uuid.v4();
    final importDir = Directory('$_appDocumentsPath/imports');
    if (!importDir.existsSync()) {
      importDir.createSync(recursive: true);
    }
    final destPath = '${importDir.path}/$clipId.mp4';
    final sourceFile = File(filePath);
    await sourceFile.copy(destPath);

    // Extract thumbnail
    String? thumbnailPath;
    try {
      final thumbnailResult = await VideoThumbnailService.extractThumbnail(
        videoPath: destPath,
      );
      thumbnailPath = thumbnailResult?.path;
    } catch (e) {
      Log.warning(
        'Failed to extract thumbnail for import: $e',
        name: 'VideoImportService',
        category: LogCategory.video,
      );
    }

    // Extract video metadata (duration, dimensions)
    Duration duration = Duration.zero;
    double aspectRatio = 9 / 16; // default vertical
    try {
      final metadata = await ProVideoEditor.instance.getMetadata(destPath);
      if (metadata != null) {
        duration = metadata.duration ?? Duration.zero;
        if (metadata.width != null &&
            metadata.height != null &&
            metadata.height! > 0) {
          aspectRatio = metadata.width! / metadata.height!;
        }
      }
    } catch (e) {
      Log.warning(
        'Failed to extract video metadata for import: $e',
        name: 'VideoImportService',
        category: LogCategory.video,
      );
    }

    // Create clip
    final clip = DivineVideoClip(
      id: clipId,
      video: EditorVideo.file(destPath),
      duration: duration,
      recordedAt: DateTime.now(),
      targetAspectRatio: model.AspectRatio.square,
      originalAspectRatio: aspectRatio,
      thumbnailPath: thumbnailPath,
    );

    await _clipLibraryService.saveClip(clip);

    // Create draft pre-populated with C2PA metadata
    final draft = DivineVideoDraft.create(
      clips: [clip],
      title: validationResult.title ?? '',
      description: '',
      hashtags: const {},
      selectedApproach: '',
    );

    await _draftStorageService.saveDraft(draft);

    Log.info(
      'Video imported successfully: draftId=${draft.id}, clipId=$clipId',
      name: 'VideoImportService',
      category: LogCategory.video,
    );

    return draft.id;
  }
}
```

- [ ] **Step 3: Run tests**

Run: `cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target/mobile && flutter test test/services/video_import_service_test.dart`
Expected: ALL PASS

- [ ] **Step 4: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target
git add mobile/lib/services/video_import_service.dart mobile/test/services/video_import_service_test.dart
git commit -m "feat: add VideoImportService for importing C2PA-verified videos to library"
```

---

## Chunk 3: Import Verification UI

### Task 6: Import Verification Screen

**Files:**
- Create: `lib/screens/import_verification/import_verification_page.dart`
- Test: `test/screens/import_verification/import_verification_screen_test.dart`

This is a full-screen that shows one of three states:
1. **Validating** - spinner with "Verifying Content Credentials..."
2. **Verified** - success badge with source app name, "Continue to Publish" button
3. **Rejected** - education screen explaining why, with "Learn More" / "Close" buttons

- [ ] **Step 1: Write the widget test**

```dart
// test/screens/import_verification/import_verification_screen_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_import/video_import_bloc.dart';
import 'package:openvine/models/c2pa_import_result.dart';
import 'package:openvine/screens/import_verification/import_verification_page.dart';

class _MockVideoImportBloc
    extends MockBloc<VideoImportEvent, VideoImportState>
    implements VideoImportBloc {}

void main() {
  late _MockVideoImportBloc mockBloc;

  setUp(() {
    mockBloc = _MockVideoImportBloc();
  });

  Widget buildSubject() {
    return MaterialApp(
      home: BlocProvider<VideoImportBloc>.value(
        value: mockBloc,
        child: const ImportVerificationView(),
      ),
    );
  }

  group(ImportVerificationView, () {
    testWidgets('shows loading indicator when validating', (tester) async {
      when(() => mockBloc.state).thenReturn(
        const VideoImportState(status: VideoImportStatus.validating),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Verifying Content Credentials...'), findsOneWidget);
    });

    testWidgets('shows verified badge when verification succeeds',
        (tester) async {
      when(() => mockBloc.state).thenReturn(
        VideoImportState(
          status: VideoImportStatus.verified,
          validationResult: C2paImportResult.verified(
            claimGenerator: 'Adobe Fresco/5.0',
            digitalSourceType: C2paSourceClassification.humanCreated,
            digitalSourceTypeRaw:
                'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCreation',
            signatureIssuer: 'Adobe Inc.',
          ),
        ),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.text('Content Credentials Verified'), findsOneWidget);
      expect(find.textContaining('Adobe Fresco'), findsOneWidget);
      expect(find.text('Continue to Publish'), findsOneWidget);
    });

    testWidgets('shows education screen when no credentials', (tester) async {
      when(() => mockBloc.state).thenReturn(
        VideoImportState(
          status: VideoImportStatus.rejected,
          validationResult: C2paImportResult.noCredentials(),
        ),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.text('No Content Credentials'), findsOneWidget);
      expect(
        find.textContaining('verified human-made content'),
        findsOneWidget,
      );
    });

    testWidgets('shows AI rejection when AI-generated', (tester) async {
      when(() => mockBloc.state).thenReturn(
        VideoImportState(
          status: VideoImportStatus.rejected,
          validationResult: C2paImportResult.aiGenerated(
            claimGenerator: 'Adobe Photoshop/25.0',
          ),
        ),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.textContaining('AI-generated'), findsOneWidget);
    });

    testWidgets('dispatches VideoImportConfirmed on continue tap',
        (tester) async {
      when(() => mockBloc.state).thenReturn(
        VideoImportState(
          status: VideoImportStatus.verified,
          validationResult: C2paImportResult.verified(
            claimGenerator: 'Adobe Fresco/5.0',
            digitalSourceType: C2paSourceClassification.humanCreated,
            digitalSourceTypeRaw:
                'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCreation',
          ),
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Continue to Publish'));

      verify(() => mockBloc.add(const VideoImportConfirmed())).called(1);
    });
  });
}
```

- [ ] **Step 2: Write the screen**

```dart
// lib/screens/import_verification/import_verification_page.dart
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:meta/meta.dart';
import 'package:openvine/blocs/video_import/video_import_bloc.dart';
import 'package:openvine/models/c2pa_import_result.dart';
import 'package:openvine/services/c2pa_import_validation_service.dart';
import 'package:openvine/services/video_import_service.dart';

/// Page: provides BLoC dependencies for the import verification flow.
class ImportVerificationPage extends StatelessWidget {
  const ImportVerificationPage({super.key, required this.filePath});

  final String filePath;

  static const routeName = 'import-verification';
  static const path = '/import-verification';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => VideoImportBloc(
        validationService:
            context.read<C2paImportValidationService>(),
        importService: context.read<VideoImportService>(),
      )..add(VideoImportReceived(filePath: filePath)),
      child: const ImportVerificationView(),
    );
  }
}

/// View: UI implementation for import verification.
@visibleForTesting
class ImportVerificationView extends StatelessWidget {
  const ImportVerificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      body: SafeArea(
        child: BlocListener<VideoImportBloc, VideoImportState>(
          listenWhen: (prev, curr) =>
              curr.status == VideoImportStatus.imported,
          listener: (context, state) {
            // Navigate to metadata screen with draft ID.
            // The implementing engineer must resolve how
            // VideoMetadataScreen loads a draft by ID.
            // See "Known Blockers" in plan header.
            context.go(
              '/video-metadata?draftId=${state.draftId}',
            );
          },
          child: BlocBuilder<VideoImportBloc, VideoImportState>(
            builder: (context, state) {
              return switch (state.status) {
                VideoImportStatus.initial ||
                VideoImportStatus.validating =>
                    const _ValidatingView(),
                VideoImportStatus.verified => _VerifiedView(
                  result: state.validationResult!,
                ),
                VideoImportStatus.rejected => _RejectedView(
                  result: state.validationResult!,
                ),
                VideoImportStatus.importing =>
                    const _ImportingView(),
                VideoImportStatus.imported =>
                    const _ImportingView(),
                VideoImportStatus.error => _RejectedView(
                  result: state.validationResult ??
                      C2paImportResult.error('Unknown error'),
                ),
              };
            },
          ),
        ),
      ),
    );
  }
}

class _ValidatingView extends StatelessWidget {
  const _ValidatingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 24,
        children: [
          const CircularProgressIndicator(
            color: VineTheme.primary,
          ),
          Text(
            'Verifying Content Credentials...',
            style: VineTheme.bodyLargeFont(
              color: VineTheme.lightText,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedView extends StatelessWidget {
  const _VerifiedView({required this.result});

  final C2paImportResult result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.verified,
            color: VineTheme.primary,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Content Credentials Verified',
            style: VineTheme.titleLargeFont(
              color: VineTheme.lightText,
            ),
          ),
          const SizedBox(height: 12),
          if (result.sourceAppName != null)
            Text(
              'Created in ${result.sourceAppName}',
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceMuted,
              ),
            ),
          if (result.signatureIssuer != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Signed by ${result.signatureIssuer}',
                style: VineTheme.bodyMediumFont(
                  color: VineTheme.onSurfaceMuted,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            _sourceTypeLabel(result.digitalSourceType),
            style: VineTheme.bodyMediumFont(
              color: VineTheme.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                context
                    .read<VideoImportBloc>()
                    .add(const VideoImportConfirmed());
              },
              child: const Text('Continue to Publish'),
            ),
          ),
        ],
      ),
    );
  }

  static String _sourceTypeLabel(
    C2paSourceClassification? type,
  ) {
    return switch (type) {
      C2paSourceClassification.humanCreated =>
          'Human-made content',
      _ => 'Verified content',
    };
  }
}

class _RejectedView extends StatelessWidget {
  const _RejectedView({required this.result});

  final C2paImportResult result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            result.status == C2paImportStatus.aiGenerated
                ? Icons.smart_toy
                : Icons.shield_outlined,
            color: VineTheme.onSurfaceMuted,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            result.status == C2paImportStatus.aiGenerated
                ? 'AI-Generated Content Detected'
                : 'No Content Credentials',
            style: VineTheme.titleLargeFont(
              color: VineTheme.lightText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            result.status == C2paImportStatus.aiGenerated
                ? 'This video is marked as AI-generated. '
                  'diVine is a platform for verified '
                  'human-made content.'
                : 'diVine is a platform for verified '
                  'human-made content. We use C2PA Content '
                  'Credentials to verify that videos were '
                  'made by real people.',
            textAlign: TextAlign.center,
            style: VineTheme.bodyMediumFont(
              color: VineTheme.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Create with apps that support\n'
            'Content Credentials:',
            textAlign: TextAlign.center,
            style: VineTheme.bodyMediumFont(
              color: VineTheme.lightText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Adobe Fresco  \u2022  Adobe Premiere Pro\n'
            'Or record directly in diVine',
            textAlign: TextAlign.center,
            style: VineTheme.bodyMediumFont(
              color: VineTheme.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                context
                    .read<VideoImportBloc>()
                    .add(const VideoImportDismissed());
                context.go('/');
              },
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportingView extends StatelessWidget {
  const _ImportingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 24,
        children: [
          const CircularProgressIndicator(
            color: VineTheme.primary,
          ),
          Text(
            'Importing to your library...',
            style: VineTheme.bodyLargeFont(
              color: VineTheme.lightText,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Run widget tests**

Run: `cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target/mobile && flutter test test/screens/import_verification/import_verification_screen_test.dart`
Expected: ALL PASS

- [ ] **Step 4: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target
git add mobile/lib/screens/import_verification/ mobile/test/screens/import_verification/
git commit -m "feat: add import verification screen with C2PA status display"
```

---

## Chunk 4: Platform Integration (iOS Share Extension + Android Intent Filter)

### Task 7: iOS Share Extension

**Files:**
- Create: `ios/ShareExtension/ShareViewController.swift`
- Create: `ios/ShareExtension/Info.plist`
- Create: `ios/ShareExtension/ShareExtension.entitlements`
- Modify: `ios/Runner/Runner.entitlements` (add App Group)

**Important:** This task requires Xcode for adding the Share Extension target. The files below are the content, but the target must be added via Xcode: File > New > Target > Share Extension.

- [ ] **Step 1: Add Share Extension target in Xcode**

Open `ios/Runner.xcworkspace` in Xcode. File > New > Target > Share Extension. Name it `ShareExtension`. Set the App Group to `group.co.openvine.app`.

- [ ] **Step 2: Configure App Group entitlements**

Add `group.co.openvine.app` to both the Runner and ShareExtension entitlements. The implementing engineer should check the existing bundle identifier in the project to use the correct App Group name.

```xml
<!-- ios/ShareExtension/ShareExtension.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.co.openvine.app</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 3: Write the ShareViewController**

```swift
// ios/ShareExtension/ShareViewController.swift
import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    private let appGroupId = "group.co.openvine.app"
    private let sharedKey = "SharedVideoPath"
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleSharedVideo()
    }
    
    private func handleSharedVideo() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            close()
            return
        }
        
        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.movie.identifier) { [weak self] item, error in
                        guard let url = item as? URL else {
                            self?.close()
                            return
                        }
                        self?.saveAndOpenApp(videoUrl: url)
                    }
                    return
                }
                
                if provider.hasItemConformingToTypeIdentifier(UTType.mpeg4Movie.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.mpeg4Movie.identifier) { [weak self] item, error in
                        guard let url = item as? URL else {
                            self?.close()
                            return
                        }
                        self?.saveAndOpenApp(videoUrl: url)
                    }
                    return
                }
            }
        }
        
        close()
    }
    
    private func saveAndOpenApp(videoUrl: URL) {
        guard let containerUrl = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            close()
            return
        }
        
        // Copy video to shared container
        let sharedDir = containerUrl.appendingPathComponent("shared_imports", isDirectory: true)
        try? FileManager.default.createDirectory(at: sharedDir, withIntermediateDirectories: true)
        
        let fileName = "\(UUID().uuidString).mp4"
        let destUrl = sharedDir.appendingPathComponent(fileName)
        
        do {
            try FileManager.default.copyItem(at: videoUrl, to: destUrl)
        } catch {
            close()
            return
        }
        
        // Save path to UserDefaults for the main app to read
        let userDefaults = UserDefaults(suiteName: appGroupId)
        userDefaults?.set(destUrl.path, forKey: sharedKey)
        userDefaults?.synchronize()
        
        // Open main app via URL scheme
        let urlString = "divine://import?path=\(destUrl.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        DispatchQueue.main.async { [weak self] in
            guard let url = URL(string: urlString) else {
                self?.close()
                return
            }
            
            // iOS 18+ share extensions can open URLs via responder chain
            self?.openURL(url)
            self?.close()
        }
    }
    
    @objc private func openURL(_ url: URL) {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = responder?.next
        }
        
        // Fallback: use selector-based approach
        let selector = sel_registerName("openURL:")
        var ancestor = self as UIResponder?
        while let r = ancestor {
            if r.responds(to: selector) {
                r.perform(selector, with: url)
                return
            }
            ancestor = r.next
        }
    }
    
    private func close() {
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
```

- [ ] **Step 4: Configure Share Extension Info.plist**

```xml
<!-- ios/ShareExtension/Info.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.share-services</string>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>NSExtensionActivationRule</key>
            <dict>
                <key>NSExtensionActivationSupportsMovieWithMaxCount</key>
                <integer>1</integer>
            </dict>
        </dict>
    </dict>
    <key>CFBundleDisplayName</key>
    <string>diVine</string>
</dict>
</plist>
```

- [ ] **Step 5: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target
git add mobile/ios/ShareExtension/ mobile/ios/Runner/Runner.entitlements
git commit -m "feat: add iOS Share Extension for receiving video files"
```

---

### Task 8: Android Intent Filter

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add intent filter for video sharing**

In `android/app/src/main/AndroidManifest.xml`, add the following intent filter inside the `<activity>` tag for `MainActivity` (after the existing deep link intent filters around line 139):

```xml
<!-- Share target: receive video files from other apps -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="video/*" />
</intent-filter>
```

- [ ] **Step 2: Build to verify no manifest errors**

Run: `cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target/mobile && flutter build apk --debug 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target
git add mobile/android/app/src/main/AndroidManifest.xml
git commit -m "feat: add Android intent filter for receiving shared video files"
```

---

### Task 9: Share Handler Package Integration

**Files:**
- Modify: `pubspec.yaml:133` (add `share_handler`)
- Modify: `lib/main.dart` (initialize share listener)
- Modify: `lib/router/app_router.dart` (add import route + deep link handling)

- [ ] **Step 1: Add share_handler to pubspec.yaml**

After line 133 (`share_plus: ^12.0.0`), add:

```yaml
  share_handler: ^0.0.25 # Receive shared files from other apps
```

Run: `cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target/mobile && flutter pub get`

- [ ] **Step 2: Add import verification route to app_router.dart**

Add the route for `ImportVerificationScreen` in `app_router.dart`. The exact insertion point depends on the existing route structure -- add it as a top-level route (not inside the shell route / tab navigation):

```dart
GoRoute(
  path: ImportVerificationPage.path,
  name: ImportVerificationPage.routeName,
  parentNavigatorKey: NavigatorKeys.root,
  builder: (context, state) {
    final filePath =
        state.uri.queryParameters['path'] ?? '';
    return ImportVerificationPage(filePath: filePath);
  },
),
```

- [ ] **Step 3: Handle deep link from share extension**

In the GoRouter's `redirect` function, handle the `divine://import` deep link by routing to the import verification screen. The implementing engineer should check how the existing `divine://` URL scheme is handled and extend it.

- [ ] **Step 4: Initialize share handler listener in main.dart**

Add share handler initialization after the app starts. When a shared file is received while the app is running or triggers a cold start, navigate to the import verification screen:

```dart
// In the app initialization (after GoRouter is available)
final handler = ShareHandlerPlatform.instance;

// Handle shared media when app is opened from share
handler.getInitialSharedMedia().then((media) {
  if (media?.attachments?.isNotEmpty ?? false) {
    final path = media!.attachments!.first.path;
    if (path != null) {
      router.go('${ImportVerificationPage.path}?path=$path');
    }
  }
});

// Handle shared media while app is running
handler.sharedMediaStream.listen((media) {
  if (media.attachments?.isNotEmpty ?? false) {
    final path = media.attachments!.first.path;
    if (path != null) {
      router.go('${ImportVerificationPage.path}?path=$path');
    }
  }
});
```

- [ ] **Step 5: Run flutter analyze to verify no errors**

Run: `cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target/mobile && flutter analyze lib/main.dart lib/router/app_router.dart`
Expected: No issues found

- [ ] **Step 6: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target
git add mobile/pubspec.yaml mobile/pubspec.lock mobile/lib/main.dart mobile/lib/router/app_router.dart
git commit -m "feat: integrate share_handler for receiving shared video files"
```

---

## Chunk 5: Navigation and End-to-End Wiring

### Task 10: (Merged into Task 6)

The `BlocListener` for post-import navigation is now built into `ImportVerificationView` directly. See the `BlocListener` wrapping the `BlocBuilder` in Task 6's screen code.

---

### Task 11: Service Registration (Dependency Injection)

**Files:**
- Modify: Wherever services are registered (check for `RepositoryProvider`, `MultiRepositoryProvider`, or service locator pattern in the app)

- [ ] **Step 1: Find service registration location**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target/mobile
grep -rn 'RepositoryProvider\|MultiRepositoryProvider\|GetIt\|get_it\|serviceLocator' lib/main.dart lib/app*.dart --include='*.dart' | head -20
```

- [ ] **Step 2: Register new services**

Register `C2paImportValidationService` and `VideoImportService` in the service provider tree so they're available to the `VideoImportBloc`:

```dart
RepositoryProvider(
  create: (context) => C2paImportValidationService(
    c2paSigningService: context.read<C2paSigningService>(),
  ),
),
RepositoryProvider(
  create: (context) => VideoImportService(
    clipLibraryService: context.read<ClipLibraryService>(),
    draftStorageService: context.read<DraftStorageService>(),
    appDocumentsPath: appDocumentsPath,
  ),
),
```

- [ ] **Step 3: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target
git add mobile/lib/main.dart mobile/lib/router/app_router.dart mobile/pubspec.yaml mobile/pubspec.lock
git commit -m "feat: register C2PA import services and wire share handler"
```

---

### Task 12: End-to-End Smoke Test

- [ ] **Step 1: Build and run on iOS simulator**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target/mobile
flutter run --debug -d 'iPhone'
```

- [ ] **Step 2: Test share flow**

1. Open Photos app on simulator
2. Select a video, tap Share
3. Verify diVine appears in the share sheet
4. Tap diVine
5. Verify the import verification screen appears
6. Verify C2PA validation runs (most simulator videos won't have C2PA, so expect the education/rejected screen)

- [ ] **Step 3: Test with C2PA-signed video**

If a C2PA-signed test video is available (from Adobe Fresco or created with `c2patool`):
1. Add it to the simulator's Photos library
2. Share it to diVine
3. Verify the "Verified" screen appears with correct source app name
4. Tap "Continue to Publish"
5. Verify navigation to metadata screen with draft pre-populated

- [ ] **Step 4: Run full test suite**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target/mobile
flutter test
```
Expected: ALL PASS

- [ ] **Step 5: Final commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/feat-c2pa-share-target
git add mobile/lib/ mobile/test/ mobile/ios/ShareExtension/ mobile/android/app/src/main/AndroidManifest.xml
git commit -m "feat: complete C2PA-verified video import via share sheet"
```

---

## Remaining Open Questions

1. **VideoMetadataScreen draft loading** (BLOCKING): The metadata screen currently relies on providers populated during the recording flow. An alternative entry point that loads a draft by ID from `DraftStorageService` is needed. See "Known Blockers" section above.

2. **Codemagic CI**: A wildcard provisioning profile (`co.openvine.app.*`) or separate signing entry is needed for the Share Extension bundle ID (`co.openvine.app.ShareExtension`). Do NOT change `bundle_identifier` back to a list format (recently reverted). A new provisioning profile must be created in Apple Developer Portal.

4. **ProVideoEditor metadata API**: Verify `ProVideoEditor.instance.getMetadata(path)` is the correct API for extracting video duration and dimensions from the `pro_video_editor` package.

5. **Large file handling in Share Extension**: The extension has ~120MB memory. Copying a large 4K video inside the extension may fail. Consider using hard links (`link()` instead of `copyItem()`) or coordinated file access.

### Resolved During Review (No Longer Open)

- ~~ManifestStoreInfo construction~~: Has public const constructor. Test helper implemented.
- ~~App Group identifier~~: Confirmed as `group.co.openvine.app` from existing entitlements.
- ~~VineTheme constants~~: Corrected to `surfaceBackground`, `primary`, `lightText`, `onSurfaceMuted`.
- ~~share_handler vs custom extension~~: Custom Swift extension for iOS, share_handler for Flutter/Android listening only. See Design Decisions.
- ~~DivineVideoClip.empty()~~: Tests use real constructors with minimal values for `registerFallbackValue`.
