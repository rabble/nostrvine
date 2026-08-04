// ABOUTME: Autosaving editor for private device-local sound labels and hashtags.
// ABOUTME: Keeps organization metadata inside SavedSoundsBloc and out of Nostr.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/saved_sound.dart';

class SavedSoundDetailsEditor extends StatefulWidget {
  const SavedSoundDetailsEditor({
    required this.sound,
    this.autosaveDelay = const Duration(milliseconds: 350),
    super.key,
  });

  final SavedSound sound;
  final Duration autosaveDelay;

  @override
  State<SavedSoundDetailsEditor> createState() =>
      _SavedSoundDetailsEditorState();
}

class _SavedSoundDetailsEditorState extends State<SavedSoundDetailsEditor> {
  late final TextEditingController _labelController;
  late final TextEditingController _hashtagController;
  late final FocusNode _labelFocus;
  late final FocusNode _hashtagFocus;
  late List<String> _hashtags;
  Timer? _autosaveTimer;
  bool _updatingHashtagField = false;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(
      text: widget.sound.personalLabel ?? '',
    );
    _hashtagController = TextEditingController();
    _hashtags = [...widget.sound.personalHashtags];
    _labelFocus = FocusNode()..addListener(_onFocusChanged);
    _hashtagFocus = FocusNode()..addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant SavedSoundDetailsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sound.id != widget.sound.id) {
      _autosaveTimer?.cancel();
      _labelController.text = widget.sound.personalLabel ?? '';
      _hashtags = [...widget.sound.personalHashtags];
      _hashtagController.clear();
    }
  }

  void _onFocusChanged() {
    if (!_labelFocus.hasFocus && !_hashtagFocus.hasFocus) _saveNow();
  }

  void _scheduleSave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(widget.autosaveDelay, _saveNow);
  }

  void _saveNow() {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    if (!mounted) return;
    context.read<SavedSoundsBloc>().add(
      SavedSoundDetailsChanged(
        soundId: widget.sound.id,
        label: _labelController.text,
        hashtags: _hashtags,
      ),
    );
  }

  void _onHashtagChanged(String value) {
    if (_updatingHashtagField) return;
    if (!RegExp(r'[,\s]').hasMatch(value)) return;
    _commitHashtag(value);
  }

  void _commitHashtag(String raw) {
    final additions = normalizeSavedSoundHashtags(raw.split(RegExp(r'[,\s]+')));
    if (additions.isNotEmpty) {
      setState(() {
        _hashtags = [
          ...normalizeSavedSoundHashtags([..._hashtags, ...additions]),
        ];
      });
      _scheduleSave();
    }
    _updatingHashtagField = true;
    _hashtagController.clear();
    _updatingHashtagField = false;
  }

  void _removeHashtag(String hashtag) {
    setState(() => _hashtags.remove(hashtag));
    _scheduleSave();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _labelFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _hashtagFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _labelController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSaveError = context.select<SavedSoundsBloc, bool>(
      (bloc) => bloc.state.unsavedSoundIds.contains(widget.sound.id),
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DivineTextField(
            key: const Key('saved_sound_label_field'),
            controller: _labelController,
            focusNode: _labelFocus,
            labelText: context.l10n.savedSoundYourLabel,
            spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
            onChanged: (_) => _scheduleSave(),
          ),
          const SizedBox(height: 8),
          DivineTextField(
            key: const Key('saved_sound_hashtag_field'),
            controller: _hashtagController,
            focusNode: _hashtagFocus,
            labelText: context.l10n.savedSoundAddHashtags,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
            onChanged: _onHashtagChanged,
            onSubmitted: _commitHashtag,
          ),
          if (_hashtags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final hashtag in _hashtags)
                  InputChip(
                    key: Key('saved_sound_hashtag_$hashtag'),
                    label: Text('#$hashtag'),
                    onDeleted: () => _removeHashtag(hashtag),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            context.l10n.savedSoundDeviceOnly,
            style: VineTheme.labelSmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
          if (hasSaveError)
            DivineButton(
              key: const Key('saved_sound_details_retry'),
              label: context.l10n.savedSoundDetailsRetry,
              type: DivineButtonType.link,
              size: DivineButtonSize.small,
              onPressed: _saveNow,
            ),
        ],
      ),
    );
  }
}
