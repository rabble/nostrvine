// ABOUTME: Deterministically assigns the post-publish create-again experiment.
// ABOUTME: Assignment is local: sha256 over the pubkey, no remote input.

import 'dart:convert';

import 'package:analytics/analytics.dart';
import 'package:crypto/crypto.dart';
import 'package:unified_logger/unified_logger.dart';

enum PostPublishVariant {
  control('control'),
  createAgain('create_again');

  const PostPublishVariant(this.analyticsName);

  final String analyticsName;
}

class PostPublishCreateAgainOffer {
  const PostPublishCreateAgainOffer({required this.publishedAt});

  final DateTime publishedAt;
}

class PostPublishExperiment {
  PostPublishExperiment({
    required AnalyticsEventSink analytics,
    DateTime Function()? now,
  }) : _analytics = analytics,
       _now = now ?? DateTime.now;

  final AnalyticsEventSink _analytics;
  final DateTime Function() _now;

  /// Pending assignments, oldest first. A publish that neither succeeds nor
  /// fails in this app session (a vanished background entry, a kill before
  /// the upload resolves) never reaches [completed] or [failed], so the map
  /// is capped and evicts its oldest entry instead of growing for the
  /// lifetime of the process.
  final Map<String, PostPublishVariant> _publishVariants = {};

  static const _maxPendingVariants = 32;

  PostPublishVariant variantForUser(String? pubkeyHex) {
    if (pubkeyHex == null) return PostPublishVariant.control;
    // Lowercased so a signer that returns uppercase hex cannot move the same
    // account between buckets.
    final assignmentByte = sha256
        .convert(utf8.encode(pubkeyHex.toLowerCase()))
        .bytes
        .first;
    return assignmentByte < 128
        ? PostPublishVariant.control
        : PostPublishVariant.createAgain;
  }

  Future<void> screenShown({
    required String publishId,
    required String destination,
    required PostPublishVariant variant,
  }) async {
    _publishVariants
      ..remove(publishId)
      ..[publishId] = variant;
    while (_publishVariants.length > _maxPendingVariants) {
      _publishVariants.remove(_publishVariants.keys.first);
    }
    await _logEvent(
      name: 'post_publish_screen_shown',
      parameters: {
        'destination': destination,
        'variant': variant.analyticsName,
      },
    );
  }

  PostPublishCreateAgainOffer? completed(Set<String> publishIds) {
    var showCreateAgain = false;
    for (final publishId in publishIds) {
      showCreateAgain =
          _publishVariants.remove(publishId) ==
              PostPublishVariant.createAgain ||
          showCreateAgain;
    }
    return showCreateAgain
        ? PostPublishCreateAgainOffer(publishedAt: _now())
        : null;
  }

  void failed(Set<String> publishIds) {
    publishIds.forEach(_publishVariants.remove);
  }

  Future<void> createAgainTapped(PostPublishCreateAgainOffer offer) async {
    final elapsed = _now().difference(offer.publishedAt).inSeconds;
    await _logEvent(
      name: 'post_publish_create_again_tapped',
      parameters: {'seconds_since_publish': elapsed < 0 ? 0 : elapsed},
    );
  }

  Future<void> _logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (error) {
      Log.warning(
        'Post-publish analytics event $name failed: $error',
        name: 'PostPublishExperiment',
        category: LogCategory.system,
      );
    }
  }
}
