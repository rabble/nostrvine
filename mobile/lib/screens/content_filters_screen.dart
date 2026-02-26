// ABOUTME: Per-category content filter settings screen with Show/Warn/Hide controls
// ABOUTME: Bluesky-inspired grouped layout with segmented buttons per content category

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/content_filter_service.dart';

class ContentFiltersScreen extends ConsumerStatefulWidget {
  static const routeName = 'content-filters';
  static const path = '/content-filters';

  const ContentFiltersScreen({super.key});

  @override
  ConsumerState<ContentFiltersScreen> createState() =>
      _ContentFiltersScreenState();
}

class _ContentFiltersScreenState extends ConsumerState<ContentFiltersScreen> {
  bool _isLoading = true;
  bool _isAgeVerified = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final contentFilterService = ref.read(contentFilterServiceProvider);
    final ageService = ref.read(ageVerificationServiceProvider);
    await contentFilterService.initialize();
    await ageService.initialize();
    if (mounted) {
      setState(() {
        _isAgeVerified = ageService.isAdultContentVerified;
        _isLoading = false;
      });
    }
  }

  Future<void> _setPreference(
    ContentLabel label,
    ContentFilterPreference preference,
  ) async {
    final service = ref.read(contentFilterServiceProvider);
    await service.setPreference(label, preference);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        leadingWidth: 80,
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: VineTheme.navGreen,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VineTheme.iconButtonBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SvgPicture.asset(
              'assets/icon/CaretLeft.svg',
              width: 32,
              height: 32,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
          onPressed: context.pop,
          tooltip: 'Back',
        ),
        title: Text('Content Filters', style: VineTheme.titleFont()),
      ),
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                if (!_isAgeVerified) _buildAgeGateBanner(),
                _buildCategoryGroup(
                  title: 'ADULT CONTENT',
                  labels: [
                    ContentLabel.nudity,
                    ContentLabel.sexual,
                    ContentLabel.porn,
                  ],
                  locked: !_isAgeVerified,
                ),
                _buildCategoryGroup(
                  title: 'VIOLENCE & GORE',
                  labels: [
                    ContentLabel.graphicMedia,
                    ContentLabel.violence,
                    ContentLabel.selfHarm,
                  ],
                ),
                _buildCategoryGroup(
                  title: 'SUBSTANCES',
                  labels: [
                    ContentLabel.drugs,
                    ContentLabel.alcohol,
                    ContentLabel.tobacco,
                    ContentLabel.gambling,
                  ],
                ),
                _buildCategoryGroup(
                  title: 'OTHER',
                  labels: [
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
            ),
    );
  }

  Widget _buildAgeGateBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VineTheme.onSurfaceDisabled, width: 0.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, color: VineTheme.onSurfaceMuted),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Verify your age in Safety & Privacy settings to '
              'unlock adult content filters',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGroup({
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
            preference: ref
                .read(contentFilterServiceProvider)
                .getPreference(label),
            locked: locked,
            onChanged: (pref) => _setPreference(label, pref),
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
              label.displayName,
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
            label: 'Show',
            selected: value == ContentFilterPreference.show,
            onTap: locked
                ? null
                : () => onChanged(ContentFilterPreference.show),
          ),
          _buildSegment(
            label: 'Warn',
            selected: value == ContentFilterPreference.warn,
            onTap: locked
                ? null
                : () => onChanged(ContentFilterPreference.warn),
          ),
          _buildSegment(
            label: 'Filter Out',
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
          color: selected ? VineTheme.vineGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: locked
                ? VineTheme.onSurfaceDisabled
                : selected
                ? Colors.black
                : VineTheme.secondaryText,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
