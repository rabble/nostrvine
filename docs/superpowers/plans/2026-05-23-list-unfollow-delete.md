# List Unfollow and Delete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users unfollow somebody else's list and delete their own lists, with protocol-backed deletion for both people lists and curated video lists.

**Architecture:** Implement by user action. First add explicit unfollow UI for subscribed external curated video lists using existing subscription state. Then add delete UI for owned people lists using existing BLoC/repository behavior, and add protocol-backed NIP-09 deletion for owned curated video lists before exposing curated delete UI.

**Tech Stack:** Flutter, Riverpod, flutter_bloc, GoRouter, mocktail/bloc_test, Flutter l10n ARB, Nostr kind `5`, curated video lists kind `30005`, people lists kind `30000`.

---

## File Map

- Modify `mobile/lib/screens/curated_list_feed_screen.dart`: expose list action menu; wire curated-list unfollow and owned curated-list delete UI.
- Modify `mobile/lib/screens/user_list_people_screen.dart`: expose owner-scoped people-list delete action and confirmation.
- Modify `mobile/lib/services/curated_list_service.dart`: add protocol-backed owned curated-list deletion and ownership helper.
- Modify `mobile/lib/l10n/app_en.arb`: add English strings for menu labels, confirmations, and snackbars.
- Generated: `mobile/lib/l10n/generated/app_localizations*.dart`, produced by `flutter gen-l10n`.
- Modify `mobile/test/l10n/arb_consistency_test.dart`: add exact new English fallback debt keys if real translations are not added.
- Create `mobile/test/screens/curated_list_feed_screen_test.dart`: widget tests for unfollow and curated-list delete actions.
- Modify `mobile/test/screens/user_list_people_screen_test.dart`: widget tests for people-list delete affordance and confirmation.
- Modify `mobile/test/services/curated_list_service_crud_test.dart`: unit tests for protocol-backed curated-list deletion.

---

## Task 0: Sync Worktree

**Files:**
- No file changes.

- [ ] **Step 1: Rebase this branch onto fresh `origin/main`**

Run:

```bash
git fetch origin
git rebase origin/main
```

Expected: rebase completes cleanly. If conflicts occur, resolve only files in this branch's docs/spec work and rerun `git rebase --continue`.

- [ ] **Step 2: Confirm clean baseline**

Run:

```bash
git status --short --branch
```

Expected: branch is ahead of `origin/main`, with no modified or untracked files.

---

## Task 1: Curated List Unfollow Tests

**Files:**
- Create: `mobile/test/screens/curated_list_feed_screen_test.dart`
- Later modify: `mobile/lib/screens/curated_list_feed_screen.dart`

- [ ] **Step 1: Write the failing widget tests**

Create `mobile/test/screens/curated_list_feed_screen_test.dart` with:

```dart
// ABOUTME: Widget tests for curated list detail actions.
// ABOUTME: Verifies explicit unfollow behavior for subscribed external lists.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/services/curated_list_service.dart';

import '../helpers/test_provider_overrides.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

class _TestCuratedListsState extends CuratedListsState {
  _TestCuratedListsState(this._mockService);

  final CuratedListService? _mockService;

  @override
  CuratedListService? get service => _mockService;

  @override
  Future<List<CuratedList>> build() async => const [];
}

void main() {
  group(CuratedListFeedScreen, () {
    late _MockCuratedListService service;

    setUp(() {
      service = _MockCuratedListService();
      when(() => service.isSubscribedToList(any())).thenReturn(false);
      when(() => service.isOwnedList(any())).thenReturn(false);
      when(() => service.unsubscribeFromList(any())).thenAnswer((_) async => true);
    });

    Widget buildSubject({
      String listId = 'external-list',
      String listName = 'External Mix',
      String authorPubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    }) {
      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(),
          curatedListsStateProvider.overrideWith(
            () => _TestCuratedListsState(service),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CuratedListFeedScreen(
            listId: listId,
            listName: listName,
            videoIds: const [],
            authorPubkey: authorPubkey,
          ),
        ),
      );
    }

    testWidgets('shows unfollow list action for subscribed external list', (
      tester,
    ) async {
      when(() => service.isSubscribedToList('external-list')).thenReturn(true);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.byTooltip('List actions'));
      await tester.pumpAndSettle();

      expect(find.text('Unfollow list'), findsOneWidget);
      expect(find.text('Delete list'), findsNothing);
    });

    testWidgets('unfollow calls service and updates action state', (
      tester,
    ) async {
      var subscribed = true;
      when(() => service.isSubscribedToList('external-list')).thenAnswer(
        (_) => subscribed,
      );
      when(() => service.unsubscribeFromList('external-list')).thenAnswer((
        _,
      ) async {
        subscribed = false;
        return true;
      });

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.byTooltip('List actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unfollow list'));
      await tester.pumpAndSettle();

      verify(() => service.unsubscribeFromList('external-list')).called(1);
      expect(find.text('Unfollowed list'), findsOneWidget);

      await tester.tap(find.byTooltip('List actions'));
      await tester.pumpAndSettle();
      expect(find.text('Unfollow list'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```bash
cd mobile
flutter test --no-pub test/screens/curated_list_feed_screen_test.dart --plain-name "shows unfollow list action for subscribed external list"
```

Expected: FAIL because `CuratedListFeedScreen` has no `List actions` menu and `CuratedListService` has no `isOwnedList` method.

---

## Task 2: Curated List Unfollow Implementation

**Files:**
- Modify: `mobile/lib/screens/curated_list_feed_screen.dart`
- Modify: `mobile/lib/services/curated_list_service.dart`
- Modify: `mobile/lib/l10n/app_en.arb`
- Modify generated l10n files via `flutter gen-l10n`
- Modify: `mobile/test/l10n/arb_consistency_test.dart` if fallback debt is used.

- [ ] **Step 1: Add minimal ownership helper to service**

In `CuratedListService`, add:

```dart
  /// Whether [listId] is a locally-owned curated list for the active user.
  ///
  /// Locally-created lists may have `pubkey == null` until their first
  /// successful relay publish writes a Nostr event id. Remote lists decoded
  /// from relays carry their author's pubkey, so a different pubkey means
  /// external.
  bool isOwnedList(String listId) {
    final list = getListById(listId);
    if (list == null) return false;
    final currentPubkey = _authService.currentPublicKeyHex;
    if (currentPubkey == null || currentPubkey.isEmpty) return false;
    return list.pubkey == null || list.pubkey == currentPubkey;
  }
```

- [ ] **Step 2: Add l10n keys**

Add these exact keys to `mobile/lib/l10n/app_en.arb`:

```json
  "curatedListActionsTooltip": "List actions",
  "curatedListUnfollowAction": "Unfollow list",
  "curatedListUnfollowedSnack": "Unfollowed list",
  "curatedListUnfollowFailed": "Couldn't unfollow list",
  "listDeleteAction": "Delete list"
```

If the ARB consistency tool reports missing locale keys and no real translations are being added, add these exact keys to `_knownUntranslatedDebt` in `mobile/test/l10n/arb_consistency_test.dart` with a comment naming this feature.

- [ ] **Step 3: Generate l10n**

Run:

```bash
cd mobile
flutter gen-l10n
```

Expected: generated `app_localizations*.dart` files include the new getters.

- [ ] **Step 4: Add list action menu and unfollow handler**

In `CuratedListFeedScreen`, replace the app bar actions:

```dart
actions: [_buildSubscribeAction()],
```

with custom action support:

```dart
actions: [_buildSubscribeAction()],
customActions: [_buildListActionsMenu()],
```

Add a menu method:

```dart
  Widget _buildListActionsMenu() {
    final serviceAsync = ref.watch(curatedListsStateProvider);
    final service = ref.read(curatedListsStateProvider.notifier).service;
    final isSubscribed =
        serviceAsync.whenOrNull(
          data: (_) => service?.isSubscribedToList(widget.listId),
        ) ??
        false;
    final isOwned = service?.isOwnedList(widget.listId) ?? false;

    if (!isSubscribed || isOwned) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<_CuratedListAction>(
      tooltip: context.l10n.curatedListActionsTooltip,
      icon: const Icon(Icons.more_horiz, color: VineTheme.whiteText),
      color: VineTheme.surfaceContainer,
      onSelected: (action) {
        switch (action) {
          case _CuratedListAction.unfollow:
            _unfollowList();
          case _CuratedListAction.delete:
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _CuratedListAction.unfollow,
          child: Text(context.l10n.curatedListUnfollowAction),
        ),
      ],
    );
  }
```

Add the enum near the top of the file:

```dart
enum _CuratedListAction { unfollow, delete }
```

Add the handler:

```dart
  Future<void> _unfollowList() async {
    final service = ref.read(curatedListsStateProvider.notifier).service;
    final messenger = ScaffoldMessenger.of(context);
    final didUnfollow = await service?.unsubscribeFromList(widget.listId) ?? false;

    if (!mounted) return;

    if (didUnfollow) {
      ref.invalidate(curatedListsProvider);
      setState(() {});
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.curatedListUnfollowedSnack)),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.curatedListUnfollowFailed),
        backgroundColor: VineTheme.likeRed,
      ),
    );
  }
```

- [ ] **Step 5: Run GREEN tests**

Run:

```bash
cd mobile
flutter test --no-pub test/screens/curated_list_feed_screen_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Slice 1**

Run:

```bash
git add mobile/lib/screens/curated_list_feed_screen.dart mobile/lib/services/curated_list_service.dart mobile/lib/l10n mobile/test/l10n/arb_consistency_test.dart mobile/test/screens/curated_list_feed_screen_test.dart
git commit -m "feat(lists): unfollow external curated lists"
```

---

## Task 3: Owned Delete Slice, Part A - People List Tests

**Files:**
- Modify: `mobile/test/screens/user_list_people_screen_test.dart`
- Later modify: `mobile/lib/screens/user_list_people_screen.dart`

- [ ] **Step 1: Write RED tests for people-list delete**

Append these tests to the `group(UserListPeopleScreen, () { ... })` block in `mobile/test/screens/user_list_people_screen_test.dart`:

```dart
    testWidgets('shows delete action when current list is editable', (
      tester,
    ) async {
      final bloc = _MockPeopleListsBloc();
      final list = _buildList(id: 'owned-list', name: 'Owned List');
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey:
              'f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0',
          lists: [list],
        ),
      );

      await tester.pumpWidget(
        testProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: UserListPeopleScreen(listId: list.id),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('List actions'));
      await tester.pumpAndSettle();

      expect(find.text('Delete list'), findsOneWidget);
    });

    testWidgets('hides delete action when current list is read-only', (
      tester,
    ) async {
      final bloc = _MockPeopleListsBloc();
      final list = _buildList(
        id: 'system-list',
        name: 'System List',
        isEditable: false,
      );
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey:
              'f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0',
          lists: [list],
        ),
      );

      await tester.pumpWidget(
        testProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: UserListPeopleScreen(listId: list.id),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('List actions'), findsNothing);
    });

    testWidgets('delete confirmation cancel does not dispatch', (tester) async {
      final bloc = _MockPeopleListsBloc();
      final list = _buildList(id: 'owned-list', name: 'Owned List');
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey:
              'f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0',
          lists: [list],
        ),
      );

      await tester.pumpWidget(
        testProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: UserListPeopleScreen(listId: list.id),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('List actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(PeopleListsDeleteRequested(listId: list.id)));
    });

    testWidgets('delete confirmation dispatches delete and pops route', (
      tester,
    ) async {
      final bloc = _MockPeopleListsBloc();
      final list = _buildList(id: 'owned-list', name: 'Owned List');
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey:
              'f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0',
          lists: [list],
        ),
      );

      final router = GoRouter(
        initialLocation: '/people-lists/${list.id}',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/people-lists/:listId',
            builder: (context, state) => BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: UserListPeopleScreen(listId: state.pathParameters['listId']!),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        testProviderScope(
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('List actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(PeopleListsDeleteRequested(listId: list.id))).called(1);
      expect(find.text('Home'), findsOneWidget);
    });
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```bash
cd mobile
flutter test --no-pub test/screens/user_list_people_screen_test.dart --plain-name "shows delete action when current list is editable"
```

Expected: FAIL because `UserListPeopleScreen` has no list action menu.

---

## Task 4: Owned Delete Slice, Part A - People List Implementation

**Files:**
- Modify: `mobile/lib/screens/user_list_people_screen.dart`
- Modify: `mobile/lib/l10n/app_en.arb`
- Generated: `mobile/lib/l10n/generated/app_localizations*.dart`
- Modify: `mobile/test/l10n/arb_consistency_test.dart` if fallback debt is used.

- [ ] **Step 1: Add l10n keys**

Add these exact keys to `mobile/lib/l10n/app_en.arb`:

```json
  "peopleListsActionsTooltip": "List actions",
  "peopleListsDeleteConfirmTitle": "Delete list?",
  "peopleListsDeleteConfirmBody": "This removes the list for everyone. The people in it will not be unfollowed."
```

Run:

```bash
cd mobile
flutter gen-l10n
```

If real translations are not added, add the new keys to `_knownUntranslatedDebt` in `mobile/test/l10n/arb_consistency_test.dart`.

- [ ] **Step 2: Add people-list actions menu**

In `UserListPeopleScreen`, add a private enum:

```dart
enum _PeopleListAction { delete }
```

In the editable actions block, keep the add-people action and add a menu:

```dart
                if (userList.isEditable)
                  DiVineAppBarAction(
                    icon: const MaterialIconSource(Icons.person_add_alt_1),
                    tooltip: context.l10n.peopleListsAddPeopleTooltip,
                    semanticLabel:
                        context.l10n.peopleListsAddPeopleSemanticLabel,
                    onPressed: () => _navigateToAddPeople(userList.id),
                  ),
```

becomes:

```dart
                if (userList.isEditable) ...[
                  DiVineAppBarAction(
                    icon: const MaterialIconSource(Icons.person_add_alt_1),
                    tooltip: context.l10n.peopleListsAddPeopleTooltip,
                    semanticLabel:
                        context.l10n.peopleListsAddPeopleSemanticLabel,
                    onPressed: () => _navigateToAddPeople(userList.id),
                  ),
                ],
              ],
              customActions: [
                if (userList.isEditable) _PeopleListActionsMenu(userList: userList),
              ],
```

Add the menu widget below `_PeopleListAppBarTitle`:

```dart
class _PeopleListActionsMenu extends StatelessWidget {
  const _PeopleListActionsMenu({required this.userList});

  final UserList userList;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_PeopleListAction>(
      tooltip: context.l10n.peopleListsActionsTooltip,
      icon: const Icon(Icons.more_horiz, color: VineTheme.whiteText),
      color: VineTheme.surfaceContainer,
      onSelected: (action) {
        switch (action) {
          case _PeopleListAction.delete:
            _confirmDeletePeopleList(context, userList);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _PeopleListAction.delete,
          child: Text(
            context.l10n.listDeleteAction,
            style: VineTheme.bodyMediumFont(color: VineTheme.error),
          ),
        ),
      ],
    );
  }
}
```

Add the confirmation helper:

```dart
Future<void> _confirmDeletePeopleList(
  BuildContext context,
  UserList userList,
) async {
  final l10n = context.l10n;
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: VineTheme.surfaceContainer,
      title: Text(l10n.peopleListsDeleteConfirmTitle),
      content: Text(l10n.peopleListsDeleteConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            l10n.commonDelete,
            style: VineTheme.labelMediumFont(color: VineTheme.error),
          ),
        ),
      ],
    ),
  );

  if (shouldDelete != true || !context.mounted) return;

  context.read<PeopleListsBloc>().add(
    PeopleListsDeleteRequested(listId: userList.id),
  );
  Navigator.of(context).maybePop();
}
```

- [ ] **Step 3: Run people-list tests**

Run:

```bash
cd mobile
flutter test --no-pub test/screens/user_list_people_screen_test.dart
```

Expected: PASS.

---

## Task 5: Owned Delete Slice, Part B - Curated List Tests

**Files:**
- Modify: `mobile/test/services/curated_list_service_crud_test.dart`
- Modify: `mobile/test/screens/curated_list_feed_screen_test.dart`
- Later modify: `mobile/lib/services/curated_list_service.dart`
- Later modify: `mobile/lib/screens/curated_list_feed_screen.dart`

- [ ] **Step 1: Add RED service tests**

Add this import near the existing `nostr_sdk` imports:

```dart
import 'package:nostr_sdk/event_kind.dart';
```

Add this test pubkey constant near the mock class declarations:

```dart
const _ownerPubkey =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
```

Replace the `currentPublicKeyHex` stub in `setUp` with:

```dart
      when(() => mockAuth.currentPublicKeyHex).thenReturn(_ownerPubkey);
```

Replace the common `mockAuth.createAndSignEvent` stub in `setUp` so tests can inspect the actual kind, content, and tags passed by the service:

```dart
      when(
        () => mockAuth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        final kind = invocation.namedArguments[#kind] as int;
        final content = invocation.namedArguments[#content] as String;
        final tags = invocation.namedArguments[#tags] as List<List<String>>;
        return Event.fromJson({
          'id':
              'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          'pubkey': _ownerPubkey,
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': kind,
          'tags': tags,
          'content': content,
          'sig':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        });
      });
```

In `mobile/test/services/curated_list_service_crud_test.dart`, add this group after `deleteList()`:

```dart
    group('deleteOwnedList()', () {
      test('publishes NIP-09 deletion for owned kind 30005 list', () async {
        final list = await service.createList(name: 'Relay List');

        final result = await service.deleteOwnedList(list!.id);

        expect(result, isTrue);
        final published = verify(
          () => mockNostr.publishEvent(captureAny()),
        ).captured.last as Event;

        expect(published.kind, equals(EventKind.eventDeletion));
        expect(published.content, equals('Deleted curated list ${list.id}'));
        expect(
          published.tags,
          contains([
            'a',
            '30005:$_ownerPubkey:${list.id}',
          ]),
        );
        expect(published.tags, contains(['k', '30005']));
        expect(service.getListById(list.id), isNull);
      });

      test('keeps local list when publish fails', () async {
        final list = await service.createList(name: 'Relay List');
        when(() => mockNostr.publishEvent(any())).thenAnswer(
          (_) async => const PublishFailure(error: 'relay unavailable'),
        );

        final result = await service.deleteOwnedList(list!.id);

        expect(result, isFalse);
        expect(service.getListById(list.id), isNotNull);
      });

      test('removes owned private list without publishing deletion event', () async {
        final list = await service.createList(
          name: 'Local List',
          isPublic: false,
        );

        final result = await service.deleteOwnedList(list!.id);

        expect(result, isTrue);
        expect(service.getListById(list.id), isNull);
        verifyNever(() => mockNostr.publishEvent(any()));
      });
    });
```

- [ ] **Step 2: Add RED widget test for owned curated delete action**

Append to `mobile/test/screens/curated_list_feed_screen_test.dart`:

```dart
    testWidgets('shows delete list action for owned curated list', (
      tester,
    ) async {
      when(() => service.isOwnedList('owned-list')).thenReturn(true);
      when(() => service.isSubscribedToList('owned-list')).thenReturn(true);

      await tester.pumpWidget(
        buildSubject(
          listId: 'owned-list',
          listName: 'Owned Mix',
          authorPubkey:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('List actions'));
      await tester.pumpAndSettle();

      expect(find.text('Delete list'), findsOneWidget);
      expect(find.text('Unfollow list'), findsNothing);
    });
```

- [ ] **Step 3: Run tests to verify RED**

Run:

```bash
cd mobile
flutter test --no-pub test/services/curated_list_service_crud_test.dart --plain-name "publishes NIP-09 deletion for owned kind 30005 list"
flutter test --no-pub test/screens/curated_list_feed_screen_test.dart --plain-name "shows delete list action for owned curated list"
```

Expected: both FAIL because `deleteOwnedList` and delete UI do not exist.

---

## Task 6: Owned Delete Slice, Part B - Curated List Implementation

**Files:**
- Modify: `mobile/lib/services/curated_list_service.dart`
- Modify: `mobile/lib/screens/curated_list_feed_screen.dart`
- Modify: `mobile/lib/l10n/app_en.arb`
- Generated: `mobile/lib/l10n/generated/app_localizations*.dart`
- Modify: `mobile/test/l10n/arb_consistency_test.dart` if fallback debt is used.

- [ ] **Step 1: Add l10n keys**

Add these exact keys to `mobile/lib/l10n/app_en.arb`:

```json
  "curatedListDeleteConfirmTitle": "Delete list?",
  "curatedListDeleteConfirmBody": "This removes the list from relays. Videos in the list will not be deleted.",
  "curatedListDeletedSnack": "Deleted list",
  "curatedListDeleteFailed": "Couldn't delete list"
```

Run:

```bash
cd mobile
flutter gen-l10n
```

If real translations are not added, add the new keys to `_knownUntranslatedDebt` in `mobile/test/l10n/arb_consistency_test.dart`.

- [ ] **Step 2: Add protocol-backed delete method**

Add this import in `mobile/lib/services/curated_list_service.dart`:

```dart
import 'package:nostr_sdk/event_kind.dart';
```

In `CuratedListService`, add:

```dart
  /// Deletes an owned curated video list.
  ///
  /// Public lists publish a NIP-09 deletion before local removal. Private lists
  /// are local-only, so they can be removed without relay publication.
  Future<bool> deleteOwnedList(String listId) async {
    if (listId == defaultListId) return false;

    final listIndex = _lists.indexWhere((list) => list.id == listId);
    if (listIndex == -1) return false;
    if (!isOwnedList(listId)) return false;

    final list = _lists[listIndex];
    final currentPubkey = _authService.currentPublicKeyHex;
    if (list.isPublic && (!_authService.isAuthenticated || currentPubkey == null)) {
      return false;
    }

    try {
      if (list.isPublic) {
        final tags = <List<String>>[
          ['a', '30005:$currentPubkey:$listId'],
          ['k', '30005'],
        ];
        final event = await _authService.createAndSignEvent(
          kind: EventKind.eventDeletion,
          content: 'Deleted curated list $listId',
          tags: tags,
        );
        if (event == null) return false;

        final sent = await _nostrService.publishEvent(event);
        if (sent is! PublishSuccess) return false;
      }

      _lists.removeAt(listIndex);
      _subscribedListIds.remove(listId);
      await _saveLists();
      await _saveSubscribedListIds();
      _onListUnsubscribed?.call(listId);
      return true;
    } catch (error, stackTrace) {
      Log.error(
        'Failed to delete curated list $listId',
        name: 'CuratedListService',
        category: LogCategory.relay,
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
```

- [ ] **Step 3: Wire owned curated-list delete UI**

In `_buildListActionsMenu`, add the owned branch:

```dart
    if (!isSubscribed && !isOwned) {
      return const SizedBox.shrink();
    }
```

Set menu items:

```dart
      itemBuilder: (context) => [
        if (isOwned)
          PopupMenuItem(
            value: _CuratedListAction.delete,
            child: Text(
              context.l10n.listDeleteAction,
              style: VineTheme.bodyMediumFont(color: VineTheme.error),
            ),
          )
        else if (isSubscribed)
          PopupMenuItem(
            value: _CuratedListAction.unfollow,
            child: Text(context.l10n.curatedListUnfollowAction),
          ),
      ],
```

Handle delete:

```dart
          case _CuratedListAction.delete:
            _confirmDeleteList();
```

Add confirmation handler:

```dart
  Future<void> _confirmDeleteList() async {
    final l10n = context.l10n;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VineTheme.surfaceContainer,
        title: Text(l10n.curatedListDeleteConfirmTitle),
        content: Text(l10n.curatedListDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.commonDelete,
              style: VineTheme.labelMediumFont(color: VineTheme.error),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    final service = ref.read(curatedListsStateProvider.notifier).service;
    final deleted = await service?.deleteOwnedList(widget.listId) ?? false;

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (deleted) {
      ref.invalidate(curatedListsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.curatedListDeletedSnack)),
      );
      Navigator.of(context).maybePop();
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.curatedListDeleteFailed),
        backgroundColor: VineTheme.likeRed,
      ),
    );
  }
```

- [ ] **Step 4: Run curated tests**

Run:

```bash
cd mobile
flutter test --no-pub test/services/curated_list_service_crud_test.dart --plain-name "publishes NIP-09 deletion for owned kind 30005 list"
flutter test --no-pub test/services/curated_list_service_crud_test.dart --plain-name "keeps local list when publish fails"
flutter test --no-pub test/services/curated_list_service_crud_test.dart --plain-name "removes owned private list without publishing deletion event"
flutter test --no-pub test/screens/curated_list_feed_screen_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit Slice 2**

Run:

```bash
git add mobile/lib/screens/user_list_people_screen.dart mobile/lib/screens/curated_list_feed_screen.dart mobile/lib/services/curated_list_service.dart mobile/lib/l10n mobile/test/l10n/arb_consistency_test.dart mobile/test/screens/user_list_people_screen_test.dart mobile/test/screens/curated_list_feed_screen_test.dart mobile/test/services/curated_list_service_crud_test.dart
git commit -m "feat(lists): delete owned lists"
```

---

## Task 7: Final Verification

**Files:**
- No new implementation files.

- [ ] **Step 1: Run l10n consistency helper**

Run:

```bash
python3 ~/.codex/skills/divine-mobile-l10n-pr-check/scripts/check_divine_mobile_l10n.py
```

Expected: no missing non-allowlisted keys.

- [ ] **Step 2: Run focused tests**

Run:

```bash
cd mobile
flutter test --no-pub test/screens/curated_list_feed_screen_test.dart
flutter test --no-pub test/screens/user_list_people_screen_test.dart
flutter test --no-pub test/services/curated_list_service_crud_test.dart
flutter test --no-pub test/l10n/arb_consistency_test.dart --plain-name "all locales define the same message keys as app_en.arb"
```

Expected: PASS.

- [ ] **Step 3: Run analysis**

Run:

```bash
cd mobile
flutter analyze
```

Expected: no new errors or warnings.

- [ ] **Step 4: Review diff**

Run:

```bash
git diff --stat origin/main...HEAD
git diff --check
git status --short --branch
```

Expected: no whitespace errors; only files from this plan changed; worktree clean after commits.
