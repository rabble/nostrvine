// ABOUTME: Widget tests for the single-platform verify connect form.
// ABOUTME: Covers the manual account fallback used when a proof link is opaque.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart' hide VerificationResult;
import 'package:openvine/blocs/verify/verify_connect_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/verify/verify_connect_screen.dart';
import 'package:openvine/screens/verify/verify_platform_labels.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockIdentityClaimsRepository extends Mock
    implements IdentityClaimsRepository {}

const _pubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _npub = 'npub1zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygsh9cc9';
const _returnUrl = 'https://divine.video/app/callback';
const _telegram = VerifierPlatform(
  key: 'telegram',
  label: 'Telegram',
  supported: true,
);
const _bluesky = VerifierPlatform(
  key: 'bluesky',
  label: 'Bluesky',
  supported: true,
);

void main() {
  group(VerifyConnectView, () {
    late _MockIdentityClaimsRepository repository;
    late VerifyConnectCubit cubit;

    setUp(() {
      repository = _MockIdentityClaimsRepository();
      cubit = VerifyConnectCubit(
        repository: repository,
        pubkey: _pubkey,
        platform: _telegram,
        oauthReturnUrl: _returnUrl,
        launchOAuth: (_) async => null,
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: BlocProvider<VerifyConnectCubit>.value(
            value: cubit,
            child: const VerifyConnectView(npub: _npub),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('keeps manual account field visible while typing', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await pump(tester);

      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'some nonsense');
      await tester.pump();

      expect(
        find.text(verifyIdentityFieldLabel(l10n, _telegram.key)),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNWidgets(2));

      await tester.enterText(find.byType(TextField).first, 'testdivine');
      await tester.pump();

      expect(
        find.text(verifyIdentityFieldLabel(l10n, _telegram.key)),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('keeps the typed proof when the account field appears', (
      tester,
    ) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'some nonsense');
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('some nonsense'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('keeps a pasted link when the account field goes away', (
      tester,
    ) async {
      // Deliberately not verifyProofHint('telegram') — that string is the
      // field's own hint, so find.text would match an empty field.
      const pastedLink = 'https://t.me/divinechannel/456';
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'nonsense');
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(2));

      await tester.enterText(find.byType(TextField).last, pastedLink);
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(pastedLink), findsOneWidget);
    });
  });

  group('$VerifyConnectView OAuth support arriving late', () {
    late VerifyConnectCubit cubit;

    setUp(() {
      cubit = VerifyConnectCubit(
        repository: _MockIdentityClaimsRepository(),
        pubkey: _pubkey,
        platform: _bluesky,
        oauthReturnUrl: _returnUrl,
        launchOAuth: (_) async => null,
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    Future<void> pump(
      WidgetTester tester, {
      required bool oauthAvailable,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: BlocProvider<VerifyConnectCubit>.value(
            value: cubit,
            child: VerifyConnectView(
              npub: _npub,
              oauthAvailable: oauthAvailable,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('keeps the typed handle when the OAuth block appears', (
      tester,
    ) async {
      // Not verifyIdentityHint('bluesky') — that is 'alice.bsky.social', and
      // find.text would match the hint of an empty field.
      // appOAuthSupportProvider resolves a frame or two after the screen
      // opens, and the handle field moves from the proof block up into the
      // OAuth block when it does.
      await pump(tester, oauthAvailable: false);
      await tester.enterText(
        find.byType(TextField).first,
        'divine.bsky.social',
      );
      await tester.pump();

      await pump(tester, oauthAvailable: true);

      expect(find.text('divine.bsky.social'), findsOneWidget);
    });
  });
}
