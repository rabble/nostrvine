// ABOUTME: Unit tests for DmUnreadCountCubit.
// ABOUTME: Verifies the badge count mirrors the follow-aware, blocklist-filtered
// ABOUTME: Messages list (accepted union followed-but-unreplied), per #4976.

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockContentPolicyState extends Mock implements ContentPolicyState {}

// Full 64-character hex Nostr IDs for test data — never truncate.
const _me = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const _alice =
    'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4';
const _bob = 'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5';
const _carol =
    'e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6';

DmConversation _convo(
  String id, {
  required String peer,
  required bool isRead,
  required bool currentUserHasSent,
  int timestamp = 1700000000,
}) {
  return DmConversation(
    id: id,
    participantPubkeys: [_me, peer],
    isGroup: false,
    createdAt: timestamp,
    lastMessageTimestamp: timestamp,
    isRead: isRead,
    currentUserHasSent: currentUserHasSent,
  );
}

/// Pad an index into a unique 64-char hex conversation id / pubkey.
String _hex(int i) => i.toRadixString(16).padLeft(64, '0');

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  setUpAll(() {
    registerFallbackValue(<DmConversation>[]);
  });

  group(DmUnreadCountCubit, () {
    late _MockDmRepository dmRepository;
    late _MockFollowRepository followRepository;
    late StreamController<List<DmConversation>> acceptedController;
    late StreamController<List<DmConversation>> potentialController;
    late StreamController<List<String>> followingController;
    late Set<String> followed;

    setUp(() {
      dmRepository = _MockDmRepository();
      followRepository = _MockFollowRepository();
      acceptedController = StreamController<List<DmConversation>>();
      potentialController = StreamController<List<DmConversation>>();
      followingController = StreamController<List<String>>();
      followed = <String>{};

      when(() => dmRepository.userPubkey).thenReturn(_me);
      // Identity stream (#5374): seeded via `.startWith(userPubkey)` in the
      // cubit, so an empty stream suffices for the steady-state value to flow.
      when(
        () => dmRepository.userPubkeyStream,
      ).thenAnswer((_) => const Stream<String>.empty());
      // No-arg stub: this matches only a call WITHOUT a limit, locking in that
      // the badge counts the full (unpaginated) accepted set, not a page.
      when(
        () => dmRepository.watchAcceptedConversations(),
      ).thenAnswer((_) => acceptedController.stream);
      when(
        () => dmRepository.watchPotentialRequests(),
      ).thenAnswer((_) => potentialController.stream);
      when(
        () => followRepository.followingStream,
      ).thenAnswer((_) => followingController.stream);
      when(
        () => followRepository.isFollowing(any()),
      ).thenAnswer((inv) => followed.contains(inv.positionalArguments.first));
    });

    tearDown(() async {
      await acceptedController.close();
      await potentialController.close();
      await followingController.close();
    });

    DmUnreadCountCubit buildCubit({
      ContentBlocklistRepository? contentBlocklistRepository,
    }) {
      return DmUnreadCountCubit(
        dmRepository: dmRepository,
        followRepository: followRepository,
        contentBlocklistRepository: contentBlocklistRepository,
        // Behaviour tests assert the final settled count, not coalescing
        // timing — disable the debounce so a single `_settle()` is enough.
        // The debounce itself is covered by the dedicated coalescing test.
        recomputeDebounce: Duration.zero,
      );
    }

    test('initial state is 0', () {
      final cubit = buildCubit();
      expect(cubit.state, equals(0));
      cubit.close();
    });

    test('stays at 0 when there are no conversations', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      acceptedController.add(const []);
      potentialController.add(const []);
      await _settle();

      expect(cubit.state, equals(0));
    });

    test(
      'counts an unread conversation from a followed peer the user has '
      'never replied to (#4976 regression — old follow-blind count returned 0)',
      () async {
        followed.add(_alice);
        final cubit = buildCubit();
        addTearDown(cubit.close);

        acceptedController.add(const []);
        potentialController.add([
          _convo('c1', peer: _alice, isRead: false, currentUserHasSent: false),
        ]);
        await _settle();

        expect(cubit.state, equals(1));
      },
    );

    test(
      'holds the count while userPubkey is empty, then counts the followed '
      '1:1 once the identity arrives (#5374)',
      () async {
        followed.add(_alice);
        // Cold start: empty pubkey until the identity stream delivers it.
        when(() => dmRepository.userPubkey).thenReturn('');
        final pubkeyController = StreamController<String>();
        addTearDown(pubkeyController.close);
        when(
          () => dmRepository.userPubkeyStream,
        ).thenAnswer((_) => pubkeyController.stream);

        final cubit = buildCubit();
        addTearDown(cubit.close);

        acceptedController.add(const []);
        potentialController.add([
          _convo('c1', peer: _alice, isRead: false, currentUserHasSent: false),
        ]);
        await _settle();
        // Empty pubkey: self cannot be filtered, so the guard holds the count
        // instead of misclassifying the 1:1 as a group and dropping it.
        expect(cubit.state, equals(0));

        pubkeyController.add(_me);
        await _settle();
        // Identity arrived → the followed-but-unreplied 1:1 is counted.
        expect(cubit.state, equals(1));
      },
    );

    test('counts an unread accepted conversation', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      acceptedController.add([
        _convo('c2', peer: _bob, isRead: false, currentUserHasSent: true),
      ]);
      potentialController.add(const []);
      await _settle();

      expect(cubit.state, equals(1));
    });

    test(
      'excludes an unread request from a non-followed peer the user has '
      'never replied to (it is not shown in the Messages list)',
      () async {
        // _carol is not in `followed`, never replied -> classifies as a request.
        final cubit = buildCubit();
        addTearDown(cubit.close);

        acceptedController.add(const []);
        potentialController.add([
          _convo('c3', peer: _carol, isRead: false, currentUserHasSent: false),
        ]);
        await _settle();

        expect(cubit.state, equals(0));
      },
    );

    test('excludes read conversations', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      acceptedController.add([
        _convo('c4', peer: _bob, isRead: true, currentUserHasSent: true),
      ]);
      potentialController.add(const []);
      await _settle();

      expect(cubit.state, equals(0));
    });

    test('counts the full unpaginated accepted set', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      // More than one inbox page of unread accepted conversations.
      final many = List.generate(
        60,
        (i) => _convo(
          _hex(i),
          peer: _hex(1000 + i),
          isRead: false,
          currentUserHasSent: true,
        ),
      );
      acceptedController.add(many);
      potentialController.add(const []);
      await _settle();

      expect(cubit.state, equals(60));
      // The badge must subscribe without a limit (full count, not a page).
      verify(() => dmRepository.watchAcceptedConversations()).called(1);
    });

    test('recomputes when the following list changes', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      acceptedController.add(const []);
      potentialController.add([
        _convo('c5', peer: _alice, isRead: false, currentUserHasSent: false),
      ]);
      await _settle();
      // _alice not followed yet -> request -> not counted.
      expect(cubit.state, equals(0));

      followed.add(_alice);
      followingController.add([_alice]);
      await _settle();
      // Now followed -> appears in the Messages list -> counted.
      expect(cubit.state, equals(1));
    });

    group('blocklist-aware', () {
      late _MockContentBlocklistRepository blocklist;
      late StreamController<ContentPolicyState> stateController;

      setUp(() {
        blocklist = _MockContentBlocklistRepository();
        stateController = StreamController<ContentPolicyState>();
        when(
          () => blocklist.stateStream,
        ).thenAnswer((_) => stateController.stream);
      });

      tearDown(() async {
        await stateController.close();
      });

      test('excludes a blocked unread accepted conversation', () async {
        // Blocklist drops _bob's conversation, mirroring the list.
        when(
          () => blocklist.filterBlockedConversations(
            any(),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenReturn(const <DmConversation>[]);

        final cubit = buildCubit(contentBlocklistRepository: blocklist);
        addTearDown(cubit.close);

        acceptedController.add([
          _convo('c6', peer: _bob, isRead: false, currentUserHasSent: true),
        ]);
        potentialController.add(const []);
        await _settle();

        expect(cubit.state, equals(0));
      });

      test('counts conversations the blocklist passes through', () async {
        when(
          () => blocklist.filterBlockedConversations(
            any(),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer(
          (inv) => inv.positionalArguments.first as List<DmConversation>,
        );

        final cubit = buildCubit(contentBlocklistRepository: blocklist);
        addTearDown(cubit.close);

        acceptedController.add([
          _convo('c7', peer: _bob, isRead: false, currentUserHasSent: true),
        ]);
        potentialController.add(const []);
        await _settle();

        expect(cubit.state, equals(1));
      });

      test('recomputes when the blocklist changes', () async {
        // Initially passes through -> counted.
        when(
          () => blocklist.filterBlockedConversations(
            any(),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer(
          (inv) => inv.positionalArguments.first as List<DmConversation>,
        );

        final cubit = buildCubit(contentBlocklistRepository: blocklist);
        addTearDown(cubit.close);

        acceptedController.add([
          _convo('c8', peer: _bob, isRead: false, currentUserHasSent: true),
        ]);
        potentialController.add(const []);
        await _settle();
        expect(cubit.state, equals(1));

        // Block _bob mid-session: the filter now drops it, and a blocklist
        // state tick must force the badge to recompute.
        when(
          () => blocklist.filterBlockedConversations(
            any(),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenReturn(const <DmConversation>[]);
        stateController.add(_MockContentPolicyState());
        await _settle();

        expect(cubit.state, equals(0));
      });
    });

    test(
      'setRepositories re-points the count at fresh repositories and stops '
      'counting against the stale ones (app-shell auth-ready rebuild, #4976)',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        // Pre-auth repository emits one unread accepted conversation.
        acceptedController.add([
          _convo('c9', peer: _bob, isRead: false, currentUserHasSent: true),
        ]);
        potentialController.add(const []);
        await _settle();
        expect(cubit.state, equals(1));

        // Auth becomes ready: the providers rebuild into fresh instances.
        final dmRepository2 = _MockDmRepository();
        final followRepository2 = _MockFollowRepository();
        final acceptedController2 = StreamController<List<DmConversation>>();
        final potentialController2 = StreamController<List<DmConversation>>();
        final followingController2 = StreamController<List<String>>();
        addTearDown(() async {
          await acceptedController2.close();
          await potentialController2.close();
          await followingController2.close();
        });
        when(() => dmRepository2.userPubkey).thenReturn(_me);
        when(
          () => dmRepository2.userPubkeyStream,
        ).thenAnswer((_) => const Stream<String>.empty());
        when(
          dmRepository2.watchAcceptedConversations,
        ).thenAnswer((_) => acceptedController2.stream);
        when(
          dmRepository2.watchPotentialRequests,
        ).thenAnswer((_) => potentialController2.stream);
        when(
          () => followRepository2.followingStream,
        ).thenAnswer((_) => followingController2.stream);
        when(
          () => followRepository2.isFollowing(any()),
        ).thenReturn(false);

        cubit.setRepositories(
          dmRepository: dmRepository2,
          followRepository: followRepository2,
        );

        // The fresh repository drives the count.
        acceptedController2.add([
          _convo('c10', peer: _bob, isRead: false, currentUserHasSent: true),
          _convo('c11', peer: _carol, isRead: false, currentUserHasSent: true),
        ]);
        potentialController2.add(const []);
        await _settle();
        expect(cubit.state, equals(2));

        // The stale repository must no longer affect the badge.
        acceptedController.add(const []);
        await _settle();
        expect(cubit.state, equals(2));
      },
    );

    test(
      'coalesces a burst of conversation writes into a single recompute '
      '(debounce)',
      () async {
        var filterCalls = 0;
        final blocklist = _MockContentBlocklistRepository();
        final stateController = StreamController<ContentPolicyState>();
        addTearDown(stateController.close);
        when(
          () => blocklist.stateStream,
        ).thenAnswer((_) => stateController.stream);
        // filterBlockedConversations runs once per `_countUnread` pass, so it
        // doubles as a recompute counter.
        when(
          () => blocklist.filterBlockedConversations(
            any(),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((inv) {
          filterCalls++;
          return inv.positionalArguments.first as List<DmConversation>;
        });

        // Real (non-zero) debounce window so the burst is genuinely coalesced.
        final cubit = DmUnreadCountCubit(
          dmRepository: dmRepository,
          followRepository: followRepository,
          contentBlocklistRepository: blocklist,
          recomputeDebounce: const Duration(milliseconds: 100),
        );
        addTearDown(cubit.close);

        potentialController.add(const []);
        // Five rapid accepted-list updates inside the debounce window.
        for (var i = 0; i < 5; i++) {
          acceptedController.add([
            _convo('c$i', peer: _bob, isRead: false, currentUserHasSent: true),
          ]);
        }

        // Still inside the window: the expensive pass has not run yet.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(filterCalls, equals(0));

        // After the window settles: exactly one recompute for the whole burst.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(filterCalls, equals(1));
        expect(cubit.state, equals(1));
      },
    );

    test('cancels subscription on close', () async {
      final cubit = buildCubit();
      await cubit.close();

      // Emitting after close must not throw (subscription cancelled).
      acceptedController.add(const []);
      potentialController.add(const []);
      await _settle();
    });
  });
}
