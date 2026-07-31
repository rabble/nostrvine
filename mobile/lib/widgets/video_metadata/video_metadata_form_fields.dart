import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' show AudioEvent, UserProfile;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_reply_context_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_collaborators_input.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_content_warning_selector.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_expiration_selector.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_inspired_by_input.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_limit_warning_banner.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_tags_selector.dart';

class VideoMetadataFormFields extends ConsumerStatefulWidget {
  const VideoMetadataFormFields({
    super.key,
    this.enableTags = true,
    this.enableExpiration = true,
    this.enableContentWarning = true,
    this.enableCollaborators = true,
    this.enableInspiredBy = true,
    this.enableAudioReuse = true,
    this.enableVideoReply = true,
  });

  final bool enableTags;
  final bool enableExpiration;
  final bool enableContentWarning;
  final bool enableCollaborators;
  final bool enableInspiredBy;
  final bool enableAudioReuse;
  final bool enableVideoReply;

  @override
  ConsumerState<VideoMetadataFormFields> createState() =>
      _VideoMetadataFormFieldsState();
}

class _VideoMetadataFormFieldsState
    extends ConsumerState<VideoMetadataFormFields> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final editorState = ref.read(videoEditorProvider);
      _titleController.text = editorState.title;
      _descriptionController.text = editorState.description;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reusing another creator's audio isn't the user's to offer for reuse, and
    // the publisher skips the reuse tag in that case, so hide the toggle
    // entirely rather than showing a control that does nothing.
    final reusesExternalAudio = ref.watch(
      videoEditorProvider.select((state) => state.reusesExternalAudio),
    );

    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: 16,
        children: [
          const VideoMetadataLimitWarningBanner(),

          // Title input field
          _InputWrapper(
            child: DivineTextField(
              controller: _titleController,
              labelText: context.l10n.videoMetadataTitleLabel,
              focusNode: _titleFocusNode,
              textInputAction: .next,
              primaryWhenFilled: true,
              minLines: 1,
              maxLines: 5,
              onChanged: (value) {
                ref
                    .read(videoEditorProvider.notifier)
                    .updateMetadata(title: value);
              },
              onSubmitted: (_) => _descriptionFocusNode.requestFocus(),
            ),
          ),

          // Description input field
          _InputWrapper(
            child: Stack(
              children: [
                DivineTextField(
                  controller: _descriptionController,
                  labelText: context.l10n.videoMetadataDescriptionLabel,
                  focusNode: _descriptionFocusNode,
                  keyboardType: .multiline,
                  textInputAction: .newline,
                  primaryWhenFilled: true,
                  minLines: 1,
                  maxLines: 10,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      VideoEditorConstants.descriptionLimit,
                    ),
                  ],
                  onChanged: (value) {
                    ref
                        .read(videoEditorProvider.notifier)
                        .updateMetadata(description: value);
                  },
                ),
                Positioned(
                  // Align the counter to the field's content padding so a
                  // future tweak to [DivineTextField.defaultContentPadding]
                  // keeps it in sync. The -1 nudges the baseline up to match
                  // the floating label.
                  top: DivineTextField.defaultContentPadding.top - 1,
                  right: DivineTextField.defaultContentPadding.right,
                  child: ValueListenableBuilder(
                    valueListenable: _descriptionController,
                    builder: (context, value, child) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _descriptionController.text.isNotEmpty
                            ? Text(
                                '${_descriptionController.text.length}/'
                                '${VideoEditorConstants.descriptionLimit}',
                                style: VineTheme.labelSmallFont(
                                  color: context.vineColors.onSurfaceMuted,
                                ),
                              )
                            : const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          if (widget.enableTags)
            const _InputWrapper(child: VideoMetadataTagsSelector()),

          if (widget.enableExpiration)
            const _InputWrapper(child: VideoMetadataExpirationSelector()),

          if (widget.enableCollaborators)
            const _InputWrapper(child: VideoMetadataCollaboratorsInput()),

          if (widget.enableInspiredBy)
            const _InputWrapper(child: VideoMetadataInspiredByInput()),

          if (widget.enableContentWarning)
            const _InputWrapper(child: VideoMetadataContentWarningSelector()),

          if (widget.enableAudioReuse && !reusesExternalAudio)
            const _InputWrapper(child: _VideoMetadataAudioSharingSection()),

          if (widget.enableVideoReply)
            const _InputWrapper(child: _VideoReplyVisibilityToggle()),

          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _VideoReplyVisibilityToggle extends ConsumerWidget {
  const _VideoReplyVisibilityToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replyContext = ref.watch(videoReplyContextProvider);
    if (replyContext == null) return const SizedBox.shrink();

    final shareReplyToFeed = ref.watch(
      videoEditorProvider.select((state) => state.shareReplyToFeed),
    );

    return Padding(
      padding: const .symmetric(horizontal: 4),
      child: Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          value: shareReplyToFeed,
          title: Text(
            context.l10n.videoMetadataShareReplyToFeedTitle,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.onSurface,
            ),
          ),
          subtitle: Text(
            context.l10n.videoMetadataShareReplyToFeedSubtitle,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
          contentPadding: const .symmetric(horizontal: 12, vertical: 4),
          activeThumbColor: VineTheme.vineGreen,
          inactiveThumbColor: context.vineColors.mutedText,
          onChanged: (value) {
            ref.read(videoEditorProvider.notifier).setShareReplyToFeed(value);
          },
        ),
      ),
    );
  }
}

class _VideoMetadataAudioSharingSection extends ConsumerWidget {
  const _VideoMetadataAudioSharingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(videoEditorProvider);
    final sound = editorState.audioForAttribution;
    final external = sound?.externalSource;
    final derivativesAllowed = external?.license.allowsDerivatives ?? true;
    final allowAudioReuse = editorState.allowAudioReuse && derivativesAllowed;

    void updateReuse(bool value) {
      final notifier = ref.read(videoEditorProvider.notifier);
      notifier.setAllowAudioReuse(value);
      if (!value ||
          external != null ||
          editorState.audioShareAttribution != null) {
        return;
      }
      notifier.setAudioShareAttribution(
        _initialAttribution(ref, sound),
      );
    }

    return Padding(
      padding: const .symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              value: allowAudioReuse,
              title: Text(
                context.l10n.soundAllowRemix,
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.onSurface,
                ),
              ),
              subtitle: Text(
                derivativesAllowed
                    ? context.l10n.videoMetadataAudioReuseSubtitle
                    : context.l10n.soundCreditOnly,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
              ),
              contentPadding: const .symmetric(horizontal: 12, vertical: 4),
              activeThumbColor: VineTheme.vineGreen,
              inactiveThumbColor: context.vineColors.mutedText,
              onChanged: derivativesAllowed ? updateReuse : null,
            ),
          ),
          if (external != null)
            _ProviderAudioCredit(sound: sound!)
          else if (allowAudioReuse)
            _PublicAudioCreditEditor(
              key: ValueKey(sound?.id ?? 'original-audio'),
              sound: sound,
            ),
        ],
      ),
    );
  }

  AudioShareAttribution _initialAttribution(
    WidgetRef ref,
    AudioEvent? sound,
  ) {
    final pubkey = ref.read(authServiceProvider).currentPublicKeyHex ?? '';
    final profile = pubkey.isEmpty
        ? null
        : ref.read(userProfileReactiveProvider(pubkey)).value;
    final publisherName =
        profile?.bestDisplayName ??
        (pubkey.isEmpty ? '' : UserProfile.defaultDisplayNameFor(pubkey));
    final title = sound?.title?.trim();
    if (sound?.isLocalImport == true) {
      return AudioShareAttribution(
        title: title?.isNotEmpty == true ? title! : '',
        creatorName: '',
        publicTags: const [],
        confirmedOwnWork: false,
      );
    }
    return AudioShareAttribution.forOwnedSound(
      title: title?.isNotEmpty == true ? title! : 'Original sound',
      publisherName: publisherName,
      publisherPubkey: pubkey,
    );
  }
}

class _ProviderAudioCredit extends StatelessWidget {
  const _ProviderAudioCredit({required this.sound});

  final AudioEvent sound;

  @override
  Widget build(BuildContext context) {
    final external = sound.externalSource!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.soundPublicCredit,
            style: VineTheme.titleSmallFont(
              color: context.vineColors.onSurface,
            ),
          ),
          Text(
            sound.title ?? external.providerName,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurface,
            ),
          ),
          if (external.creatorName case final creator?)
            Text(
              context.l10n.soundCreatorBy(creator),
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          Text(
            external.license.name,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicAudioCreditEditor extends ConsumerStatefulWidget {
  const _PublicAudioCreditEditor({required this.sound, super.key});

  final AudioEvent? sound;

  @override
  ConsumerState<_PublicAudioCreditEditor> createState() =>
      _PublicAudioCreditEditorState();
}

class _PublicAudioCreditEditorState
    extends ConsumerState<_PublicAudioCreditEditor> {
  late final TextEditingController _titleController;
  late final TextEditingController _creatorController;
  late final TextEditingController _sourceController;
  late final TextEditingController _tagsController;

  AudioShareAttribution get _attribution =>
      ref.read(videoEditorProvider).audioShareAttribution ??
      AudioShareAttribution(
        title: widget.sound?.title ?? '',
        creatorName: '',
        publicTags: const [],
        confirmedOwnWork: false,
      );

  @override
  void initState() {
    super.initState();
    final attribution = _attribution;
    _titleController = TextEditingController(text: attribution.title);
    _creatorController = TextEditingController(text: attribution.creatorName);
    _sourceController = TextEditingController(text: attribution.sourceUrl);
    _tagsController = TextEditingController(
      text: attribution.publicTags.map((tag) => '#$tag').join(' '),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _creatorController.dispose();
    _sourceController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _update({
    String? title,
    String? creatorName,
    String? sourceUrl,
    List<String>? publicTags,
    bool? confirmedOwnWork,
  }) {
    final current = _attribution;
    ref
        .read(videoEditorProvider.notifier)
        .setAudioShareAttribution(
          current.copyWith(
            title: title,
            creatorName: creatorName,
            sourceUrl: sourceUrl,
            publicTags: publicTags,
            confirmedOwnWork: confirmedOwnWork,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final attribution = ref.watch(
      videoEditorProvider.select((state) => state.audioShareAttribution),
    );
    final ownWork = attribution?.confirmedOwnWork ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(
            context.l10n.soundPublicCredit,
            style: VineTheme.titleSmallFont(
              color: context.vineColors.onSurface,
            ),
          ),
          DivineTextField(
            key: const Key('audio_credit_title'),
            controller: _titleController,
            labelText: context.l10n.soundCreditTitleLabel,
            onChanged: (value) => _update(title: value),
          ),
          DivineTextField(
            key: const Key('audio_credit_creator'),
            controller: _creatorController,
            labelText: context.l10n.soundCreditCreatorLabel,
            onChanged: (value) => _update(creatorName: value),
          ),
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              value: ownWork,
              title: Text(context.l10n.soundOwnWork),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) => _update(confirmedOwnWork: value ?? false),
            ),
          ),
          if (!ownWork)
            DivineTextField(
              key: const Key('audio_credit_source'),
              controller: _sourceController,
              labelText: context.l10n.soundCreditSourceUrlLabel,
              keyboardType: TextInputType.url,
              autocorrect: false,
              onChanged: (value) => _update(sourceUrl: value),
            ),
          DivineTextField(
            key: const Key('audio_credit_tags'),
            controller: _tagsController,
            labelText: context.l10n.soundCreditPublicHashtagsLabel,
            autocorrect: false,
            onChanged: (value) => _update(
              publicTags: value.split(RegExp(r'[,\s]+')),
            ),
          ),
          Text(
            context.l10n.soundSharedAs,
            style: VineTheme.labelMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
          Text(
            [
              _titleController.text.trim(),
              if (_creatorController.text.trim().isNotEmpty)
                context.l10n.soundCreatorBy(_creatorController.text.trim()),
            ].where((value) => value.isNotEmpty).join(' · '),
            key: const Key('audio_credit_preview'),
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InputWrapper extends StatelessWidget {
  const _InputWrapper({required this.child});

  final Widget child;

  static const _borderRadius = 24.0;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.vineColors.surface,
        borderRadius: .circular(_borderRadius),
      ),
      child: child,
    );
  }
}
