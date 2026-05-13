// ABOUTME: Full-screen scaffold for editing already-published video metadata.
// ABOUTME: Reuses VideoMetadataFormFields from the capture stack.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart' hide AspectRatio;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory, NIP71VideoKinds;
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_cover_screen.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/utils/collaborator_tags.dart';
import 'package:openvine/widgets/share_video_menu.dart'
    show extractEngagementCountTags, sendPostPublishCollaboratorInvites;
import 'package:openvine/widgets/video_metadata/modes/edit/video_metadata_edit_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_form_fields.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Full-screen scaffold for editing an already-published [VideoEvent].
///
/// Wraps an inner [ProviderScope] so that [videoEditorProvider] is isolated
/// from any pre-existing capture flow. The editor state is pre-seeded from
/// [video] via [VideoEditorNotifier.initFromPublishedVideo].
class VideoMetadataEditStack extends StatefulWidget {
  const VideoMetadataEditStack({required this.video, super.key});

  final VideoEvent video;

  @override
  State<VideoMetadataEditStack> createState() => _VideoMetadataEditStackState();
}

class _VideoMetadataEditStackState extends State<VideoMetadataEditStack> {
  late final Set<String> _initialCollaboratorPubkeys;

  @override
  void initState() {
    super.initState();
    _initialCollaboratorPubkeys = widget.video.collaboratorPubkeys.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        videoEditorProvider.overrideWith(VideoEditorNotifier.new),
      ],
      child: _VideoMetadataEditStackContent(
        video: widget.video,
        initialCollaboratorPubkeys: _initialCollaboratorPubkeys,
      ),
    );
  }
}

/// Inner widget that seeds the isolated [videoEditorProvider] from [video]
/// and renders the edit scaffold.
class _VideoMetadataEditStackContent extends ConsumerStatefulWidget {
  const _VideoMetadataEditStackContent({
    required this.video,
    required this.initialCollaboratorPubkeys,
  });

  final VideoEvent video;
  final Set<String> initialCollaboratorPubkeys;

  @override
  ConsumerState<_VideoMetadataEditStackContent> createState() =>
      _VideoMetadataEditStackContentState();
}

class _VideoMetadataEditStackContentState
    extends ConsumerState<_VideoMetadataEditStackContent> {
  bool _isCoverUpdating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(videoEditorProvider.notifier)
          .initFromPublishedVideo(widget.video);
    });
  }

  Future<void> _openCoverEditor() async {
    final videoUrl = widget.video.videoUrl;
    if (videoUrl == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 300);
    final clip = DivineVideoClip(
      id: widget.video.id,
      video: EditorVideo.network(videoUrl),
      duration: Duration(seconds: widget.video.duration ?? 0),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        widget.video.createdAt * 1000,
      ),
      targetAspectRatio: AspectRatio.vertical,
      originalAspectRatio: null,
    );
    await Navigator.push<void>(
      context,
      PageRouteBuilder<void>(
        transitionDuration: duration,
        reverseTransitionDuration: duration,
        pageBuilder: (_, _, _) => VideoMetadataCoverScreen(
          clip: clip,
          thumbnailUrl: widget.video.thumbnailUrl,
          onNetworkCoverReady: _republishWithNewThumbnail,
        ),
        transitionsBuilder: (_, animation, _, child) {
          if (reduceMotion) return child;
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _republishWithNewThumbnail(String newThumbnailUrl) async {
    setState(() => _isCoverUpdating = true);

    // Capture l10n eagerly — awaiting the publish round-trip means the
    // widget may have unmounted by the time the invite service needs it.
    final inviteL10n = context.l10n;

    try {
      final editorState = ref.read(videoEditorProvider);

      final authService = ref.read(authServiceProvider);
      if (!authService.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final tags = <List<String>>[];

      tags.add(['d', widget.video.stableId]);

      final videoUrls = <String>[];
      for (final tag in widget.video.nostrEventTags) {
        if (tag.isEmpty || tag[0] != 'imeta') continue;
        if (tag.length > 1 && tag[1].contains(' ')) {
          for (var i = 1; i < tag.length; i++) {
            final spaceIdx = tag[i].indexOf(' ');
            if (spaceIdx > 0) {
              final key = tag[i].substring(0, spaceIdx);
              final value = tag[i].substring(spaceIdx + 1);
              if (key == 'url' &&
                  _isHttpUrl(value) &&
                  !videoUrls.contains(value)) {
                videoUrls.add(value);
              }
            }
          }
        } else {
          for (var i = 1; i < tag.length - 1; i += 2) {
            if (tag[i] == 'url' &&
                _isHttpUrl(tag[i + 1]) &&
                !videoUrls.contains(tag[i + 1])) {
              videoUrls.add(tag[i + 1]);
            }
          }
        }
      }

      if (videoUrls.isEmpty && _isHttpUrl(widget.video.videoUrl)) {
        videoUrls.add(widget.video.videoUrl!);
      }

      if (videoUrls.isEmpty) {
        throw Exception('Cannot update video: no valid HTTP video URLs found');
      }

      final imetaComponents = <String>[];
      for (final url in videoUrls) {
        imetaComponents.add('url $url');
      }
      imetaComponents.add('m video/mp4');

      imetaComponents.add('image $newThumbnailUrl');

      if (widget.video.blurhash != null) {
        imetaComponents.add('blurhash ${widget.video.blurhash!}');
      }
      if (widget.video.dimensions != null) {
        imetaComponents.add('dim ${widget.video.dimensions!}');
      }
      if (widget.video.sha256 != null) {
        imetaComponents.add('x ${widget.video.sha256!}');
      }
      if (widget.video.fileSize != null) {
        imetaComponents.add('size ${widget.video.fileSize!}');
      }

      if (imetaComponents.isNotEmpty) {
        tags.add(['imeta', ...imetaComponents]);
      }

      final title = editorState.title.trim();
      if (title.isNotEmpty) {
        tags.add(['title', title]);
      }

      for (final hashtag in editorState.tags) {
        tags.add(['t', hashtag]);
      }

      for (final label in editorState.contentWarnings) {
        tags.add(['l', label.value, 'content-warning']);
      }

      tags.addAll(extractEngagementCountTags(widget.video.nostrEventTags));

      if (widget.video.publishedAt != null) {
        tags.add(['published_at', widget.video.publishedAt!]);
      }
      if (widget.video.duration != null) {
        tags.add(['duration', widget.video.duration.toString()]);
      }
      if (widget.video.altText != null) {
        tags.add(['alt', widget.video.altText!]);
      }

      for (final pubkey in editorState.collaboratorPubkeys) {
        tags.add(buildCollaboratorPTag(pubkey));
      }

      if (editorState.inspiredByVideo != null) {
        tags.add([
          'a',
          editorState.inspiredByVideo!.addressableId,
          editorState.inspiredByVideo!.relayUrl ?? '',
          'inspired-by',
        ]);
      }

      tags.add(['client', 'diVine']);

      if (editorState.allowAudioReuse) {
        tags.add(['allow_audio_reuse', 'true']);
      }

      var content = editorState.description.trim();
      final inspiredByNpub = editorState.inspiredByNpub;
      if (inspiredByNpub != null && inspiredByNpub.isNotEmpty) {
        final ibText = '\n\nInspired by nostr:$inspiredByNpub';
        content = content.isEmpty ? ibText.trim() : '$content$ibText';
      }

      final event = await authService.createAndSignEvent(
        kind: NIP71VideoKinds.addressableShortVideo,
        content: content,
        tags: tags,
        createdAt: widget.video.createdAt + 1,
      );

      if (event == null) {
        throw Exception('Failed to create updated event');
      }

      final nostrService = ref.read(nostrServiceProvider);
      final publishResult = await nostrService.publishEvent(event);
      if (publishResult is! PublishSuccess) {
        throw Exception('Failed to publish updated event');
      }
      final publishedEvent = publishResult.event;

      final personalEventCache = ref.read(personalEventCacheServiceProvider);
      personalEventCache.cacheUserEvent(publishedEvent);

      final videoEventService = ref.read(videoEventServiceProvider);
      final updatedVideoEvent = VideoEvent.fromNostrEvent(publishedEvent);
      videoEventService.updateVideoEvent(updatedVideoEvent);

      await sendPostPublishCollaboratorInvites(
        inviteService: CollaboratorInviteService(
          dmRepository: ref.read(dmRepositoryProvider),
          l10n: inviteL10n,
        ),
        video: updatedVideoEvent,
        previousCollaboratorPubkeys: widget.initialCollaboratorPubkeys,
        updatedCollaboratorPubkeys: editorState.collaboratorPubkeys,
      );

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.shareMenuVideoUpdated),
            backgroundColor: VineTheme.vineGreen,
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to update cover: $e',
        name: 'VideoMetadataEditStack',
        category: LogCategory.ui,
      );

      if (mounted) {
        setState(() => _isCoverUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.shareMenuFailedToUpdateVideo('$e')),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    }
  }

  static bool _isHttpUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.surfaceContainerHigh,
      appBar: DiVineAppBar(
        backgroundColor: VineTheme.surfaceContainerHigh,
        leadingIcon: SvgIconSource(DivineIconName.caretLeft.assetPath),
        onLeadingPressed: context.pop,
        title: context.l10n.shareMenuEditVideo,
      ),
      body: Column(
        spacing: 12,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thumbnail preview, matching capture stack style.
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: _EditClipPreview(
                      video: widget.video,
                      onEditCover: _openCoverEditor,
                      isCoverUpdating: _isCoverUpdating,
                    ),
                  ),
                  // Editing is post-publish; expiration cannot be changed.
                  const VideoMetadataFormFields(enableExpiration: false),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: VideoMetadataEditBottomBar(
              video: widget.video,
              initialCollaboratorPubkeys: widget.initialCollaboratorPubkeys,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thumbnail preview for an already-published video, mirroring the visual
/// style of [VideoMetadataCaptureClipPreview] in the capture flow.
class _EditClipPreview extends StatelessWidget {
  const _EditClipPreview({
    required this.video,
    this.onEditCover,
    this.isCoverUpdating = false,
  });

  final VideoEvent video;
  final VoidCallback? onEditCover;
  final bool isCoverUpdating;

  /// Parses "WxH" dimension string into a width/height ratio.
  /// Falls back to 9/16 (vertical) if unavailable or unparseable.
  double _aspectRatio() {
    final dim = video.dimensions;
    if (dim == null) return 9 / 16;
    final parts = dim.split('x');
    if (parts.length != 2) return 9 / 16;
    final w = double.tryParse(parts[0]);
    final h = double.tryParse(parts[1]);
    if (w == null || h == null || h == 0) return 9 / 16;
    return w / h;
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = video.thumbnailUrl;
    final ratio = _aspectRatio();
    return Center(
      child: Hero(
        tag: VideoEditorConstants.heroMetaPreviewId,
        createRectTween: (begin, end) => RectTween(begin: begin, end: end),
        child: SizedBox(
          height: 200,
          width: 200 * ratio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumbnailUrl != null)
                  VineCachedImage(imageUrl: thumbnailUrl)
                else
                  const ColoredBox(
                    color: VineTheme.onSurfaceMuted,
                    child: DivineIcon(
                      icon: .playCircle,
                      size: 64,
                      color: VineTheme.whiteText,
                    ),
                  ),
                if (onEditCover != null)
                  Center(
                    child: Semantics(
                      button: true,
                      label: context.l10n.shareMenuChangeCover,
                      excludeSemantics: true,
                      child: DivineIconButton(
                        icon: .pencilSimpleLine,
                        type: .ghostSecondary,
                        size: .small,
                        onPressed: isCoverUpdating ? null : onEditCover,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
