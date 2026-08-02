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
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/screens/settings/app_language_screen.dart';
import 'package:openvine/screens/settings/appearance_settings_screen.dart';
import 'package:openvine/screens/settings/bluesky_settings_screen.dart';
import 'package:openvine/screens/settings/crossposting_settings_screen.dart';
import 'package:openvine/screens/settings/storage/storage_management_page.dart';
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
    final showAppearance = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.lightMode),
    );
    final showCrossposting = ref.watch(crosspostingEligibleProvider);

    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.settingsGeneralTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              if (showBluesky || showCrossposting)
                DivineSectionHeader(
                  context.l10n.generalSettingsSectionIntegrations,
                ),
              if (showBluesky)
                ListTile(
                  leading: const Icon(
                    Icons.cloud_upload,
                    color: VineTheme.vineGreen,
                  ),
                  title: Text(
                    context.l10n.settingsBlueskyPublishing,
                    style: _titleStyleOf(context),
                  ),
                  subtitle: Text(
                    context.l10n.settingsBlueskyPublishingSubtitle,
                    style: _subtitleStyleOf(context),
                  ),
                  trailing: DivineIcon(
                    icon: DivineIconName.caretRight,
                    color: context.vineColors.mutedText,
                  ),
                  onTap: () => context.push(BlueskySettingsScreen.path),
                ),
              if (showCrossposting)
                ListTile(
                  leading: const DivineIcon(
                    icon: DivineIconName.shareNetwork,
                    color: VineTheme.vineGreen,
                  ),
                  title: Text(
                    context.l10n.settingsCrosspostingTitle,
                    style: _titleStyleOf(context),
                  ),
                  subtitle: Text(
                    context.l10n.settingsCrosspostingSubtitle,
                    style: _subtitleStyleOf(context),
                  ),
                  trailing: DivineIcon(
                    icon: DivineIconName.caretRight,
                    color: context.vineColors.mutedText,
                  ),
                  onTap: () => context.push(CrosspostingSettingsScreen.path),
                ),
              DivineSectionHeader(context.l10n.generalSettingsSectionViewing),
              const _ClosedCaptionsToggle(),
              const _FeedAspectRatioPreferenceTile(),
              DivineSectionHeader(context.l10n.generalSettingsSectionCreating),
              const _AudioSharingToggle(),
              const _LongPressRecordingToggle(),
              DivineSectionHeader(context.l10n.generalSettingsSectionApp),
              const _AppLanguageTile(),
              if (showAppearance)
                ListTile(
                  leading: const DivineIcon(
                    icon: DivineIconName.sun,
                    color: VineTheme.vineGreen,
                  ),
                  title: Text(
                    context.l10n.appearanceSettingsTitle,
                    style: _titleStyleOf(context),
                  ),
                  subtitle: Text(
                    context.l10n.appearanceSettingsSubtitle,
                    style: _subtitleStyleOf(context),
                  ),
                  trailing: DivineIcon(
                    icon: DivineIconName.caretRight,
                    color: context.vineColors.mutedText,
                  ),
                  onTap: () => context.push(AppearanceSettingsScreen.path),
                ),
              ListTile(
                leading: const DivineIcon(
                  icon: DivineIconName.stackSimple,
                  color: VineTheme.vineGreen,
                ),
                title: Text(
                  context.l10n.settingsStorageTitle,
                  style: _titleStyleOf(context),
                ),
                trailing: DivineIcon(
                  icon: DivineIconName.caretRight,
                  color: context.vineColors.mutedText,
                ),
                onTap: () => context.push(StorageManagementPage.path),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _titleStyleOf(BuildContext context) =>
    VineTheme.titleMediumFont(color: context.vineColors.primaryText);

TextStyle _subtitleStyleOf(BuildContext context) =>
    VineTheme.bodyMediumFont(color: context.vineColors.mutedText);

class _ClosedCaptionsToggle extends ConsumerWidget {
  const _ClosedCaptionsToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(subtitleVisibilityProvider);
    return DivineSwitchTile(
      leadingIcon: DivineIconName.closedCaptioning,
      title: context.l10n.generalSettingsClosedCaptions,
      subtitle: context.l10n.generalSettingsClosedCaptionsSubtitle,
      value: enabled,
      onChanged: (_) => ref.read(subtitleVisibilityProvider.notifier).toggle(),
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
      leading: const DivineIcon(
        icon: DivineIconName.cropSquare,
        color: VineTheme.vineGreen,
      ),
      title: Text(
        context.l10n.generalSettingsVideoShape,
        style: _titleStyleOf(context),
      ),
      subtitle: Text(subtitle, style: _subtitleStyleOf(context)),
      trailing: DivineIcon(
        icon: DivineIconName.caretRight,
        color: context.vineColors.mutedText,
      ),
      onTap: () => _showPicker(context, service),
    );
  }

  Future<void> _showPicker(
    BuildContext context,
    FeedAspectRatioPreferenceService service,
  ) async {
    Future<void> select(FeedAspectRatioPreference value) async {
      await service.setPreference(value);
      if (context.mounted) Navigator.pop(context);
    }

    await VineBottomSheet.show<void>(
      context: context,
      scrollable: false,
      contentTitle: context.l10n.generalSettingsVideoShape,
      children: [
        DivineSelectableRow(
          title: context.l10n.generalSettingsVideoShapeSquareAndPortrait,
          subtitle:
              context.l10n.generalSettingsVideoShapeSquareAndPortraitSubtitle,
          isSelected:
              service.preference == FeedAspectRatioPreference.squareAndPortrait,
          onTap: () => select(FeedAspectRatioPreference.squareAndPortrait),
        ),
        DivineSelectableRow(
          title: context.l10n.generalSettingsVideoShapeSquareOnly,
          subtitle: context.l10n.generalSettingsVideoShapeSquareOnlySubtitle,
          isSelected:
              service.preference == FeedAspectRatioPreference.squareOnly,
          onTap: () => select(FeedAspectRatioPreference.squareOnly),
        ),
      ],
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

    return DivineSwitchTile(
      leadingIcon: DivineIconName.musicNote,
      title: context.l10n.contentPreferencesAudioSharing,
      subtitle: context.l10n.contentPreferencesAudioSharingSubtitle,
      value: isEnabled,
      onChanged: (value) async {
        await audioSharingService.setAudioSharingEnabled(value);
        setState(() {});
      },
    );
  }
}

class _LongPressRecordingToggle extends ConsumerWidget {
  const _LongPressRecordingToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(holdToRecordPreferenceServiceProvider);
    final isEnabled = service.isHoldToRecordEnabled;

    return DivineSwitchTile(
      leadingIcon: DivineIconName.cameraRetro,
      title: context.l10n.generalSettingsHoldToRecord,
      subtitle: context.l10n.generalSettingsHoldToRecordSubtitle,
      value: isEnabled,
      onChanged: (value) async {
        await service.setHoldToRecordEnabled(value);
        ref.invalidate(holdToRecordPreferenceServiceProvider);
      },
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
          leading: const DivineIcon(
            icon: DivineIconName.globe,
            color: VineTheme.vineGreen,
          ),
          title: Text(
            context.l10n.settingsAppLanguage,
            style: _titleStyleOf(context),
          ),
          subtitle: Text(subtitle, style: _subtitleStyleOf(context)),
          trailing: DivineIcon(
            icon: DivineIconName.caretRight,
            color: context.vineColors.mutedText,
          ),
          onTap: () => context.push(AppLanguageScreen.path),
        );
      },
    );
  }
}
