// ABOUTME: Events for [TagsPickerBloc].

part of 'tags_picker_bloc.dart';

/// Base class for tags picker events.
sealed class TagsPickerEvent extends Equatable {
  const TagsPickerEvent();

  @override
  List<Object?> get props => const [];
}

/// One or more raw tokens were committed by the user (separator typed, paste,
/// submit, or suggestion tap). The bloc is responsible for sanitizing and
/// deduplicating before adding them to the selected set.
final class TagsPickerTagsAdded extends TagsPickerEvent {
  const TagsPickerTagsAdded(this.rawTokens);

  final List<String> rawTokens;

  @override
  List<Object?> get props => [rawTokens];
}

/// User selected a suggestion chip while keeping the current search active.
final class TagsPickerSuggestionSelected extends TagsPickerEvent {
  const TagsPickerSuggestionSelected(this.tag);

  final String tag;

  @override
  List<Object?> get props => [tag];
}

/// User removed a previously selected tag.
final class TagsPickerTagRemoved extends TagsPickerEvent {
  const TagsPickerTagRemoved(this.tag);

  final String tag;

  @override
  List<Object?> get props => [tag];
}

/// The current (uncommitted) query in the search field changed.
final class TagsPickerQueryChanged extends TagsPickerEvent {
  const TagsPickerQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// Clears the current query and search results immediately.
final class TagsPickerSearchCleared extends TagsPickerEvent {
  const TagsPickerSearchCleared();
}
