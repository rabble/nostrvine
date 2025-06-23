// ABOUTME: Unit tests for CommentsProvider state management and optimistic updates
// ABOUTME: Tests comment loading, posting, threading, and error handling

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/providers/comments_provider.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/models/comment.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

// Generate mocks
@GenerateMocks([
  SocialService,
  AuthService,
])
import 'comments_provider_test.mocks.dart';

void main() {
  group('CommentsProvider Unit Tests', () {
    late MockSocialService mockSocialService;
    late MockAuthService mockAuthService;
    late CommentsProvider commentsProvider;
    
    // Valid 64-character hex pubkeys for testing
    const testVideoEventId = 'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
    const testVideoAuthorPubkey = 'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a';
    const testCurrentUserPubkey = 'c3d4e5f6789012345678901234567890abcdef123456789012345678901234ab';
    const testCommentContent = 'This is a test comment';
    
    setUp(() {
      mockSocialService = MockSocialService();
      mockAuthService = MockAuthService();
      
      // Default setup for auth service
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(testCurrentUserPubkey);
      
      // Mock empty comment stream by default
      when(mockSocialService.fetchCommentsForEvent(any))
          .thenAnswer((_) => const Stream<Event>.empty());
    });

    CommentsProvider createProvider() {
      return CommentsProvider(
        socialService: mockSocialService,
        authService: mockAuthService,
        rootEventId: testVideoEventId,
        rootAuthorPubkey: testVideoAuthorPubkey,
      );
    }

    group('Initial State', () {
      test('should initialize with correct root event ID', () {
        // Act
        commentsProvider = createProvider();
        
        // Assert
        expect(commentsProvider.state.rootEventId, equals(testVideoEventId));
        expect(commentsProvider.state.topLevelComments, isEmpty);
        expect(commentsProvider.state.totalCommentCount, equals(0));
        expect(commentsProvider.state.error, isNull);
      });

      test('should start loading comments on initialization', () {
        // Act
        commentsProvider = createProvider();
        
        // Assert
        verify(mockSocialService.fetchCommentsForEvent(testVideoEventId)).called(1);
      });
    });

    group('Comment Loading', () {
      test('should parse comment events correctly', () async {
        // Arrange
        final testCommentEvent = Event(
          testCurrentUserPubkey,
          1,
          [
            ['e', testVideoEventId, '', 'root'],
            ['p', testVideoAuthorPubkey],
          ],
          testCommentContent,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        
        when(mockSocialService.fetchCommentsForEvent(testVideoEventId))
            .thenAnswer((_) => Stream.fromIterable([testCommentEvent]));
        
        // Act
        commentsProvider = createProvider();
        await Future.delayed(const Duration(milliseconds: 100)); // Allow stream processing
        
        // Assert
        expect(commentsProvider.state.topLevelComments.length, equals(1));
        expect(commentsProvider.state.topLevelComments.first.comment.content, equals(testCommentContent));
        expect(commentsProvider.state.totalCommentCount, equals(1));
      });

      test('should handle comment event parsing errors gracefully', () async {
        // Arrange - Create an invalid event that will cause parsing errors
        final invalidEvent = Event(
          'invalid_pubkey', // This will cause parsing to fail
          1,
          [], // Missing required tags
          testCommentContent,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        
        when(mockSocialService.fetchCommentsForEvent(testVideoEventId))
            .thenAnswer((_) => Stream.fromIterable([invalidEvent]));
        
        // Act
        commentsProvider = createProvider();
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Assert - Should not crash, just ignore the invalid event
        expect(commentsProvider.state.topLevelComments, isEmpty);
        expect(commentsProvider.state.totalCommentCount, equals(0));
      });

      test('should build hierarchical comment tree', () async {
        // Arrange
        final parentCommentEvent = Event(
          testCurrentUserPubkey,
          1,
          [
            ['e', testVideoEventId, '', 'root'],
            ['p', testVideoAuthorPubkey],
          ],
          'Parent comment',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        
        final replyCommentEvent = Event(
          'd4e5f6789012345678901234567890abcdef123456789012345678901234abc',
          1,
          [
            ['e', testVideoEventId, '', 'root'],
            ['p', testVideoAuthorPubkey],
            ['e', parentCommentEvent.id, '', 'reply'],
            ['p', testCurrentUserPubkey],
          ],
          'Reply comment',
          createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 1,
        );
        
        when(mockSocialService.fetchCommentsForEvent(testVideoEventId))
            .thenAnswer((_) => Stream.fromIterable([parentCommentEvent, replyCommentEvent]));
        
        // Act
        commentsProvider = createProvider();
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Assert
        expect(commentsProvider.state.topLevelComments.length, equals(1));
        expect(commentsProvider.state.topLevelComments.first.replies.length, equals(1));
        expect(commentsProvider.state.totalCommentCount, equals(2));
      });
    });

    group('Comment Posting', () {
      test('should show optimistic update immediately', () async {
        // Arrange
        commentsProvider = createProvider();
        
        // Mock delayed posting to test optimistic update
        when(mockSocialService.postComment(
          content: testCommentContent,
          rootEventId: testVideoEventId,
          rootEventAuthorPubkey: testVideoAuthorPubkey,
        )).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        
        // Act
        final postFuture = commentsProvider.postComment(content: testCommentContent);
        
        // Assert - Check optimistic update happened immediately
        expect(commentsProvider.state.topLevelComments.length, equals(1));
        expect(commentsProvider.state.topLevelComments.first.comment.content, equals(testCommentContent));
        expect(commentsProvider.state.topLevelComments.first.comment.authorPubkey, equals(testCurrentUserPubkey));
        expect(commentsProvider.state.topLevelComments.first.comment.id.startsWith('temp_'), isTrue);
        
        // Wait for posting to complete
        await postFuture;
        
        // Verify social service was called
        verify(mockSocialService.postComment(
          content: testCommentContent,
          rootEventId: testVideoEventId,
          rootEventAuthorPubkey: testVideoAuthorPubkey,
        )).called(1);
      });

      test('should handle authentication error', () async {
        // Arrange
        when(mockAuthService.isAuthenticated).thenReturn(false);
        commentsProvider = createProvider();
        
        // Act
        await commentsProvider.postComment(content: testCommentContent);
        
        // Assert
        expect(commentsProvider.state.error, contains('Please sign in to comment'));
        verifyNever(mockSocialService.postComment(
          content: any,
          rootEventId: any,
          rootEventAuthorPubkey: any,
        ));
      });

      test('should handle empty comment content', () async {
        // Arrange
        commentsProvider = createProvider();
        
        // Act
        await commentsProvider.postComment(content: '   '); // Only whitespace
        
        // Assert
        expect(commentsProvider.state.error, contains('Comment cannot be empty'));
        verifyNever(mockSocialService.postComment(
          content: any,
          rootEventId: any,
          rootEventAuthorPubkey: any,
        ));
      });

      test('should remove optimistic update on posting failure', () async {
        // Arrange
        commentsProvider = createProvider();
        
        when(mockSocialService.postComment(
          content: testCommentContent,
          rootEventId: testVideoEventId,
          rootEventAuthorPubkey: testVideoAuthorPubkey,
        )).thenThrow(Exception('Network error'));
        
        // Act
        await commentsProvider.postComment(content: testCommentContent);
        
        // Assert
        expect(commentsProvider.state.topLevelComments, isEmpty);
        expect(commentsProvider.state.error, contains('Failed to post comment'));
      });

      test('should add reply to correct parent comment', () async {
        // Arrange
        final parentComment = Comment(
          id: 'parent_comment_id',
          content: 'Parent comment',
          authorPubkey: testCurrentUserPubkey,
          createdAt: DateTime.now(),
          rootEventId: testVideoEventId,
          rootAuthorPubkey: testVideoAuthorPubkey,
        );
        
        // Simulate existing parent comment
        commentsProvider = createProvider();
        commentsProvider.state.commentCache['parent_comment_id'] = parentComment;
        
        when(mockSocialService.postComment(
          content: testCommentContent,
          rootEventId: testVideoEventId,
          rootEventAuthorPubkey: testVideoAuthorPubkey,
          replyToEventId: 'parent_comment_id',
          replyToAuthorPubkey: testCurrentUserPubkey,
        )).thenAnswer((_) async {});
        
        // Act
        await commentsProvider.postComment(
          content: testCommentContent,
          replyToEventId: 'parent_comment_id',
          replyToAuthorPubkey: testCurrentUserPubkey,
        );
        
        // Assert
        verify(mockSocialService.postComment(
          content: testCommentContent,
          rootEventId: testVideoEventId,
          rootEventAuthorPubkey: testVideoAuthorPubkey,
          replyToEventId: 'parent_comment_id',
          replyToAuthorPubkey: testCurrentUserPubkey,
        )).called(1);
      });
    });

    group('State Management', () {
      test('should notify listeners on state changes', () {
        // Arrange
        var notificationCount = 0;
        commentsProvider = createProvider();
        commentsProvider.addListener(() {
          notificationCount++;
        });
        
        // Act
        commentsProvider.postComment(content: testCommentContent);
        
        // Assert
        expect(notificationCount, greaterThan(0));
      });

      test('should update comment count correctly', () async {
        // Arrange
        final comment1Event = Event(
          testCurrentUserPubkey,
          1,
          [
            ['e', testVideoEventId, '', 'root'],
            ['p', testVideoAuthorPubkey],
          ],
          'Comment 1',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        
        final comment2Event = Event(
          'other_user_pubkey_123456789012345678901234567890abcdef123456789012',
          1,
          [
            ['e', testVideoEventId, '', 'root'],
            ['p', testVideoAuthorPubkey],
          ],
          'Comment 2',
          createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 1,
        );
        
        when(mockSocialService.fetchCommentsForEvent(testVideoEventId))
            .thenAnswer((_) => Stream.fromIterable([comment1Event, comment2Event]));
        
        // Act
        commentsProvider = createProvider();
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Assert
        expect(commentsProvider.state.totalCommentCount, equals(2));
      });

      test('should clear error state when posting new comment', () async {
        // Arrange
        commentsProvider = createProvider();
        
        // Simulate an error state
        await commentsProvider.postComment(content: ''); // This will set an error
        expect(commentsProvider.state.error, isNotNull);
        
        when(mockSocialService.postComment(
          content: testCommentContent,
          rootEventId: testVideoEventId,
          rootEventAuthorPubkey: testVideoAuthorPubkey,
        )).thenAnswer((_) async {});
        
        // Act
        await commentsProvider.postComment(content: testCommentContent);
        
        // Assert
        expect(commentsProvider.state.error, isNull);
      });
    });
  });
}