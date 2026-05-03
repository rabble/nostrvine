// ABOUTME: General app behavior and integration settings screen.
// ABOUTME: Groups viewing, creation, app language, and integration controls.

import 'dart:ui';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/screens/settings/app_language_screen.dart';
import 'package:openvine/screens/settings/bluesky_settings_screen.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:openvine/services/locale_preference_service.dart';

class GeneralSettingsScreen extends ConsumerWidget {
  static const routeName = 'general-settings';
  static const path = '/general-settings';

  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBluesky = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.blueskyPublishing),
    );

    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.settingsGeneralTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              if (showBluesky) ...[
                _SectionHeader(context.l10n.generalSettingsSectionIntegrations),
                ListTile(
                  leading: const Icon(
                    Icons.cloud_upload,
                    color: VineTheme.vineGreen,
                  ),
                  title: Text(
                    context.l10n.settingsBlueskyPublishing,
                    style: _titleStyle,
                  ),
                  subtitle: Text(
                    context.l10n.settingsBlueskyPublishingSubtitle,
                    style: _subtitleStyle,
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: VineTheme.lightText,
                  ),
                  onTap: () => context.push(BlueskySettingsScreen.path),
                ),
              ],
              _SectionHeader(context.l10n.generalSettingsSectionViewing),
              const _ClosedCaptionsToggle(),
              const _FeedAspectRatioPreferenceTile(),
              _SectionHeader(context.l10n.generalSettingsSectionCreating),
              const _AudioSharingToggle(),
              _SectionHeader(context.l10n.generalSettingsSectionApp),
              const _AppLanguageTile(),
            ],
          ),
        ),
      ),
    );
  }
}

const _titleStyle = TextStyle(
  color: VineTheme.whiteText,
  fontSize: 16,
  fontWeight: FontWeight.w500,
);

const _subtitleStyle = TextStyle(color: VineTheme.lightText, fontSize: 14);

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

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

class _ClosedCaptionsToggle extends ConsumerWidget {
  const _ClosedCaptionsToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(subtitleVisibilityProvider);
    return SwitchListTile(
      value: enabled,
      onChanged: (_) => ref.read(subtitleVisibilityProvider.notifier).toggle(),
      title: Text(
        context.l10n.generalSettingsClosedCaptions,
        style: _titleStyle,
      ),
      subtitle: Text(context.l10n.generalSettingsClosedCaptionsSubtitle),
      activeThumbColor: VineTheme.vineGreen,
      secondary: const Icon(Icons.closed_caption, color: VineTheme.vineGreen),
    );
  }
}

class _FeedAspectRatioPreferenceTile extends ConsumerWidget {
  const _FeedAspectRatioPreferenceTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(feedAspectRatioPreferenceServiceProvider);
    final preference = service.preference;
    final subtitle = switch (preference) {
      FeedAspectRatioPreference.squareOnly =>
        context.l10n.generalSettingsVideoShapeSquareOnly,
      FeedAspectRatioPreference.squareAndPortrait =>
        context.l10n.generalSettingsVideoShapeSquareAndPortrait,
    };

    return ListTile(
      leading: const Icon(Icons.crop_square, color: VineTheme.vineGreen),
      title: Text(context.l10n.generalSettingsVideoShape, style: _titleStyle),
      subtitle: Text(subtitle, style: _subtitleStyle),
      trailing: const Icon(Icons.chevron_right, color: VineTheme.lightText),
      onTap: () => _showPicker(context, service),
    );
  }

  Future<void> _showPicker(
    BuildContext context,
    FeedAspectRatioPreferenceService service,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: VineTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.generalSettingsVideoShape,
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: VineTheme.lightText, height: 1),
            RadioGroup<FeedAspectRatioPreference>(
              groupValue: service.preference,
              onChanged: (value) async {
                if (value == null) return;
                await service.setPreference(value);
                if (context.mounted) Navigator.pop(context);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FeedAspectRatioOption(
                    title:
                        context.l10n.generalSettingsVideoShapeSquareAndPortrait,
                    subtitle: context
                        .l10n
                        .generalSettingsVideoShapeSquareAndPortraitSubtitle,
                    value: FeedAspectRatioPreference.squareAndPortrait,
                  ),
                  _FeedAspectRatioOption(
                    title: context.l10n.generalSettingsVideoShapeSquareOnly,
                    subtitle: context
                        .l10n
                        .generalSettingsVideoShapeSquareOnlySubtitle,
                    value: FeedAspectRatioPreference.squareOnly,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedAspectRatioOption extends StatelessWidget {
  const _FeedAspectRatioOption({
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final String title;
  final String subtitle;
  final FeedAspectRatioPreference value;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<FeedAspectRatioPreference>(
      value: value,
      title: Text(title, style: _titleStyle),
      subtitle: Text(subtitle, style: _subtitleStyle),
      activeColor: VineTheme.vineGreen,
    );
  }
}

class _AudioSharingToggle extends ConsumerStatefulWidget {
  const _AudioSharingToggle();

  @override
  ConsumerState<_AudioSharingToggle> createState() =>
      _AudioSharingToggleState();
}

class _AudioSharingToggleState extends ConsumerState<_AudioSharingToggle> {
  @override
  Widget build(BuildContext context) {
    final audioSharingService = ref.watch(
      audioSharingPreferenceServiceProvider,
    );
    final isEnabled = audioSharingService.isAudioSharingEnabled;

    return SwitchListTile(
      value: isEnabled,
      onChanged: (value) async {
        await audioSharingService.setAudioSharingEnabled(value);
        setState(() {});
      },
      title: Text(
        context.l10n.contentPreferencesAudioSharing,
        style: _titleStyle,
      ),
      subtitle: Text(
        context.l10n.contentPreferencesAudioSharingSubtitle,
        style: _subtitleStyle,
      ),
      activeThumbColor: VineTheme.vineGreen,
      secondary: const Icon(Icons.music_note, color: VineTheme.vineGreen),
    );
  }
}

class _AppLanguageTile extends StatelessWidget {
  const _AppLanguageTile();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, LocaleState>(
      builder: (context, state) {
        final locale = state.locale;
        final subtitle = locale == null
            ? context.l10n.settingsAppLanguageDeviceDefault(
                LocalePreferenceService.nativeNameFor(
                  PlatformDispatcher.instance.locale.languageCode,
                ),
              )
            : LocalePreferenceService.nativeNameFor(locale.languageCode);

        return ListTile(
          leading: const Icon(Icons.language, color: VineTheme.vineGreen),
          title: Text(context.l10n.settingsAppLanguage, style: _titleStyle),
          subtitle: Text(subtitle, style: _subtitleStyle),
          trailing: const Icon(Icons.chevron_right, color: VineTheme.lightText),
          onTap: () => context.push(AppLanguageScreen.path),
        );
      },
    );
  }
}
