# Bug Report Image Attachments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add image attachment support (up to 3 gallery images) to the mobile in-app bug report dialog, uploading them as Zendesk ticket attachments via the native SDK.

**Architecture:** New `ImageAttachmentPicker` widget handles selection/preview/removal. `BugReportDialog` hosts it and passes file paths through `ZendeskSupportService.createStructuredBugReport()` → `createTicket()` → native platform channel. Native iOS (Swift) and Android (Kotlin) handlers upload files via `ZDKUploadProvider`/`UploadProvider` before attaching tokens to the `CreateRequest`. Desktop hides the picker entirely.

**Tech Stack:** Flutter (Dart), `image_picker` ^1.2.0 (already in pubspec), ZendeskSupportSDK ~9.0 (iOS), com.zendesk:support:5.1.2 (Android), platform channels via `MethodChannel('com.openvine/zendesk_support')`.

**Spec:** `docs/superpowers/specs/2026-04-23-bug-report-image-attachments-design.md`

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `mobile/lib/widgets/image_attachment_picker.dart` | Stateful widget: gallery picker, thumbnail previews, remove buttons, platform guard |
| Create | `mobile/test/widgets/image_attachment_picker_test.dart` | Widget tests for picker behavior |
| Modify | `mobile/lib/l10n/app_en.arb` | Add 4 ARB keys for picker strings |
| Modify | `mobile/lib/widgets/bug_report_dialog.dart` | Host picker, pass attachment paths to service |
| Modify | `mobile/test/widgets/bug_report_dialog_test.dart` | Test attachment passthrough and zero-attachment regression |
| Modify | `mobile/lib/services/zendesk_support_service.dart` | Add `attachmentPaths` param to `createStructuredBugReport()` and `createTicket()` |
| Modify | `mobile/test/services/zendesk_support_service_test.dart` | Test platform channel includes/omits `attachmentPaths` |
| Modify | `mobile/ios/Runner/AppDelegate.swift` | Upload files via `ZDKUploadProvider`, attach tokens to `ZDKCreateRequest` |
| Modify | `mobile/android/app/src/main/kotlin/co/openvine/app/MainActivity.kt` | Upload files via `UploadProvider`, attach tokens to `CreateRequest` |

---

## Task 1: Add Localization Keys

**Files:**
- Modify: `mobile/lib/l10n/app_en.arb` (append before closing `}`)

- [ ] **Step 1: Add ARB keys**

Open `mobile/lib/l10n/app_en.arb`. Before the final closing `}`, add a comma after the last entry and append:

```json
  "bugReportAttachImages": "Attach images",
  "@bugReportAttachImages": {
    "description": "Tooltip and semantics label for the add-images button in bug report dialog"
  },
  "bugReportRemoveImage": "Remove image",
  "@bugReportRemoveImage": {
    "description": "Semantics label for the remove button on an attached image thumbnail"
  },
  "bugReportImagesCount": "{count} of {max} images",
  "@bugReportImagesCount": {
    "placeholders": {
      "count": { "type": "int" },
      "max": { "type": "int" }
    },
    "description": "Screen reader announcement after adding or removing an image attachment"
  },
  "bugReportUploadFailed": "Image upload failed. Please try again.",
  "@bugReportUploadFailed": {
    "description": "Error message when image attachment upload fails during bug report submission"
  }
```

- [ ] **Step 2: Generate l10n code**

Run from `mobile/`:

```bash
flutter gen-l10n
```

Expected: no errors, files regenerated under `mobile/lib/l10n/generated/`.

- [ ] **Step 3: Verify the keys are accessible**

Run from `mobile/`:

```bash
grep 'bugReportAttachImages\|bugReportRemoveImage\|bugReportImagesCount\|bugReportUploadFailed' lib/l10n/generated/app_localizations_en.dart
```

Expected: 4 getter methods visible.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/generated/
git commit -m "feat(l10n): add ARB keys for bug report image attachments"
```

---

## Task 2: Create ImageAttachmentPicker Widget

**Files:**
- Create: `mobile/lib/widgets/image_attachment_picker.dart`

- [ ] **Step 1: Create the widget file**

Create `mobile/lib/widgets/image_attachment_picker.dart`:

```dart
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/l10n/l10n.dart';

class ImageAttachmentPicker extends StatefulWidget {
  const ImageAttachmentPicker({
    required this.onChanged,
    super.key,
    this.maxImages = 3,
    this.enabled = true,
  });

  final int maxImages;
  final ValueChanged<List<XFile>> onChanged;
  final bool enabled;

  @override
  State<ImageAttachmentPicker> createState() => _ImageAttachmentPickerState();
}

class _ImageAttachmentPickerState extends State<ImageAttachmentPicker> {
  final List<XFile> _images = [];

  @visibleForTesting
  static ImagePicker imagePicker = ImagePicker();

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  Future<void> _pickImages() async {
    if (!widget.enabled) return;

    final remaining = widget.maxImages - _images.length;
    if (remaining <= 0) return;

    final picked = await imagePicker.pickMultiImage(
      maxWidth: 1920,
      imageQuality: 80,
    );

    if (picked.isEmpty) return;

    setState(() {
      final toAdd = picked.take(remaining).toList();
      _images.addAll(toAdd);
    });
    widget.onChanged(List.unmodifiable(_images));

    if (mounted) {
      SemanticsService.announce(
        context.l10n.bugReportImagesCount(_images.length, widget.maxImages),
        TextDirection.ltr,
      );
    }
  }

  void _removeImage(int index) {
    if (!widget.enabled) return;

    setState(() {
      _images.removeAt(index);
    });
    widget.onChanged(List.unmodifiable(_images));

    if (mounted) {
      SemanticsService.announce(
        context.l10n.bugReportImagesCount(_images.length, widget.maxImages),
        TextDirection.ltr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMobile) return const SizedBox.shrink();

    final l10n = context.l10n;
    final showAddButton = _images.length < widget.maxImages;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _images.length; i++)
          _Thumbnail(
            file: _images[i],
            enabled: widget.enabled,
            semanticsLabel: l10n.bugReportRemoveImage,
            onRemove: () => _removeImage(i),
          ),
        if (showAddButton)
          _AddButton(
            enabled: widget.enabled,
            semanticsLabel: l10n.bugReportAttachImages,
            onTap: _pickImages,
          ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.file,
    required this.enabled,
    required this.semanticsLabel,
    required this.onRemove,
  });

  final XFile file;
  final bool enabled;
  final String semanticsLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(file.path),
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              semanticLabel: file.name,
            ),
          ),
          if (enabled)
            Positioned(
              top: 0,
              right: 0,
              child: Semantics(
                button: true,
                label: semanticsLabel,
                child: GestureDetector(
                  onTap: onRemove,
                  child: ExcludeSemantics(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: VineTheme.cardBackground,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: VineTheme.whiteText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.enabled,
    required this.semanticsLabel,
    required this.onTap,
  });

  final bool enabled;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: ExcludeSemantics(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
            child: Icon(
              Icons.add_photo_alternate_outlined,
              color: enabled ? VineTheme.vineGreen : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run from `mobile/`:

```bash
flutter analyze lib/widgets/image_attachment_picker.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/image_attachment_picker.dart
git commit -m "feat: add ImageAttachmentPicker widget for bug report attachments"
```

---

## Task 3: Test ImageAttachmentPicker Widget

**Files:**
- Create: `mobile/test/widgets/image_attachment_picker_test.dart`

- [ ] **Step 1: Write the test file**

Create `mobile/test/widgets/image_attachment_picker_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/image_attachment_picker.dart';

class _MockImagePicker extends Mock implements ImagePicker {}

void main() {
  late _MockImagePicker mockPicker;
  late AppLocalizations l10n;

  setUp(() {
    mockPicker = _MockImagePicker();
    ImageAttachmentPicker.imagePicker = mockPicker;
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  tearDown(() {
    ImageAttachmentPicker.imagePicker = ImagePicker();
  });

  Widget buildTestWidget({
    int maxImages = 3,
    bool enabled = true,
    ValueChanged<List<XFile>>? onChanged,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ImageAttachmentPicker(
          maxImages: maxImages,
          enabled: enabled,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    );
  }

  group('ImageAttachmentPicker', () {
    testWidgets('renders add button on mobile', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
    });

    testWidgets('renders SizedBox.shrink on non-mobile', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('calls onChanged when images are picked', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final pickedFiles = [XFile('/tmp/img1.jpg')];
      when(
        () => mockPicker.pickMultiImage(
          maxWidth: any(named: 'maxWidth'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => pickedFiles);

      List<XFile>? result;
      await tester.pumpWidget(
        buildTestWidget(onChanged: (files) => result = files),
      );

      await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.length, 1);
      expect(result!.first.path, '/tmp/img1.jpg');
    });

    testWidgets('truncates selection to remaining slots', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final fourFiles = [
        XFile('/tmp/a.jpg'),
        XFile('/tmp/b.jpg'),
        XFile('/tmp/c.jpg'),
        XFile('/tmp/d.jpg'),
      ];
      when(
        () => mockPicker.pickMultiImage(
          maxWidth: any(named: 'maxWidth'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => fourFiles);

      List<XFile>? result;
      await tester.pumpWidget(
        buildTestWidget(
          maxImages: 3,
          onChanged: (files) => result = files,
        ),
      );

      await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await tester.pumpAndSettle();

      expect(result!.length, 3);
    });

    testWidgets('hides add button at max count', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final threeFiles = [
        XFile('/tmp/a.jpg'),
        XFile('/tmp/b.jpg'),
        XFile('/tmp/c.jpg'),
      ];
      when(
        () => mockPicker.pickMultiImage(
          maxWidth: any(named: 'maxWidth'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => threeFiles);

      await tester.pumpWidget(buildTestWidget(maxImages: 3));

      // Pick 3 images
      await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await tester.pumpAndSettle();

      // Add button should be gone
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
    });

    testWidgets('remove button removes correct image', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final twoFiles = [XFile('/tmp/a.jpg'), XFile('/tmp/b.jpg')];
      when(
        () => mockPicker.pickMultiImage(
          maxWidth: any(named: 'maxWidth'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => twoFiles);

      List<XFile>? lastResult;
      await tester.pumpWidget(
        buildTestWidget(onChanged: (files) => lastResult = files),
      );

      // Pick 2 images
      await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await tester.pumpAndSettle();

      expect(lastResult!.length, 2);

      // Remove the first image (first close icon)
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      expect(lastResult!.length, 1);
      expect(lastResult!.first.path, '/tmp/b.jpg');
    });

    testWidgets('has correct semantics labels', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await tester.pumpWidget(buildTestWidget());

      final addButtonSemantics = tester.getSemantics(
        find.byIcon(Icons.add_photo_alternate_outlined),
      );
      expect(addButtonSemantics.label, l10n.bugReportAttachImages);
    });

    testWidgets('disabled state prevents interaction', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await tester.pumpWidget(buildTestWidget(enabled: false));

      expect(
        find.byIcon(Icons.add_photo_alternate_outlined),
        findsOneWidget,
      );
      // Icon should be grey when disabled
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.add_photo_alternate_outlined),
      );
      expect(icon.color, Colors.grey);
    });
  });
}
```

- [ ] **Step 2: Run the tests**

Run from `mobile/`:

```bash
flutter test test/widgets/image_attachment_picker_test.dart
```

Expected: all tests pass. If `Image.file` causes issues in test (no real file), you may need to mock the file or adjust — the `Image.file` widget renders a placeholder in test without crashing. If tests fail due to missing file, wrap `Image.file` with an `errorBuilder` in the widget.

- [ ] **Step 3: Commit**

```bash
git add test/widgets/image_attachment_picker_test.dart
git commit -m "test: add ImageAttachmentPicker widget tests"
```

---

## Task 4: Wire Picker Into BugReportDialog

**Files:**
- Modify: `mobile/lib/widgets/bug_report_dialog.dart`

- [ ] **Step 1: Add imports**

At the top of `mobile/lib/widgets/bug_report_dialog.dart`, add after the existing imports:

```dart
import 'package:image_picker/image_picker.dart';
import 'package:openvine/widgets/image_attachment_picker.dart';
```

- [ ] **Step 2: Add state field**

In `_BugReportDialogState`, after line 91 (`bool _isDisposed = false;`), add:

```dart
  List<XFile> _attachments = [];
```

- [ ] **Step 3: Add picker widget to the form**

In the `build` method, between the "Expected Behavior" `TextField` (ending around line 257) and the `SizedBox(height: 8)` before the info text (line 259), insert:

```dart
              const SizedBox(height: 16),

              // Image attachments (mobile only)
              ImageAttachmentPicker(
                enabled: !_isSubmitting,
                onChanged: (files) => setState(() => _attachments = files),
              ),
```

- [ ] **Step 4: Pass attachment paths to createStructuredBugReport**

In `_submitReport()`, modify the call to `ZendeskSupportService.createStructuredBugReport()` (around line 129) to include the new parameter:

```dart
      final success = await ZendeskSupportService.createStructuredBugReport(
        subject: subject,
        description: description,
        stepsToReproduce: _stepsController.text.trim(),
        expectedBehavior: _expectedController.text.trim(),
        reportId: reportData.reportId,
        appVersion: reportData.appVersion,
        deviceInfo: reportData.deviceInfo,
        currentScreen: widget.currentScreen,
        userPubkey: widget.userPubkey,
        errorCounts: reportData.errorCounts,
        logsSummary: _buildLogsSummary(reportData.recentLogs),
        attachmentPaths: _attachments.map((f) => f.path).toList(),
      );
```

Note: This will show an analysis error until Task 5 adds the parameter to the service. That's expected.

- [ ] **Step 5: Verify the dialog compiles (will fail until Task 5)**

Run from `mobile/`:

```bash
flutter analyze lib/widgets/bug_report_dialog.dart
```

Expected: error about `attachmentPaths` not being a valid parameter. This is resolved in Task 5.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/bug_report_dialog.dart
git commit -m "feat: wire ImageAttachmentPicker into BugReportDialog"
```

---

## Task 5: Add attachmentPaths to ZendeskSupportService

**Files:**
- Modify: `mobile/lib/services/zendesk_support_service.dart`

- [ ] **Step 1: Add attachmentPaths to createStructuredBugReport**

In `mobile/lib/services/zendesk_support_service.dart`, find the `createStructuredBugReport` method signature (line 837). Add `List<String>? attachmentPaths` as the last named parameter:

```dart
  static Future<bool> createStructuredBugReport({
    required String subject,
    required String description,
    required String reportId,
    required String appVersion,
    required Map<String, dynamic> deviceInfo,
    String? stepsToReproduce,
    String? expectedBehavior,
    String? currentScreen,
    String? userPubkey,
    Map<String, int>? errorCounts,
    String? logsSummary,
    List<String>? attachmentPaths,
  }) async {
```

- [ ] **Step 2: Pass attachmentPaths through to createTicket**

Find the `createTicket` call inside `createStructuredBugReport` (around line 949). Add the new parameter:

```dart
      return createTicket(
        subject: effectiveSubject,
        description: buffer.toString(),
        tags: tags,
        ticketFormId: 14772963437071,
        customFields: customFields,
        attachmentPaths: attachmentPaths,
      );
```

- [ ] **Step 3: Add attachmentPaths to createTicket signature**

Find the `createTicket` method signature (line 562). Add `List<String>? attachmentPaths` as the last named parameter:

```dart
  static Future<bool> createTicket({
    required String subject,
    required String description,
    List<String>? tags,
    int? ticketFormId,
    List<Map<String, dynamic>>? customFields,
    List<String>? attachmentPaths,
  }) async {
```

- [ ] **Step 4: Include attachmentPaths in the platform channel call**

In `createTicket`, find the first `_channel.invokeMethod('createTicket', {` block (around line 583). Add `attachmentPaths` to the args map:

```dart
      final result = await _channel.invokeMethod('createTicket', {
        'subject': subject,
        'description': description,
        'tags': tags ?? [],
        'ticketFormId': ?ticketFormId,
        if (customFields != null && customFields.isNotEmpty)
          'customFields': customFields,
        if (attachmentPaths != null && attachmentPaths.isNotEmpty)
          'attachmentPaths': attachmentPaths,
      });
```

- [ ] **Step 5: Also add to the JWT retry path**

Find the second `_channel.invokeMethod('createTicket', {` block inside the PlatformException handler (around line 647). Add the same parameter:

```dart
            final retryResult = await _channel.invokeMethod('createTicket', {
              'subject': subject,
              'description': description,
              'tags': tags ?? [],
              'ticketFormId': ?ticketFormId,
              if (customFields != null && customFields.isNotEmpty)
                'customFields': customFields,
              if (attachmentPaths != null && attachmentPaths.isNotEmpty)
                'attachmentPaths': attachmentPaths,
            });
```

- [ ] **Step 6: Verify compilation**

Run from `mobile/`:

```bash
flutter analyze lib/services/zendesk_support_service.dart lib/widgets/bug_report_dialog.dart
```

Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/services/zendesk_support_service.dart
git commit -m "feat: add attachmentPaths parameter to createTicket and createStructuredBugReport"
```

---

## Task 6: Test ZendeskSupportService attachmentPaths

**Files:**
- Modify: `mobile/test/services/zendesk_support_service_test.dart`

- [ ] **Step 1: Add test for attachmentPaths included in platform channel call**

Add to the existing `createTicket` test group in `mobile/test/services/zendesk_support_service_test.dart`:

```dart
  group('ZendeskSupportService.createTicket attachmentPaths', () {
    setUp(() async {
      // Initialize Zendesk for tests
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'initialize') return true;
            return null;
          });
      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );
    });

    test('includes attachmentPaths when provided', () async {
      Map<String, dynamic>? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'createTicket') {
              capturedArgs = Map<String, dynamic>.from(
                call.arguments as Map,
              );
              return true;
            }
            return null;
          });

      await ZendeskSupportService.createTicket(
        subject: 'Test',
        description: 'Test desc',
        attachmentPaths: ['/tmp/img1.jpg', '/tmp/img2.jpg'],
      );

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!['attachmentPaths'], ['/tmp/img1.jpg', '/tmp/img2.jpg']);
    });

    test('omits attachmentPaths when null', () async {
      Map<String, dynamic>? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'createTicket') {
              capturedArgs = Map<String, dynamic>.from(
                call.arguments as Map,
              );
              return true;
            }
            return null;
          });

      await ZendeskSupportService.createTicket(
        subject: 'Test',
        description: 'Test desc',
      );

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!.containsKey('attachmentPaths'), false);
    });

    test('omits attachmentPaths when empty list', () async {
      Map<String, dynamic>? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'createTicket') {
              capturedArgs = Map<String, dynamic>.from(
                call.arguments as Map,
              );
              return true;
            }
            return null;
          });

      await ZendeskSupportService.createTicket(
        subject: 'Test',
        description: 'Test desc',
        attachmentPaths: [],
      );

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!.containsKey('attachmentPaths'), false);
    });
  });
```

- [ ] **Step 2: Run the tests**

Run from `mobile/`:

```bash
flutter test test/services/zendesk_support_service_test.dart
```

Expected: all tests pass, including the new ones.

- [ ] **Step 3: Commit**

```bash
git add test/services/zendesk_support_service_test.dart
git commit -m "test: verify attachmentPaths in platform channel invocations"
```

---

## Task 7: Test BugReportDialog Attachment Passthrough

**Files:**
- Modify: `mobile/test/widgets/bug_report_dialog_test.dart`

- [ ] **Step 1: Add test for zero-attachment regression**

Add to the existing test group in `mobile/test/widgets/bug_report_dialog_test.dart`. The existing tests already verify submission works — add a test that explicitly confirms no `attachmentPaths` parameter causes issues:

```dart
    testWidgets('submits successfully with zero attachments', (tester) async {
      // This is a regression test — the new attachmentPaths parameter
      // must not break submission when no images are attached.
      when(() => mockBugReportService.collectDiagnostics(
            userDescription: any(named: 'userDescription'),
            currentScreen: any(named: 'currentScreen'),
            userPubkey: any(named: 'userPubkey'),
          )).thenAnswer((_) async => _FakeBugReportData());

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => InheritedGoRouter(
                goRouter: GoRouter(routes: [
                  GoRoute(path: '/', builder: (_, __) => const SizedBox()),
                ]),
                child: BugReportDialog(
                  bugReportService: mockBugReportService,
                  testMode: true,
                ),
              ),
            ),
          ),
        ),
      );

      // Fill required fields
      await tester.enterText(find.byType(TextField).at(0), 'Test subject');
      await tester.enterText(find.byType(TextField).at(1), 'Test description');
      await tester.pumpAndSettle();

      // Verify Send button is enabled (canSubmit = true)
      final sendButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Send Report'),
      );
      expect(sendButton.onPressed, isNotNull);
    });
```

Note: The exact test setup may need adjustment based on how `_FakeBugReportData` is configured in the existing test file. Check the existing `_FakeBugReportData` class and ensure it provides the required fields. If `collectDiagnostics` requires specific return values, match the existing test patterns.

- [ ] **Step 2: Run the tests**

Run from `mobile/`:

```bash
flutter test test/widgets/bug_report_dialog_test.dart
```

Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add test/widgets/bug_report_dialog_test.dart
git commit -m "test: add zero-attachment regression test for BugReportDialog"
```

---

## Task 8: iOS Native — Upload Attachments via ZDKUploadProvider

**Files:**
- Modify: `mobile/ios/Runner/AppDelegate.swift`

- [ ] **Step 1: Add upload logic to the createTicket handler**

In `mobile/ios/Runner/AppDelegate.swift`, find the `createTicket` case (line 293). After extracting `customFieldsData` (line 309) and before building the `ZDKCreateRequest` (line 312), add attachment path extraction:

```swift
        let attachmentPaths = args["attachmentPaths"] as? [String] ?? []
```

- [ ] **Step 2: Add upload helper method**

After the `setupZendeskChannel` method's closing brace (but still inside the `AppDelegate` class), add a helper to upload files sequentially and collect tokens:

```swift
  private func uploadAttachments(
    _ paths: [String],
    completion: @escaping (Result<[ZDKUploadResponse], FlutterError>) -> Void
  ) {
    var responses: [ZDKUploadResponse] = []
    let uploadProvider = ZDKUploadProvider()

    func uploadNext(index: Int) {
      guard index < paths.count else {
        completion(.success(responses))
        return
      }

      let path = paths[index]
      guard let data = FileManager.default.contents(atPath: path) else {
        completion(.failure(FlutterError(
          code: "UPLOAD_FAILED",
          message: "Could not read file at \(path)",
          details: nil
        )))
        return
      }

      let filename = (path as NSString).lastPathComponent
      let contentType = filename.hasSuffix(".png") ? "image/png" : "image/jpeg"

      uploadProvider.uploadAttachment(data, withFilename: filename, andContentType: contentType) {
        uploadResponse, error in
        if let error = error {
          NSLog("❌ Zendesk: Upload failed for \(filename) - \(error.localizedDescription)")
          completion(.failure(FlutterError(
            code: "UPLOAD_FAILED",
            message: "Failed to upload \(filename): \(error.localizedDescription)",
            details: nil
          )))
          return
        }

        guard let response = uploadResponse else {
          completion(.failure(FlutterError(
            code: "UPLOAD_FAILED",
            message: "No upload response for \(filename)",
            details: nil
          )))
          return
        }

        NSLog("✅ Zendesk: Uploaded \(filename) - token: \(response.uploadToken ?? "nil")")
        responses.append(response)
        uploadNext(index: index + 1)
      }
    }

    uploadNext(index: 0)
  }
```

- [ ] **Step 3: Modify createTicket to upload before submitting**

Replace the section from `ZDKCreateRequest()` creation through `ZDKRequestProvider().createRequest()` (lines 312-359). The new logic uploads attachments first if present, then creates the request:

```swift
        // Build create request object using ZDK API
        let createRequest = ZDKCreateRequest()
        createRequest.subject = subject
        createRequest.requestDescription = description
        createRequest.tags = tags

        // Set ticket form ID if provided
        if let formId = ticketFormId {
          createRequest.ticketFormId = formId
          NSLog("🎫 Zendesk: Using ticket form ID: \(formId)")
        }

        // Set custom fields if provided
        if !customFieldsData.isEmpty {
          var customFields: [CustomField] = []
          for fieldData in customFieldsData {
            if let fieldId = fieldData["id"] as? NSNumber,
               let fieldValue = fieldData["value"] {
              let customField = CustomField(dictionary: ["id": fieldId, "value": fieldValue])
              customFields.append(customField)
              NSLog("🎫 Zendesk: Custom field \(fieldId) = \(fieldValue)")
            }
          }
          createRequest.customFields = customFields
        }

        NSLog("🎫 Zendesk: Submitting ticket - subject: '\(subject)', tags: \(tags), attachments: \(attachmentPaths.count)")

        // Upload attachments first, then create ticket
        if attachmentPaths.isEmpty {
          // No attachments — submit directly (existing path)
          ZDKRequestProvider().createRequest(createRequest) { (request, error) in
            DispatchQueue.main.async {
              if let error = error {
                NSLog("❌ Zendesk: Failed to create ticket - \(error.localizedDescription)")
                result(FlutterError(code: "CREATE_FAILED",
                                  message: error.localizedDescription,
                                  details: nil))
              } else if let request = request as? ZDKRequest {
                NSLog("✅ Zendesk: Ticket created successfully - ID: \(request.requestId)")
                result(true)
              } else {
                NSLog("✅ Zendesk: Ticket created (no error, response type: \(type(of: request)))")
                result(true)
              }
            }
          }
        } else {
          // Upload attachments, then attach tokens to request
          self.uploadAttachments(attachmentPaths) { uploadResult in
            switch uploadResult {
            case .success(let uploadResponses):
              createRequest.attachments = uploadResponses
              NSLog("🎫 Zendesk: All \(uploadResponses.count) attachments uploaded, creating ticket")

              ZDKRequestProvider().createRequest(createRequest) { (request, error) in
                DispatchQueue.main.async {
                  if let error = error {
                    NSLog("❌ Zendesk: Failed to create ticket - \(error.localizedDescription)")
                    result(FlutterError(code: "CREATE_FAILED",
                                      message: error.localizedDescription,
                                      details: nil))
                  } else if let request = request as? ZDKRequest {
                    NSLog("✅ Zendesk: Ticket created with attachments - ID: \(request.requestId)")
                    result(true)
                  } else {
                    NSLog("✅ Zendesk: Ticket created with attachments (no error)")
                    result(true)
                  }
                }
              }

            case .failure(let error):
              DispatchQueue.main.async {
                result(error)
              }
            }
          }
        }
```

- [ ] **Step 4: Build iOS to verify compilation**

Run from `mobile/`:

```bash
flutter build ios --no-codesign --debug 2>&1 | tail -20
```

Expected: build succeeds. If there are Swift type issues, adjust the `uploadAttachments` helper signatures.

- [ ] **Step 5: Commit**

```bash
git add ios/Runner/AppDelegate.swift
git commit -m "feat(ios): upload image attachments via ZDKUploadProvider before ticket creation"
```

---

## Task 9: Android Native — Upload Attachments via UploadProvider

**Files:**
- Modify: `mobile/android/app/src/main/kotlin/co/openvine/app/MainActivity.kt`

- [ ] **Step 1: Add UploadProvider import**

At the top of `MainActivity.kt`, add after the existing Zendesk imports (around line 27):

```kotlin
import zendesk.support.UploadProvider
import zendesk.support.UploadResponse
import com.zendesk.service.ErrorResponse
```

- [ ] **Step 2: Extract attachmentPaths in createTicket handler**

In the `createTicket` handler (line 442), after extracting `customFieldsData` (line 448), add:

```kotlin
                    val attachmentPaths = (args?.get("attachmentPaths") as? List<*>)?.filterIsInstance<String>() ?: emptyList()
```

- [ ] **Step 3: Add upload helper method**

Add a private method to the `MainActivity` class (before or after `configureFlutterEngine`):

```kotlin
    private fun uploadAttachments(
        uploadProvider: UploadProvider,
        paths: List<String>,
        mainHandler: Handler,
        onComplete: (Result<List<UploadResponse>>) -> Unit
    ) {
        val responses = mutableListOf<UploadResponse>()

        fun uploadNext(index: Int) {
            if (index >= paths.size) {
                onComplete(Result.success(responses))
                return
            }

            val path = paths[index]
            val file = File(path)
            if (!file.exists()) {
                onComplete(Result.failure(Exception("File not found: $path")))
                return
            }

            val filename = file.name
            val contentType = if (filename.endsWith(".png")) "image/png" else "image/jpeg"

            uploadProvider.uploadAttachment(
                filename,
                file,
                contentType,
                object : ZendeskCallback<UploadResponse>() {
                    override fun onSuccess(response: UploadResponse?) {
                        if (response != null) {
                            Log.d(ZENDESK_TAG, "Uploaded $filename - token: ${response.token}")
                            responses.add(response)
                            uploadNext(index + 1)
                        } else {
                            mainHandler.post {
                                onComplete(Result.failure(Exception("No upload response for $filename")))
                            }
                        }
                    }

                    override fun onError(error: ErrorResponse?) {
                        Log.e(ZENDESK_TAG, "Upload failed for $filename: ${error?.reason}")
                        mainHandler.post {
                            onComplete(Result.failure(Exception("Upload failed for $filename: ${error?.reason}")))
                        }
                    }
                }
            )
        }

        uploadNext(0)
    }
```

- [ ] **Step 4: Modify createTicket to upload before submitting**

Replace the ticket submission section in the `createTicket` handler (from `val mainHandler` around line 492 through the end of the `ZendeskCallback` at line 515). The new logic uploads first if attachments are present:

```kotlin
                        val mainHandler = Handler(Looper.getMainLooper())

                        if (attachmentPaths.isEmpty()) {
                            // No attachments — submit directly (existing path)
                            provider.createRequest(createRequest, object : ZendeskCallback<Request>() {
                                override fun onSuccess(request: Request?) {
                                    mainHandler.post {
                                        if (isActivityDestroyed || isFinishing) {
                                            Log.w(ZENDESK_TAG, "Dropped ticket result: activity destroyed")
                                            return@post
                                        }
                                        Log.d(ZENDESK_TAG, "Ticket created successfully - ID: ${request?.id}")
                                        result.success(true)
                                    }
                                }

                                override fun onError(error: ErrorResponse?) {
                                    mainHandler.post {
                                        if (isActivityDestroyed || isFinishing) {
                                            Log.w(ZENDESK_TAG, "Dropped ticket error: activity destroyed")
                                            return@post
                                        }
                                        Log.e(ZENDESK_TAG, "Failed to create ticket: ${error?.reason}")
                                        result.success(false)
                                    }
                                }
                            })
                        } else {
                            // Upload attachments first
                            Log.d(ZENDESK_TAG, "Uploading ${attachmentPaths.size} attachments before ticket creation")
                            val uploadProvider: UploadProvider = providerStore.uploadProvider()

                            uploadAttachments(uploadProvider, attachmentPaths, mainHandler) { uploadResult ->
                                uploadResult.fold(
                                    onSuccess = { uploadResponses ->
                                        createRequest.attachments = uploadResponses.map { it.token }
                                        Log.d(ZENDESK_TAG, "All ${uploadResponses.size} attachments uploaded, creating ticket")

                                        provider.createRequest(createRequest, object : ZendeskCallback<Request>() {
                                            override fun onSuccess(request: Request?) {
                                                mainHandler.post {
                                                    if (isActivityDestroyed || isFinishing) {
                                                        Log.w(ZENDESK_TAG, "Dropped ticket result: activity destroyed")
                                                        return@post
                                                    }
                                                    Log.d(ZENDESK_TAG, "Ticket created with attachments - ID: ${request?.id}")
                                                    result.success(true)
                                                }
                                            }

                                            override fun onError(error: ErrorResponse?) {
                                                mainHandler.post {
                                                    if (isActivityDestroyed || isFinishing) {
                                                        Log.w(ZENDESK_TAG, "Dropped ticket error: activity destroyed")
                                                        return@post
                                                    }
                                                    Log.e(ZENDESK_TAG, "Failed to create ticket: ${error?.reason}")
                                                    result.success(false)
                                                }
                                            }
                                        })
                                    },
                                    onFailure = { error ->
                                        mainHandler.post {
                                            if (isActivityDestroyed || isFinishing) {
                                                Log.w(ZENDESK_TAG, "Dropped upload error: activity destroyed")
                                                return@post
                                            }
                                            Log.e(ZENDESK_TAG, "Attachment upload failed: ${error.message}")
                                            result.error("UPLOAD_FAILED", error.message, null)
                                        }
                                    }
                                )
                            }
                        }
```

- [ ] **Step 5: Build Android to verify compilation**

Run from `mobile/`:

```bash
flutter build apk --debug 2>&1 | tail -20
```

Expected: build succeeds. Note: the Android SDK `CreateRequest.setAttachments()` takes a `List<String>` of upload tokens. The code uses `uploadResponses.map { it.token }` to extract tokens. If `UploadResponse.token` is named differently in `com.zendesk:support:5.1.2`, check the class with `javap` or IDE autocomplete and adjust the property name.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/kotlin/co/openvine/app/MainActivity.kt
git commit -m "feat(android): upload image attachments via UploadProvider before ticket creation"
```

---

## Task 10: Final Verification

- [ ] **Step 1: Run full analysis**

Run from `mobile/`:

```bash
flutter analyze lib/widgets/image_attachment_picker.dart lib/widgets/bug_report_dialog.dart lib/services/zendesk_support_service.dart
```

Expected: no issues.

- [ ] **Step 2: Run all related tests**

```bash
flutter test test/widgets/image_attachment_picker_test.dart test/widgets/bug_report_dialog_test.dart test/services/zendesk_support_service_test.dart
```

Expected: all pass.

- [ ] **Step 3: Run full test suite**

```bash
flutter test
```

Expected: no regressions.

- [ ] **Step 4: Format changed files**

```bash
dart format lib/widgets/image_attachment_picker.dart lib/widgets/bug_report_dialog.dart lib/services/zendesk_support_service.dart test/widgets/image_attachment_picker_test.dart test/widgets/bug_report_dialog_test.dart test/services/zendesk_support_service_test.dart
```

- [ ] **Step 5: Build iOS to verify native changes**

```bash
flutter build ios --no-codesign --debug 2>&1 | tail -20
```

- [ ] **Step 6: Build Android to verify native changes**

```bash
flutter build apk --debug 2>&1 | tail -20
```

- [ ] **Step 7: Commit any format fixes**

If `dart format` changed anything:

```bash
git add -u
git commit -m "style: format changed files"
```

---

## Manual Testing Checklist (Post-Implementation)

These must be verified on device before the PR is merge-ready:

1. **iOS device/simulator:** Open bug report dialog → attach 1 image → submit → verify ticket in Zendesk has attachment
2. **Android device/emulator:** Same as above
3. **3 images max:** Attach 3 images → add button disappears → try long-press or other paths → no way to exceed limit
4. **Remove image:** Attach 2 → remove 1 → submit → ticket has 1 attachment
5. **Zero attachments (regression):** Submit bug report with no images → works exactly as before
6. **Upload failure:** Attach 1 image → airplane mode → submit → error shown, no ticket created, user can retry
7. **Desktop/macOS:** Open bug report → picker not shown → submit works as before
8. **Disabled during submission:** Tap submit → while spinner showing, picker add/remove buttons are non-interactive
