import 'package:test/test.dart';
import 'package:time_formatter/time_formatter.dart';

void main() {
  group(TimeFormatter, () {
    int unixSecondsAgo(Duration duration) {
      return DateTime.now().subtract(duration).millisecondsSinceEpoch ~/ 1000;
    }

    group('formatRelative', () {
      test('returns "now" for less than a minute ago', () {
        final ts = unixSecondsAgo(const Duration(seconds: 30));
        expect(TimeFormatter.formatRelative(ts), equals('now'));
      });

      test('returns minutes for less than an hour ago', () {
        final ts = unixSecondsAgo(const Duration(minutes: 5));
        expect(TimeFormatter.formatRelative(ts), equals('5m'));
      });

      test('returns hours for less than a day ago', () {
        final ts = unixSecondsAgo(const Duration(hours: 14));
        expect(TimeFormatter.formatRelative(ts), equals('14h'));
      });

      test('returns days for less than a week ago', () {
        final ts = unixSecondsAgo(const Duration(days: 3));
        expect(TimeFormatter.formatRelative(ts), equals('3d'));
      });

      test('returns weeks for less than 60 days ago', () {
        final ts = unixSecondsAgo(const Duration(days: 14));
        expect(TimeFormatter.formatRelative(ts), equals('2w'));
      });

      test('returns months for less than a year ago', () {
        final ts = unixSecondsAgo(const Duration(days: 90));
        expect(TimeFormatter.formatRelative(ts), equals('3mo'));
      });

      test('returns years for more than a year ago', () {
        final ts = unixSecondsAgo(const Duration(days: 400));
        expect(TimeFormatter.formatRelative(ts), equals('1y'));
      });
    });

    group('formatRelativeVerbose', () {
      test('returns "Now" for less than a minute ago', () {
        final ts = unixSecondsAgo(const Duration(seconds: 10));
        expect(TimeFormatter.formatRelativeVerbose(ts), equals('Now'));
      });

      test('returns verbose format with "ago" suffix', () {
        final ts = unixSecondsAgo(const Duration(minutes: 3));
        expect(TimeFormatter.formatRelativeVerbose(ts), equals('3m ago'));
      });

      test('returns verbose format for hours', () {
        final ts = unixSecondsAgo(const Duration(hours: 2));
        expect(TimeFormatter.formatRelativeVerbose(ts), equals('2h ago'));
      });
    });

    group('formatDateLabel', () {
      test('returns Today for current day', () {
        final now = DateTime.now();
        final earlierToday = DateTime(now.year, now.month, now.day, 12);
        final safeTime = earlierToday.isAfter(now)
            ? DateTime(now.year, now.month, now.day, 0, 1)
            : earlierToday;
        final ts = safeTime.millisecondsSinceEpoch ~/ 1000;
        expect(TimeFormatter.formatDateLabel(ts), equals('Today'));
      });

      test('returns Yesterday for previous day', () {
        final now = DateTime.now();
        final yesterday = DateTime(now.year, now.month, now.day - 1, 12);
        final ts = yesterday.millisecondsSinceEpoch ~/ 1000;
        expect(TimeFormatter.formatDateLabel(ts), equals('Yesterday'));
      });

      test('returns day name for recent dates within a week', () {
        final ts = unixSecondsAgo(const Duration(days: 3));
        final result = TimeFormatter.formatDateLabel(ts);
        expect(
          [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ],
          contains(result),
        );
      });

      test('returns month and day for older dates', () {
        final ts = unixSecondsAgo(const Duration(days: 30));
        final result = TimeFormatter.formatDateLabel(ts);
        expect(result, matches(RegExp(r'^[A-Z][a-z]+ \d+$')));
      });
    });

    group('formatConversationTimestamp', () {
      test('returns "1m" floor for less than a minute ago', () {
        final ts = unixSecondsAgo(const Duration(seconds: 30));
        expect(
          TimeFormatter.formatConversationTimestamp(ts),
          equals('1m'),
        );
      });

      test('returns minutes for less than an hour ago', () {
        final ts = unixSecondsAgo(const Duration(minutes: 23));
        expect(
          TimeFormatter.formatConversationTimestamp(ts),
          equals('23m'),
        );
      });

      test('returns hours for same calendar day', () {
        final now = DateTime.now();
        if (now.hour < 1) return; // skip: within first hour of the day
        // Explicitly stay on today to avoid cross-day edge cases
        final sameDay = DateTime(
          now.year,
          now.month,
          now.day,
          now.hour - 1,
          now.minute,
        );
        final ts = sameDay.millisecondsSinceEpoch ~/ 1000;
        expect(
          TimeFormatter.formatConversationTimestamp(ts),
          equals('1h'),
        );
      });

      test('returns "Yesterday" for previous calendar day', () {
        final now = DateTime.now();
        final yesterday = DateTime(now.year, now.month, now.day - 1, 12);
        final ts = yesterday.millisecondsSinceEpoch ~/ 1000;
        expect(
          TimeFormatter.formatConversationTimestamp(ts),
          equals('Yesterday'),
        );
      });

      test('returns day name for 2-6 days ago', () {
        final now = DateTime.now();
        final threeDaysAgo = DateTime(now.year, now.month, now.day - 3, 12);
        final ts = threeDaysAgo.millisecondsSinceEpoch ~/ 1000;
        final result = TimeFormatter.formatConversationTimestamp(ts);
        expect(
          [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ],
          contains(result),
        );
      });

      test('returns abbreviated month and day for same year', () {
        final now = DateTime.now();
        final twoMonthsAgo = DateTime(
          now.year,
          now.month - 2,
          now.day.clamp(1, 28),
          12,
        );
        final ts = twoMonthsAgo.millisecondsSinceEpoch ~/ 1000;
        final result = TimeFormatter.formatConversationTimestamp(ts);
        // Matches patterns like "Mar 3" or "Jan 15"
        expect(result, matches(RegExp(r'^[A-Z][a-z]{2} \d{1,2}$')));
      });

      test('returns month, day, and year for previous year', () {
        final now = DateTime.now();
        final lastYear = DateTime(now.year - 1, 6, 15, 12);
        final ts = lastYear.millisecondsSinceEpoch ~/ 1000;
        final result = TimeFormatter.formatConversationTimestamp(ts);
        // Matches patterns like "Jun 15, 2025"
        expect(
          result,
          matches(RegExp(r'^[A-Z][a-z]{2} \d{1,2}, \d{4}$')),
        );
      });
    });

    group('formatMessageTime', () {
      test('returns "Now" for less than 60 seconds ago', () {
        final ts = unixSecondsAgo(const Duration(seconds: 30));
        expect(TimeFormatter.formatMessageTime(ts), equals('Now'));
      });

      test('returns time format for today', () {
        final now = DateTime.now();
        if (now.hour < 1) return; // skip: within first hour of the day
        // Explicitly stay on today to avoid cross-day edge cases on CI
        final sameDay = DateTime(
          now.year,
          now.month,
          now.day,
          now.hour - 1,
          now.minute,
        );
        final ts = sameDay.millisecondsSinceEpoch ~/ 1000;
        final result = TimeFormatter.formatMessageTime(ts);
        // Matches patterns like "9:41 AM" or "2:30 PM"
        // intl uses Unicode narrow no-break space (U+202F) before AM/PM
        expect(result, matches(RegExp(r'^\d{1,2}:\d{2}\s[AP]M$')));
      });

      test('returns "Yesterday" for previous day', () {
        final now = DateTime.now();
        final yesterday = DateTime(now.year, now.month, now.day - 1, 12);
        final ts = yesterday.millisecondsSinceEpoch ~/ 1000;
        expect(TimeFormatter.formatMessageTime(ts), equals('Yesterday'));
      });

      test('returns day name for 2-6 days ago', () {
        final now = DateTime.now();
        final threeDaysAgo = DateTime(now.year, now.month, now.day - 3, 12);
        final ts = threeDaysAgo.millisecondsSinceEpoch ~/ 1000;
        final result = TimeFormatter.formatMessageTime(ts);
        expect(
          [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ],
          contains(result),
        );
      });

      test('returns abbreviated month and day for same year', () {
        final now = DateTime.now();
        final twoMonthsAgo = DateTime(
          now.year,
          now.month - 2,
          now.day.clamp(1, 28),
          12,
        );
        final ts = twoMonthsAgo.millisecondsSinceEpoch ~/ 1000;
        final result = TimeFormatter.formatMessageTime(ts);
        // Matches patterns like "Mar 3" or "Jan 15"
        expect(result, matches(RegExp(r'^[A-Z][a-z]{2} \d{1,2}$')));
      });

      test('returns abbreviated month, day, and year for previous year', () {
        final now = DateTime.now();
        final lastYear = DateTime(now.year - 1, 6, 15, 12);
        final ts = lastYear.millisecondsSinceEpoch ~/ 1000;
        final result = TimeFormatter.formatMessageTime(ts);
        // Matches patterns like "Jun 15, 2025"
        expect(
          result,
          matches(RegExp(r'^[A-Z][a-z]{2} \d{1,2}, \d{4}$')),
        );
      });
    });
  });
}
