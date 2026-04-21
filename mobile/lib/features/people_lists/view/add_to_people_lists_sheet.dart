// ABOUTME: Bottom sheet to add/remove a pubkey across the user's editable
// ABOUTME: people lists. Routes taps through PeopleListsBloc.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/models/people_list_entry_point.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/features/people_lists/view/widgets/widgets.dart';

/// Bottom sheet that displays the authenticated user's editable people
/// lists and lets them toggle membership for the given [pubkey].
///
/// Consumers should call [AddToPeopleListsSheet.show] from within a
/// subtree that has a [PeopleListsBloc] provided above it.
///
/// The sheet filters out read-only lists (`isEditable == false`). When
/// there are no editable lists, an empty state offers a `Create list`
/// affordance; Task 9 wires that button into `/people-lists/new`.
class AddToPeopleListsSheet extends StatelessWidget {
  /// Creates the sheet widget.
  const AddToPeopleListsSheet({
    required this.pubkey,
    required this.entryPoint,
    this.displayName,
    super.key,
  });

  /// The full hex pubkey whose list membership is being edited. The
  /// pubkey is never truncated in storage, dispatched events, or logs.
  final String pubkey;

  /// Identifies which UI surface triggered this sheet. Threaded through
  /// to child rows so analytics and future copy can branch on source.
  final PeopleListEntryPoint entryPoint;

  /// Optional display name for the person. Only used for layout copy;
  /// the underlying [pubkey] is always the source of truth.
  final String? displayName;

  /// Shows the sheet as a modal [VineBottomSheet].
  ///
  /// Returns a [Future] that completes when the sheet is dismissed.
  static Future<void> show(
    BuildContext context, {
    required String pubkey,
    required PeopleListEntryPoint entryPoint,
    String? displayName,
  }) {
    return VineBottomSheet.show<void>(
      context: context,
      title: const Text('Add to list'),
      buildScrollBody: (scrollController) => AddToPeopleListsSheet(
        pubkey: pubkey,
        entryPoint: entryPoint,
        displayName: displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editableLists = context.select<PeopleListsBloc, List<UserList>>(
      (bloc) => bloc.state.lists
          .where((list) => list.isEditable)
          .toList(growable: false),
    );

    if (editableLists.isEmpty) {
      return const _EmptyState();
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: editableLists.length,
      itemBuilder: (context, index) {
        final list = editableLists[index];
        return PeopleListRow(
          listId: list.id,
          listName: list.name,
          pubkey: pubkey,
          entryPoint: entryPoint,
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'No lists yet',
            textAlign: TextAlign.center,
            style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a list to start grouping people.',
            textAlign: TextAlign.center,
            style: VineTheme.bodyMediumFont(
              color: VineTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 24),
          DivineButton(
            label: 'Create list',
            expanded: true,
            leadingIcon: DivineIconName.listPlus,
            // Pop the sheet first so the push navigates the root Navigator,
            // then push the full-screen create page. The sheet and the new
            // page both rely on the ambient PeopleListsBloc.
            onPressed: () {
              Navigator.of(context).pop();
              context.push(CreatePeopleListPage.path);
            },
          ),
        ],
      ),
    );
  }
}
