// ABOUTME: Events for the CategoriesBloc
// ABOUTME: Defines actions for loading categories, selecting, and pagination

part of 'categories_bloc.dart';

/// Base class for all categories events.
sealed class CategoriesEvent extends Equatable {
  const CategoriesEvent();

  @override
  List<Object?> get props => [];
}

/// Request to load the list of categories.
final class CategoriesLoadRequested extends CategoriesEvent {
  const CategoriesLoadRequested();
}

/// A category was selected to view its videos.
final class CategorySelected extends CategoriesEvent {
  const CategorySelected(this.category);

  final VideoCategory category;

  @override
  List<Object?> get props => [category];
}

/// Request to load more videos in the current category.
final class CategoryVideosLoadMore extends CategoriesEvent {
  const CategoryVideosLoadMore();
}

/// Sort order changed for category videos.
final class CategoryVideosSortChanged extends CategoriesEvent {
  const CategoryVideosSortChanged(this.sort);

  final String sort;

  @override
  List<Object?> get props => [sort];
}

/// Go back to the categories grid (deselect current category).
final class CategoryDeselected extends CategoriesEvent {
  const CategoryDeselected();
}
