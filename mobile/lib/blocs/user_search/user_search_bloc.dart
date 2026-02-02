// ABOUTME: BLoC for searching user profiles via Funnelcake REST API and NIP-50
// ABOUTME: Uses hybrid approach: fast REST first, then WebSocket fallback

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/services/analytics_api_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:stream_transform/stream_transform.dart';

part 'user_search_event.dart';
part 'user_search_state.dart';

/// Debounce duration for search queries
const _debounceDuration = Duration(milliseconds: 300);

/// Event transformer that debounces and restarts on new events
EventTransformer<E> _debounceRestartable<E>() {
  return (events, mapper) {
    return restartable<E>().call(events.debounce(_debounceDuration), mapper);
  };
}

/// BLoC for searching user profiles.
///
/// Handles:
/// - Searching users via Funnelcake REST API first (fast)
/// - Falling back to NIP-50 WebSocket search (comprehensive)
/// - Managing loading and error states
/// - Clearing search results
/// - Debouncing search queries (300ms)
class UserSearchBloc extends Bloc<UserSearchEvent, UserSearchState> {
  UserSearchBloc({
    required ProfileRepository profileRepository,
    AnalyticsApiService? analyticsApiService,
  }) : _profileRepository = profileRepository,
       _analyticsApiService = analyticsApiService,
       super(const UserSearchState()) {
    on<UserSearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(),
    );
    on<UserSearchCleared>(_onCleared);
  }

  final ProfileRepository _profileRepository;
  final AnalyticsApiService? _analyticsApiService;

  Future<void> _onQueryChanged(
    UserSearchQueryChanged event,
    Emitter<UserSearchState> emit,
  ) async {
    final query = event.query.trim();

    // Empty query resets to initial state
    if (query.isEmpty) {
      emit(const UserSearchState());
      return;
    }

    emit(state.copyWith(status: UserSearchStatus.loading, query: query));

    final resultMap = <String, UserProfile>{};

    try {
      // ===== PHASE 1: Funnelcake REST API (fast) =====
      if (_analyticsApiService?.isAvailable ?? false) {
        try {
          Log.debug(
            '🔍 UserSearchBloc: Trying Funnelcake REST search...',
            category: LogCategory.system,
          );

          final restResults = await _analyticsApiService!.searchProfiles(
            query: query,
            limit: 50,
          );

          for (final profileJson in restResults) {
            try {
              final profile = _profileFromFunnelcakeJson(profileJson);
              if (profile != null) {
                resultMap[profile.pubkey] = profile;
              }
            } catch (e) {
              Log.warning(
                '🔍 UserSearchBloc: Failed to parse profile: $e',
                category: LogCategory.system,
              );
            }
          }

          Log.info(
            '🔍 UserSearchBloc: REST search returned ${resultMap.length} '
            'profiles',
            category: LogCategory.system,
          );

          // Emit intermediate results from REST API
          if (resultMap.isNotEmpty) {
            emit(
              state.copyWith(
                status: UserSearchStatus.success,
                results: resultMap.values.toList(),
              ),
            );
          }
        } catch (e) {
          Log.warning(
            '🔍 UserSearchBloc: REST search failed, continuing to '
            'WebSocket: $e',
            category: LogCategory.system,
          );
        }
      }

      // ===== PHASE 2: WebSocket NIP-50 search (comprehensive) =====
      Log.debug(
        '🔍 UserSearchBloc: Starting WebSocket NIP-50 search...',
        category: LogCategory.system,
      );

      final wsResults = await _profileRepository.searchUsers(query: query);

      // Merge WebSocket results (don't overwrite REST results)
      for (final profile in wsResults) {
        resultMap.putIfAbsent(profile.pubkey, () => profile);
      }

      Log.info(
        '🔍 UserSearchBloc: Combined search returned ${resultMap.length} '
        'unique profiles',
        category: LogCategory.system,
      );

      emit(
        state.copyWith(
          status: UserSearchStatus.success,
          results: resultMap.values.toList(),
        ),
      );
    } catch (_) {
      // If we have REST results, still show them even if WebSocket fails
      if (resultMap.isNotEmpty) {
        emit(
          state.copyWith(
            status: UserSearchStatus.success,
            results: resultMap.values.toList(),
          ),
        );
      } else {
        emit(state.copyWith(status: UserSearchStatus.failure));
      }
    }
  }

  /// Convert Funnelcake profile JSON to UserProfile
  UserProfile? _profileFromFunnelcakeJson(Map<String, dynamic> json) {
    final pubkey = json['pubkey']?.toString();
    if (pubkey == null || pubkey.isEmpty) return null;

    return UserProfile(
      pubkey: pubkey,
      name: json['name']?.toString(),
      displayName:
          json['display_name']?.toString() ?? json['displayName']?.toString(),
      about: json['about']?.toString(),
      picture: json['picture']?.toString(),
      banner: json['banner']?.toString(),
      website: json['website']?.toString(),
      nip05: json['nip05']?.toString(),
      lud16: json['lud16']?.toString(),
      lud06: json['lud06']?.toString(),
      rawData: json,
      createdAt: _parseCreatedAt(json['created_at']),
      eventId: json['event_id']?.toString() ?? json['id']?.toString() ?? '',
    );
  }

  /// Parse created_at from various formats
  DateTime _parseCreatedAt(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  void _onCleared(UserSearchCleared event, Emitter<UserSearchState> emit) {
    emit(const UserSearchState());
  }
}
