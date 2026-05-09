// ABOUTME: Time-window chip row for the Explore → Popular tab.
// ABOUTME: Chip taps update popularPeriodProvider directly. Cold-start
// ABOUTME: deep-linking via ?period= is handled by ExploreScreen.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/popular_period_provider.dart';

/// Horizontal chip row that filters the Popular tab by time window.
///
/// Chip taps mutate [popularPeriodProvider] directly. The route URL is
/// not changed on tap — driving navigation from chip taps caused a web
/// page-rebuild hang when transitioning between sibling explore routes
/// (`/explore` → `/explore/tab/popular?period=…`). Deep-link cold-start
/// is still supported: `ExploreScreen.didChangeDependencies` reads
/// `?period=` from the URL and seeds the provider on first build.
class PopularFilterBar extends ConsumerWidget {
  const PopularFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(popularPeriodProvider);
    final l10n = context.l10n;

    final chips = <_ChipSpec>[
      _ChipSpec(period: null, label: l10n.popularFilterRightNow),
      _ChipSpec(period: LeaderboardPeriod.day, label: l10n.popularFilterToday),
      _ChipSpec(period: LeaderboardPeriod.week, label: l10n.popularFilterWeek),
      _ChipSpec(
        period: LeaderboardPeriod.month,
        label: l10n.popularFilterMonth,
      ),
      _ChipSpec(
        period: LeaderboardPeriod.alltime,
        label: l10n.popularFilterAllTime,
      ),
    ];

    return Semantics(
      label: l10n.popularFilterLabel,
      container: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            for (final spec in chips)
              _PeriodChip(
                spec: spec,
                isSelected: selected == spec.period,
                onTap: () => ref.read(popularPeriodProvider.notifier).state =
                    spec.period,
              ),
          ],
        ),
      ),
    );
  }
}

class _ChipSpec {
  const _ChipSpec({required this.period, required this.label});
  final LeaderboardPeriod? period;
  final String label;
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.spec,
    required this.isSelected,
    required this.onTap,
  });

  final _ChipSpec spec;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(spec.label, style: VineTheme.labelMediumFont()),
      selected: isSelected,
      onSelected: (_) => onTap(),
    );
  }
}
