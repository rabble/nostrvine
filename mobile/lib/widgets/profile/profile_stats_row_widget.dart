// ABOUTME: Stats row widget for profile page showing loops and likes counts
// ABOUTME: Displays animated stat values with loading states

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/string_utils.dart';

/// Stats row showing total loops and likes for a profile
class ProfileStatsRowWidget extends StatelessWidget {
  const ProfileStatsRowWidget({required this.profileStatsAsync, super.key});

  final AsyncValue<ProfileStats> profileStatsAsync;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: VineTheme.cardBackground,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ProfileStatValue(
          count: profileStatsAsync.value?.totalViews ?? 0,
          label: 'Known Loops',
          isLoading: profileStatsAsync.isLoading,
        ),
        _ProfileStatValue(
          count: profileStatsAsync.value?.totalLikes ?? 0,
          label: 'Known Likes',
          isLoading: profileStatsAsync.isLoading,
        ),
      ],
    ),
  );
}

/// Private widget for displaying a single stat value with animated loading state
class _ProfileStatValue extends StatelessWidget {
  const _ProfileStatValue({
    required this.count,
    required this.label,
    required this.isLoading,
  });

  final int count;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: isLoading
            ? const Text(
                '—',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              )
            : Text(
                StringUtils.formatCompactNumber(count),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
      Text(label, style: TextStyle(color: Colors.grey.shade300, fontSize: 12)),
    ],
  );
}

/// Individual stat column widget for videos/followers/following counts
class ProfileStatColumn extends StatelessWidget {
  const ProfileStatColumn({
    required this.count,
    required this.label,
    required this.isLoading,
    this.onTap,
    super.key,
  });

  final int? count;
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isLoading
              ? const Text(
                  '—',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : Text(
                  count != null ? StringUtils.formatCompactNumber(count!) : '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.all(8.0), child: column),
      );
    }

    return column;
  }
}
