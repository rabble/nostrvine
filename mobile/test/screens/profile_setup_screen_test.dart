// ABOUTME: Widget tests for username field in ProfileSetupScreen
// ABOUTME: Tests status indicators, pre-population, and validation behavior

import 'package:bloc_test/bloc_test.dart';
import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/screens/profile_setup_screen.dart';

import '../helpers/test_provider_overrides.dart';

class _MockProfileEditorBloc
    extends MockBloc<ProfileEditorEvent, ProfileEditorState>
    implements ProfileEditorBloc {}

void main() {
  group('UsernameStatusIndicator', () {
    late _MockProfileEditorBloc mockBloc;

    setUp(() {
      mockBloc = _MockProfileEditorBloc();
      when(() => mockBloc.state).thenReturn(
        const ProfileEditorState(
          username: 'testuser',
          usernameStatus: UsernameStatus.reserved,
        ),
      );
    });

    Widget buildIndicator(
      UsernameStatus status, {
      UsernameValidationError? error,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: UsernameStatusIndicator(status: status, error: error),
        ),
      );
    }

    Widget buildIndicatorWithBloc(
      UsernameStatus status, {
      UsernameValidationError? error,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: BlocProvider<ProfileEditorBloc>.value(
          value: mockBloc,
          child: Scaffold(
            body: UsernameStatusIndicator(status: status, error: error),
          ),
        ),
      );
    }

    testWidgets('shows nothing when status is idle', (tester) async {
      await tester.pumpWidget(buildIndicator(UsernameStatus.idle));

      expect(find.text('Checking availability...'), findsNothing);
      expect(find.text('Username available!'), findsNothing);
      expect(find.text('Username already taken'), findsNothing);
      expect(find.text('Username is reserved'), findsNothing);
    });

    testWidgets('shows spinner when checking', (tester) async {
      await tester.pumpWidget(buildIndicator(UsernameStatus.checking));

      expect(find.text('Checking availability...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows green checkmark when available', (tester) async {
      await tester.pumpWidget(buildIndicator(UsernameStatus.available));

      expect(find.text('Username available!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows red X when taken', (tester) async {
      await tester.pumpWidget(buildIndicator(UsernameStatus.taken));

      expect(find.text('Username already taken'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('shows reserved indicator when status is reserved', (
      tester,
    ) async {
      await tester.pumpWidget(buildIndicatorWithBloc(UsernameStatus.reserved));

      expect(find.text('Username is reserved'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('shows Contact support link when reserved', (tester) async {
      await tester.pumpWidget(buildIndicatorWithBloc(UsernameStatus.reserved));

      expect(find.text('Contact support'), findsOneWidget);
    });

    testWidgets('shows Check again link when reserved', (tester) async {
      await tester.pumpWidget(buildIndicatorWithBloc(UsernameStatus.reserved));

      expect(find.text('Check again'), findsOneWidget);
    });

    testWidgets('Check again link adds $UsernameRechecked event', (
      tester,
    ) async {
      await tester.pumpWidget(buildIndicatorWithBloc(UsernameStatus.reserved));

      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();

      verify(() => mockBloc.add(const UsernameRechecked())).called(1);
    });

    testWidgets('shows error message when network error', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          UsernameStatus.error,
          error: UsernameValidationError.networkError,
        ),
      );

      expect(
        find.text('Could not check availability. Please try again.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows default error message when no error provided', (
      tester,
    ) async {
      await tester.pumpWidget(buildIndicator(UsernameStatus.error));

      expect(find.text('Failed to check availability'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows format error message', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          UsernameStatus.error,
          error: UsernameValidationError.invalidFormat,
        ),
      );

      expect(
        find.text('Only letters, numbers, and hyphens are allowed'),
        findsOneWidget,
      );
    });

    testWidgets('shows length error message', (tester) async {
      await tester.pumpWidget(
        buildIndicator(
          UsernameStatus.error,
          error: UsernameValidationError.invalidLength,
        ),
      );

      expect(find.text('Username must be 3-20 characters'), findsOneWidget);
    });
  });

  group('LowercaseTextInputFormatter', () {
    const formatter = LowercaseTextInputFormatter();

    TextEditingValue value(String text, {int? selection}) {
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: selection ?? text.length),
      );
    }

    test('lowercases newly typed uppercase letters', () {
      final result = formatter.formatEditUpdate(value(''), value('Alice'));

      expect(result.text, 'alice');
      expect(result.selection.baseOffset, 5);
    });

    test('preserves all-lowercase input unchanged (returns same instance)', () {
      final next = value('alice');
      final result = formatter.formatEditUpdate(value(''), next);

      expect(identical(result, next), isTrue);
    });

    test('preserves caret position when editing in the middle', () {
      // User has "abcde" with caret at offset 2, types capital "X" — newValue
      // is "abXcde" with caret at 3.
      final result = formatter.formatEditUpdate(
        value('abcde', selection: 2),
        value('abXcde', selection: 3),
      );

      expect(result.text, 'abxcde');
      expect(result.selection.baseOffset, 3);
    });

    test('lowercases pasted mixed-case text', () {
      final result = formatter.formatEditUpdate(value(''), value('MrBeast123'));

      expect(result.text, 'mrbeast123');
    });
  });

  group('username field input formatters', () {
    Widget buildField(TextEditingController controller) {
      return MaterialApp(
        home: Scaffold(
          body: TextField(
            controller: controller,
            inputFormatters: [
              const LowercaseTextInputFormatter(),
              FilteringTextInputFormatter.allow(RegExp('[a-z0-9-]')),
            ],
          ),
        ),
      );
    }

    testWidgets('uppercase typed by user is normalized to lowercase', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(buildField(controller));

      await tester.enterText(find.byType(TextField), 'Alice');

      expect(controller.text, 'alice');
    });

    testWidgets('disallowed characters are stripped, others lowercased', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(buildField(controller));

      // Underscore, dot, and space are not in [a-z0-9-]; capitals get
      // lowercased.
      await tester.enterText(find.byType(TextField), 'Mr Beast.123_xyz');

      expect(controller.text, 'mrbeast123xyz');
    });
  });

  group('UsernameReservedDialog', () {
    late _MockProfileEditorBloc mockBloc;

    setUp(() {
      mockBloc = _MockProfileEditorBloc();
      when(() => mockBloc.state).thenReturn(
        const ProfileEditorState(
          username: 'reservedname',
          usernameStatus: UsernameStatus.reserved,
        ),
      );
    });

    Widget buildDialog(String username) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: BlocProvider<ProfileEditorBloc>.value(
          value: mockBloc,
          child: Scaffold(body: UsernameReservedDialog(username)),
        ),
      );
    }

    testWidgets('shows correct title', (tester) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      expect(find.text('Username reserved'), findsOneWidget);
    });

    testWidgets('shows username in message content', (tester) async {
      const username = 'reservedname';
      await tester.pumpWidget(buildDialog(username));

      expect(
        find.text(
          'The name $username is reserved. Tell us why it should be yours.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('has reason text field', (tester) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text("e.g. It's my brand name, stage name, etc."),
        findsOneWidget,
      );
    });

    testWidgets('has Close button', (tester) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      final closeButton = find.widgetWithText(TextButton, 'Close');
      expect(closeButton, findsOneWidget);
    });

    testWidgets('has Send request button', (tester) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      expect(find.widgetWithText(FilledButton, 'Send request'), findsOneWidget);
    });

    testWidgets('has Check again button', (tester) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      expect(find.widgetWithText(TextButton, 'Check again'), findsOneWidget);
    });

    testWidgets('Close button dismisses dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: BlocProvider<ProfileEditorBloc>.value(
            value: mockBloc,
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => BlocProvider<ProfileEditorBloc>.value(
                      value: mockBloc,
                      child: const UsernameReservedDialog('testuser'),
                    ),
                  ),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Username reserved'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Username reserved'), findsNothing);
    });

    testWidgets('Check again button adds $UsernameRechecked event', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: BlocProvider<ProfileEditorBloc>.value(
            value: mockBloc,
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => BlocProvider<ProfileEditorBloc>.value(
                      value: mockBloc,
                      child: const UsernameReservedDialog('testuser'),
                    ),
                  ),
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Check again'));
      await tester.pumpAndSettle();

      verify(() => mockBloc.add(const UsernameRechecked())).called(1);
    });

    testWidgets('shows hint about checking again after contacting support', (
      tester,
    ) async {
      await tester.pumpWidget(buildDialog('reservedname'));

      expect(
        find.text(
          'Already contacted support? Tap "Check again" to see if '
          "it's been released to you.",
        ),
        findsOneWidget,
      );
    });
  });

  group('profileSetupUploadErrorMessage', () {
    Future<AppLocalizations> loadL10n(WidgetTester tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      return l10n;
    }

    testWidgets('maps server failures to the server error message', (
      tester,
    ) async {
      final l10n = await loadL10n(tester);

      expect(
        profileSetupUploadErrorMessage(
          l10n,
          BlossomUploadFailureReason.server,
        ),
        l10n.profileSetupUploadServerError,
      );
    });

    testWidgets('maps network failures to the network error message', (
      tester,
    ) async {
      final l10n = await loadL10n(tester);

      expect(
        profileSetupUploadErrorMessage(
          l10n,
          BlossomUploadFailureReason.network,
        ),
        l10n.profileSetupUploadNetworkError,
      );
    });

    testWidgets('maps auth failures to the auth error message', (
      tester,
    ) async {
      final l10n = await loadL10n(tester);

      expect(
        profileSetupUploadErrorMessage(
          l10n,
          BlossomUploadFailureReason.auth,
        ),
        l10n.profileSetupUploadAuthError,
      );
    });

    testWidgets('maps fileTooLarge failures to the file-too-large message', (
      tester,
    ) async {
      final l10n = await loadL10n(tester);

      expect(
        profileSetupUploadErrorMessage(
          l10n,
          BlossomUploadFailureReason.fileTooLarge,
        ),
        l10n.profileSetupUploadFileTooLarge,
      );
    });

    testWidgets('falls back to the generic message for unknown failures', (
      tester,
    ) async {
      final l10n = await loadL10n(tester);

      expect(
        profileSetupUploadErrorMessage(
          l10n,
          BlossomUploadFailureReason.unknown,
        ),
        l10n.profileSetupUploadFailedGeneric,
      );
    });

    testWidgets('falls back to the generic message when reason is null', (
      tester,
    ) async {
      final l10n = await loadL10n(tester);

      expect(
        profileSetupUploadErrorMessage(l10n, null),
        l10n.profileSetupUploadFailedGeneric,
      );
    });
  });

  group('$ProfileSetupScreen npub demotion (#3933)', () {
    const testPubkeyHex =
        'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
    const testNpub =
        'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz';

    late MockAuthService mockAuthService;
    late MockProfileRepository mockProfileRepository;

    setUp(() {
      mockAuthService = createMockAuthService();
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkeyHex);
      when(() => mockAuthService.currentNpub).thenReturn(testNpub);
      when(() => mockAuthService.hasExistingProfile).thenReturn(true);

      mockProfileRepository = createMockProfileRepository();
    });

    List<dynamic> baseOverrides() {
      return [
        authServiceProvider.overrideWithValue(mockAuthService),
        profileRepositoryProvider.overrideWith((ref) => mockProfileRepository),
        fetchUserProfileProvider(testPubkeyHex).overrideWith(
          (ref) async => null,
        ),
        userProfileReactiveProvider(testPubkeyHex).overrideWith(
          (ref) => Stream<models.UserProfile?>.value(null),
        ),
      ];
    }

    Widget buildSubject() {
      return testProviderScope(
        additionalOverrides: baseOverrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const ProfileSetupScreen(isNewUser: false),
        ),
      );
    }

    Widget buildSubjectWithRouter() {
      final router = GoRouter(
        initialLocation: ProfileSetupScreen.editPath,
        routes: [
          GoRoute(
            path: ProfileSetupScreen.editPath,
            name: ProfileSetupScreen.editRouteName,
            builder: (context, state) =>
                const ProfileSetupScreen(isNewUser: false),
          ),
          GoRoute(
            path: KeyManagementScreen.path,
            name: KeyManagementScreen.routeName,
            builder: (context, state) => const KeyManagementScreen(),
          ),
        ],
      );

      return testProviderScope(
        additionalOverrides: baseOverrides(),
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          routerConfig: router,
        ),
      );
    }

    testWidgets('does not render the labeled npub field', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Public key (npub)'), findsNothing);
    });

    testWidgets('renders a "View your public key" link', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.profileEditPublicKeyLink), findsOneWidget);
    });

    testWidgets(
      'navigates to key management when "View your public key" is tapped',
      (tester) async {
        await tester.pumpWidget(buildSubjectWithRouter());
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.profileEditPublicKeyLink));
        await tester.pumpAndSettle();

        expect(find.byType(KeyManagementScreen), findsOneWidget);
      },
    );
  });
}
