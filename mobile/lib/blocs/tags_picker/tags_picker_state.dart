// ABOUTME: State for [TagsPickerBloc].

part of 'tags_picker_bloc.dart';

/// Status of the tags picker search lifecycle.
enum TagsPickerStatus {
  /// No query is active; suggestions are empty.
  initial,

  /// A debounced search is in flight.
  searching,

  /// Search completed; [TagsPickerState.suggestions] is populated (possibly
  /// empty if the repository found no matches or fell back silently).
  success,
}

/// State for the tags picker sheet.
final class TagsPickerState extends Equatable {
  const TagsPickerState({
    this.selectedTags = const <String>{},
    this.query = '',
    this.suggestions = const <String>[],
    this.status = TagsPickerStatus.initial,
  });

  /// Tags the user has committed in this session.
  final Set<String> selectedTags;

  /// Current (trimmed) query driving the suggestion list.
  final String query;

  /// Suggestions returned by [HashtagRepository], minus anything that has
  /// already been selected.
  final List<String> suggestions;

  /// Lifecycle of the suggestion search.
  final TagsPickerStatus status;

  /// The sanitized query — i.e. what would be added if the user committed it.
  String get sanitizedQuery => query.replaceAll(_sanitizePattern, '');

  /// Whether the sanitized query is non-empty and not already selected
  /// (case-insensitive).
  bool get canAddQuery {
    final s = sanitizedQuery;
    if (s.isEmpty) return false;
    final lower = s.toLowerCase();
    return !selectedTags.any((t) => t.toLowerCase() == lower);
  }

  TagsPickerState copyWith({
    Set<String>? selectedTags,
    String? query,
    List<String>? suggestions,
    TagsPickerStatus? status,
  }) {
    return TagsPickerState(
      selectedTags: selectedTags ?? this.selectedTags,
      query: query ?? this.query,
      suggestions: suggestions ?? this.suggestions,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [selectedTags, query, suggestions, status];
}
