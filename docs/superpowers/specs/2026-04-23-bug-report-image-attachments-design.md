# Bug Report Image Attachments

**Issue:** divinevideo/divine-mobile#3094
**Date:** 2026-04-23
**Status:** Design approved, pending implementation

## Problem

Users filing in-app bug reports cannot attach screenshots. Triage of vague reports ("error pop up", "video won't play") dead-ends because there is no visual context and no follow-up channel.

## Scope

Add image attachment support (up to 3 images) to the in-app bug report dialog on iOS and Android. Images are selected from the device gallery, resized for upload efficiency, and attached to the Zendesk ticket via the native SDK's upload API.

### Not in scope

- Desktop (macOS/Windows/Linux) attachment support. Desktop REST API path is internal-only and does not have `ZENDESK_API_TOKEN` in production builds.
- Camera capture as image source. Gallery only, matching the existing profile avatar picker pattern.
- Immediate-on-select uploads. Images upload at submission time.
- Partial submission on upload failure. All-or-nothing: if any image fails to upload, the submission fails and the user retries.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Platform scope | Mobile only (iOS/Android) | Desktop bug reports go through Slack/GitHub; REST API fallback lacks `ZENDESK_API_TOKEN` in prod |
| Image source | Gallery only | Matches existing `image_picker` usage for profile avatars; users screenshot first, then attach |
| Max images | 3 | Covers the common case without overloading Zendesk tickets |
| Compression | Resize to 1920px max width, JPEG 80% quality | Keeps uploads under ~500KB each; `image_picker` has built-in `maxWidth`/`imageQuality` params |
| Upload timing | At submission | Simpler state management; spinner already shown during submission |
| Upload failure | Fail entire submission | No partial state; user can retry. Avoids confusing triage with missing attachments |
| Architecture | Extract `ImageAttachmentPicker` widget | Keeps `BugReportDialog` focused on form logic; picker is independently testable and reusable |
| Desktop UI | Hide picker entirely | No false affordance; widget checks platform and renders `SizedBox.shrink()` on non-mobile |

## Architecture

### Component Flow

```
BugReportDialog
  |-- ImageAttachmentPicker (new widget, mobile only)
  |     |-- thumbnail previews (64x64, X to remove)
  |     |-- add button (hidden at max count)
  |     |-- onChanged callback -> List<XFile>
  |
  |-- _submitReport()
        |-- BugReportService.collectDiagnostics() (unchanged)
        |-- ZendeskSupportService.createStructuredBugReport(
        |     ...,
        |     attachmentPaths: [file paths from picker]
        |   )
              |-- createTicket(
              |     ...,
              |     attachmentPaths: [file paths]
              |   )
                    |-- MethodChannel('com.openvine/zendesk_support')
                          |-- Native: upload each file via UploadProvider
                          |-- Native: attach tokens to CreateRequest
                          |-- Native: createRequest()
```

### New File

**`mobile/lib/widgets/image_attachment_picker.dart`**

Stateful widget with parameters:
- `maxImages: int` (default 3)
- `onChanged: ValueChanged<List<XFile>>`
- `enabled: bool` (disabled during submission)

Behavior:
- Renders a horizontal row of thumbnail previews + an add button.
- Thumbnails are ~64x64 with a small circular X overlay to remove.
- Add button calls `ImagePicker().pickMultiImage(maxWidth: 1920, imageQuality: 80)`.
- If the user selects more images than remaining slots, the selection is truncated to the limit.
- On non-mobile platforms (`defaultTargetPlatform` is not iOS or Android), renders `SizedBox.shrink()`.
- Styled with `VineTheme` colors: grey border on add button, `vineGreen` icon, dark card background on thumbnails.
- All interactive elements wrapped with `Semantics(button: true, label: ...)` per `accessibility.md`. Minimum 48x48 touch targets on add and remove buttons.
- `SemanticsService.announce()` after image add/remove to communicate count change to screen readers.
- Thumbnail images get `semanticLabel`; decorative overlays (gradient behind X) wrapped in `ExcludeSemantics`.

### Localization

All user-facing strings use `context.l10n` per `localization.md`. ARB keys to add in `mobile/lib/l10n/app_en.arb` (feature-prefixed `bugReport*`):

```json
{
  "bugReportAttachImages": "Attach images",
  "bugReportRemoveImage": "Remove image",
  "bugReportImagesCount": "{count} of {max} images",
  "@bugReportImagesCount": {
    "placeholders": {
      "count": { "type": "int" },
      "max": { "type": "int" }
    }
  },
  "bugReportUploadFailed": "Image upload failed. Please try again."
}
```

Run `flutter gen-l10n` from `mobile/` and commit generated files.

### Modified Files

**`mobile/lib/widgets/bug_report_dialog.dart`**
- Add `List<XFile> _attachments` state field.
- Host `ImageAttachmentPicker` between "Expected Behavior" field and info text.
- Pass `_attachments.map((f) => f.path).toList()` to `createStructuredBugReport()`.

**`mobile/lib/services/zendesk_support_service.dart`**
- `createStructuredBugReport()`: new optional `List<String>? attachmentPaths` parameter, passed through to `createTicket()`.
- `createTicket()`: new optional `List<String>? attachmentPaths` parameter. Added to platform channel `invokeMethod` args when non-null and non-empty. REST API fallback path ignores attachments (no crash, just text-only ticket).

**`mobile/ios/Runner/AppDelegate.swift`** -- `createTicket` handler:
- Extract optional `attachmentPaths: [String]` from args.
- If present, upload each file sequentially via `ZDKUploadProvider().uploadAttachment()`.
- Collect upload responses and set on `createRequest.attachments`.
- If any upload fails, return `FlutterError(code: "UPLOAD_FAILED", message: ..., details: nil)` without creating the ticket.
- No change to existing flow when no attachments provided.

**`mobile/android/app/src/main/kotlin/co/openvine/app/MainActivity.kt`** -- `createTicket` handler:
- Same pattern as iOS: extract `attachmentPaths`, upload via `UploadProvider`, collect tokens, set on `CreateRequest`.
- Fail-fast on any upload error.
- No change to existing flow when no attachments provided.

### Platform Channel Contract

The `createTicket` method gains one new optional field:

```
createTicket({
  subject: String,            // existing
  description: String,        // existing
  tags: [String],             // existing
  ticketFormId: int?,         // existing
  customFields: [Map]?,       // existing
  attachmentPaths: [String]?  // NEW - absolute file paths to upload
})
```

Native implementations treat `attachmentPaths` as optional. When absent or empty, behavior is identical to today.

## Testing

### Dart Unit Tests

**`mobile/test/widgets/image_attachment_picker_test.dart`** (new):
- Renders add button when under max count.
- Hides add button when at max count.
- Displays thumbnails for selected images.
- Remove button removes the correct image.
- Calls `onChanged` with updated file list on add and remove.
- Renders nothing (`SizedBox.shrink()`) on non-mobile platforms.
- Test `MaterialApp` includes `AppLocalizations.localizationsDelegates` and `supportedLocales`.
- String assertions use `lookupAppLocalizations` instead of hardcoded English.

**`bug_report_dialog_test.dart`** (extend existing):
- Attachment file paths are passed through to `createStructuredBugReport()`.
- Submission works with zero attachments (regression).

**`zendesk_support_service_test.dart`** (extend existing):
- `attachmentPaths` included in platform channel invocation when provided.
- `attachmentPaths` omitted from platform channel invocation when null/empty.
- REST API fallback creates ticket without attachments (no error).

### Native Verification (Manual)

No native unit tests for iOS/Android upload flow. Verified manually on device:

1. Submit with 0 images -- works as before (regression check).
2. Submit with 1 image -- ticket created with attachment visible in Zendesk.
3. Submit with 3 images, try to add a 4th -- add button not shown at max.
4. Attach 2, remove 1, submit -- ticket has 1 attachment.
5. Attach 1, airplane mode, submit -- error shown, no ticket created.
6. Desktop/macOS -- picker not shown, submit works as before.

## SDK API Notes

The exact method signatures for `ZDKUploadProvider` (iOS) and `UploadProvider` (Android) need to be verified against the SDK versions linked in the Podfile and build.gradle during implementation. The design assumes a standard upload-file-get-token pattern which is consistent across Zendesk SDK versions, but parameter names may vary.
