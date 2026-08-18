// ABOUTME: Pins the cold-start hydration of NIP-09 coordinate tombstones from
// ABOUTME: persisted delete history, including the deletedAt unit conversion.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_provider_overrides.dart';

const _pubkey =
    'c3dd74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e';
const _dTag = 'clip-1';

/// Seconds, so the stored ISO timestamp round-trips to a Nostr `created_at`.
const _deletedAtSeconds = 2000;

VideoEvent _video({required String id, required int createdAt}) =>
    VideoEvent.fromNostrEvent(
      Event(
        _pubkey,
        34236,
        [
          ['d', _dTag],
          ['url', 'https://example.com/$id.mp4'],
        ],
        'a video',
        createdAt: createdAt,
      )..id = id,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('videoEventServiceProvider deletion-history hydration', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        ContentDeletionService.deletionsStorageKey: jsonEncode([
          {
            'deleteEventId': 'deletion-event-id',
            'originalEventId': 'original-event-id',
            'addressableId': '34236:$_pubkey:$_dTag',
            'reason': 'personal choice',
            'deletedAt': DateTime.fromMillisecondsSinceEpoch(
              _deletedAtSeconds * 1000,
              isUtc: true,
            ).toIso8601String(),
          },
        ]),
      });
      final prefs = await SharedPreferences.getInstance();

      container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockSharedPreferences: prefs),
          appVersionProvider.overrideWithValue('test'),
        ].cast(),
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'covers versions up to the persisted deletedAt, and no later ones',
      () {
        final service = container.read(videoEventServiceProvider);

        expect(
          service.isVideoEventKnownDeleted(
            _video(id: 'before', createdAt: _deletedAtSeconds - 1),
          ),
          isTrue,
          reason: 'published before the deletion request',
        );
        expect(
          service.isVideoEventKnownDeleted(
            _video(id: 'after', createdAt: _deletedAtSeconds + 1),
          ),
          isFalse,
          reason:
              'republished after the deletion request; a wrong unit conversion '
              'here silently makes every persisted tombstone cover nothing',
        );
      },
    );

    test('covers a version created at exactly the deletion timestamp', () {
      final service = container.read(videoEventServiceProvider);

      // NIP-09 deletes "up to the created_at timestamp" — inclusive.
      expect(
        service.isVideoEventKnownDeleted(
          _video(id: 'exact', createdAt: _deletedAtSeconds),
        ),
        isTrue,
      );
    });
  });
}
