// ABOUTME: BLoC for the video metadata tags picker sheet.
// ABOUTME: Sanitizes / dedups committed tags and searches suggestions.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:openvine/constants/search_constants.dart';

part 'tags_picker_event.dart';
part 'tags_picker_state.dart';

/// Allowed characters in a hashtag — everything else is stripped on commit.
final _sanitizePattern = RegExp('[^a-zA-Z0-9]');

/// Matches one or more consecutive tag separators (space or comma). Used
/// both for detecting whether the input contains a separator and for
/// splitting it into tokens.
final _separatorPattern = RegExp('[ ,]+');

/// Result of parsing a tag-input text change into committable tokens
/// plus a remainder that should stay in the text field.
class TagsPickerInputParseResult {
  /// Creates a parse result.
  const TagsPickerInputParseResult({
    required this.completed,
    required this.remainder,
  });

  /// Tokens that are ready to be added to the selected tags.
  final List<String> completed;

  /// Trailing partial token that should remain in the text field.
  final String remainder;
}

/// Pure parser that decides which tokens are completed and which is a
/// remainder partial token, based on the new and previous text.
///
/// A "paste" is detected when [text] grew by more than one character vs
/// [previousText]; in that case the trailing token is also committed
/// (so pasting `"foo, bar, baz"` adds all three).
///
/// This is the parsing rule for the tags picker text field. The widget
/// is only responsible for forwarding the result to the controller and
/// dispatching the bloc events.
TagsPickerInputParseResult parseTagsPickerInput({
  required String text,
  required String previousText,
}) {
  if (!text.contains(_separatorPattern)) {
    return TagsPickerInputParseResult(
      completed: const [],
      remainder: text,
    );
  }
  final parts = text.split(_separatorPattern);
  // Heuristic: input that grew by >1 character in a single notifier tick
  // is treated as a paste. Safe today because the field filters to
  // [a-zA-Z0-9 ,] — if the allow-list is widened, autocorrect / IME
  // (e.g. CJK composition, swipe-to-type, `omw` → `on my way`) may land
  // here and unexpectedly commit a token.
  final isPaste = text.length - previousText.length > 1;
  if (isPaste) {
    return TagsPickerInputParseResult(
      completed: parts.where((p) => p.isNotEmpty).toList(),
      remainder: '',
    );
  }
  return TagsPickerInputParseResult(
    completed: parts
        .sublist(0, parts.length - 1)
        .where((p) => p.isNotEmpty)
        .toList(),
    remainder: parts.last,
  );
}

/// BLoC that owns the state of the tags picker sheet.
///
/// Responsibilities:
///   * sanitize and deduplicate tokens before adding them to [TagsPickerState.selectedTags]
///   * debounce-restart hashtag search requests against [HashtagRepository]
///   * filter the resulting suggestions against already-selected tags
class TagsPickerBloc extends Bloc<TagsPickerEvent, TagsPickerState> {
  TagsPickerBloc({
    required HashtagRepository hashtagRepository,
    required Set<String> initialTags,
  }) : _hashtagRepository = hashtagRepository,
       super(TagsPickerState(selectedTags: Set.of(initialTags))) {
    on<TagsPickerTagsAdded>(_onTagsAdded);
    on<TagsPickerTagRemoved>(_onTagRemoved);
    on<TagsPickerQueryChanged>(
      _onQueryChanged,
      transformer: debounceRestartable(),
    );
  }

  final HashtagRepository _hashtagRepository;

  void _onTagsAdded(
    TagsPickerTagsAdded event,
    Emitter<TagsPickerState> emit,
  ) {
    final updated = Set<String>.of(state.selectedTags);
    var changed = false;
    for (final raw in event.rawTokens) {
      final tag = raw.replaceAll(_sanitizePattern, '');
      if (tag.isEmpty) continue;
      final exists = updated.any(
        (t) => t.toLowerCase() == tag.toLowerCase(),
      );
      if (exists) continue;
      updated.add(tag);
      changed = true;
    }
    if (!changed) return;
    emit(
      state.copyWith(
        selectedTags: updated,
        suggestions: _filterSuggestions(state.suggestions, updated),
      ),
    );
  }

  void _onTagRemoved(
    TagsPickerTagRemoved event,
    Emitter<TagsPickerState> emit,
  ) {
    if (!state.selectedTags.contains(event.tag)) return;
    final updated = Set<String>.of(state.selectedTags)..remove(event.tag);
    emit(state.copyWith(selectedTags: updated));
  }

  Future<void> _onQueryChanged(
    TagsPickerQueryChanged event,
    Emitter<TagsPickerState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      emit(
        state.copyWith(
          status: TagsPickerStatus.initial,
          query: '',
          suggestions: const [],
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: TagsPickerStatus.searching,
        query: query,
      ),
    );

    // HashtagRepository.searchHashtags is documented as never-throws and
    // falls back to an empty list on any upstream failure, so we don't need
    // a try/catch or a separate failure status here.
    final results = await _hashtagRepository.searchHashtags(query: query);
    emit(
      state.copyWith(
        status: TagsPickerStatus.success,
        suggestions: _filterSuggestions(results, state.selectedTags),
      ),
    );
  }

  static List<String> _filterSuggestions(
    List<String> suggestions,
    Set<String> selected,
  ) {
    if (suggestions.isEmpty) return suggestions;
    final lowerSelected = selected.map((t) => t.toLowerCase()).toSet();
    return suggestions
        .where((s) => !lowerSelected.contains(s.toLowerCase()))
        .toList();
  }
}
