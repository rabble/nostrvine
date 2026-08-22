// ABOUTME: Tests for SupporterRepository caching + stream bridging.
// ABOUTME: Uses a fake EntitlementValidator to drive entitlement changes.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iap_repository/iap_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/services/supporter_api_client.dart';
import 'package:openvine/services/supporter_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A controllable fake validator that emits on a stream we own.
class _FakeValidator implements EntitlementValidator {
  _FakeValidator(this._controller);

  final StreamController<SupporterEntitlement> _controller;
  final StreamController<SupporterPurchaseProof> proofController =
      StreamController<SupporterPurchaseProof>.broadcast();
  List<SupporterTier> products = const [];
  SupporterEntitlement purchaseResult = SupporterEntitlement.inactive;
  int restoreCallCount = 0;
  String? restoredPubkey;
  Completer<void>? restoreCompleter;

  @override
  void startListening() {}

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<List<SupporterTier>> fetchProducts() async => products;

  @override
  Future<SupporterEntitlement> purchase(
    String productId, {
    String? capturedPubkey,
    String? attemptId,
  }) async => purchaseResult;

  @override
  Future<SupporterEntitlement> restorePurchases({
    String? capturedPubkey,
    String? attemptId,
  }) async {
    restoreCallCount++;
    restoredPubkey = capturedPubkey;
    await restoreCompleter?.future;
    return purchaseResult;
  }

  @override
  Stream<SupporterEntitlement> get entitlementChanges => _controller.stream;

  @override
  Stream<EntitlementLifecycle> get lifecycleChanges => const Stream.empty();

  @override
  Stream<SupporterPurchaseProof> get purchaseProofChanges =>
      proofController.stream;

  @override
  Future<void> completePurchase(SupporterPurchaseProof proof) async {}

  void emit(SupporterEntitlement e) => _controller.add(e);

  void emitError(Object error, [StackTrace? stackTrace]) =>
      _controller.addError(error, stackTrace);

  @override
  void dispose() {
    unawaited(proofController.close());
  }
}

void main() {
  const pubkeyA =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const pubkeyB =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  SharedPreferences.setMockInitialValues({});

  group(SupporterRepository, () {
    late _FakeValidator validator;
    late StreamController<SupporterEntitlement> controller;

    setUp(() {
      // Reset the in-memory SharedPreferences between tests so writes in one
      // test do not leak into the next (the mock persists across getInstance
      // calls within a test process).
      SharedPreferences.setMockInitialValues({});
      controller = StreamController<SupporterEntitlement>.broadcast();
      validator = _FakeValidator(controller);
    });

    tearDown(() {
      controller.close();
    });

    test('loads inactive when no cache present', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);
      expect(repo.current, equals(SupporterEntitlement.inactive));
      expect(repo.isSupporter, isFalse);
    });

    test('hydrates cached entitlement on construction', () async {
      final cached = SupporterEntitlement(
        productId: 'divine.supporter.monthly',
        source: EntitlementSource.appStore,
        purchaseDate: DateTime.utc(2030),
      ).toJson();
      SharedPreferences.setMockInitialValues({
        'divine_supporter_entitlement:$pubkeyA': jsonEncode(cached),
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);
      expect(repo.current.productId, 'divine.supporter.monthly');
      expect(repo.isSupporter, isTrue);
    });

    test('marks expired cached entitlement inactive on load', () async {
      final cached = SupporterEntitlement(
        productId: 'divine.supporter.monthly',
        source: EntitlementSource.appStore,
        purchaseDate: DateTime.utc(2000),
        expirationDate: DateTime.utc(2000, 2),
      ).toJson();
      SharedPreferences.setMockInitialValues({
        'divine_supporter_entitlement:$pubkeyA': jsonEncode(cached),
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);
      expect(repo.isSupporter, isFalse);
    });

    test('updates current and persists when validator emits', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);

      final emitted = <SupporterEntitlement>[];
      repo.changes.listen(emitted.add);

      validator.emit(
        SupporterEntitlement(
          productId: 'divine.supporter.monthly',
          source: EntitlementSource.playStore,
          purchaseDate: DateTime.utc(2030),
        ),
      );
      // Allow the stream listener to fire.
      await Future<void>.delayed(Duration.zero);

      expect(repo.isSupporter, isTrue);
      expect(emitted.last.isSupporter, isTrue);

      final stored = prefs.getString('divine_supporter_entitlement:$pubkeyA');
      expect(stored, isNotNull);
      expect(stored, contains('divine.supporter.monthly'));
    });

    test('ignores duplicate emissions', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);

      var emissions = 0;
      repo.changes.listen((_) => emissions++);

      validator.emit(SupporterEntitlement.inactive);
      validator.emit(SupporterEntitlement.inactive);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, 0);
    });

    test('forwards validator stream errors to repository listeners', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);

      const error = StoreUnavailableException();
      final errorFuture = expectLater(
        repo.changes,
        emitsError(isA<StoreUnavailableException>()),
      );
      validator.emitError(error);

      await errorFuture;
    });

    test('clearLocalEntitlement sets inactive and removes cache', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'divine_supporter_entitlement:$pubkeyA',
        jsonEncode(
          SupporterEntitlement(
            productId: 'p',
            source: EntitlementSource.appStore,
            purchaseDate: DateTime.utc(2030),
          ).toJson(),
        ),
      );
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);

      await repo.clearLocalEntitlement();
      expect(repo.isSupporter, isFalse);
      expect(prefs.getString('divine_supporter_entitlement:$pubkeyA'), isNull);
    });

    test('loads only the cache belonging to the active pubkey', () async {
      final active = SupporterEntitlement(
        productId: 'divine.supporter.monthly',
        source: EntitlementSource.appStore,
        purchaseDate: DateTime.utc(2030),
      );
      SharedPreferences.setMockInitialValues({
        'divine_supporter_entitlement:$pubkeyA': jsonEncode(active.toJson()),
        'divine_supporter_entitlement:$pubkeyB': jsonEncode(
          SupporterEntitlement.inactive.toJson(),
        ),
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SupporterRepository(
        pubkey: pubkeyB,
        validator: validator,
        prefs: prefs,
      );
      addTearDown(repo.dispose);

      expect(repo.isSupporter, isFalse);
    });

    test(
      'silently restores configured purchases for the signed-in account',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final apiClient = SupporterApiClient(
          baseUri: Uri.parse('https://supporters.test'),
          authHeaderProvider:
              ({required url, required method, payload}) async => (
                authorizationHeader: 'Nostr test-token',
                pubkey: pubkeyA,
              ),
        );
        final repo = SupporterRepository(
          pubkey: pubkeyA,
          validator: validator,
          prefs: prefs,
          apiClient: apiClient,
        );
        addTearDown(repo.dispose);
        addTearDown(apiClient.dispose);

        await repo.recoverPurchases();

        expect(validator.restoreCallCount, 1);
        expect(validator.restoredPubkey, pubkeyA);
      },
    );

    test('coalesces concurrent automatic recovery attempts', () async {
      final prefs = await SharedPreferences.getInstance();
      final apiClient = SupporterApiClient(
        baseUri: Uri.parse('https://supporters.test'),
        authHeaderProvider: ({required url, required method, payload}) async =>
            (
              authorizationHeader: 'Nostr test-token',
              pubkey: pubkeyA,
            ),
      );
      final repo = SupporterRepository(
        pubkey: pubkeyA,
        validator: validator,
        prefs: prefs,
        apiClient: apiClient,
      );
      addTearDown(repo.dispose);
      addTearDown(apiClient.dispose);
      validator.restoreCompleter = Completer<void>();

      final first = repo.recoverPurchases();
      final second = repo.recoverPurchases();
      await Future<void>.delayed(Duration.zero);

      expect(validator.restoreCallCount, 1);
      validator.restoreCompleter!.complete();
      await Future.wait([first, second]);
    });
  });
}
