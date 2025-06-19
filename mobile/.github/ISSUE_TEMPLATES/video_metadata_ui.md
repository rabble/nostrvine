# Video Creation Metadata UI

## Description
Currently when users record videos, the title, description, and hashtags are hardcoded to placeholder values. We need a proper metadata input interface for users to add context to their videos before publishing.

## Current State
- Video recording works in `CameraScreen`
- Metadata is hardcoded at `camera_screen.dart:645-647`:
  ```dart
  title: 'Vine Video', // TODO: Allow user to set title
  description: 'Created with NostrVine', // TODO: Allow user to set description
  hashtags: ['nostrvine', 'vine'], // TODO: Allow user to set hashtags
  ```

## Proposed Solution
Add a metadata input screen after video recording but before upload:

### UI Components Needed
- **Video Preview**: Small preview of recorded video with play/pause
- **Title Input**: Single line text field with character limit (100 chars)
- **Description Input**: Multi-line text area with character limit (500 chars)
- **Hashtag Input**: Smart hashtag input with suggestions and validation
  - Type-ahead suggestions from popular hashtags
  - Remove hashtags with tap
  - Automatic `#` prefix
- **Publish/Discard Buttons**: Clear actions with confirmation

### Technical Requirements
- Smooth transition from camera recording to metadata screen
- Real-time character counting with visual feedback
- Hashtag validation (no spaces, special chars)
- Save draft state if user navigates away
- Integration with existing upload pipeline

### User Flow
1. User finishes recording video in CameraScreen
2. Transition to VideoMetadataScreen with video preview
3. User adds title, description, hashtags
4. User taps "Publish" to start upload with metadata
5. Or taps "Discard" to delete video and return to camera

### Advanced Features (Future)
- Save as draft for later publishing
- Hashtag suggestions based on video content analysis
- Location tagging option
- Audience/privacy settings

## Acceptance Criteria
- [ ] Metadata screen appears after successful video recording
- [ ] Video preview plays smoothly in background
- [ ] All input fields work with proper validation
- [ ] Character limits are enforced with visual feedback
- [ ] Hashtag input has smart UX (suggestions, easy removal)
- [ ] Metadata is properly passed to upload pipeline
- [ ] Draft saving works if user navigates away
- [ ] Publish/Discard actions work correctly

## Files to Modify
- `lib/screens/camera_screen.dart` - Navigate to metadata screen after recording
- `lib/screens/video_metadata_screen.dart` - New file
- `lib/widgets/hashtag_input_widget.dart` - Reusable hashtag input
- `lib/widgets/character_counter_widget.dart` - Reusable counter
- `lib/services/upload_manager.dart` - Accept metadata parameters

## Priority
High - Essential for user-generated content quality

## Labels
`enhancement`, `ui`, `camera`, `metadata`, `ux`