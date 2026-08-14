// ABOUTME: Riverpod wiring for the post-publish create-again experiment.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/post_publish/post_publish_experiment.dart';
import 'package:openvine/providers/analytics_providers.dart';

final postPublishExperimentProvider = Provider<PostPublishExperiment>((ref) {
  return PostPublishExperiment(
    analytics: ref.watch(analyticsEventSinkProvider),
  );
});
