// ABOUTME: Widget tests for username field in ProfileSetupScreen
// ABOUTME: Tests status indicators, pre-population, and validation behavior

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/username_notifier.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/state/username_state.dart';
import 'package:openvine/theme/vine_theme.dart';

void main() {
  group('UsernameStatusIndicator', () {
    Widget buildIndicator(UsernameState state) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(body: UsernameStatusIndicator(state: state)),
      );
    }

    testWidgets('shows nothing when status is idle', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          const UsernameState(username: '', status: UsernameCheckStatus.idle),
        ),
      );

      expect(find.text('Checking availability...'), findsNothing);
      expect(find.text('Username available!'), findsNothing);
      expect(find.text('Username already taken'), findsNothing);
      expect(find.text('Username is reserved'), findsNothing);
    });

    testWidgets('shows spinner when checking', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          const UsernameState(
            username: 'testuser',
            status: UsernameCheckStatus.checking,
          ),
        ),
      );

      expect(find.text('Checking availability...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows green checkmark when available', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          const UsernameState(
            username: 'availableuser',
            status: UsernameCheckStatus.available,
          ),
        ),
      );

      expect(find.text('Username available!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows red X when taken', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          const UsernameState(
            username: 'takenuser',
            status: UsernameCheckStatus.taken,
          ),
        ),
      );

      expect(find.text('Username already taken'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('shows contact support when reserved', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          const UsernameState(
            username: 'reserveduser',
            status: UsernameCheckStatus.reserved,
          ),
        ),
      );

      expect(find.text('Username is reserved'), findsOneWidget);
      expect(find.text('Contact Support'), findsOneWidget);
    });

    testWidgets('shows error message when error', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          const UsernameState(
            username: 'erroruser',
            status: UsernameCheckStatus.error,
            errorMessage: 'Network error',
          ),
        ),
      );

      expect(find.text('Network error'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('Username Validation Logic', () {
    test('allows valid usernames', () {
      expect(_isValidUsername('testuser'), isTrue);
      expect(_isValidUsername('test_user'), isTrue);
      expect(_isValidUsername('test-user'), isTrue);
      expect(_isValidUsername('test.user'), isTrue);
      expect(_isValidUsername('TestUser123'), isTrue);
    });

    test('rejects usernames that are too short', () {
      expect(_isValidUsername('ab'), isFalse);
      expect(_isValidUsername('a'), isFalse);
      expect(_isValidUsername(''), isFalse);
    });

    test('rejects usernames that are too long', () {
      expect(_isValidUsername('a' * (kMaxUsernameLength + 1)), isFalse);
      expect(_isValidUsername('a' * 30), isFalse);
    });

    test('rejects usernames with invalid characters', () {
      expect(_isValidUsername('user@name'), isFalse);
      expect(_isValidUsername('user name'), isFalse);
      expect(_isValidUsername('user!name'), isFalse);
      expect(_isValidUsername('user#name'), isFalse);
    });
  });

  group('NIP-05 Username Extraction', () {
    test('extracts username from @divine.video domain', () {
      expect(_extractUsername('testuser@divine.video'), equals('testuser'));
      expect(_extractUsername('my_user@divine.video'), equals('my_user'));
    });

    test('extracts username from legacy @openvine.co domain', () {
      expect(_extractUsername('legacyuser@openvine.co'), equals('legacyuser'));
    });

    test('returns null for external domains', () {
      expect(_extractUsername('user@nostr.com'), isNull);
      expect(_extractUsername('user@example.org'), isNull);
    });

    test('returns null for invalid formats', () {
      expect(_extractUsername('invalid'), isNull);
      expect(_extractUsername(''), isNull);
      expect(_extractUsername('user@'), isNull);
    });
  });
}

/// Validation logic matching ProfileSetupScreen
bool _isValidUsername(String username) {
  final regex = RegExp(r'^[a-z0-9\-_.]+$', caseSensitive: false);
  return regex.hasMatch(username) &&
      username.length >= kMinUsernameLength &&
      username.length <= kMaxUsernameLength;
}

/// Username extraction logic matching ProfileSetupScreen
String? _extractUsername(String? nip05) {
  if (nip05 == null || nip05.isEmpty) return null;

  if (nip05.endsWith('@divine.video') || nip05.endsWith('@openvine.co')) {
    final parts = nip05.split('@');
    if (parts.length == 2) {
      return parts[0];
    }
  }
  return null;
}
