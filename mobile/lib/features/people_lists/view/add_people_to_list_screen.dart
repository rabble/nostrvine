// ABOUTME: Full-screen picker for adding multiple people to an existing list.
// ABOUTME: Batches selections and dispatches one add request per selected pubkey.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/widgets/person_pickable_row.dart';
import 'package:openvine/l10n/l10n.dart';

/// Full-screen picker that lets the authenticated user batch-add candidate
/// pubkeys to an existing people list.
///
/// The screen is addressed by [listId] and reads the target [UserList] from
/// the ambient [PeopleListsBloc]. Candidates are supplied via
/// [candidatePubkeys] — typically the current user's following or followers
/// list. Candidates already in the target list are greyed out and
/// pre-checked (they cannot be re-toggled here — removal uses a different
/// flow). The pinned bottom "Add N" button dispatches one
/// [PeopleListsPubkeyAddRequested] per selected pubkey and then pops.
///
/// Per project rules, full Nostr pubkeys flow through the screen verbatim —
/// they are never truncated in state, events, or navigation.
class AddPeopleToListScreen extends StatefulWidget {
  /// Creates the add-people picker.
  const AddPeopleToListScreen({
    required this.listId,
    this.candidatePubkeys = const [],
    this.candidateLabelBuilder,
    super.key,
  });

  /// GoRouter name for this route.
  static const routeName = 'people-list-add-people';

  /// GoRouter path template for this route.
  static const path = '/people-lists/:listId/add-people';

  /// Target list's full addressable id. Never truncated.
  final String listId;

  /// Full-hex candidate pubkeys to show in the picker. Never truncated.
  final List<String> candidatePubkeys;

  /// Optional builder used to derive a display-name and handle line for a
  /// candidate pubkey. Exposed so future callers can plug in a reactive
  /// profile lookup without the screen itself depending on Riverpod. When
  /// `null`, the screen falls back to generating a deterministic display
  /// name from the pubkey.
  final CandidateLabelBuilder? candidateLabelBuilder;

  @override
  State<AddPeopleToListScreen> createState() => _AddPeopleToListScreenState();
}

/// Signature for resolving a candidate pubkey's display-name and handle
/// without coupling the picker to a specific profile lookup mechanism.
typedef CandidateLabelBuilder =
    ({String displayName, String handle, String? avatarUrl}) Function(
      String pubkey,
    );

class _AddPeopleToListScreenState extends State<AddPeopleToListScreen> {
  final Set<String> _selected = <String>{};

  void _toggle(String pubkey) {
    setState(() {
      if (_selected.contains(pubkey)) {
        _selected.remove(pubkey);
      } else {
        _selected.add(pubkey);
      }
    });
  }

  void _submit() {
    final bloc = context.read<PeopleListsBloc>();
    for (final pubkey in _selected) {
      bloc.add(
        PeopleListsPubkeyAddRequested(
          listId: widget.listId,
          pubkey: pubkey,
        ),
      );
    }
    _selected.clear();
    // Use Navigator.maybePop so the screen works even when no GoRouter is
    // present (e.g., simple widget-test harnesses without MaterialApp.router).
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PeopleListsBloc, PeopleListsState, UserList?>(
      selector: (state) {
        for (final list in state.lists) {
          if (list.id == widget.listId) return list;
        }
        return null;
      },
      builder: (context, userList) {
        if (userList == null) {
          return const _ListNotFoundScaffold();
        }
        return _AddPeopleToListView(
          userList: userList,
          candidatePubkeys: widget.candidatePubkeys,
          selected: _selected,
          onToggle: _toggle,
          onSubmit: _selected.isEmpty ? null : _submit,
          labelBuilder: widget.candidateLabelBuilder,
        );
      },
    );
  }
}

class _ListNotFoundScaffold extends StatelessWidget {
  const _ListNotFoundScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: DiVineAppBar(
        title: context.l10n.peopleListsAddPeopleTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.peopleListsListNotFoundSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: VineTheme.secondaryText),
          ),
        ),
      ),
    );
  }
}

class _AddPeopleToListView extends StatelessWidget {
  const _AddPeopleToListView({
    required this.userList,
    required this.candidatePubkeys,
    required this.selected,
    required this.onToggle,
    required this.onSubmit,
    this.labelBuilder,
  });

  final UserList userList;
  final List<String> candidatePubkeys;
  final Set<String> selected;
  final void Function(String pubkey) onToggle;
  final VoidCallback? onSubmit;
  final CandidateLabelBuilder? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: DiVineAppBar(
        title: context.l10n.peopleListsAddToListName(userList.name),
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: candidatePubkeys.isEmpty
                  ? const _EmptyCandidatesState()
                  : _CandidateList(
                      userList: userList,
                      candidatePubkeys: candidatePubkeys,
                      selected: selected,
                      onToggle: onToggle,
                      labelBuilder: labelBuilder,
                    ),
            ),
            _AddButtonBar(
              selectionCount: selected.length,
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCandidatesState extends StatelessWidget {
  const _EmptyCandidatesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.l10n.peopleListsNoPeopleToAdd,
          textAlign: TextAlign.center,
          style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
        ),
      ),
    );
  }
}

class _CandidateList extends StatelessWidget {
  const _CandidateList({
    required this.userList,
    required this.candidatePubkeys,
    required this.selected,
    required this.onToggle,
    this.labelBuilder,
  });

  final UserList userList;
  final List<String> candidatePubkeys;
  final Set<String> selected;
  final void Function(String pubkey) onToggle;
  final CandidateLabelBuilder? labelBuilder;

  @override
  Widget build(BuildContext context) {
    final memberSet = userList.pubkeys.toSet();

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: candidatePubkeys.length,
      itemBuilder: (context, index) {
        final pubkey = candidatePubkeys[index];
        final isMember = memberSet.contains(pubkey);
        final isSelected = isMember || selected.contains(pubkey);
        final label = labelBuilder?.call(pubkey) ?? _fallbackLabel(pubkey);

        return PersonPickableRow(
          pubkey: pubkey,
          displayName: label.displayName,
          handle: label.handle,
          avatarUrl: label.avatarUrl,
          isSelected: isSelected,
          enabled: !isMember,
          onTap: () => onToggle(pubkey),
        );
      },
    );
  }

  ({String displayName, String handle, String? avatarUrl}) _fallbackLabel(
    String pubkey,
  ) {
    final generated = UserProfile.defaultDisplayNameFor(pubkey);
    return (
      displayName: generated,
      handle: pubkey,
      avatarUrl: null,
    );
  }
}

class _AddButtonBar extends StatelessWidget {
  const _AddButtonBar({required this.selectionCount, required this.onPressed});

  final int selectionCount;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = selectionCount == 0
        ? l10n.peopleListsAddButton
        : l10n.peopleListsAddButtonWithCount(selectionCount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: DivineButton(
        label: label,
        expanded: true,
        onPressed: onPressed,
      ),
    );
  }
}
