// ABOUTME: State for ContentFiltersCubit — per-category content-filter
// ABOUTME: preferences plus the age-verification gate flag.

import 'package:equatable/equatable.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/content_filter_service.dart';

/// Load lifecycle of the content filters screen.
enum ContentFiltersStatus { loading, ready }

/// State for [ContentFiltersCubit].
///
/// [preferences] is read once from `ContentFilterService` on load (replacing
/// the pre-migration per-row imperative reads in `build`). Adult categories are
/// locked in the UI when [isAgeVerified] is false.
class ContentFiltersState extends Equatable {
  const ContentFiltersState({
    this.status = ContentFiltersStatus.loading,
    this.isAgeVerified = false,
    this.preferences = const {},
  });

  final ContentFiltersStatus status;
  final bool isAgeVerified;
  final Map<ContentLabel, ContentFilterPreference> preferences;

  /// Preference for [label], defaulting to "show" until loaded.
  ContentFilterPreference preferenceFor(ContentLabel label) =>
      preferences[label] ?? ContentFilterPreference.show;

  ContentFiltersState copyWith({
    ContentFiltersStatus? status,
    bool? isAgeVerified,
    Map<ContentLabel, ContentFilterPreference>? preferences,
  }) {
    return ContentFiltersState(
      status: status ?? this.status,
      isAgeVerified: isAgeVerified ?? this.isAgeVerified,
      preferences: preferences ?? this.preferences,
    );
  }

  @override
  List<Object?> get props => [status, isAgeVerified, preferences];
}
