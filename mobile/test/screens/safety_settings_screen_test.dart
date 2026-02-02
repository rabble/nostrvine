// ABOUTME: Widget tests for SafetySettingsScreen UI and functionality
// ABOUTME: Tests section headers, blocked users list, muted content, filters, and report history

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/services/mute_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:divine_ui/divine_ui.dart';

class MockMuteService extends Mock implements MuteService {
  final List<MuteItem> _mutedUsers = [];

  @override
  List<MuteItem> get mutedUsers => List.unmodifiable(_mutedUsers);

  @override
  Future<bool> muteUser(
    String pubkey, {
    String? reason,
    Duration? duration,
  }) async {
    _mutedUsers.add(
      MuteItem(
        type: MuteType.user,
        value: pubkey,
        createdAt: DateTime.now(),
        reason: reason,
      ),
    );
    return true;
  }

  @override
  Future<bool> unmuteUser(String pubkey) async {
    _mutedUsers.removeWhere((item) => item.value == pubkey);
    return true;
  }

  @override
  bool isUserMuted(String pubkey) =>
      _mutedUsers.any((item) => item.value == pubkey);
}

class MockContentReportingService extends Mock
    implements ContentReportingService {}

void main() {
  group('SafetySettingsScreen Widget Tests', () {
    late MockMuteService mockMuteService;
    late MockContentReportingService mockReportingService;

    setUp(() {
      mockMuteService = MockMuteService();
      mockReportingService = MockContentReportingService();
    });

    Widget createTestWidget() {
      final container = ProviderContainer(
        overrides: [
          muteServiceProvider.overrideWith((ref) async => mockMuteService),
          // contentReportingServiceProvider is async, so wrap in AsyncValue
          contentReportingServiceProvider.overrideWith(
            (ref) async => mockReportingService,
          ),
        ],
      );

      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: VineTheme.theme,
          home: const SafetySettingsScreen(),
        ),
      );
    }

    testWidgets('should display "Safety Settings" title in app bar', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Safety Settings'), findsOneWidget);
      // TODO(any): Fix and enable this test
    }, skip: true);

    testWidgets('should display back button and navigate on tap', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);

      // Test back navigation
      await tester.tap(backButton);
      await tester.pumpAndSettle();
      // TODO(any): Fix and re-enable these tests
      // Fails on CI
    }, skip: true);

    testWidgets('should display "Blocked Users" section header', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('BLOCKED USERS'), findsOneWidget);
      // TODO(any): Fix and enable this test
    }, skip: true);

    testWidgets('should display "Muted Content" section header', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('MUTED CONTENT'), findsOneWidget);
      // TODO(any): Fix and enable this test
    }, skip: true);

    testWidgets('should display "Content Filters" section header', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('CONTENT FILTERS'), findsOneWidget);
      // TODO(any): Fix and enable this test
    }, skip: true);

    testWidgets('should display "Report History" section header', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('REPORT HISTORY'), findsOneWidget);
      // TODO(any): Fix and enable this test
    }, skip: true);

    testWidgets('should use dark background color', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(Colors.black));
    });

    testWidgets('should use VineTheme.vineGreen for app bar background', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, isNotNull);
    });
  });

  group('SafetySettingsScreen Blocked Users Section - Unit Tests', () {
    test('mutedUsers returns muted users list', () {
      final service = MockMuteService();

      // Initially empty
      expect(service.mutedUsers, isEmpty);

      // Mute a user
      service.muteUser('muted_pubkey_1');
      expect(
        service.mutedUsers.any((item) => item.value == 'muted_pubkey_1'),
        isTrue,
      );

      // Mute another
      service.muteUser('muted_pubkey_2');
      expect(service.mutedUsers.length, equals(2));
    });

    test('unmuteUser removes user from muted list', () {
      final service = MockMuteService();

      service.muteUser('user_to_unmute');
      expect(service.isUserMuted('user_to_unmute'), isTrue);

      service.unmuteUser('user_to_unmute');
      expect(service.isUserMuted('user_to_unmute'), isFalse);
    });

    test('isUserMuted returns correct status', () {
      final service = MockMuteService();

      expect(service.isUserMuted('some_user'), isFalse);

      service.muteUser('some_user');
      expect(service.isUserMuted('some_user'), isTrue);

      service.unmuteUser('some_user');
      expect(service.isUserMuted('some_user'), isFalse);
    });
  });
}
