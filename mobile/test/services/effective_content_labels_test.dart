import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/effective_content_labels.dart';
import 'package:openvine/services/moderation_label_service.dart';

/// Fake exposing only the four lookup getters that
/// [resolveEffectiveContentLabels] consumes; all other members are unused and
/// fall through to [noSuchMethod].
class _FakeModerationLabelService implements ModerationLabelService {
  _FakeModerationLabelService({
    Map<String, List<ModerationLabel>>? byAddressableId,
    Map<String, List<ModerationLabel>>? byEventId,
    Map<String, List<ModerationLabel>>? byHash,
    Map<String, List<ModerationLabel>>? byPubkey,
  }) : _byAddressableId = byAddressableId ?? const {},
       _byEventId = byEventId ?? const {},
       _byHash = byHash ?? const {},
       _byPubkey = byPubkey ?? const {};

  final Map<String, List<ModerationLabel>> _byAddressableId;
  final Map<String, List<ModerationLabel>> _byEventId;
  final Map<String, List<ModerationLabel>> _byHash;
  final Map<String, List<ModerationLabel>> _byPubkey;

  @override
  List<ModerationLabel> getContentWarningsByAddressableId(
    String addressableId,
  ) => _byAddressableId[addressableId] ?? const [];

  @override
  List<ModerationLabel> getContentWarnings(String eventId) =>
      _byEventId[eventId] ?? const [];

  @override
  List<ModerationLabel> getContentWarningsByHash(String sha256) =>
      _byHash[sha256] ?? const [];

  @override
  List<ModerationLabel> getLabelsForPubkey(String pubkey) =>
      _byPubkey[pubkey] ?? const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ModerationLabel _label(String value) => ModerationLabel(
  labelerPubkey: 'labeler-pubkey',
  labelValue: value,
  targetEventId: null,
);

VideoEvent _video({
  String id = 'event-id',
  String pubkey = 'author-pubkey',
  List<String> contentWarningLabels = const [],
  List<String> hashtags = const [],
  String? sha256,
  String? vineId,
}) => VideoEvent(
  id: id,
  pubkey: pubkey,
  createdAt: 1700000000,
  content: 'content',
  timestamp: DateTime(2024, 6, 15),
  hashtags: hashtags,
  sha256: sha256,
  vineId: vineId,
  contentWarningLabels: contentWarningLabels,
);

void main() {
  group('normalizeModerationLabelValue', () {
    test('returns null for null, empty, or whitespace-only input', () {
      expect(normalizeModerationLabelValue(null), isNull);
      expect(normalizeModerationLabelValue(''), isNull);
      expect(normalizeModerationLabelValue('   '), isNull);
    });

    test('passes canonical labels through unchanged', () {
      expect(normalizeModerationLabelValue('nudity'), equals('nudity'));
      expect(normalizeModerationLabelValue('violence'), equals('violence'));
    });

    test('trims and lowercases', () {
      expect(normalizeModerationLabelValue('  Nudity  '), equals('nudity'));
    });

    test('resolves known aliases to their canonical value', () {
      expect(normalizeModerationLabelValue('NSFW'), equals('nudity'));
      expect(normalizeModerationLabelValue('gore'), equals('graphic-media'));
      expect(normalizeModerationLabelValue('pornography'), equals('porn'));
      expect(normalizeModerationLabelValue('explicit'), equals('porn'));
      expect(normalizeModerationLabelValue('hate-speech'), equals('hate'));
      expect(normalizeModerationLabelValue('weapon'), equals('violence'));
      expect(normalizeModerationLabelValue('sexual_content'), equals('sexual'));
    });

    test('preserves unknown labels (trimmed + lowercased)', () {
      expect(
        normalizeModerationLabelValue('Custom Label'),
        equals('custom label'),
      );
      expect(normalizeModerationLabelValue('  Banana '), equals('banana'));
    });
  });

  group('resolveEffectiveContentLabels', () {
    test('returns empty when there are no labels, service, or hashtags', () {
      expect(resolveEffectiveContentLabels(_video()), isEmpty);
    });

    group('creator self-labels', () {
      test('includes content-warning labels in order', () {
        final result = resolveEffectiveContentLabels(
          _video(contentWarningLabels: ['nudity', 'violence']),
        );
        expect(result, equals(['nudity', 'violence']));
      });

      test('normalizes self-labels via known aliases', () {
        expect(
          resolveEffectiveContentLabels(
            _video(contentWarningLabels: ['NSFW', 'GORE']),
          ),
          equals(['nudity', 'graphic-media']),
        );
      });

      test('preserves unknown self-labels', () {
        expect(
          resolveEffectiveContentLabels(
            _video(contentWarningLabels: ['Spicy Take']),
          ),
          equals(['spicy take']),
        );
      });

      test('skips empty and whitespace-only self-labels', () {
        expect(
          resolveEffectiveContentLabels(
            _video(contentWarningLabels: ['', '   ', 'nudity']),
          ),
          equals(['nudity']),
        );
      });

      test('de-duplicates after normalization', () {
        expect(
          resolveEffectiveContentLabels(
            _video(contentWarningLabels: ['nudity', 'NSFW', 'nudity']),
          ),
          equals(['nudity']),
        );
      });
    });

    group('hashtag fallback', () {
      test('maps #nsfw and #adult to nudity (case-insensitive)', () {
        expect(
          resolveEffectiveContentLabels(_video(hashtags: ['nsfw'])),
          equals(['nudity']),
        );
        expect(
          resolveEffectiveContentLabels(_video(hashtags: ['adult'])),
          equals(['nudity']),
        );
        expect(
          resolveEffectiveContentLabels(_video(hashtags: ['  NSFW '])),
          equals(['nudity']),
        );
      });

      test('ignores unrelated hashtags', () {
        expect(
          resolveEffectiveContentLabels(_video(hashtags: ['funny', 'cats'])),
          isEmpty,
        );
      });

      test('de-duplicates against an existing self-label', () {
        expect(
          resolveEffectiveContentLabels(
            _video(contentWarningLabels: ['nudity'], hashtags: ['nsfw']),
          ),
          equals(['nudity']),
        );
      });
    });

    group('moderation label service', () {
      test('includes labels matched by addressable id', () {
        final video = _video(vineId: 'vine-123');
        final service = _FakeModerationLabelService(
          byAddressableId: {
            video.addressableId!: [_label('sexual')],
          },
        );
        expect(
          resolveEffectiveContentLabels(video, moderationLabelService: service),
          equals(['sexual']),
        );
      });

      test('includes labels matched by event id', () {
        final video = _video(id: 'evt-xyz');
        final service = _FakeModerationLabelService(
          byEventId: {
            'evt-xyz': [_label('graphic-media')],
          },
        );
        expect(
          resolveEffectiveContentLabels(video, moderationLabelService: service),
          equals(['graphic-media']),
        );
      });

      test('includes labels matched by content hash', () {
        final video = _video(sha256: 'deadbeef');
        final service = _FakeModerationLabelService(
          byHash: {
            'deadbeef': [_label('violence')],
          },
        );
        expect(
          resolveEffectiveContentLabels(video, moderationLabelService: service),
          equals(['violence']),
        );
      });

      test('includes account-level labels matched by pubkey', () {
        final video = _video(pubkey: 'author-9');
        final service = _FakeModerationLabelService(
          byPubkey: {
            'author-9': [_label('hate')],
          },
        );
        expect(
          resolveEffectiveContentLabels(video, moderationLabelService: service),
          equals(['hate']),
        );
      });

      test('skips addressable and hash lookups when those ids are absent', () {
        // No vineId => addressableId is null; sha256 is null. Only event-id and
        // pubkey lookups should run.
        final video = _video(id: 'evt-1', pubkey: 'pk-1');
        final service = _FakeModerationLabelService(
          byAddressableId: {
            'unused': [_label('porn')],
          },
          byHash: {
            'unused': [_label('porn')],
          },
          byEventId: {
            'evt-1': [_label('violence')],
          },
          byPubkey: {
            'pk-1': [_label('hate')],
          },
        );
        expect(
          resolveEffectiveContentLabels(video, moderationLabelService: service),
          equals(['violence', 'hate']),
        );
      });

      test('skips the hash lookup when sha256 is empty', () {
        final video = _video(id: 'evt-2', sha256: '');
        final service = _FakeModerationLabelService(
          byHash: {
            '': [_label('porn')],
          },
        );
        expect(
          resolveEffectiveContentLabels(video, moderationLabelService: service),
          isEmpty,
        );
      });

      test('normalizes service label values', () {
        final video = _video(id: 'evt-3');
        final service = _FakeModerationLabelService(
          byEventId: {
            'evt-3': [_label('NSFW')],
          },
        );
        expect(
          resolveEffectiveContentLabels(video, moderationLabelService: service),
          equals(['nudity']),
        );
      });

      test('preserves unknown service label values', () {
        final video = _video(id: 'evt-4');
        final service = _FakeModerationLabelService(
          byEventId: {
            'evt-4': [_label('Experimental')],
          },
        );
        expect(
          resolveEffectiveContentLabels(video, moderationLabelService: service),
          equals(['experimental']),
        );
      });

      test('de-duplicates a service label against a self-label', () {
        final video = _video(
          pubkey: 'pk-dup',
          contentWarningLabels: ['nudity'],
        );
        final service = _FakeModerationLabelService(
          byPubkey: {
            'pk-dup': [_label('nudity')],
          },
        );
        expect(
          resolveEffectiveContentLabels(video, moderationLabelService: service),
          equals(['nudity']),
        );
      });

      test('merges all sources in priority order without duplicates', () {
        final video = _video(
          id: 'evt-merge',
          pubkey: 'pk-merge',
          sha256: 'hash-merge',
          vineId: 'vine-merge',
          contentWarningLabels: ['nudity'],
          hashtags: ['nsfw'], // also resolves to nudity -> deduped
        );
        final service = _FakeModerationLabelService(
          byAddressableId: {
            video.addressableId!: [_label('sexual')],
          },
          byEventId: {
            'evt-merge': [_label('violence')],
          },
          byHash: {
            'hash-merge': [_label('porn')],
          },
          byPubkey: {
            'pk-merge': [_label('hate')],
          },
        );
        expect(
          resolveEffectiveContentLabels(video, moderationLabelService: service),
          equals(['nudity', 'sexual', 'violence', 'porn', 'hate']),
        );
      });
    });
  });
}
