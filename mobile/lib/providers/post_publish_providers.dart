// ABOUTME: Riverpod wiring for the post-publish create-again experiment.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/post_publish/post_publish_experiment.dart';
import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/social_providers.dart';

final postPublishExperimentProvider = Provider<PostPublishExperiment>((ref) {
  return PostPublishExperiment(
    analytics: ref.watch(analyticsEventSinkProvider),
    recordExposure: (variant) async {
      await ref
          .read(analyticsServiceProvider)
          .recordExperimentExposure(
            experimentKey: 'post_publish_confirmation',
            variantKey: variant.analyticsName,
            assignmentSource: ProductAnalyticsV2AssignmentSource.client,
          );
    },
  );
});
