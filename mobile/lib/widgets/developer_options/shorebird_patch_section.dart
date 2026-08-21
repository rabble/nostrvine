// ABOUTME: Developer-options section for validating a staged Shorebird patch
// ABOUTME: Checks and applies the staging track on the installed store binary

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/shorebird_patch/shorebird_patch_cubit.dart';
import 'package:openvine/blocs/shorebird_patch/shorebird_patch_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Lets a tester pull the `staging` track on the binary they are running.
///
/// iOS release artifacts are signed for App Store distribution, so
/// `shorebird preview` cannot install them, and an installed build only polls
/// `stable`. Without this, the only way to see a staged patch is to promote it
/// to production — which is the deploy that is supposed to follow validation.
class ShorebirdPatchSection extends StatelessWidget {
  const ShorebirdPatchSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ShorebirdPatchCubit>(
      // ShorebirdUpdater is a plain factory with no auth or account coupling,
      // so it cannot flip identity and needs no ValueKey guard.
      create: (_) => ShorebirdPatchCubit(updater: ShorebirdUpdater())..load(),
      child: const ShorebirdPatchView(),
    );
  }
}

@visibleForTesting
class ShorebirdPatchView extends StatelessWidget {
  @visibleForTesting
  const ShorebirdPatchView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(),
        _CurrentPatchTile(),
        _CheckTile(),
        _ApplyTile(),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        context.l10n.devOptionsShorebirdTitle,
        style: VineTheme.titleMediumFont(
          color: context.vineColors.accentPositive,
        ),
      ),
    );
  }
}

class _CurrentPatchTile extends StatelessWidget {
  const _CurrentPatchTile();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ShorebirdPatchCubit>().state;
    final l10n = context.l10n;
    final unavailable = state.status == ShorebirdPatchStatus.unavailable;

    // The patch number renders as the row's value rather than inside a
    // sentence: it names which patch is running, so interpolating it into
    // localized copy would invite translators to inflect it as a quantity.
    return ListTile(
      title: Text(
        unavailable
            ? l10n.devOptionsShorebirdUnavailable
            : l10n.devOptionsShorebirdPatchLabel,
        style: VineTheme.titleMediumFont(
          color: context.vineColors.primaryText,
        ),
      ),
      subtitle: Text(
        _subtitleFor(state, l10n),
        style: VineTheme.bodyMediumFont(
          color: context.vineColors.secondaryText,
        ),
      ),
      trailing: unavailable
          ? null
          : Text(
              state.currentPatchNumber?.toString() ??
                  l10n.devOptionsShorebirdNoPatch,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
    );
  }

  String _subtitleFor(ShorebirdPatchState state, AppLocalizations l10n) {
    return switch (state.status) {
      ShorebirdPatchStatus.unavailable =>
        l10n.devOptionsShorebirdUnavailableSubtitle,
      ShorebirdPatchStatus.checking => l10n.devOptionsShorebirdChecking,
      ShorebirdPatchStatus.updateAvailable =>
        l10n.devOptionsShorebirdUpdateAvailable,
      ShorebirdPatchStatus.upToDate => l10n.devOptionsShorebirdUpToDate,
      ShorebirdPatchStatus.applying => l10n.devOptionsShorebirdApplying,
      ShorebirdPatchStatus.applied => l10n.devOptionsShorebirdApplied,
      ShorebirdPatchStatus.failure => l10n.devOptionsShorebirdFailure,
      ShorebirdPatchStatus.initial => l10n.devOptionsShorebirdUpToDate,
    };
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ShorebirdPatchCubit>().state;
    final enabled = state.isAvailable && !state.isBusy;

    return ListTile(
      enabled: enabled,
      leading: DivineIcon(
        icon: DivineIconName.arrowClockwise,
        color: enabled
            ? context.vineColors.primaryText
            : context.vineColors.secondaryText,
      ),
      title: Text(
        context.l10n.devOptionsShorebirdCheck,
        style: VineTheme.titleMediumFont(
          color: enabled
              ? context.vineColors.primaryText
              : context.vineColors.secondaryText,
        ),
      ),
      onTap: enabled
          ? () => context.read<ShorebirdPatchCubit>().checkStagingTrack()
          : null,
    );
  }
}

class _ApplyTile extends StatelessWidget {
  const _ApplyTile();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ShorebirdPatchCubit>().state;
    final enabled = state.isAvailable && !state.isBusy;

    return ListTile(
      enabled: enabled,
      leading: DivineIcon(
        icon: DivineIconName.arrowDown,
        color: enabled
            ? context.vineColors.primaryText
            : context.vineColors.secondaryText,
      ),
      title: Text(
        context.l10n.devOptionsShorebirdApply,
        style: VineTheme.titleMediumFont(
          color: enabled
              ? context.vineColors.primaryText
              : context.vineColors.secondaryText,
        ),
      ),
      onTap: enabled
          ? () => context.read<ShorebirdPatchCubit>().applyStagedPatch()
          : null,
    );
  }
}
