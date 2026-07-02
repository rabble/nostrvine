// ABOUTME: Unit tests for ProtectedMinorStickyStore — the persisted fail-safe
// ABOUTME: state machine backing the protected-minor seam (#175).

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/services/protected_minor_sticky_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final pubkey = 'a' * 64;
  final otherPubkey = 'b' * 64;

  late SharedPreferences prefs;
  late ProtectedMinorStickyStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = ProtectedMinorStickyStore(prefs: prefs);
  });

  test('unconfirmed account is not protected', () {
    expect(store.isProtectedMinorFor(pubkey), false);
    expect(store.isProtectedMinorFor(null), false);
  });

  test('confirmed protected persists true', () async {
    await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());
    expect(store.isProtectedMinorFor(pubkey), true);
  });

  test('confirmed not-protected lifts to false (positive signal)', () async {
    await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());
    await store.applyLiveStatus(pubkey, ProtectedMinorStatus.notProtected());
    expect(store.isProtectedMinorFor(pubkey), false);
  });

  test('unknown status retains last-known (sticky, never weakens)', () async {
    await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());
    await store.applyLiveStatus(pubkey, ProtectedMinorStatus.unknown());
    expect(store.isProtectedMinorFor(pubkey), true);
  });

  test('is per-account', () async {
    await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());
    expect(store.isProtectedMinorFor(otherPubkey), false);
  });

  test('null pubkey never persists', () async {
    await store.applyLiveStatus(null, ProtectedMinorStatus.protected());
    expect(store.isProtectedMinorFor(null), false);
  });

  test('persists across instances (cold-start read)', () async {
    await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());
    final fresh = ProtectedMinorStickyStore(prefs: prefs);
    expect(fresh.isProtectedMinorFor(pubkey), true);
  });
}
