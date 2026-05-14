# Collaborator Invite Video Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace text-only collaborator invite cards with inline video preview cards whose actions clearly mean "co-post this video" or "this is not mine."

**Architecture:** Keep the existing structured invite parser, `CollaboratorInviteCard`, and `CollaboratorInviteActionsCubit`. Add sender display-name context from the conversation/request preview owners, render a stable portrait thumbnail card when `thumb` exists, and keep the current compact non-thumbnail fallback.

**Tech Stack:** Flutter/Dart, `flutter_test`, `mocktail`, `flutter_bloc`, `go_router`, `divine_ui`, Flutter gen-l10n, existing `VineCachedImage` image cache.

---

## File Structure

- Modify `mobile/test/screens/inbox/conversation/conversation_view_test.dart`: add recipient-side thumbnail/copy assertions and update action-copy expectations.
- Modify `mobile/test/screens/inbox/message_requests/request_preview_view_test.dart`: add request-preview assertions for thumbnail/copy and update action-copy expectations.
- Modify `mobile/lib/screens/inbox/conversation/conversation_view.dart`: pass resolved participant display name into `_MessageList`, then into `CollaboratorInviteCard`.
- Modify `mobile/lib/screens/inbox/message_requests/request_preview_view.dart`: pass resolved display name into `_InvitePreview`, then into `CollaboratorInviteCard`.
- Modify `mobile/lib/screens/inbox/conversation/widgets/collaborator_invite_card.dart`: add thumbnail-first card layout, fallback copy, `senderDisplayName`, new action labels, and existing state behavior.
- Modify `mobile/lib/l10n/app_en.arb`: add new copy keys while preserving old status keys.
- Generated `mobile/lib/l10n/generated/*.dart`: regenerate with `flutter gen-l10n`.

## Task 1: Conversation Tests For Thumbnail-First Recipient Card

**Files:**
- Modify: `mobile/test/screens/inbox/conversation/conversation_view_test.dart`

- [ ] **Step 1: Add failing recipient-card test**

In the existing `group(ConversationView, ...)`, in the loaded-message tests near `renders collaborator invite card instead of plaintext invite copy`, add this test:

```dart
testWidgets(
  'renders collaborator invite as an inline video preview with co-post actions',
  (tester) async {
    const thumbnailUrl = 'https://cdn.divine.video/thumbs/skate-loop.jpg';
    final message = DmMessage(
      id: '9999999999999999999999999999999999999999999999999999999999999999',
      conversationId:
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      senderPubkey: otherPubkey,
      content: 'You were invited to collaborate.',
      createdAt: now.millisecondsSinceEpoch ~/ 1000,
      giftWrapId:
          'aaaaaaaabbbbbbbbccccccccddddddddaaaaaaaabbbbbbbbccccccccdddddddd',
      tags: const [
        ['divine', 'collab-invite'],
        [
          'a',
          '34236:1122334411223344112233441122334411223344112233441122334411223344:skate-loop',
          'wss://relay.divine.video',
        ],
        ['p', otherPubkey],
        ['role', 'Collaborator'],
        ['title', 'Skate loop'],
        ['thumb', thumbnailUrl],
      ],
    );

    await tester.pumpWidget(
      buildSubject(
        state: ConversationState(
          status: ConversationStatus.loaded,
          messages: [message],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Co-post invite'), findsOneWidget);
    expect(find.textContaining('Skate loop'), findsOneWidget);
    expect(
      find.text(
        'Co-posting adds this video to your timeline as a collaboration.',
      ),
      findsOneWidget,
    );
    expect(find.text('Co-post'), findsOneWidget);
    expect(find.text('Not mine'), findsOneWidget);
    expect(find.text(l10n.inboxCollabInviteAcceptButton), findsNothing);
    expect(find.text(l10n.inboxCollabInviteIgnoreButton), findsNothing);
    expect(find.byKey(const ValueKey('collaborator_invite_thumbnail')), findsOneWidget);

    await tester.tap(find.text('Co-post'));
    await tester.pump();

    verify(
      () => mockInviteActionsCubit.acceptInvite(any()),
    ).called(1);
  },
);
```

- [ ] **Step 2: Update existing action-copy assertions**

In the existing recipient invite test, replace:

```dart
expect(find.text(l10n.inboxCollabInviteAcceptButton), findsOneWidget);
expect(find.text(l10n.inboxCollabInviteIgnoreButton), findsOneWidget);
...
await tester.tap(find.text(l10n.inboxCollabInviteAcceptButton));
```

with:

```dart
expect(find.text('Co-post'), findsOneWidget);
expect(find.text('Not mine'), findsOneWidget);
...
await tester.tap(find.text('Co-post'));
```

Keep the sender-side test assertions that recipient actions are absent, but update them to assert:

```dart
expect(find.text('Co-post'), findsNothing);
expect(find.text('Not mine'), findsNothing);
```

- [ ] **Step 3: Run conversation red test**

Run:

```bash
cd mobile
flutter test --no-pub test/screens/inbox/conversation/conversation_view_test.dart --plain-name "inline video preview"
```

Expected: FAIL because the current card does not render `Co-post`, `Not mine`, the consequence line, or `collaborator_invite_thumbnail`.

## Task 2: Request Preview Tests For Reused Card Behavior

**Files:**
- Modify: `mobile/test/screens/inbox/message_requests/request_preview_view_test.dart`

- [ ] **Step 1: Add thumbnail tag to the existing invite request message**

In the existing request-preview collaborator invite test, add:

```dart
['thumb', 'https://cdn.divine.video/thumbs/skate-loop.jpg'],
```

to the invite message tags after the `title` tag.

- [ ] **Step 2: Update assertions to new copy and thumbnail behavior**

Replace:

```dart
expect(find.text(l10n.inboxCollabInviteCardTitle), findsOneWidget);
expect(find.text(l10n.inboxCollabInviteAcceptButton), findsOneWidget);
expect(find.text(l10n.inboxCollabInviteIgnoreButton), findsOneWidget);
...
await tester.ensureVisible(
  find.text(l10n.inboxCollabInviteIgnoreButton),
);
await tester.pump();
await tester.tap(find.text(l10n.inboxCollabInviteIgnoreButton));
```

with:

```dart
expect(find.text('Co-post invite'), findsOneWidget);
expect(find.text('Co-post'), findsOneWidget);
expect(find.text('Not mine'), findsOneWidget);
expect(find.byKey(const ValueKey('collaborator_invite_thumbnail')), findsOneWidget);
expect(
  find.text(
    'Co-posting adds this video to your timeline as a collaboration.',
  ),
  findsOneWidget,
);
...
await tester.ensureVisible(find.text('Not mine'));
await tester.pump();
await tester.tap(find.text('Not mine'));
```

- [ ] **Step 3: Run request-preview red test**

Run:

```bash
cd mobile
flutter test --no-pub test/screens/inbox/message_requests/request_preview_view_test.dart --plain-name "collaborator invite"
```

Expected: FAIL because the current card still renders the text-only invite and old action labels.

## Task 3: L10n Keys And Generated Accessors

**Files:**
- Modify: `mobile/lib/l10n/app_en.arb`
- Generated: `mobile/lib/l10n/generated/*.dart`

- [ ] **Step 1: Add English ARB keys**

In `mobile/lib/l10n/app_en.arb`, near the existing `inboxCollabInvite*` keys, add:

```json
"inboxCollabInviteCoPostButton": "Co-post",
"@inboxCollabInviteCoPostButton": {
  "description": "Primary action on a collaborator invite card. Accepts the invite and co-posts the video to the recipient's timeline as a collaboration."
},
"inboxCollabInviteNotMineButton": "Not mine",
"@inboxCollabInviteNotMineButton": {
  "description": "Secondary action on a collaborator invite card. Ignores the invite because the recipient does not claim the video as their collaboration."
},
"inboxCollabInvitePreviewTitle": "Co-post invite",
"@inboxCollabInvitePreviewTitle": {
  "description": "Header label shown over the video preview on a collaborator invite card."
},
"inboxCollabInvitePreviewTitleFrom": "Co-post invite from {displayName}",
"@inboxCollabInvitePreviewTitleFrom": {
  "description": "Header label shown over the video preview on a collaborator invite card when the inviter's display name is known.",
  "placeholders": {
    "displayName": {
      "type": "String"
    }
  }
},
"inboxCollabInviteTimelineConsequence": "Co-posting adds this video to your timeline as a collaboration.",
"@inboxCollabInviteTimelineConsequence": {
  "description": "Explains what accepting a collaborator invite does."
},
```

- [ ] **Step 2: Regenerate l10n**

Run:

```bash
cd mobile
flutter gen-l10n
```

Expected: no errors, generated files under `mobile/lib/l10n/generated/` update.

## Task 4: Implement Inline Video Preview Card

**Files:**
- Modify: `mobile/lib/screens/inbox/conversation/widgets/collaborator_invite_card.dart`
- Modify: `mobile/lib/screens/inbox/conversation/conversation_view.dart`
- Modify: `mobile/lib/screens/inbox/message_requests/request_preview_view.dart`

- [ ] **Step 1: Extend `CollaboratorInviteCard` API**

Change the constructor to accept optional sender context:

```dart
const CollaboratorInviteCard({
  required this.invite,
  required this.isSent,
  this.senderDisplayName,
  super.key,
});

final String? senderDisplayName;
```

Pass `senderDisplayName` into `_CardChrome`.

- [ ] **Step 2: Pass display name from owners**

In `ConversationView`, pass `displayName` to `_MessageList`:

```dart
_MessageList(
  messages: selected.messages,
  currentPubkey: currentPubkey,
  senderDisplayName: displayName,
),
```

Update `_MessageList`:

```dart
const _MessageList({
  required this.messages,
  required this.currentPubkey,
  required this.senderDisplayName,
});

final String senderDisplayName;
```

When rendering the invite:

```dart
return CollaboratorInviteCard(
  invite: invite,
  isSent: isSent,
  senderDisplayName: isSent ? null : senderDisplayName,
);
```

In `RequestPreviewView`, pass `displayName` into `_InvitePreview` and then into `CollaboratorInviteCard`.

- [ ] **Step 3: Add thumbnail rendering helpers**

In `collaborator_invite_card.dart`, import:

```dart
import 'package:openvine/widgets/vine_cached_image.dart';
```

Add helper getters/methods to `_CardChrome`:

```dart
String? get _thumbnailUrl {
  final value = invite.thumbnailUrl?.trim();
  return value == null || value.isEmpty ? null : value;
}

String _previewTitle(BuildContext context) {
  final name = senderDisplayName?.trim();
  if (name != null && name.isNotEmpty) {
    return context.l10n.inboxCollabInvitePreviewTitleFrom(name);
  }
  return context.l10n.inboxCollabInvitePreviewTitle;
}
```

- [ ] **Step 4: Render thumbnail-first content**

Inside `_CardChrome.build`, keep the existing outer padding/alignment/GestureDetector, but replace the inner column with:

```dart
child: _thumbnailUrl == null
    ? _FallbackInviteContent(
        title: _titleText(context),
        previewTitle: _previewTitle(context),
        action: action,
      )
    : _ThumbnailInviteContent(
        thumbnailUrl: _thumbnailUrl!,
        title: _titleText(context),
        previewTitle: _previewTitle(context),
        action: action,
      ),
```

Create `_ThumbnailInviteContent` with a stable portrait `AspectRatio`, `VineCachedImage`, overlay text, and the action below the preview. Give the image wrapper this key:

```dart
key: const ValueKey('collaborator_invite_thumbnail'),
```

Create `_FallbackInviteContent` with the same `previewTitle`, title, consequence line, and action.

- [ ] **Step 5: Update action labels**

In `_ActionRow`, replace:

```dart
label: l10n.inboxCollabInviteAcceptButton,
...
label: l10n.inboxCollabInviteIgnoreButton,
```

with:

```dart
label: l10n.inboxCollabInviteCoPostButton,
...
label: l10n.inboxCollabInviteNotMineButton,
```

Keep the existing accept/ignore cubit calls unchanged.

- [ ] **Step 6: Run green tests**

Run:

```bash
cd mobile
flutter test --no-pub test/screens/inbox/conversation/conversation_view_test.dart --plain-name "collaborator invite"
flutter test --no-pub test/screens/inbox/message_requests/request_preview_view_test.dart --plain-name "collaborator invite"
```

Expected: both commands PASS.

## Task 5: Format, Analyze, And Commit Implementation

**Files:**
- Modify/test files from Tasks 1-4.

- [ ] **Step 1: Format touched Dart files**

Run:

```bash
cd mobile
dart format \
  lib/screens/inbox/conversation/widgets/collaborator_invite_card.dart \
  lib/screens/inbox/conversation/conversation_view.dart \
  lib/screens/inbox/message_requests/request_preview_view.dart \
  test/screens/inbox/conversation/conversation_view_test.dart \
  test/screens/inbox/message_requests/request_preview_view_test.dart \
  lib/l10n/generated/app_localizations.dart \
  lib/l10n/generated/app_localizations_en.dart
```

Expected: formatter exits 0.

- [ ] **Step 2: Run focused analyzer**

Run:

```bash
cd mobile
flutter analyze \
  lib/screens/inbox/conversation/widgets/collaborator_invite_card.dart \
  lib/screens/inbox/conversation/conversation_view.dart \
  lib/screens/inbox/message_requests/request_preview_view.dart \
  test/screens/inbox/conversation/conversation_view_test.dart \
  test/screens/inbox/message_requests/request_preview_view_test.dart
```

Expected: no issues for these files.

- [ ] **Step 3: Run final focused tests**

Run:

```bash
cd mobile
flutter test --no-pub test/screens/inbox/conversation/conversation_view_test.dart --plain-name "collaborator invite"
flutter test --no-pub test/screens/inbox/message_requests/request_preview_view_test.dart --plain-name "collaborator invite"
```

Expected: both commands PASS.

- [ ] **Step 4: Review and commit**

Run:

```bash
git diff --stat
git status --short
```

Stage only the plan, implementation, tests, ARB, and generated l10n files:

```bash
git add \
  docs/superpowers/plans/2026-05-15-collab-invite-video-preview.md \
  mobile/lib/screens/inbox/conversation/widgets/collaborator_invite_card.dart \
  mobile/lib/screens/inbox/conversation/conversation_view.dart \
  mobile/lib/screens/inbox/message_requests/request_preview_view.dart \
  mobile/lib/l10n/app_en.arb \
  mobile/lib/l10n/generated/ \
  mobile/test/screens/inbox/conversation/conversation_view_test.dart \
  mobile/test/screens/inbox/message_requests/request_preview_view_test.dart
git commit -m "feat(collabs): preview videos in invite cards"
```

Expected: commit succeeds.
