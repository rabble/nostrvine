// ABOUTME: Per-category content filter settings screen with Show/Warn/Hide controls
// ABOUTME: Bluesky-inspired grouped layout with segmented buttons per content category

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/content_filters/content_filters_cubit.dart';
import 'package:openvine/blocs/content_filters/content_filters_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_content_label_name.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/content_filter_service.dart';

/// Page: bridges the filter + age services into [ContentFiltersCubit].
class ContentFiltersScreen extends ConsumerWidget {
  const ContentFiltersScreen({super.key});

  static const routeName = 'content-filters';
  static const path = '/content-filters';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentFilterService = ref.watch(contentFilterServiceProvider);
    final ageVerificationService = ref.watch(ageVerificationServiceProvider);
    return BlocProvider(
      // Both are moderation services that can be rebuilt; re-key so the Cubit
      // reloads with fresh instances rather than operating on stale ones.
      key: ValueKey((contentFilterService, ageVerificationService)),
      create: (_) => ContentFiltersCubit(
        contentFilterService: contentFilterService,
        ageVerificationService: ageVerificationService,
      )..load(),
      child: const ContentFiltersView(),
    );
  }
}

/// View: renders the per-category filter controls from the Cubit state.
class ContentFiltersView extends StatelessWidget {
  @visibleForTesting
  const ContentFiltersView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.contentPreferencesContentFilters,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BlocBuilder<ContentFiltersCubit, ContentFiltersState>(
            builder: (context, state) {
              if (state.status != ContentFiltersStatus.ready) {
                return const Center(
                  child: CircularProgressIndicator(color: VineTheme.vineGreen),
                );
              }
              final cubit = context.read<ContentFiltersCubit>();
              return ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  if (!state.isAgeVerified) _buildAgeGateBanner(context),
                  _buildCategoryGroup(
                    context,
                    state,
                    cubit,
                    title: context.l10n.contentFiltersAdultContent,
                    labels: const [
                      ContentLabel.nudity,
                      ContentLabel.sexual,
                      ContentLabel.porn,
                    ],
                    locked: !state.isAgeVerified,
                  ),
                  _buildCategoryGroup(
                    context,
                    state,
                    cubit,
                    title: context.l10n.contentFiltersViolenceGore,
                    labels: const [
                      ContentLabel.graphicMedia,
                      ContentLabel.violence,
                      ContentLabel.selfHarm,
                    ],
                  ),
                  _buildCategoryGroup(
                    context,
                    state,
                    cubit,
                    title: context.l10n.contentFiltersSubstances,
                    labels: const [
                      ContentLabel.drugs,
                      ContentLabel.alcohol,
                      ContentLabel.tobacco,
                      ContentLabel.gambling,
                    ],
                  ),
                  _buildCategoryGroup(
                    context,
                    state,
                    cubit,
                    title: context.l10n.contentFiltersOther,
                    labels: const [
                      ContentLabel.profanity,
                      ContentLabel.hate,
                      ContentLabel.harassment,
                      ContentLabel.flashingLights,
                      ContentLabel.aiGenerated,
                      ContentLabel.spoiler,
                      ContentLabel.misleading,
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAgeGateBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VineTheme.onSurfaceDisabled, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: VineTheme.onSurfaceMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.contentFiltersAgeGateMessage,
              style: const TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGroup(
    BuildContext context,
    ContentFiltersState state,
    ContentFiltersCubit cubit, {
    required String title,
    required List<ContentLabel> labels,
    bool locked = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        ...labels.map(
          (label) => _ContentFilterRow(
            label: label,
            preference: state.preferenceFor(label),
            locked: locked,
            onChanged: (pref) => cubit.setPreference(label, pref),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(
      title,
      style: const TextStyle(
        color: VineTheme.vineGreen,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _ContentFilterRow extends StatelessWidget {
  const _ContentFilterRow({
    required this.label,
    required this.preference,
    required this.locked,
    required this.onChanged,
  });

  final ContentLabel label;
  final ContentFilterPreference preference;
  final bool locked;
  final ValueChanged<ContentFilterPreference> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              localizedContentLabelName(context.l10n, label),
              style: TextStyle(
                color: locked
                    ? VineTheme.onSurfaceDisabled
                    : VineTheme.whiteText,
                fontSize: 15,
              ),
            ),
          ),
          _FilterSegmentedControl(
            value: preference,
            locked: locked,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterSegmentedControl extends StatelessWidget {
  const _FilterSegmentedControl({
    required this.value,
    required this.locked,
    required this.onChanged,
  });

  final ContentFilterPreference value;
  final bool locked;
  final ValueChanged<ContentFilterPreference> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VineTheme.onSurfaceDisabled, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegment(
            label: context.l10n.contentFiltersShow,
            selected: value == ContentFilterPreference.show,
            onTap: locked
                ? null
                : () => onChanged(ContentFilterPreference.show),
          ),
          _buildSegment(
            label: context.l10n.contentFiltersWarn,
            selected: value == ContentFilterPreference.warn,
            onTap: locked
                ? null
                : () => onChanged(ContentFilterPreference.warn),
          ),
          _buildSegment(
            label: context.l10n.contentFiltersFilterOut,
            selected: value == ContentFilterPreference.hide,
            onTap: locked
                ? null
                : () => onChanged(ContentFilterPreference.hide),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? VineTheme.vineGreen : VineTheme.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: locked
                ? VineTheme.onSurfaceDisabled
                : selected
                ? VineTheme.backgroundColor
                : VineTheme.secondaryText,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
