import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/search_results/widgets/search_filter_pill.dart';

/// App bar for the search results screen.
///
/// Receives its [TextEditingController] from the parent (so the body can
/// read the same live text) and owns the [FocusNode] and listener
/// lifecycle. Dispatches `*QueryChanged` events to the four search BLoCs
/// on text changes.
class SearchResultsAppBar extends StatefulWidget {
  const SearchResultsAppBar({
    required this.controller,
    required this.initialQuery,
    this.requestFocusOnMount = false,
    super.key,
  });

  /// Shared text controller. Owned and disposed by the parent so the body
  /// can subscribe to the same live value for its idle-placeholder gate.
  final TextEditingController controller;

  /// Pre-filled search text. The parent seeds [controller] with this value
  /// at construction; we use it here only to decide whether to (a) dispatch
  /// the initial query synchronously and (b) request focus on mount.
  final String initialQuery;

  /// When true, a prefilled search field claims focus after the first frame.
  ///
  /// Route call sites must opt in explicitly so prefilled destinations like
  /// mention taps and search deep links can keep the keyboard dismissed.
  ///
  /// Empty-query mounts still request focus by default.
  final bool requestFocusOnMount;

  @override
  State<SearchResultsAppBar> createState() => _SearchResultsAppBarState();
}

class _SearchResultsAppBarState extends State<SearchResultsAppBar> {
  late final FocusNode _focusNode;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    if (widget.initialQuery.isNotEmpty) {
      // Synchronous dispatch — bypass the UI 300ms debounce so the BLoCs
      // leave `initial` this frame, preventing the misleading idle
      // placeholder during Explore → Search transitions (#3802). Each
      // BLoC still applies its own `debounceRestartable` transformer;
      // the same-query dedup guard inside each handler coalesces a
      // late-arriving event from the listener if one happens to fire.
      _dispatchQuery(widget.initialQuery);
    }

    if (widget.requestFocusOnMount || widget.initialQuery.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }

    // Attach the listener AFTER the synchronous initial dispatch so the
    // controller's pre-seeded text (set in the parent's initState) does
    // not bounce through the debounced path and produce a duplicate event.
    widget.controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onSearchChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _dispatchQuery(widget.controller.text);
    });
  }

  void _dispatchQuery(String query) {
    context.read<VideoSearchBloc>().add(VideoSearchQueryChanged(query));
    context.read<UserSearchBloc>().add(UserSearchQueryChanged(query));
    context.read<HashtagSearchBloc>().add(HashtagSearchQueryChanged(query));
    context.read<ListSearchBloc>().add(ListSearchQueryChanged(query));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          spacing: 8,
          children: [
            DivineIconButton(
              icon: DivineIconName.caretLeft,
              type: DivineIconButtonType.secondary,
              size: DivineIconButtonSize.small,
              onPressed: () => Navigator.of(context).maybePop(),
              semanticLabel: context.l10n.commonBack,
            ),
            Expanded(
              child: DivineSearchBar(
                controller: widget.controller,
                focusNode: _focusNode,
                hintText: context.l10n.exploreSearchHint,
                suffixIcon: const SearchFilterPill(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
