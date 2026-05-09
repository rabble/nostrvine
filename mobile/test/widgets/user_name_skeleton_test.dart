// ABOUTME: Tests UserName loading-skeleton behavior added by #4163.
// ABOUTME: Pins the Skeletonizer-vs-generated-fallback contract.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  // Real 64-char hex pubkey. Never truncate Nostr IDs in code or tests.
  const pubkey =
      '0000000000000000000000000000000000000000000000000000000000000001';

  Widget pumped(Widget child) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('UserName.fromPubKey isLoading', () {
    testWidgets('renders Skeletonizer and never the generated fallback name', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumped(UserName.fromPubKey(pubkey, isLoading: true)),
      );

      // bySubtype because Skeletonizer is abstract; the concrete widget
      // in the tree is the private _Skeletonizer subclass.
      expect(find.bySubtype<Skeletonizer>(), findsOneWidget);

      final generated = UserProfile.defaultDisplayNameFor(pubkey);
      expect(find.text(generated), findsNothing);

      final l10n = lookupAppLocalizations(const Locale('en'));
      // The placeholder string lives behind the shimmer but is the
      // child Text widget — it must come from l10n, not be hardcoded.
      expect(find.text(l10n.userNameSkeletonPlaceholder), findsOneWidget);
    });

    testWidgets(
      'preserves the existing generated fallback when isLoading is false',
      (tester) async {
        await tester.pumpWidget(pumped(UserName.fromPubKey(pubkey)));

        // No skeleton — un-gated callers keep today's behaviour.
        expect(find.bySubtype<Skeletonizer>(), findsNothing);

        // The existing AsyncLoading-arm contract still produces the
        // deterministic generated name. This is the regression guard
        // for the "user genuinely has no Kind 0" steady-state path.
        final generated = UserProfile.defaultDisplayNameFor(pubkey);
        expect(find.text(generated), findsOneWidget);
      },
    );
  });

  group('UserName.fromUserProfile isLoading', () {
    testWidgets('skeletons over the supplied profile when isLoading is true', (
      tester,
    ) async {
      final profile = UserProfile(
        pubkey: pubkey,
        name: 'Alice',
        rawData: const {},
        createdAt: DateTime(2026),
        eventId: 'kind0_event_id',
      );

      await tester.pumpWidget(
        pumped(UserName.fromUserProfile(profile, isLoading: true)),
      );

      // bySubtype because Skeletonizer is abstract; the concrete widget
      // in the tree is the private _Skeletonizer subclass.
      expect(find.bySubtype<Skeletonizer>(), findsOneWidget);
      // The real name must be hidden behind the shimmer — never visible
      // text — because the loading state must not look like a real
      // identity (#4163).
      expect(find.text('Alice'), findsNothing);
    });

    testWidgets('renders the real display name when isLoading is false', (
      tester,
    ) async {
      final profile = UserProfile(
        pubkey: pubkey,
        name: 'Alice',
        rawData: const {},
        createdAt: DateTime(2026),
        eventId: 'kind0_event_id',
      );

      await tester.pumpWidget(pumped(UserName.fromUserProfile(profile)));

      expect(find.byType(Skeletonizer), findsNothing);
      expect(find.text('Alice'), findsOneWidget);
    });
  });
}
