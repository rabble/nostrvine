// ABOUTME: Service that owns a user's supporter entitlement across sessions.
// ABOUTME: Caches the latest entitlement in SharedPreferences and bridges the
// ABOUTME: EntitlementValidator stream to app state.

import 'dart:async';
import 'dart:convert';

import 'package:iap_repository/iap_repository.dart';
import 'package:models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and surfaces the current [SupporterEntitlement].
///
/// Wraps an [EntitlementValidator] (StoreKit/Play Billing in production) and
/// keeps the last known entitlement in [SharedPreferences] so it survives
/// relaunches and is available offline. The repository is the single read-side
/// surface the UI consults; the validator is the write side.
class SupporterRepository {
  /// Creates a [SupporterRepository].
  ///
  /// [validator] is the store-backed validator. [prefs] is the canonical
  /// [SharedPreferences] from [sharedPreferencesProvider].
  SupporterRepository({
    required EntitlementValidator validator,
    required SharedPreferences prefs,
  }) : _validator = validator,
       _prefs = prefs {
    _current = _loadCached();
    _subscription = _validator.entitlementChanges.listen(_handleChange);
  }

  final EntitlementValidator _validator;
  final SharedPreferences _prefs;

  static const String _cacheKey = 'divine_supporter_entitlement';

  late SupporterEntitlement _current;
  StreamSubscription<SupporterEntitlement>? _subscription;
  final StreamController<SupporterEntitlement> _controller =
      StreamController<SupporterEntitlement>.broadcast();

  /// The current entitlement (hydrated from cache on construction, refreshed by
  /// the validator stream as purchases arrive).
  SupporterEntitlement get current => _current;

  /// Whether the user is currently an active supporter.
  bool get isSupporter => _current.isSupporter;

  /// A stream of entitlement updates. Emits the current value to new
  /// listeners.
  Stream<SupporterEntitlement> get changes => _controller.stream;

  /// The underlying validator, exposed so the UI/cubit can drive purchases and
  /// restores through the same store connection this repository owns.
  EntitlementValidator get validator => _validator;

  SupporterEntitlement _loadCached() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return SupporterEntitlement.inactive;
    try {
      final decoded = SupporterEntitlement.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      // Recompute active against the current clock in case expiry passed while
      // the app was closed.
      return decoded.refreshed();
    } on Object {
      return SupporterEntitlement.inactive;
    }
  }

  Future<void> _persist(SupporterEntitlement entitlement) async {
    try {
      await _prefs.setString(
        _cacheKey,
        jsonEncode(entitlement.toJson()),
      );
    } on Object {
      // Swallow: persistence is best-effort; the in-memory value is still
      // authoritative for this session.
    }
  }

  void _handleChange(SupporterEntitlement entitlement) {
    if (entitlement == _current) return;
    _current = entitlement;
    _controller.add(entitlement);
    _persist(entitlement);
  }

  /// Mark the entitlement inactive locally (e.g. after a confirmed expiry or
  /// cancellation detected out-of-band). The validator stream is the source of
  /// truth; this is a cache reset.
  Future<void> clearLocalEntitlement() async {
    _handleChange(SupporterEntitlement.inactive);
    try {
      await _prefs.remove(_cacheKey);
    } on Object {
      // best-effort
    }
  }

  /// Release the validator stream subscription. The validator itself is
  /// disposed by whoever owns it (the provider).
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller.close();
  }
}
