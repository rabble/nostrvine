// ABOUTME: Riverpod wiring for the remotely controlled post-publish experiment.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/post_publish/post_publish_experiment.dart';
import 'package:openvine/providers/analytics_providers.dart';

final postPublishFlagClientProvider = Provider<PostPublishFlagClient>((ref) {
  final client = FirebasePostPublishFlagClient();
  ref.onDispose(client.dispose);
  return client;
});

final postPublishExperimentProvider = Provider<PostPublishExperiment>((ref) {
  return PostPublishExperiment(
    flags: ref.watch(postPublishFlagClientProvider),
    analytics: ref.watch(analyticsEventSinkProvider),
  );
});
