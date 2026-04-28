// ABOUTME: Bottom sheet for creating a new people list from a profile
// ABOUTME: Shows list name and description inputs with close and done buttons

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/user_picker_sheet.dart';
import 'package:unified_logger/unified_logger.dart';

/// Shows the "New people list" bottom sheet.
///
/// Creates the list locally via [UserListService] and publishes it to Nostr
/// via [SocialService] when the check button is tapped.
///
/// [initialCollaborator] is pre-added as the first collaborator — useful when
/// opening the sheet directly from a profile.
Future<void> showNewPeopleListSheet(
  BuildContext context, {
  UserProfile? initialCollaborator,
}) {
  final bodyKey = GlobalKey<_NewPeopleListSheetBodyState>();

  return VineBottomSheet.show<void>(
    context: context,
    scrollable: false,
    title: Builder(
      builder: (context) => Text(context.l10n.listNewPeopleList),
    ),
    onComplete: () async {
      await bodyKey.currentState?._createList();
    },
    body: _NewPeopleListSheetBody(
      key: bodyKey,
      initialCollaborator: initialCollaborator,
    ),
  );
}

class _NewPeopleListSheetBody extends ConsumerStatefulWidget {
  const _NewPeopleListSheetBody({
    this.initialCollaborator,
    super.key,
  });

  final UserProfile? initialCollaborator;

  @override
  ConsumerState<_NewPeopleListSheetBody> createState() =>
      _NewPeopleListSheetBodyState();
}

class _NewPeopleListSheetBodyState
    extends ConsumerState<_NewPeopleListSheetBody> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  late final List<UserProfile> _collaborators;

  @override
  void initState() {
    super.initState();
    _collaborators = [
      if (widget.initialCollaborator != null) widget.initialCollaborator!,
    ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Creates the list locally and publishes it to Nostr.
  Future<void> _createList() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    final pubkeys = _collaborators.map((p) => p.pubkey).toList();

    // 1. Persist locally so the list appears in the Lists tab immediately.
    final userListService =
        await ref.read(userListServiceProvider.future);
    await userListService.createList(
      name: name,
      description: description,
      pubkeys: pubkeys,
    );

    // 2. Publish to Nostr as a NIP-51 kind 30000 follow set.
    final socialService = ref.read(socialServiceProvider);
    await socialService.createFollowSet(
      name: name,
      description: description,
      initialPubkeys: pubkeys,
    );

    Log.info(
      'Created people list "$name" with ${pubkeys.length} members',
      name: 'NewPeopleListSheet',
      category: LogCategory.ui,
    );

    // Invalidate the provider so the Lists tab refreshes.
    ref.invalidate(userListServiceProvider);
  }

  Future<void> _pickCollaborator() async {
    await showUserPickerSheet(
      context,
      filterMode: UserPickerFilterMode.mutualFollowsOnly,
      title: context.l10n.listAddCollaboratorTitle,
      searchText: context.l10n.videoMetadataMutualFollowersSearchText,
      searchHint: context.l10n.listCollaboratorSearchHint,
      excludePubkeys: _collaborators.map((p) => p.pubkey).toSet(),
      onUserToggled: (profile) {
        setState(() {
          final already = _collaborators.any((p) => p.pubkey == profile.pubkey);
          if (already) {
            _collaborators.removeWhere((p) => p.pubkey == profile.pubkey);
          } else {
            _collaborators.add(profile);
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DivineAuthTextField(
            label: l10n.listNameLabel,
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          DivineAuthTextField(
            label: l10n.listDescriptionLabel,
            controller: _descriptionController,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          _CollaboratorsRow(
            collaborators: _collaborators,
            onTap: _pickCollaborator,
            l10n: l10n,
          ),
        ],
      ),
    );
  }
}

class _CollaboratorsRow extends StatelessWidget {
  const _CollaboratorsRow({
    required this.collaborators,
    required this.onTap,
    required this.l10n,
  });

  final List<UserProfile> collaborators;
  final VoidCallback onTap;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final hasCollaborators = collaborators.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.metadataCollaboratorsLabel,
          style: VineTheme.titleSmallFont(color: VineTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: hasCollaborators
                      ? Text(
                          collaborators
                              .map((p) => p.bestDisplayName)
                              .join(', '),
                          style: VineTheme.titleMediumFont(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Text(
                          l10n.listCollaboratorsNone,
                          style: VineTheme.titleMediumFont(),
                        ),
                ),
                const DivineIcon(
                  icon: DivineIconName.caretRight,
                  color: VineTheme.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
