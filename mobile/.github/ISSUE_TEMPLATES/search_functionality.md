# Search Functionality & UI

## Description
The app currently has no search functionality. Users need to be able to search for other users, videos, and hashtags to discover content and connect with others in the Nostr network.

## Current State
- No search interface exists
- Search button in `FeedScreen` has TODO comment at line 65
- User discovery is limited to random feed content
- No way to find specific users or content

## Proposed Solution
Implement a comprehensive search interface with multiple search types:

### Search Types
1. **Users**: Search by display name, username, npub
2. **Videos**: Search by title, description, hashtags
3. **Hashtags**: Discover trending and popular hashtags

### UI Components Needed

#### Search Screen Layout
- **Search Bar**: Sticky header with search input
- **Filter Tabs**: Switch between Users, Videos, Hashtags
- **Results List**: Scrollable results with appropriate item layouts
- **Empty States**: When no results found
- **Loading States**: During search requests

#### User Search Results
- **User List Items**:
  - Profile picture
  - Display name and username
  - Bio preview (first line)
  - Follow button
  - Follow count

#### Video Search Results  
- **Video List Items**:
  - Video thumbnail
  - Title and creator
  - Duration and view count
  - Hashtags preview
  - Tap to play/view

#### Hashtag Search Results
- **Hashtag List Items**:
  - Hashtag name
  - Usage count
  - Recent video thumbnails using hashtag
  - Tap to see hashtag feed

### Search Features
- **Real-time Search**: Results update as user types (with debouncing)
- **Search History**: Recent searches saved locally
- **Popular Suggestions**: Show trending content when search is empty
- **Advanced Filters**: Filter by date, duration, etc.
- **Search Analytics**: Track popular searches (privacy-conscious)

### Technical Implementation
- **Search API**: New endpoints in `ApiService`
- **Search Service**: Dedicated service for search operations
- **Local Caching**: Cache recent results for offline viewing
- **Nostr Integration**: Search across connected relays
- **Performance**: Efficient search with pagination

### User Flow
1. User taps search icon in main navigation
2. Navigate to SearchScreen with empty state
3. User starts typing in search bar
4. Real-time results appear below
5. User can switch between filter tabs
6. Tap result to view user profile or video
7. Search history saved for future use

## Acceptance Criteria
- [ ] Search screen accessible from main navigation
- [ ] Search bar works with real-time results
- [ ] User search finds Nostr profiles
- [ ] Video search works by title/description/hashtags
- [ ] Hashtag search shows popular tags
- [ ] Filter tabs switch between search types
- [ ] Search results are properly formatted
- [ ] Empty and loading states work correctly
- [ ] Search history is saved and displayed
- [ ] Tapping results navigates to appropriate screens
- [ ] Search performance is smooth (debounced, cached)

## Files to Create/Modify
- `lib/screens/search_screen.dart` - New search interface
- `lib/services/search_service.dart` - Search logic and API calls
- `lib/widgets/search_bar_widget.dart` - Reusable search input
- `lib/widgets/user_search_item.dart` - User result list item
- `lib/widgets/video_search_item.dart` - Video result list item
- `lib/widgets/hashtag_search_item.dart` - Hashtag result list item
- `lib/services/api_service.dart` - Add search endpoints
- `lib/screens/feed_screen.dart` - Connect search button to new screen

## Future Enhancements
- Voice search capability
- Search within user's own videos
- Saved searches and search alerts
- AI-powered content recommendations
- Location-based search results

## Priority
Medium - Important for content discovery and user engagement

## Labels
`enhancement`, `ui`, `search`, `discovery`, `nostr`