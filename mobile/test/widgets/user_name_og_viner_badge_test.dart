// ABOUTME: Tests UserName OG Viner badge display from the local cache.
// ABOUTME: Keeps badge rendering tied to known cached pubkeys only.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/og_viner_cache_service.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  Future<Widget> buildSubject({required bool cachedOgViner}) async {
    SharedPreferences.setMockInitialValues({
      if (cachedOgViner) ogVinerPubkeysCacheKey: jsonEncode([pubkey]),
    });
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: UserName.fromUserProfile(
              UserProfile(
                pubkey: pubkey,
                name: 'Alice',
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

  testWidgets('shows OG Viner badge for cached pubkey', (tester) async {
    await tester.pumpWidget(await buildSubject(cachedOgViner: true));
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('V'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'OG Viner',
      ),
      findsOneWidget,
    );
  });

  testWidgets('hides OG Viner badge for unknown pubkey', (tester) async {
    await tester.pumpWidget(await buildSubject(cachedOgViner: false));
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('V'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'OG Viner',
      ),
      findsNothing,
    );
  });
}
