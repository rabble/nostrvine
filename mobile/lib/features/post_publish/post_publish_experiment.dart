// ABOUTME: Deterministically assigns the post-publish create-again experiment.
// ABOUTME: Uses Firebase Remote Config as a live kill switch.

import 'dart:async';
import 'dart:convert';

import 'package:analytics/analytics.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:unified_logger/unified_logger.dart';

const postPublishCreateAgainRemoteConfigKey =
    'post_publish_create_again_enabled';

enum PostPublishVariant {
  control('control'),
  createAgain('create_again');

  const PostPublishVariant(this.analyticsName);

  final String analyticsName;
}

abstract interface class PostPublishFlagClient {
  Future<void> initialize();
  bool get createAgainEnabled;
  void dispose();
}

class FirebasePostPublishFlagClient implements PostPublishFlagClient {
  FirebasePostPublishFlagClient({this.defaultEnabled = true});

  final bool defaultEnabled;
  FirebaseRemoteConfig? _remoteConfig;
  StreamSubscription<RemoteConfigUpdate>? _updates;
  Future<void>? _initialization;
  bool _defaultsReady = false;

  @override
  bool get createAgainEnabled {
    if (!_defaultsReady) return defaultEnabled;
    try {
      return _remoteConfig?.getBool(postPublishCreateAgainRemoteConfigKey) ??
          defaultEnabled;
    } catch (_) {
      return defaultEnabled;
    }
  }

  @override
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      _remoteConfig = remoteConfig;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults({
        postPublishCreateAgainRemoteConfigKey: defaultEnabled,
      });
      _defaultsReady = true;

      try {
        await remoteConfig.fetchAndActivate();
      } catch (error) {
        Log.warning(
          'Post-publish Remote Config fetch failed: $error',
          name: 'FirebasePostPublishFlagClient',
          category: LogCategory.system,
        );
      }

      _updates = remoteConfig.onConfigUpdated.listen((_) async {
        try {
          await remoteConfig.activate();
        } catch (error) {
          Log.warning(
            'Post-publish Remote Config activation failed: $error',
            name: 'FirebasePostPublishFlagClient',
            category: LogCategory.system,
          );
        }
      });
    } catch (error) {
      Log.warning(
        'Post-publish Remote Config unavailable: $error',
        name: 'FirebasePostPublishFlagClient',
        category: LogCategory.system,
      );
    }
  }

  @override
  void dispose() {
    unawaited(_updates?.cancel());
  }
}

class PostPublishCreateAgainOffer {
  const PostPublishCreateAgainOffer({required this.publishedAt});

  final DateTime publishedAt;
}

class PostPublishExperiment {
  PostPublishExperiment({
    required PostPublishFlagClient flags,
    required AnalyticsEventSink analytics,
    DateTime Function()? now,
  }) : _flags = flags,
       _analytics = analytics,
       _now = now ?? DateTime.now;

  final PostPublishFlagClient _flags;
  final AnalyticsEventSink _analytics;
  final DateTime Function() _now;
  final Map<String, PostPublishVariant> _publishVariants = {};

  Future<void> initialize() => _flags.initialize();

  PostPublishVariant variantForUser(String? pubkeyHex) {
    if (!_flags.createAgainEnabled || pubkeyHex == null) {
      return PostPublishVariant.control;
    }
    final assignmentByte = sha256.convert(utf8.encode(pubkeyHex)).bytes.first;
    return assignmentByte < 128
        ? PostPublishVariant.control
        : PostPublishVariant.createAgain;
  }

  Future<void> screenShown({
    required String publishId,
    required String destination,
    required PostPublishVariant variant,
  }) async {
    _publishVariants[publishId] = variant;
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
    for (final publishId in publishIds) {
      _publishVariants.remove(publishId);
    }
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
