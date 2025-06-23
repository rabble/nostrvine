// ABOUTME: Integration test for comment posting to verify Nostr event creation and UI updates
// ABOUTME: Tests that comments create proper Kind 1 events, send to relays, and update UI immediately

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/providers/comments_provider.dart';
import 'package:openvine/models/comment.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

// Generate mocks
@GenerateMocks([
  INostrService,
  AuthService,
])
import 'comment_posting_integration_test.mocks.dart';
void main() {
  group('Comment Posting Integration Tests', () {
    late MockINostrService mockNostrService;
    late MockAuthService mockAuthService;
    late SocialService socialService;
    late CommentsProvider commentsProvider;
    
    const testVideoEventId = 'test_video_event_123';
    const testVideoAuthorPubkey = 'test_video_author_pubkey_456';
    const testCurrentUserPubkey = 'test_current_user_pubkey_789';
    const testCommentContent = 'This is a test comment';
    
    setUp(() {
      mockNostrService = MockINostrService();
      mockAuthService = MockAuthService();
      
      // Setup auth service defaults
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(testCurrentUserPubkey);
      
      socialService = SocialService(mockNostrService, mockAuthService);
      commentsProvider = CommentsProvider(
        socialService: socialService,
        authService: mockAuthService,
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
      );
    });

    testWidgets('Comment posting creates correct Nostr Kind 1 event', (WidgetTester tester) async {
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
      
      final testBroadcastResult = NostrBroadcastResult(
        event: testEvent,
        successCount: 1,
        totalRelays: 1,
        results: const {'relay1': true},
        errors: const {},
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
      
      when(mockNostrService.broadcastEvent(any))
          .thenAnswer((_) async => testBroadcastResult);
      
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

    testWidgets('Comment posting with reply creates correct event tags', (WidgetTester tester) async {
      // Arrange
      const replyToEventId = 'reply_to_event_456';
      const replyToAuthorPubkey = 'reply_to_author_789';
      
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
      
      final testBroadcastResult = NostrBroadcastResult(
        event: testEvent,
        successCount: 1,
        totalRelays: 1,
        results: const {'relay1': true},
        errors: const {},
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
      
      when(mockNostrService.broadcastEvent(any))
          .thenAnswer((_) async => testBroadcastResult);
      
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

    testWidgets('CommentsProvider shows optimistic update before relay confirmation', (WidgetTester tester) async {
      // Arrange
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
      
      final testBroadcastResult = NostrBroadcastResult(
        event: testEvent,
        successCount: 1,
        totalRelays: 1,
        results: const {'relay1': true},
        errors: const {},
      );
      
      // Setup mocks with delay to test optimistic update
      when(mockAuthService.createAndSignEvent(
        kind: any,
        tags: any,
        content: any,
      )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return testEvent;
      });
      
      when(mockNostrService.broadcastEvent(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 200));
        return testBroadcastResult;
      });
      
      // Mock the comment loading stream (empty initially)
      when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
          .thenAnswer((_) => const Stream.empty());
      
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
        tags: any,
        content: testCommentContent,
      )).called(1);
      
      verify(mockNostrService.broadcastEvent(any)).called(1);
    });

    testWidgets('Failed comment posting removes optimistic update', (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.createAndSignEvent(
        kind: any,
        tags: any,
        content: any,
      )).thenThrow(Exception('Failed to create event'));
      
      // Mock the comment loading stream (empty)
      when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
          .thenAnswer((_) => const Stream.empty());
      
      // Act - Post comment (should fail)
      try {
        await commentsProvider.postComment(content: testCommentContent);
      } catch (e) {
        // Expected to fail
      }
      
      // Assert - Optimistic comment should be removed
      expect(commentsProvider.state.topLevelComments.length, equals(0));
      expect(commentsProvider.state.error, isNotNull);
    });

    testWidgets('Comment event structure matches Nostr NIP-10 threading specification', (WidgetTester tester) async {
      // Arrange
      const replyToEventId = 'parent_comment_123';
      const replyToAuthorPubkey = 'parent_author_456';
      
      Event? capturedEvent;
      
      when(mockAuthService.createAndSignEvent(
        kind: any,
        tags: any,
        content: any,
      )).thenAnswer((invocation) async {
        final kind = invocation.namedArguments[#kind] as int;
        final tags = invocation.namedArguments[#tags] as List<List<String>>;
        final content = invocation.namedArguments[#content] as String;
        
        capturedEvent = Event(
          testCurrentUserPubkey,
          kind,
          tags,
          content,
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

    testWidgets('CommentsProvider handles concurrent comment posts correctly', (WidgetTester tester) async {
      // Arrange
      const comment1 = 'First comment';
      const comment2 = 'Second comment';
      
      when(mockAuthService.createAndSignEvent(
        kind: any,
        tags: any,
        content: any,
      )).thenAnswer((invocation) async {
        final content = invocation.namedArguments[#content] as String;
        await Future.delayed(const Duration(milliseconds: 50));
        return Event(
          testCurrentUserPubkey,
          1,
          [
            ['e', testVideoEventId, '', 'root'],
            ['p', testVideoAuthorPubkey],
          ],
          content,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
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
      
      when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
          .thenAnswer((_) => const Stream.empty());
      
      // Act - Post two comments concurrently
      final future1 = commentsProvider.postComment(content: comment1);
      final future2 = commentsProvider.postComment(content: comment2);
      
      // Assert - Both optimistic comments should appear immediately
      expect(commentsProvider.state.topLevelComments.length, equals(2));
      
      // Wait for both to complete
      await Future.wait([future1, future2]);
      
      // Verify both events were created and broadcast
      verify(mockAuthService.createAndSignEvent(
        kind: 1,
        tags: any,
        content: comment1,
      )).called(1);
      
      verify(mockAuthService.createAndSignEvent(
        kind: 1,
        tags: any,
        content: comment2,
      )).called(1);
      
      verify(mockNostrService.broadcastEvent(any)).called(2);
    });
  });
}