// ABOUTME: Tests for the content-moderation value types (report reasons,
// ABOUTME: severity, mute entries, moderation result).

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/content_moderation_types.dart';

void main() {
  group(MuteListEntry, () {
    final entry = MuteListEntry(
      type: 'pubkey',
      value: 'abc123',
      reason: ContentFilterReason.harassment,
      severity: ContentSeverity.hide,
      createdAt: DateTime.utc(2026, 6, 13, 12),
      note: 'repeated abuse',
    );

    test('toJson serializes enums by name and date as ISO-8601', () {
      expect(entry.toJson(), {
        'type': 'pubkey',
        'value': 'abc123',
        'reason': 'harassment',
        'severity': 'hide',
        'createdAt': '2026-06-13T12:00:00.000Z',
        'note': 'repeated abuse',
      });
    });

    test('fromJson round-trips a serialized entry', () {
      final restored = MuteListEntry.fromJson(entry.toJson());
      expect(restored.type, entry.type);
      expect(restored.value, entry.value);
      expect(restored.reason, entry.reason);
      expect(restored.severity, entry.severity);
      expect(restored.createdAt, entry.createdAt);
      expect(restored.note, entry.note);
    });

    test('fromJson falls back to safe defaults for unknown enum names', () {
      final restored = MuteListEntry.fromJson({
        'type': 'pubkey',
        'value': 'abc123',
        'reason': 'not_a_real_reason',
        'severity': 'not_a_real_severity',
        'createdAt': '2026-06-13T12:00:00.000Z',
        'note': null,
      });
      expect(restored.reason, ContentFilterReason.other);
      expect(restored.severity, ContentSeverity.hide);
      expect(restored.note, isNull);
    });

    test('toNIP51Tag omits the note when absent', () {
      final noNote = MuteListEntry(
        type: 'keyword',
        value: 'spammy',
        reason: ContentFilterReason.spam,
        severity: ContentSeverity.warning,
        createdAt: DateTime.utc(2026),
      );
      expect(noNote.toNIP51Tag(), ['keyword', 'spammy']);
      expect(entry.toNIP51Tag(), ['pubkey', 'abc123', 'repeated abuse']);
    });
  });

  group(ModerationResult, () {
    test('clean is an allow-through result', () {
      expect(ModerationResult.clean.shouldFilter, isFalse);
      expect(ModerationResult.clean.severity, ContentSeverity.info);
      expect(ModerationResult.clean.reasons, isEmpty);
      expect(ModerationResult.clean.matchingEntries, isEmpty);
      expect(ModerationResult.clean.warningMessage, isNull);
    });
  });
}
