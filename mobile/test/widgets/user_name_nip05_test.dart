// ABOUTME: Tests UserName NIP-05 display behavior
// ABOUTME: Ensures valid NIP-05 does not render a verification checkmark

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/widgets/user_name.dart';

void main() {
  const defaultPubkey =
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

  Widget buildSubject({
    String pubkey = defaultPubkey,
    String nip05 = 'alice@example.com',
  }) {
    return ProviderScope(
      overrides: [
        nip05VerificationProvider.overrideWith(
          (ref, pubkey) async => Nip05VerificationStatus.verified,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: UserName.fromUserProfile(
              UserProfile(
                pubkey: pubkey,
                name: 'Alice',
                nip05: nip05,
                rawData: const {},
                createdAt: DateTime(2026),
                eventId: 'kind0_event_id',
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('does not show a checkmark for verified NIP-05', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('shows a checkmark for Kirsten Swasey special profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(nip05: '_@kirstenswasey.divine.video'),
    );
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('matches the Kirsten Swasey profile URL host', (tester) async {
    await tester.pumpWidget(
      buildSubject(nip05: 'http://kirstenswasey.divine.video'),
    );
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('shows a checkmark for Rabble special profile', (tester) async {
    await tester.pumpWidget(buildSubject(nip05: '_@rabble.divine.video'));
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('shows a checkmark for special profile pubkey', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        pubkey:
            'aa50001ef150418f30f62f827399d5c26a5ade52ab45ca4849f99b1726bb47b4',
      ),
    );
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
