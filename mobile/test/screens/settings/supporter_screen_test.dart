// ABOUTME: Widget tests for SupporterScreen — rendering and status display.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iap_repository/iap_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/supporter/supporter_cubit.dart';
import 'package:openvine/blocs/supporter/supporter_state.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/screens/settings/supporter_screen.dart';
import 'package:openvine/services/supporter_repository.dart';

import '../../helpers/l10n.dart';

/// A minimal fake repository exposing the surface the screen reads.
class _FakeRepository extends Fake implements SupporterRepository {
  _FakeRepository(
    this._controller, {
    this.initial = SupporterEntitlement.inactive,
  });

  final StreamController<SupporterEntitlement> _controller;
  final SupporterEntitlement initial;

  @override
  SupporterEntitlement get current => initial;

  @override
  bool get hasServerClient => false;

  @override
  Stream<SupporterEntitlement> get changes => _controller.stream;

  @override
  Future<SupporterEntitlement> purchase(String productId) =>
      validator.purchase(productId);

  @override
  Future<SupporterEntitlement> restorePurchases() =>
      validator.restorePurchases();

  @override
  EntitlementValidator get validator => _EmptyValidator();
}

class _EmptyValidator extends Fake implements EntitlementValidator {
  @override
  void startListening() {}

  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<List<SupporterTier>> fetchProducts() async => const [];

  @override
  Future<SupporterEntitlement> purchase(
    String productId, {
    String? capturedPubkey,
    String? attemptId,
  }) async => SupporterEntitlement.inactive;

  @override
  Future<SupporterEntitlement> restorePurchases({
    String? capturedPubkey,
    String? attemptId,
  }) async => SupporterEntitlement.inactive;

  @override
  Stream<SupporterEntitlement> get entitlementChanges =>
      const Stream<SupporterEntitlement>.empty();

  @override
  Stream<EntitlementLifecycle> get lifecycleChanges => const Stream.empty();

  @override
  Stream<SupporterPurchaseProof> get purchaseProofChanges =>
      const Stream.empty();

  @override
  Future<void> completePurchase(SupporterPurchaseProof proof) async {}
}

void main() {
  testWidgets('renders hero copy and restore button when not a supporter', (
    tester,
  ) async {
    final controller = StreamController<SupporterEntitlement>.broadcast();
    addTearDown(controller.close);
    final repo = _FakeRepository(controller);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [supporterRepositoryProvider.overrideWithValue(repo)],
        child: buildLocalizedWidget(const SupporterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keep Divine running'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
  });

  testWidgets('shows active badge when entitlement is active', (tester) async {
    final controller = StreamController<SupporterEntitlement>.broadcast();
    addTearDown(controller.close);
    final repo = _FakeRepository(
      controller,
      initial: SupporterEntitlement(
        productId: 'divine.supporter.monthly',
        source: EntitlementSource.appStore,
        purchaseDate: DateTime.utc(2030),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [supporterRepositoryProvider.overrideWithValue(repo)],
        child: buildLocalizedWidget(const SupporterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining("You're a Divine Supporter"), findsOneWidget);
  });

  testWidgets('shows unavailable note when store has no tiers', (tester) async {
    final controller = StreamController<SupporterEntitlement>.broadcast();
    addTearDown(controller.close);
    final repo = _FakeRepository(controller);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [supporterRepositoryProvider.overrideWithValue(repo)],
        child: buildLocalizedWidget(const SupporterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('not available here right now'), findsOneWidget);
  });

  testWidgets('renders failure banner for an error state', (tester) async {
    final controller = StreamController<SupporterEntitlement>.broadcast();
    addTearDown(controller.close);
    late SupporterCubit cubit;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supporterRepositoryProvider.overrideWithValue(
            _FakeRepository(controller),
          ),
        ],
        child: buildLocalizedWidget(
          BlocProvider<SupporterCubit>(
            create: (_) {
              return cubit = SupporterCubit(
                repository: _FakeRepository(controller),
              );
            },
            child: const SupporterScreenView(),
          ),
        ),
      ),
    );
    // Let start() + loadTiers() settle to idle, then surface a failure.
    await tester.pumpAndSettle();
    cubit.emit(const SupporterState(failure: SupporterFailure.purchaseFailed));
    await tester.pumpAndSettle();

    expect(find.textContaining('did not complete'), findsOneWidget);
  });
}
