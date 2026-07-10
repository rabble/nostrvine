// ABOUTME: Settings "Storage" screen — clear cached media (never the clip
// ABOUTME: library) and audit the clip library for broken entries.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/storage/storage_cubit.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/storage_providers.dart';

/// Settings screen for clearing caches and auditing the clip library.
class StorageManagementPage extends ConsumerWidget {
  /// Creates the page.
  const StorageManagementPage({super.key});

  /// Named route.
  static const String routeName = 'storage-management';

  /// Route path.
  ///
  /// A flat, first-class path (not nested under `/settings`) so
  /// `routeNormalizationProvider` can round-trip it through
  /// `parseRoute`/`buildRoute`. A `/settings/…` path collapses to
  /// `RouteType.settings` and gets normalized straight back to the
  /// Settings screen.
  static const String path = '/storage-management';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(storageManagementServiceProvider);
    return BlocProvider(
      key: ValueKey(service),
      create: (_) => StorageCubit(service: service)..loadCacheSize(),
      child: const StorageManagementView(),
    );
  }
}

/// The storage screen UI. Split from [StorageManagementPage] so it can be
/// tested with a stubbed [StorageCubit].
class StorageManagementView extends StatelessWidget {
  /// Creates the view.
  @visibleForTesting
  const StorageManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.settingsStorageTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: BlocListener<StorageCubit, StorageState>(
        listenWhen: (prev, curr) =>
            prev.cacheStatus != curr.cacheStatus ||
            prev.libraryStatus != curr.libraryStatus,
        listener: _announceOutcomes,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: const [
                _SectionHeader(_Section.cache),
                _CacheSection(),
                _SectionHeader(_Section.library),
                _LibrarySection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _announceOutcomes(BuildContext context, StorageState state) {
    final l10n = context.l10n;
    String? message;
    if (state.cacheStatus == StorageCacheStatus.cleared) {
      message = l10n.settingsStorageCleared;
    } else if (state.libraryStatus == StorageLibraryStatus.cleaned) {
      message = l10n.settingsStorageBrokenClipsRemoved;
    } else if (state.cacheStatus == StorageCacheStatus.failure ||
        state.libraryStatus == StorageLibraryStatus.failure) {
      message = l10n.settingsStorageError;
    }
    if (message == null) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }
}

enum _Section { cache, library }

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.section);

  final _Section section;

  @override
  Widget build(BuildContext context) {
    final title = switch (section) {
      _Section.cache => context.l10n.settingsStorageCacheSectionTitle,
      _Section.library => context.l10n.settingsStorageLibrarySectionTitle,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: VineTheme.labelMediumFont(color: VineTheme.vineGreen),
      ),
    );
  }
}

class _CacheSection extends StatelessWidget {
  const _CacheSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = context.select((StorageCubit c) => c.state.cacheStatus);
    final bytes = context.select((StorageCubit c) => c.state.cacheSizeBytes);
    final busy =
        status == StorageCacheStatus.loading ||
        status == StorageCacheStatus.clearing ||
        status == StorageCacheStatus.initial;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Text(
            l10n.settingsStorageCacheDescription,
            style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
          ),
          Text(
            busy
                ? l10n.settingsStorageMeasuring
                : l10n.settingsStorageCacheInUse(_formatBytes(bytes)),
            style: VineTheme.titleMediumFont(),
          ),
          const _CacheLimitControl(),
          DivineButton(
            label: l10n.settingsStorageClearButton,
            type: DivineButtonType.secondary,
            expanded: true,
            onPressed: busy || bytes == 0
                ? null
                : () => _confirmClear(context, bytes),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, int bytes) async {
    final l10n = context.l10n;
    final cubit = context.read<StorageCubit>();
    final confirmed = await VineBottomSheet.show<bool>(
      context: context,
      scrollable: false,
      contentTitle: l10n.settingsStorageClearConfirmTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.settingsStorageClearConfirmMessage(_formatBytes(bytes)),
            style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            spacing: 16,
            children: [
              Expanded(
                child: DivineButton(
                  label: l10n.settingsCancel,
                  type: DivineButtonType.secondary,
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              Expanded(
                child: DivineButton(
                  label: l10n.settingsStorageClearConfirmAction,
                  type: DivineButtonType.error,
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (confirmed ?? false) await cubit.clearCaches();
  }
}

class _CacheLimitControl extends StatelessWidget {
  const _CacheLimitControl();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<StorageCubit>();
    final limit = context.select((StorageCubit c) => c.state.cacheLimitBytes);
    final clampedBytes = limit.clamp(kCacheLimitMinBytes, kCacheLimitMaxBytes);
    final clamped = clampedBytes.toDouble();
    final approxVideos = clampedBytes ~/ kApproxVideoBytes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.settingsStorageMaxSizeLabel,
              style: VineTheme.bodyMediumFont(),
            ),
            Text(
              _formatBytes(limit),
              style: VineTheme.bodyMediumFont(color: VineTheme.vineGreen),
            ),
          ],
        ),
        DivineSlider(
          min: kCacheLimitMinBytes.toDouble(),
          max: kCacheLimitMaxBytes.toDouble(),
          divisions:
              (kCacheLimitMaxBytes - kCacheLimitMinBytes) ~/
              (512 * 1024 * 1024),
          value: clamped,
          onChanged: (value) => cubit.previewCacheLimit(value.round()),
          onChangeEnd: (value) => cubit.commitCacheLimit(value.round()),
        ),
        Text(
          l10n.settingsStorageApproxVideos(approxVideos),
          style: VineTheme.bodySmallFont(color: VineTheme.lightText),
        ),
      ],
    );
  }
}

class _LibrarySection extends StatelessWidget {
  const _LibrarySection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = context.select((StorageCubit c) => c.state.libraryStatus);
    final brokenCount = context.select(
      (StorageCubit c) => c.state.brokenClips.length,
    );
    final busy =
        status == StorageLibraryStatus.scanning ||
        status == StorageLibraryStatus.cleaning;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Text(
            l10n.settingsStorageLibraryDescription,
            style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
          ),
          if (status == StorageLibraryStatus.scanned && brokenCount == 0 ||
              status == StorageLibraryStatus.cleaned)
            Text(
              l10n.settingsStorageLibraryHealthy,
              style: VineTheme.titleMediumFont(color: VineTheme.vineGreen),
            )
          else if (status == StorageLibraryStatus.scanned && brokenCount > 0)
            Text(
              l10n.settingsStorageBrokenClipsFound(brokenCount),
              style: VineTheme.titleMediumFont(),
            ),
          if (status == StorageLibraryStatus.scanned && brokenCount > 0)
            DivineButton(
              label: l10n.settingsStorageRemoveBrokenButton,
              type: DivineButtonType.error,
              expanded: true,
              onPressed: () => _confirmRemoveBroken(context),
            )
          else
            DivineButton(
              label: l10n.settingsStorageScanButton,
              type: DivineButtonType.secondary,
              expanded: true,
              onPressed: busy
                  ? null
                  : () => context.read<StorageCubit>().scanLibrary(),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveBroken(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<StorageCubit>();
    final confirmed = await VineBottomSheet.show<bool>(
      context: context,
      scrollable: false,
      contentTitle: l10n.settingsStorageRemoveBrokenConfirmTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            spacing: 16,
            children: [
              Expanded(
                child: DivineButton(
                  label: l10n.settingsCancel,
                  type: DivineButtonType.secondary,
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              Expanded(
                child: DivineButton(
                  label: l10n.commonDelete,
                  type: DivineButtonType.error,
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (confirmed ?? false) await cubit.removeBrokenClips();
  }
}

/// Formats [bytes] as a short human-readable size (e.g. `1.2 MB`).
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var size = bytes / 1024;
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unit]}';
}
