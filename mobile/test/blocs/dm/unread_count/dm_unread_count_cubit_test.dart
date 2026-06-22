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
