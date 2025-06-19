# Upload Progress & Queue Management UI

## Description
With the new background upload pipeline, users need better visibility into their upload progress and queue status. Currently there's only a basic progress indicator - we need a comprehensive upload management interface.

## Current State
- Basic upload progress shown in `CameraScreen` via `CompactUploadProgress`
- Upload states managed by `UploadManager` service
- No way to view upload history or manage queue
- Limited error visibility for failed uploads

## Proposed Solution
Create a comprehensive upload management interface accessible from multiple screens:

### Main Upload Status Panel
**Location**: Accessible via bottom sheet from main navigation
- **Active Uploads**: Current uploads with progress bars
- **Queue**: Pending uploads waiting to start
- **History**: Recent completed/failed uploads (last 10)
- **Retry Actions**: For failed uploads

### UI Components Needed
- **Upload List Items**: 
  - Video thumbnail
  - Upload progress (0-100%)
  - Status (uploading, processing, publishing, failed)
  - Metadata (title, file size, duration)
  - Action buttons (retry, cancel, delete)

- **Status Indicators**:
  - Progress bars with percentage
  - Status badges with colors
  - Error messages for failures
  - Estimated time remaining

- **Management Actions**:
  - Pause/resume uploads
  - Cancel active uploads
  - Retry failed uploads
  - Clear completed uploads

### Upload Status Types
1. **Pending** - In queue, not started
2. **Uploading** - Currently uploading to Cloudinary
3. **Processing** - Video being processed by backend
4. **Publishing** - Publishing to Nostr network
5. **Published** - Successfully published
6. **Failed** - Failed with error message

### Integration Points
- **Camera Screen**: Quick upload status in bottom corner
- **Profile Screen**: Upload history accessible from menu
- **Navigation**: Badge with active upload count
- **Notifications**: Progress updates and completion alerts

## Technical Requirements
- Real-time updates from `UploadManager` service
- Efficient UI updates (don't rebuild entire list)
- Proper error handling and retry logic
- Upload analytics (success rate, average time)
- Memory management for upload history

## User Experience Goals
- Users always know what's happening with their uploads
- Easy to retry failed uploads
- Clear feedback on why uploads failed
- Non-intrusive progress indication
- Quick access without disrupting main app flow

## Acceptance Criteria
- [ ] Upload status panel accessible from navigation
- [ ] Real-time progress updates for active uploads
- [ ] Upload queue shows pending items
- [ ] Upload history shows recent activity
- [ ] Failed uploads clearly show error messages
- [ ] Retry functionality works for failed uploads
- [ ] Cancel/pause functionality works for active uploads
- [ ] Upload statistics are tracked and displayed
- [ ] Notifications work for upload completion
- [ ] UI performance remains smooth with multiple uploads

## Files to Create/Modify
- `lib/screens/upload_manager_screen.dart` - New upload management screen
- `lib/widgets/upload_status_panel.dart` - Main upload panel widget
- `lib/widgets/upload_list_item.dart` - Individual upload item
- `lib/widgets/upload_progress_indicator.dart` - Enhanced progress widget
- `lib/services/upload_manager.dart` - Add UI state methods
- `lib/screens/camera_screen.dart` - Integrate with new upload UI

## Priority
Medium - Improves user confidence and upload reliability

## Labels
`enhancement`, `ui`, `uploads`, `ux`, `background-processing`