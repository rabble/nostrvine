// ABOUTME: Shared constants and utilities for search UX and performance.

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

/// Debounce duration applied to search query updates.
const searchDebounceDuration = Duration(milliseconds: 300);

/// Minimum query length before expensive search work should start.
///
/// Single-character queries tend to explode result sets and force broad local
/// scans plus remote searches on every keystroke.
const minSearchQueryLength = 2;

/// Maximum counterparty profiles resolved per inbox-search pass.
///
/// `ProfileRepository.fetchBatchProfiles` falls back to one parallel relay
/// request per uncached pubkey, so resolving an entire large inbox in a single
/// call would fan out one request per conversation on the first keystroke.
const searchProfileResolveChunkSize = 50;

/// Outer timeout the user-search bloc applies to the entire progressive
/// stream. When it fires, the bloc still emits the accumulated results
/// but marks every source still in [SearchSourcePending] as
/// [SearchSourceFailed] with reason
/// [SearchSourceFailureReason.timeout] — driving the UI to surface a
/// retry affordance instead of a misleading "No results found".
const userSearchOuterTimeout = Duration(seconds: 20);

/// Event transformer that debounces then restarts on new events.
///
/// Combines [searchDebounceDuration] debounce with a restartable (switchMap)
/// strategy so only the latest query is processed.
EventTransformer<E> debounceRestartable<E>() {
  return (events, mapper) {
    return restartable<E>().call(
      events.debounce(searchDebounceDuration),
      mapper,
    );
  };
}
