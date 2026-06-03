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

  static const List<ContentLabel> _adultLabels = [
    ContentLabel.nudity,
    ContentLabel.sexual,
    ContentLabel.porn,
  ];

  static const List<ContentLabel> _violenceLabels = [
    ContentLabel.graphicMedia,
    ContentLabel.violence,
    ContentLabel.selfHarm,
  ];

  static const List<ContentLabel> _substanceLabels = [
    ContentLabel.drugs,
    ContentLabel.alcohol,
    ContentLabel.tobacco,
    ContentLabel.gambling,
  ];

  static const List<ContentLabel> _otherLabels = [
    ContentLabel.profanity,
    ContentLabel.hate,
    ContentLabel.harassment,
    ContentLabel.flashingLights,
    ContentLabel.aiGenerated,
    ContentLabel.deepfake,
    ContentLabel.spam,
    ContentLabel.scam,
    ContentLabel.spoiler,
    ContentLabel.misleading,
  ];

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
                  if (!state.isAgeVerified) const _AgeGateBanner(),
                  _CategoryGroup(
                    title: context.l10n.contentFiltersAdultContent,
                    labels: _adultLabels,
                    state: state,
                    locked: !state.isAgeVerified,
                    onChanged: cubit.setPreference,
                  ),
                  _CategoryGroup(
                    title: context.l10n.contentFiltersViolenceGore,
                    labels: _violenceLabels,
                    state: state,
                    onChanged: cubit.setPreference,
                  ),
                  _CategoryGroup(
                    title: context.l10n.contentFiltersSubstances,
                    labels: _substanceLabels,
                    state: state,
                    onChanged: cubit.setPreference,
                  ),
                  _CategoryGroup(
                    title: context.l10n.contentFiltersOther,
                    labels: _otherLabels,
                    state: state,
                    onChanged: cubit.setPreference,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AgeGateBanner extends StatelessWidget {
  const _AgeGateBanner();

  @override
  Widget build(BuildContext context) {
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
          const DivineIcon(
            icon: DivineIconName.lockSimple,
            color: VineTheme.onSurfaceMuted,
          ),
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
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    required this.title,
    required this.labels,
    required this.state,
    required this.onChanged,
    this.locked = false,
  });

  final String title;
  final List<ContentLabel> labels;
  final ContentFiltersState state;
  final bool locked;
  final Future<void> Function(
    ContentLabel label,
    ContentFilterPreference preference,
  )
  onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title),
        ...labels.map(
          (label) => _ContentFilterRow(
            label: label,
            preference: state.preferenceFor(label),
            locked: locked,
            onChanged: (preference) {
              onChanged(label, preference);
            },
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          _FilterSegment(
            label: context.l10n.contentFiltersShow,
            selected: value == ContentFilterPreference.show,
            locked: locked,
            onTap: locked
                ? null
                : () => onChanged(ContentFilterPreference.show),
          ),
          _FilterSegment(
            label: context.l10n.contentFiltersWarn,
            selected: value == ContentFilterPreference.warn,
            locked: locked,
            onTap: locked
                ? null
                : () => onChanged(ContentFilterPreference.warn),
          ),
          _FilterSegment(
            label: context.l10n.contentFiltersFilterOut,
            selected: value == ContentFilterPreference.hide,
            locked: locked,
            onTap: locked
                ? null
                : () => onChanged(ContentFilterPreference.hide),
          ),
        ],
      ),
    );
  }
}

class _FilterSegment extends StatelessWidget {
  const _FilterSegment({
    required String label,
    required bool selected,
    required bool locked,
    required VoidCallback? onTap,
  }) : _label = label,
       _selected = selected,
       _locked = locked,
       _onTap = onTap;

  final String _label;
  final bool _selected;
  final bool _locked;
  final VoidCallback? _onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _selected ? VineTheme.vineGreen : VineTheme.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          _label,
          style: TextStyle(
            color: _locked
                ? VineTheme.onSurfaceDisabled
                : _selected
                ? VineTheme.backgroundColor
                : VineTheme.secondaryText,
            fontSize: 12,
            fontWeight: _selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
