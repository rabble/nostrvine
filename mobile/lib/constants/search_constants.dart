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
