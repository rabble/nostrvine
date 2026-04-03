part of 'app_detail_cubit.dart';

/// State for the [AppDetailCubit].
sealed class AppDetailState extends Equatable {
  const AppDetailState();
}

/// The entry is being resolved.
class AppDetailLoading extends AppDetailState {
  /// Creates a loading state.
  const AppDetailLoading();

  @override
  List<Object?> get props => [];
}

/// The entry was resolved successfully.
class AppDetailLoaded extends AppDetailState {
  /// Creates a loaded state.
  const AppDetailLoaded(this.app);

  /// The resolved directory entry.
  final NostrAppDirectoryEntry app;

  @override
  List<Object?> get props => [app];
}

/// The entry was not found.
class AppDetailNotFound extends AppDetailState {
  /// Creates a not-found state.
  const AppDetailNotFound();

  @override
  List<Object?> get props => [];
}
