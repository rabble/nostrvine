// ABOUTME: Simplified integration test for comment posting to verify Nostr event creation and UI updates
// ABOUTME: Tests that comments create proper Kind 1 events, send to relays, and update UI immediately

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/providers/comments_provider.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

// Generate mocks
@GenerateMocks([
  INostrService,
  AuthService,
])
import 'comment_posting_simple_test.mocks.dart';

void main() {
  group('Comment Posting Integration Tests', () {
    late MockINostrService mockNostrService;
    late MockAuthService mockAuthService;
    late SocialService socialService;
    
    // Use valid 64-character hex pubkeys for testing
    const testVideoEventId = 'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
    const testVideoAuthorPubkey = 'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a';
    const testCurrentUserPubkey = 'c3d4e5f6789012345678901234567890abcdef123456789012345678901234ab';
    const testCommentContent = 'This is a test comment';
    
    setUp(() {
      mockNostrService = MockINostrService();
      mockAuthService = MockAuthService();
      
      // Setup auth service defaults
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(testCurrentUserPubkey);
      
      // Mock subscribeToEvents to return empty streams by default
      when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
          .thenAnswer((_) => const Stream<Event>.empty());
      
      socialService = SocialService(mockNostrService, mockAuthService);
    });

    tearDown(() {
      socialService.dispose();
    });

    test('SocialService.postComment creates correct Nostr Kind 1 event', () async {
      // Arrange
      final testEvent = Event(
        testCurrentUserPubkey,
        1, // Kind 1 (text note)
        [
          ['e', testVideoEventId, '', 'root'],
          ['p', testVideoAuthorPubkey],
        ],
        testCommentContent,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      
      // Setup mocks
      when(mockAuthService.createAndSignEvent(
        kind: 1,
        tags: [
          ['e', testVideoEventId, '', 'root'],
          ['p', testVideoAuthorPubkey],
        ],
        content: testCommentContent,
      )).thenAnswer((_) async => testEvent);
      
      when(mockNostrService.broadcastEvent(testEvent))
          .thenAnswer((_) async => NostrBroadcastResult(
            event: testEvent,
            successCount: 1,
            totalRelays: 1,
            results: const {'relay1': true},
            errors: const {},
          ));
      
      // Act
      await socialService.postComment(
        content: testCommentContent,
        rootEventId: testVideoEventId,
        rootEventAuthorPubkey: testVideoAuthorPubkey,
      );
      
      // Assert - Verify correct event was created
      verify(mockAuthService.createAndSignEvent(
        kind: 1, // Text note for comments
        tags: [
          ['e', testVideoEventId, '', 'root'], // Root event tag
          ['p', testVideoAuthorPubkey],         // Root author tag
        ],
        content: testCommentContent,
      )).called(1);
      
      // Verify event was broadcast to relays
      verify(mockNostrService.broadcastEvent(testEvent)).called(1);
    });

    test('SocialService.postComment with reply creates correct event tags', () async {
      // Arrange
      const replyToEventId = 'd4e5f6789012345678901234567890abcdef123456789012345678901234abc';
      const replyToAuthorPubkey = 'e5f6789012345678901234567890abcdef123456789012345678901234abcd';
      
      final testEvent = Event(
        testCurrentUserPubkey,
        1,
        [
          ['e', testVideoEventId, '', 'root'],
          ['p', testVideoAuthorPubkey],
          ['e', replyToEventId, '', 'reply'],
          ['p', replyToAuthorPubkey],
        ],
        testCommentContent,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      
      // Setup mocks
      when(mockAuthService.createAndSignEvent(
        kind: 1,
        tags: [
          ['e', testVideoEventId, '', 'root'],
          ['p', testVideoAuthorPubkey],
          ['e', replyToEventId, '', 'reply'],
          ['p', replyToAuthorPubkey],
        ],
        content: testCommentContent,
      )).thenAnswer((_) async => testEvent);
      
      when(mockNostrService.broadcastEvent(testEvent))
          .thenAnswer((_) async => NostrBroadcastResult(
            event: testEvent,
            successCount: 1,
            totalRelays: 1,
            results: const {'relay1': true},
            errors: const {},
          ));
      
      // Act
      await socialService.postComment(
        content: testCommentContent,
        rootEventId: testVideoEventId,
        rootEventAuthorPubkey: testVideoAuthorPubkey,
        replyToEventId: replyToEventId,
        replyToAuthorPubkey: replyToAuthorPubkey,
      );
      
      // Assert - Verify correct reply event was created
      verify(mockAuthService.createAndSignEvent(
        kind: 1,
        tags: [
          ['e', testVideoEventId, '', 'root'],   // Root video event
          ['p', testVideoAuthorPubkey],           // Root video author
          ['e', replyToEventId, '', 'reply'],     // Reply to comment
          ['p', replyToAuthorPubkey],             // Reply to comment author
        ],
        content: testCommentContent,
      )).called(1);
      
      verify(mockNostrService.broadcastEvent(testEvent)).called(1);
    });

    test('CommentsProvider shows optimistic update immediately', () async {
      // Arrange
      late CommentsProvider commentsProvider;
      
      // Mock empty comment stream initially
      when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
          .thenAnswer((_) => const Stream<Event>.empty());
      
      commentsProvider = CommentsProvider(
        socialService: socialService,
        authService: mockAuthService,
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
      );
      
      // Wait for initial loading to complete
      await Future.delayed(const Duration(milliseconds: 100));
      
      final testEvent = Event(
        testCurrentUserPubkey,
        1,
        [
          ['e', testVideoEventId, '', 'root'],
          ['p', testVideoAuthorPubkey],
        ],
        testCommentContent,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      
      // Setup mocks with delay to test optimistic update
      when(mockAuthService.createAndSignEvent(
        kind: 1,
        tags: [
          ['e', testVideoEventId, '', 'root'],
          ['p', testVideoAuthorPubkey],
        ],
        content: testCommentContent,
      )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return testEvent;
      });
      
      when(mockNostrService.broadcastEvent(testEvent)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 200));
        return NostrBroadcastResult(
          event: testEvent,
          successCount: 1,
          totalRelays: 1,
          results: const {'relay1': true},
          errors: const {},
        );
      });
      
      // Act - Post comment
      final commentsFuture = commentsProvider.postComment(content: testCommentContent);
      
      // Assert - Check optimistic update happened immediately
      expect(commentsProvider.state.topLevelComments.length, equals(1));
      expect(commentsProvider.state.topLevelComments.first.comment.content, equals(testCommentContent));
      expect(commentsProvider.state.topLevelComments.first.comment.authorPubkey, equals(testCurrentUserPubkey));
      expect(commentsProvider.state.topLevelComments.first.comment.id.startsWith('temp_'), isTrue);
      
      // Wait for actual posting to complete
      await commentsFuture;
      
      // Verify event was created and broadcast
      verify(mockAuthService.createAndSignEvent(
        kind: 1,
        tags: [
          ['e', testVideoEventId, '', 'root'],
          ['p', testVideoAuthorPubkey],
        ],
        content: testCommentContent,
      )).called(1);
      
      verify(mockNostrService.broadcastEvent(testEvent)).called(1);
    });

    test('Event structure follows NIP-10 threading specification', () async {
      // Arrange
      const replyToEventId = 'f6789012345678901234567890abcdef123456789012345678901234abcde';
      const replyToAuthorPubkey = '789012345678901234567890abcdef123456789012345678901234abcdef';
      
      Event? capturedEvent;
      
      when(mockAuthService.createAndSignEvent(
        kind: 1,
        tags: [
          ['e', testVideoEventId, '', 'root'],
          ['p', testVideoAuthorPubkey],
          ['e', replyToEventId, '', 'reply'],
          ['p', replyToAuthorPubkey],
        ],
        content: testCommentContent,
      )).thenAnswer((invocation) async {
        capturedEvent = Event(
          testCurrentUserPubkey,
          1,
          [
            ['e', testVideoEventId, '', 'root'],
            ['p', testVideoAuthorPubkey],
            ['e', replyToEventId, '', 'reply'],
            ['p', replyToAuthorPubkey],
          ],
          testCommentContent,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        return capturedEvent!;
      });
      
      when(mockNostrService.broadcastEvent(any))
          .thenAnswer((invocation) async {
            final event = invocation.positionalArguments[0] as Event;
            return NostrBroadcastResult(
              event: event,
              successCount: 1,
              totalRelays: 1,
              results: const {'relay1': true},
              errors: const {},
            );
          });
      
      // Act
      await socialService.postComment(
        content: testCommentContent,
        rootEventId: testVideoEventId,
        rootEventAuthorPubkey: testVideoAuthorPubkey,
        replyToEventId: replyToEventId,
        replyToAuthorPubkey: replyToAuthorPubkey,
      );
      
      // Assert - Verify NIP-10 compliant event structure
      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.kind, equals(1)); // Kind 1 for text notes
      expect(capturedEvent!.content, equals(testCommentContent));
      expect(capturedEvent!.pubkey, equals(testCurrentUserPubkey));
      
      // Verify NIP-10 tag structure
      final tags = capturedEvent!.tags;
      
      // Should have root event tag with marker
      final rootTag = tags.firstWhere(
        (tag) => tag.length >= 4 && tag[0] == 'e' && tag[1] == testVideoEventId && tag[3] == 'root',
        orElse: () => [],
      );
      expect(rootTag.isNotEmpty, isTrue, reason: 'Missing root event tag');
      
      // Should have root author tag
      final rootAuthorTag = tags.firstWhere(
        (tag) => tag.length >= 2 && tag[0] == 'p' && tag[1] == testVideoAuthorPubkey,
        orElse: () => [],
      );
      expect(rootAuthorTag.isNotEmpty, isTrue, reason: 'Missing root author tag');
      
      // Should have reply event tag with marker
      final replyTag = tags.firstWhere(
        (tag) => tag.length >= 4 && tag[0] == 'e' && tag[1] == replyToEventId && tag[3] == 'reply',
        orElse: () => [],
      );
      expect(replyTag.isNotEmpty, isTrue, reason: 'Missing reply event tag');
      
      // Should have reply author tag
      final replyAuthorTag = tags.firstWhere(
        (tag) => tag.length >= 2 && tag[0] == 'p' && tag[1] == replyToAuthorPubkey,
        orElse: () => [],
      );
      expect(replyAuthorTag.isNotEmpty, isTrue, reason: 'Missing reply author tag');
    });
  });
}