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
import 'package:openvine/l10n/l10n.dart';

/// Bottom sheet that displays the authenticated user's editable people
/// lists and lets them toggle membership for the given [pubkey].
///
/// Consumers should call [AddToPeopleListsSheet.show] from within a
/// subtree that has a [PeopleListsBloc] provided above it.
///
/// The sheet filters out read-only lists (`isEditable == false`). When
/// there are no editable lists, an empty state offers a `Create list`
/// affordance that opens `/people-lists/new?initialPubkey=<hex>` so the
/// single create flow both creates the list and seeds it with the
/// selected person.
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
      title: Text(context.l10n.peopleListsSheetTitle),
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
      return _EmptyState(pubkey: pubkey);
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
  const _EmptyState({required this.pubkey});

  /// The full hex pubkey of the person the user was trying to add; the
  /// Create list button threads this through to the create page as a
  /// query param so the new list is seeded with this person on submit.
  final String pubkey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.peopleListsEmptyTitle,
            textAlign: TextAlign.center,
            style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.peopleListsEmptySubtitle,
            textAlign: TextAlign.center,
            style: VineTheme.bodyMediumFont(
              color: VineTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 24),
          DivineButton(
            label: context.l10n.peopleListsCreateList,
            expanded: true,
            leadingIcon: DivineIconName.listPlus,
            // Capture the router BEFORE popping so the push navigates the
            // root Navigator — the sheet's BuildContext is invalidated by
            // pop and cannot be used afterwards.
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.push(
                CreatePeopleListPage.pathWithInitialPubkey(pubkey),
              );
            },
          ),
        ],
      ),
    );
  }
}
