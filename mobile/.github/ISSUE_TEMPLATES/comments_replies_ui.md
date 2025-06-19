# Comments & Replies Interface

## Description
Videos currently display without any comment functionality. We need to implement a comprehensive commenting system that allows users to comment on videos and reply to each other, following Nostr's reply event structure.

## Current State
- Comment button exists in `VideoFeedItem` but has no implementation
- No comment viewing or creation interface
- TODO comment in `FeedScreen` at line 270 for comment handling
- No NIP-01 reply event handling in the app

## Proposed Solution
Implement a full commenting system with threaded replies:

### UI Components Needed

#### Comment Bottom Sheet
**Triggered by**: Tapping comment button on video
- **Video Info**: Small video preview with creator info
- **Comment List**: Scrollable list of comments and replies
- **Comment Input**: Text input with send button
- **Reply Threading**: Visual indication of reply relationships

#### Comment List Item
- **User Avatar**: Profile picture with tap to view profile
- **User Info**: Display name and timestamp
- **Comment Text**: With hashtag and mention highlighting
- **Actions**: Reply, like, report buttons
- **Reply Indicator**: Show if comment has replies
- **Thread Lines**: Visual threading for nested replies

#### Comment Input
- **Text Field**: Multi-line with character limit (280 chars)
- **Mention Support**: @-mention autocomplete
- **Hashtag Support**: #hashtag highlighting
- **Send Button**: Disabled until valid comment entered
- **Reply Context**: Show which comment being replied to

### Features
- **Threaded Replies**: Support multiple levels of nesting
- **Real-time Updates**: New comments appear without refresh
- **Mention Notifications**: Notify users when mentioned
- **Comment Reactions**: Like/react to comments
- **Comment Moderation**: Report inappropriate comments
- **Offline Support**: Cache comments for offline viewing

### Nostr Integration
- **Comment Events**: Create NIP-01 kind 1 events with proper tags
- **Reply Events**: Use 'e' and 'p' tags for threading
- **Event Fetching**: Subscribe to comment events for videos
- **Real-time**: WebSocket updates for new comments
- **User Profiles**: Fetch commenter profile info

### Technical Implementation
- **Comment Service**: Handle comment creation and fetching
- **Threading Logic**: Build comment trees from flat event list
- **Caching**: Local storage for comment history
- **Performance**: Efficient UI updates for large comment threads
- **Security**: Input validation and sanitization

### User Experience
1. User taps comment button on video
2. Bottom sheet slides up with comment interface
3. Existing comments load and display in threaded view
4. User can scroll through comments and replies
5. Tap reply to start replying to specific comment
6. Type comment with mention/hashtag support
7. Send comment and see it appear in thread
8. Real-time updates show new comments from others

### Advanced Features
- **Comment Search**: Find specific comments
- **Comment Sorting**: By time, popularity, etc.
- **Comment Drafts**: Save unfinished comments
- **Rich Text**: Bold, italic formatting
- **GIF/Emoji Reactions**: Quick response options

## Acceptance Criteria
- [ ] Comment button opens comment bottom sheet
- [ ] Comments load and display in threaded format
- [ ] Users can write and post comments
- [ ] Reply functionality works with proper threading
- [ ] Mentions and hashtags are highlighted and functional
- [ ] Real-time comment updates work
- [ ] Comment like/reaction functionality works
- [ ] User profiles accessible from comment avatars
- [ ] Comment input has proper validation and limits
- [ ] Offline comment viewing works
- [ ] Comment performance is smooth with large threads

## Files to Create/Modify
- `lib/screens/comments_screen.dart` - Main comment interface
- `lib/widgets/comment_bottom_sheet.dart` - Comment modal
- `lib/widgets/comment_list_item.dart` - Individual comment widget
- `lib/widgets/comment_input_widget.dart` - Comment composition
- `lib/widgets/threaded_comment_list.dart` - Threading display logic
- `lib/services/comment_service.dart` - Comment business logic
- `lib/models/comment_event.dart` - Comment data model
- `lib/widgets/video_feed_item.dart` - Connect comment button
- `lib/services/nostr_service.dart` - Add comment event handling

## Priority
Medium - Important for user engagement and community building

## Labels
`enhancement`, `ui`, `comments`, `nostr`, `social`, `threading`