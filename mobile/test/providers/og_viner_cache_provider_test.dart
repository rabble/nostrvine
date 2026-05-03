// ABOUTME: Tests Riverpod provider wiring for the OG Viner local cache.
// ABOUTME: Ensures optional badge state can be read without network calls.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/og_viner_cache_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/og_viner_cache_service.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('reads cached OG Viner pubkeys from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      ogVinerPubkeysCacheKey: jsonEncode([pubkey]),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final service = container.read(ogVinerCacheServiceProvider);

    expect(service.isOgViner(pubkey), isTrue);
  });

  test('falls back to an empty in-memory cache when prefs are not wired', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(ogVinerCacheServiceProvider);

    expect(service.knownPubkeys, isEmpty);
  });
}
