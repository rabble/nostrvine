// ABOUTME: Bridges the content-policy engine to a repository-level filter.

import 'package:content_policy/content_policy.dart';
import 'package:videos_repository/videos_repository.dart';

/// Creates a [BlockedVideoFilter] backed by [engine].
///
/// [stateProvider] is invoked on every filter call so the filter
/// always reads the freshest [ContentPolicyState] snapshot without
/// capturing a stale copy.
BlockedVideoFilter createPolicyEngineFilter(
  ContentPolicyEngine engine,
  ContentPolicyState Function() stateProvider,
) {
  return (String pubkey) {
    final decision = engine.evaluate(
      PolicyInput(pubkey: pubkey),
      stateProvider(),
    );
    return decision is Block;
  };
}
