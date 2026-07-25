// ABOUTME: Settings screen for the Divine supporter subscription.
// ABOUTME: Signal-style: optional monthly support, nothing gated, recognition only.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/supporter/supporter_cubit.dart';
import 'package:openvine/blocs/supporter/supporter_state.dart';
import 'package:openvine/providers/supporter_providers.dart';

class SupporterScreen extends ConsumerWidget {
  static const routeName = 'supporter';
  static const subpath = 'supporter';
  static const path = '/settings/supporter';

  const SupporterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(supporterRepositoryProvider);
    return BlocProvider(
      create: (_) => SupporterCubit(repository: repository),
      child: const SupporterScreenView(),
    );
  }
}

class SupporterScreenView extends StatefulWidget {
  const SupporterScreenView({super.key});

  @override
  State<SupporterScreenView> createState() => _SupporterScreenViewState();
}

class _SupporterScreenViewState extends State<SupporterScreenView> {
  @override
  void initState() {
    super.initState();
    // Start the cubit's entitlement listener now that the BlocProvider above
    // has created the cubit.
    context.read<SupporterCubit>().start();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupporterCubit, SupporterState>(
      builder: (context, state) {
        return Scaffold(
          appBar: DiVineAppBar(
            title: 'Divine Supporters',
            showBackButton: true,
            onBackPressed: context.pop,
          ),
          backgroundColor: VineTheme.navGreen,
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Hero(state: state),
                  const SizedBox(height: 24),
                  if (state.isSupporter)
                    const _ActiveBadge()
                  else if (state.hasTiers)
                    _TierList(state: state)
                  else
                    _UnavailableNote(loading: state.isBusy),
                  const SizedBox(height: 16),
                  if (!state.isSupporter) _RestoreButton(state: state),
                  if (state.failure != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _FailureBanner(
                        failure: state.failure!,
                        onDismiss: () =>
                            context.read<SupporterCubit>().dismissError(),
                      ),
                    ),
                  const SizedBox(height: 32),
                  _Disclaimer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.state});

  final SupporterState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.favorite,
          color: VineTheme.accentOrange,
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          'Keep Divine running',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Divine is free and always will be. If you want to help us keep the '
          'loops going, become a monthly supporter. Nothing is locked — it just '
          'keeps the lights on and earns our thanks.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VineTheme.accentOrange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite, color: VineTheme.accentOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "You're a Divine Supporter. Thank you for keeping this going.",
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierList extends StatelessWidget {
  const _TierList({required this.state});

  final SupporterState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final tier in state.tiers)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DivineButton(
              label: '${tier.title} — ${tier.price} / month',
              onPressed: state.isBusy
                  ? null
                  : () => context.read<SupporterCubit>().subscribe(
                      tier.productId,
                    ),
            ),
          ),
      ],
    );
  }
}

class _UnavailableNote extends StatelessWidget {
  const _UnavailableNote({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Text(
      loading
          ? 'Checking the store…'
          : 'Supporter subscriptions are not available here right now.',
      style: Theme.of(context).textTheme.bodyMedium,
      textAlign: TextAlign.center,
    );
  }
}

class _RestoreButton extends StatelessWidget {
  const _RestoreButton({required this.state});

  final SupporterState state;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: state.isBusy
          ? null
          : () => context.read<SupporterCubit>().restore(),
      child: const Text('Restore purchases'),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failure, required this.onDismiss});

  final SupporterFailure failure;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: VineTheme.accentOrange),
        const SizedBox(width: 8),
        Expanded(child: Text(_message(failure))),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: onDismiss,
        ),
      ],
    );
  }

  String _message(SupporterFailure failure) {
    switch (failure) {
      case SupporterFailure.storeUnavailable:
        return 'The store is unavailable on this device.';
      case SupporterFailure.purchaseFailed:
        return 'The purchase did not complete. You were not charged.';
      case SupporterFailure.purchasePending:
        return 'Your purchase is pending approval.';
      case SupporterFailure.restoreFailed:
        return 'No supporter subscription was found to restore.';
      case SupporterFailure.unknown:
        return 'Something went wrong. Please try again.';
    }
  }
}

class _Disclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Supporter status is verified on your device for now. Cross-device sync '
      'will arrive when server validation lands.',
      style: Theme.of(context).textTheme.bodySmall,
      textAlign: TextAlign.center,
    );
  }
}
