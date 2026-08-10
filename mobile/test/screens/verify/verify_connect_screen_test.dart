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
  });
}
