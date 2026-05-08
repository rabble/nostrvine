// ABOUTME: Time-window chip row for the Explore → Popular tab.
// ABOUTME: Tap routes through ?period=… so the URL is the source of truth.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/popular_period_provider.dart';

/// Horizontal chip row that filters the Popular tab by time window.
///
/// Tapping a chip drives a URL change rather than mutating the provider
/// directly — `ExploreScreen` listens for the route's `?period=` param
/// and updates [popularPeriodProvider] from there. This keeps the URL
/// authoritative and deep-linkable.
class PopularFilterBar extends ConsumerWidget {
  const PopularFilterBar({super.key});

  static const _explorePopularPath = '/explore/tab/popular';

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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final spec = chips[index];
            return _PeriodChip(
              spec: spec,
              isSelected: selected == spec.period,
              onTap: () => _onChipTap(context, spec.period),
            );
          },
        ),
      ),
    );
  }

  void _onChipTap(BuildContext context, LeaderboardPeriod? period) {
    if (period == null) {
      context.go(_explorePopularPath);
    } else {
      context.go('$_explorePopularPath?period=${period.urlSlug}');
    }
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
