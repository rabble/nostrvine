# Post-publish confirmation: View / Share instead of "Record a Video"

Date: 2026-08-15

## Problem

When a background publish completes, the app shows a floating snackbar
reading "Video published to your profile". For half of all users the
snackbar's single action button reads **"Record a Video"**.

That is the wrong offer. A creator who has just published wants to see
the thing they made, or send it to someone. Offering "record another"
as the *only* affordance treats the moment as a funnel step rather than
a payoff, and there is no way to dismiss the snackbar other than waiting
it out or swiping.

The requested confirmation instead offers: **dismiss (X)**, **view the
video**, and **share it**.

## Existing behaviour this replaces

`_showPublishSuccessSnackbar` in `mobile/lib/main.dart` builds a
`SnackBar` whose `action:` is populated only when
`PostPublishExperiment.completed(...)` returns a non-null offer — that
is, only for the `createAgain` arm of a live 50/50 experiment bucketed
on `sha256(pubkeyHex)[0] < 128`.

- `control` — snackbar with no action.
- `createAgain` — snackbar with a "Record a Video" action that pushes
  the recorder and logs `post_publish_create_again_tapped`.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Experiment | **Keep the harness, swap arm B.** | A measured comparison of "good confirmation vs. nothing" is worth more than shipping blind. Control keeps the bare snackbar. |
| Surface | **`VineBottomSheet`** with thumbnail, View, Share, and a close X. | A `SnackBar` has exactly one `action:` slot, so X + View + Share cannot fit. `showDialog`/`showModalBottomSheet` trip `check_raw_dialog_ceiling.sh`; `VineBottomSheet` is the sanctioned component. |
| Timing | **Sheet only when the user is still on their own profile**; bare snackbar otherwise. | The publish completes in the background and can land minutes later while the user is mid-feed or in a DM. A snackbar over that is mild; a modal sheet is an ambush. |
| Multi-publish | When more than one video lands in the same emission, **fall back to the plural snackbar**. | A sheet shows one thumbnail and navigates to one video. Two videos have no correct single target. |
| Share action | **OS share sheet with the canonical video URL**, not the full in-app share sheet. | The in-app sheet (`ShareActionButton.showShareSheet`) requires a fully-hydrated `VideoEvent` — id, pubkey, title, thumbnail URL, full JSON. Seconds after publish the event may not yet be resolvable from Funnelcake or any relay, so that path can dead-end. The URL is derivable from the d-tag alone and always works. The rich sheet stays one tap away on the video detail screen. |

### Variant renaming

`createAgain` is no longer what arm B does, so the enum case and its
analytics name change rather than being reused. Old and new data must
not mix in one bucket name.

- `PostPublishVariant.createAgain` (`'create_again'`) →
  `PostPublishVariant.viewShare` (`'view_share'`)
- `post_publish_create_again_tapped` →
  `post_publish_view_tapped` and `post_publish_share_tapped`
- `post_publish_screen_shown` is unchanged.

## Identity plumbing

The confirmation needs to answer "which video?", and today the success
path discards that.

`VideoEventPublisher.publishVideoEvent` returns a bare `bool`;
`PublishSuccess` carries only `inviteWarnings` and `audioReuseDegraded`;
`BackgroundPublishState.recentlySucceededIds` holds *draft* ids.

The fix is narrow because the needed identifier is already in scope
where `PublishSuccess` is constructed:

```
video_publish_service.dart:453   PublishSuccess(...)   <- pendingUpload.videoId is live here
```

`pendingUpload.videoId` is the NIP-33 `d` tag, which is also
`VideoEvent.stableId`. That single value unlocks both actions with no
relay round-trip:

- **View** — `RoutePaths.videoDetailForId(stableId)`. The `/video/:id`
  route's `_VideoRouteCandidate.parse` already accepts a bare stableId
  (`videos_repository.dart:3194`), alongside hex ids, `note1`,
  `nevent1`, `naddr1`, and raw coordinates.
- **Share** — `https://divine.video/video/<stableId>`, the exact string
  `VideoSharingService.generateShareUrl` produces today.

**No change to `video_event_publisher.dart` is required.**

### Layer-by-layer changes

1. **`PublishSuccess`** gains `final String? stableId`, populated from
   `pendingUpload.videoId`. Nullable because a legacy upload without a
   `videoId` must still report success.

2. **`BackgroundPublishState`** replaces the raw
   `Set<String> recentlySucceededIds` field with
   `List<PublishedVideo> recentlyPublished`, and re-exposes
   `recentlySucceededIds` as a derived getter so existing consumers
   (`comments_screen.dart:629,653`) are untouched. One source of truth
   rather than two parallel collections.

   ```dart
   class PublishedVideo extends Equatable {
     const PublishedVideo({
       required this.draftId,
       this.stableId,
       this.thumbnailPath,
       this.title,
     });
     // ...
   }
   ```

   `thumbnailPath` comes from `DivineVideoDraft.coverThumbnailPath`
   (`customThumbnailPath ?? finalRenderedClip?.thumbnailPath ??
   clips.first.thumbnailPath`) — a local file, renderable immediately
   with no network fetch.

3. **`VideoSharingService`** gains a pure
   `static String shareUrlForStableId(String stableId)`;
   `generateShareUrl(video)` delegates to it. Removes the duplication
   the sheet would otherwise introduce.

4. **`PostPublishConfirmationOffer`** (renamed from
   `PostPublishCreateAgainOffer`) carries `publishedAt` and the
   `PublishedVideo`.

## The sheet

New file: `mobile/lib/features/post_publish/view/post_publish_confirmation_sheet.dart`

```
┌──────────────────────────────────────┐
│                                   ✕  │
│         ┌──────────┐                 │
│         │  thumb   │                 │
│         └──────────┘                 │
│      Published to your profile       │
│                                      │
│   [   View   ]     [   Share   ]     │
└──────────────────────────────────────┘
```

- Opened via `VineBottomSheet.show<void>(context: ..., body: ...)`
  with `scrollable: false, expanded: false` — the fixed-height pattern
  from `CommentOptionsModal.showForOwnComment`.
- Close X is the sheet's `headerTrailingAction` (`DivineIconButton`).
- Buttons are `DivineButton`; no raw Material buttons.
- **Colours read `context.vineColors.<token>`**, not static
  `VineTheme.*` constants. Divine now ships light *and* dark
  appearances; the sheet is an app surface, not media chrome, so it
  must adapt. Only the thumbnail's letterbox fill stays static, since
  its ground is a video frame.
- Thumbnail is `Image.file` on the local path, `ExcludeSemantics`-free
  and given a `semanticLabel`; a missing/absent path renders a plain
  placeholder rather than failing.
- The sheet takes plain data (`stableId`, `thumbnailPath`, callbacks) —
  no repository or provider reads — so it is testable in isolation.

### l10n

New keys in `app_en.arb`, mirrored to every other `app_*.arb` locale or
added to `_knownUntranslatedDebt`:

| Key | English |
|---|---|
| `postPublishConfirmationTitle` | Published to your profile |
| `postPublishConfirmationView` | View |
| `postPublishConfirmationShare` | Share |
| `postPublishConfirmationThumbnailLabel` | Thumbnail of the video you just published |

Existing near-misses (`contentWarningView`, `authShare`,
`saveOriginalShare`) are deliberately *not* reused: they are
feature-scoped keys whose meaning in this context would be wrong, and
translators need the post-publish context.

## Listener branching

`_showPublishSuccessSnackbar` becomes a dispatcher. Given `count`,
`offer`, and `container`:

```
if count == 1
   && offer != null                     (arm B)
   && offer.video.stableId != null
   && the router is on the signed-in user's own profile
→ show the sheet
otherwise
→ show today's bare snackbar (no action)
```

"On own profile" is decided by a pure predicate rather than router
mocking gymnastics:

```dart
bool isOwnProfileLocation(String location, String npub) {
  final route = parseRoute(location);
  return route.type == RouteType.profile && route.npub == npub;
}
```

The location comes from
`router.routerDelegate.currentConfiguration.uri.path` — the same
accessor `StartupSplashReleaseController` already uses
(`main.dart:1893`). Buffering/replay for the unauthenticated window is
unchanged; a buffered success that replays after the user has navigated
away simply takes the snackbar branch.

## Testing

TDD, red before green, extending
`mobile/test/widgets/upload_failure_listener_test.dart` and adding:

- `mobile/test/features/post_publish/post_publish_experiment_test.dart`
- `mobile/test/features/post_publish/view/post_publish_confirmation_sheet_test.dart`
- `mobile/test/blocs/background_publish/background_publish_bloc_test.dart` (extend)
- `mobile/test/services/video_sharing_service_test.dart` (extend)

Cases that must be able to fail:

| Case | Assertion |
|---|---|
| Arm B, single video, on own profile | sheet visible, snackbar absent |
| Arm B, single video, on the feed | snackbar visible, sheet absent |
| Arm B, two videos at once | plural snackbar, sheet absent |
| Arm B, `stableId == null` | snackbar, sheet absent |
| Control arm, on own profile | snackbar with no action |
| Tap View | router pushed `/video/<stableId>`, `post_publish_view_tapped` logged |
| Tap Share | OS share invoked with the canonical URL, `post_publish_share_tapped` logged |
| Tap X | sheet dismissed, nothing navigated |
| `isOwnProfileLocation` | true for own profile grid + feed index, false for another npub, false for `/home/0` |
| Bloc | `recentlyPublished` carries stableId/thumbnail/title; `recentlySucceededIds` still derives correctly |
| `shareUrlForStableId` | matches `generateShareUrl` for the same video |

Widget tests pumping the sheet supply
`AppLocalizations.localizationsDelegates` / `supportedLocales`, and
assert on ARB-resolved strings, never hardcoded English.

## Out of scope

- Replacing the in-app share sheet's `VideoEvent` requirement with a
  coordinate-based path. Worth doing, but it is a change to
  `ShareSheetBloc` and `VideoCrosspostCubit` with its own blast radius.
- Any change to the control arm.
- Any change to the publish navigation (`context.go` to profile).
- The failure-sheet path (`showUploadFailureSheet`), untouched.
