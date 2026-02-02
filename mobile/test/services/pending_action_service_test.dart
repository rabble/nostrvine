// ABOUTME: Unit tests for PendingActionService
// ABOUTME: Tests offline action queuing, sync on reconnect, and action
// ABOUTME: cancellation using Drift database

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/pending_action_service.dart';

class MockConnectionStatusService extends Mock
    implements ConnectionStatusService {}

void main() {
  late PendingActionService service;
  late MockConnectionStatusService mockConnectionService;
  late AppDatabase database;
  late PendingActionsDao dao;

  const testUserPubkey = 'test_user_pubkey_123';

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(PendingActionType.like);
  });

  setUp(() async {
    // Create in-memory database for testing
    database = AppDatabase.test(NativeDatabase.memory(logStatements: false));
    dao = database.pendingActionsDao;

    mockConnectionService = MockConnectionStatusService();

    // Default to online
    when(() => mockConnectionService.isOnline).thenReturn(true);

    service = PendingActionService(
      connectionStatusService: mockConnectionService,
      pendingActionsDao: dao,
      userPubkey: testUserPubkey,
    );

    await service.initialize();
  });

  tearDown(() async {
    service.dispose();
    await database.close();
  });

  group('PendingActionService', () {
    group('initialization', () {
      test('initializes successfully', () async {
        expect(service.isInitialized, isTrue);
        expect(service.pendingActions, isEmpty);
      });

      test('loads existing actions from database on init', () async {
        // Queue an action
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        expect(service.pendingActions.length, equals(1));

        // Set offline to prevent auto-sync when new service initializes
        when(() => mockConnectionService.isOnline).thenReturn(false);

        // Create a new service instance to simulate app restart
        final newService = PendingActionService(
          connectionStatusService: mockConnectionService,
          pendingActionsDao: dao,
          userPubkey: testUserPubkey,
        );
        await newService.initialize();

        expect(newService.pendingActions.length, equals(1));
        expect(newService.pendingActions.first.targetId, equals('event123'));

        newService.dispose();
      });
    });

    group('queueAction', () {
      test('queues a like action', () async {
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
          addressableId: '34236:author123:video1',
          targetKind: 34236,
        );

        expect(service.pendingActions.length, equals(1));

        final action = service.pendingActions.first;
        expect(action.type, equals(PendingActionType.like));
        expect(action.targetId, equals('event123'));
        expect(action.authorPubkey, equals('author123'));
        expect(action.addressableId, equals('34236:author123:video1'));
        expect(action.targetKind, equals(34236));
        expect(action.status, equals(PendingActionStatus.pending));
      });

      test('queues a follow action', () async {
        await service.queueAction(
          type: PendingActionType.follow,
          targetId: 'pubkey123',
        );

        expect(service.pendingActions.length, equals(1));

        final action = service.pendingActions.first;
        expect(action.type, equals(PendingActionType.follow));
        expect(action.targetId, equals('pubkey123'));
      });

      test('cancels opposite actions on same target', () async {
        // Queue a like
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );
        expect(service.pendingActions.length, equals(1));

        // Queue an unlike on same target - should cancel out
        await service.queueAction(
          type: PendingActionType.unlike,
          targetId: 'event123',
          authorPubkey: 'author123',
        );
        expect(service.pendingActions.length, equals(0));
      });

      test('cancels follow/unfollow on same target', () async {
        // Queue a follow
        await service.queueAction(
          type: PendingActionType.follow,
          targetId: 'pubkey123',
        );
        expect(service.pendingActions.length, equals(1));

        // Queue an unfollow on same target - should cancel out
        await service.queueAction(
          type: PendingActionType.unfollow,
          targetId: 'pubkey123',
        );
        expect(service.pendingActions.length, equals(0));
      });

      test('allows multiple actions on different targets', () async {
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event1',
          authorPubkey: 'author1',
        );
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event2',
          authorPubkey: 'author2',
        );
        await service.queueAction(
          type: PendingActionType.follow,
          targetId: 'pubkey1',
        );

        expect(service.pendingActions.length, equals(3));
      });
    });

    group('hasPendingAction', () {
      test('returns true when action exists', () async {
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        expect(
          service.hasPendingAction('event123', PendingActionType.like),
          isTrue,
        );
      });

      test('returns false when action does not exist', () {
        expect(
          service.hasPendingAction('event123', PendingActionType.like),
          isFalse,
        );
      });

      test('returns false for different action type on same target', () async {
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        expect(
          service.hasPendingAction('event123', PendingActionType.unlike),
          isFalse,
        );
      });
    });

    group('cancelAction', () {
      test('removes action from queue', () async {
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        final actionId = service.pendingActions.first.id;
        await service.cancelAction(actionId);

        expect(service.pendingActions, isEmpty);
      });
    });

    group('syncPendingActions', () {
      test('skips sync when offline', () async {
        when(() => mockConnectionService.isOnline).thenReturn(false);

        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        // Register a mock executor that would fail if called
        var executorCalled = false;
        service.registerExecutor(PendingActionType.like, (_) async {
          executorCalled = true;
        });

        await service.syncPendingActions();

        expect(executorCalled, isFalse);
        expect(service.pendingActions.length, equals(1));
      });

      test('syncs actions when online', () async {
        when(() => mockConnectionService.isOnline).thenReturn(true);

        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        // Register executor
        final executedActions = <PendingAction>[];
        service.registerExecutor(PendingActionType.like, (action) async {
          executedActions.add(action);
        });

        await service.syncPendingActions();

        expect(executedActions.length, equals(1));
        expect(executedActions.first.targetId, equals('event123'));
        expect(service.pendingActions, isEmpty);
      });

      test('marks action as failed after max retries', () async {
        when(() => mockConnectionService.isOnline).thenReturn(true);

        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        // Register executor that always fails
        service.registerExecutor(PendingActionType.like, (_) async {
          throw Exception('Network error');
        });

        // Run sync - it will fail
        await service.syncPendingActions();

        // After failure, action should still exist with updated retry count
        final allActions = service.allActions;
        expect(allActions.length, equals(1));
        expect(allActions.first.retryCount, greaterThan(0));
      });
    });

    group('pendingActionsStream', () {
      test('emits updates when actions are added', () async {
        final emissions = <List<PendingAction>>[];
        final subscription = service.pendingActionsStream.listen(emissions.add);

        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event123',
          authorPubkey: 'author123',
        );

        // Allow stream to emit
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(emissions.isNotEmpty, isTrue);
        expect(emissions.last.length, equals(1));

        await subscription.cancel();
      });
    });

    group('clearAll', () {
      test('removes all pending actions', () async {
        await service.queueAction(
          type: PendingActionType.like,
          targetId: 'event1',
          authorPubkey: 'author1',
        );
        await service.queueAction(
          type: PendingActionType.follow,
          targetId: 'pubkey1',
        );

        expect(service.allActions.length, equals(2));

        await service.clearAll();

        expect(service.allActions, isEmpty);
        expect(service.pendingActions, isEmpty);
      });
    });
  });

  group('PendingAction model', () {
    test('creates action with correct default values', () {
      final action = PendingAction.create(
        type: PendingActionType.like,
        targetId: 'event123',
        userPubkey: testUserPubkey,
        authorPubkey: 'author123',
      );

      expect(action.id, isNotEmpty);
      expect(action.type, equals(PendingActionType.like));
      expect(action.targetId, equals('event123'));
      expect(action.status, equals(PendingActionStatus.pending));
      expect(action.retryCount, equals(0));
    });

    test('isPositiveAction returns correct values', () {
      expect(
        PendingAction.create(
          type: PendingActionType.like,
          targetId: 'test',
          userPubkey: testUserPubkey,
        ).isPositiveAction,
        isTrue,
      );
      expect(
        PendingAction.create(
          type: PendingActionType.unlike,
          targetId: 'test',
          userPubkey: testUserPubkey,
        ).isPositiveAction,
        isFalse,
      );
      expect(
        PendingAction.create(
          type: PendingActionType.follow,
          targetId: 'test',
          userPubkey: testUserPubkey,
        ).isPositiveAction,
        isTrue,
      );
    });

    test('oppositeType returns correct type', () {
      final like = PendingAction.create(
        type: PendingActionType.like,
        targetId: 'test',
        userPubkey: testUserPubkey,
      );
      expect(like.oppositeType, equals(PendingActionType.unlike));

      final follow = PendingAction.create(
        type: PendingActionType.follow,
        targetId: 'test',
        userPubkey: testUserPubkey,
      );
      expect(follow.oppositeType, equals(PendingActionType.unfollow));
    });

    test('cancels returns true for opposite actions on same target', () {
      final like = PendingAction.create(
        type: PendingActionType.like,
        targetId: 'event123',
        userPubkey: testUserPubkey,
      );
      final unlike = PendingAction.create(
        type: PendingActionType.unlike,
        targetId: 'event123',
        userPubkey: testUserPubkey,
      );

      expect(like.cancels(unlike), isTrue);
      expect(unlike.cancels(like), isTrue);
    });

    test('cancels returns false for different targets', () {
      final like1 = PendingAction.create(
        type: PendingActionType.like,
        targetId: 'event123',
        userPubkey: testUserPubkey,
      );
      final unlike2 = PendingAction.create(
        type: PendingActionType.unlike,
        targetId: 'event456',
        userPubkey: testUserPubkey,
      );

      expect(like1.cancels(unlike2), isFalse);
    });
  });
}
