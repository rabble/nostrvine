# User Profile Editing Screen

## Description
Users currently can view profiles but cannot edit their own profile information. We need a comprehensive profile editing interface that allows users to update their Nostr profile metadata.

## Current State
- Profile viewing works in `ProfileScreen`
- User info is pulled from Nostr profile events
- No editing capabilities exist

## Proposed Solution
Create a new profile editing screen with the following features:

### UI Components Needed
- **Profile Picture**: Image picker with crop functionality
- **Banner Image**: Wide image picker for profile header  
- **Display Name**: Text input with character limit
- **Bio/About**: Multi-line text input with character counter
- **Website**: URL input with validation
- **Location**: Optional text input
- **Save/Cancel Buttons**: With confirmation dialog for unsaved changes

### Technical Requirements
- Form validation (character limits, URL format)
- Image upload handling (resize/compress before upload)
- Nostr profile event creation and broadcasting
- Loading states during save operation
- Error handling for network failures

### User Flow
1. User taps "Edit Profile" button on ProfileScreen
2. Navigate to ProfileEditScreen with current data pre-filled
3. User makes changes and taps Save
4. Show loading spinner while uploading images and broadcasting event
5. Show success/error feedback
6. Navigate back to ProfileScreen with updated data

## Acceptance Criteria
- [ ] Profile edit screen accessible from ProfileScreen
- [ ] All profile fields are editable
- [ ] Image picker works for profile and banner images
- [ ] Form validation prevents invalid data
- [ ] Changes are saved to Nostr network
- [ ] Loading and error states are handled
- [ ] Profile updates reflect immediately in UI

## Files to Modify
- `lib/screens/profile_screen.dart` - Add edit button
- `lib/screens/profile_edit_screen.dart` - New file
- `lib/services/user_profile_service.dart` - Add update methods
- `lib/widgets/image_picker_widget.dart` - New reusable component

## Priority
High - Core user functionality for social app

## Labels
`enhancement`, `ui`, `profile`, `nostr`