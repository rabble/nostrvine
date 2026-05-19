// ABOUTME: State for the SoundLibraryBloc.
// ABOUTME: Tracks providers list, selected provider, query, results, and paging.

part of 'sound_library_bloc.dart';

/// Status of the proxy-providers-list fetch.
enum SoundLibraryProvidersStatus { initial, loading, loaded, failure }

/// Status of the in-flight search.
enum SoundLibrarySearchStatus { initial, loading, loadingMore, loaded, failure }

/// State for the sound-library feature.
final class SoundLibraryState extends Equatable {
  const SoundLibraryState({
    this.providersStatus = SoundLibraryProvidersStatus.initial,
    this.providers = const [],
    this.selectedProvider = 'divine',
    this.searchStatus = SoundLibrarySearchStatus.initial,
    this.query = '',
    this.sounds = const [],
    this.page = 1,
    this.pageSize = 20,
    this.nextPage,
    this.count = 0,
  });

  final SoundLibraryProvidersStatus providersStatus;
  final List<SoundLibraryProviderInfo> providers;
  final String selectedProvider;

  final SoundLibrarySearchStatus searchStatus;
  final String query;
  final List<AudioEvent> sounds;
  final int page;
  final int pageSize;
  final int? nextPage;
  final int count;

  /// Whether more pages can be loaded for the current query.
  bool get hasMore => nextPage != null;

  SoundLibraryState copyWith({
    SoundLibraryProvidersStatus? providersStatus,
    List<SoundLibraryProviderInfo>? providers,
    String? selectedProvider,
    SoundLibrarySearchStatus? searchStatus,
    String? query,
    List<AudioEvent>? sounds,
    int? page,
    int? pageSize,
    int? nextPage,
    bool clearNextPage = false,
    int? count,
  }) {
    return SoundLibraryState(
      providersStatus: providersStatus ?? this.providersStatus,
      providers: providers ?? this.providers,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      searchStatus: searchStatus ?? this.searchStatus,
      query: query ?? this.query,
      sounds: sounds ?? this.sounds,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      nextPage: clearNextPage ? null : (nextPage ?? this.nextPage),
      count: count ?? this.count,
    );
  }

  @override
  List<Object?> get props => [
    providersStatus,
    providers,
    selectedProvider,
    searchStatus,
    query,
    sounds,
    page,
    pageSize,
    nextPage,
    count,
  ];
}
