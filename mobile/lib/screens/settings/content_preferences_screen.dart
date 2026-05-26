// ABOUTME: Content preferences screen for language, audio sharing, and content filters
// ABOUTME: Moved from old settings screen with helper methods converted to widget classes

import 'dart:ui';

import 'package:divine_camera/divine_camera.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/content_filters_screen.dart';
import 'package:openvine/screens/settings/account_content_labels_tile.dart';
import 'package:openvine/services/language_preference_service.dart';

class ContentPreferencesScreen extends ConsumerWidget {
  static const routeName = 'content-preferences';
  static const path = '/content-preferences';

  const ContentPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.contentPreferencesTitle,
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
              const _LanguageSetting(),
              ListTile(
                leading: const Icon(
                  Icons.filter_list,
                  color: VineTheme.vineGreen,
                ),
                title: Text(
                  context.l10n.contentPreferencesContentFilters,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  context.l10n.contentPreferencesContentFiltersSubtitle,
                  style: const TextStyle(
                    color: VineTheme.lightText,
                    fontSize: 14,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: VineTheme.lightText,
                ),
                onTap: () => context.push(ContentFiltersScreen.path),
              ),
              const AccountContentLabelsTile(),
              const _AudioSharingToggle(),
              if (!kIsWeb && defaultTargetPlatform != TargetPlatform.linux)
                const _AudioDeviceSelector(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageSetting extends ConsumerStatefulWidget {
  const _LanguageSetting();

  @override
  ConsumerState<_LanguageSetting> createState() => _LanguageSettingState();
}

class _LanguageSettingState extends ConsumerState<_LanguageSetting> {
  @override
  Widget build(BuildContext context) {
    final languageService = ref.watch(languagePreferenceServiceProvider);
    final currentCode = languageService.contentLanguage;
    final isCustom = languageService.isCustomLanguageSet;
    final displayName = LanguagePreferenceService.displayNameFor(currentCode);
    final subtitle = isCustom
        ? displayName
        : context.l10n.contentPreferencesContentLanguageDeviceDefault(
            displayName,
          );

    return ListTile(
      leading: const Icon(Icons.language, color: VineTheme.vineGreen),
      title: Text(
        context.l10n.contentPreferencesContentLanguage,
        style: const TextStyle(
          color: VineTheme.whiteText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: VineTheme.lightText, fontSize: 14),
      ),
      trailing: const Icon(Icons.chevron_right, color: VineTheme.lightText),
      onTap: () => _showLanguagePicker(languageService),
    );
  }

  Future<void> _showLanguagePicker(
    LanguagePreferenceService languageService,
  ) async {
    final currentCode = languageService.contentLanguage;
    final isCustom = languageService.isCustomLanguageSet;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: VineTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.contentPreferencesContentLanguage,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.l10n.contentPreferencesTagYourVideos,
                  style: const TextStyle(
                    color: VineTheme.lightText,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: VineTheme.lightText, height: 1),
              ListTile(
                leading: Icon(
                  !isCustom
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: VineTheme.vineGreen,
                ),
                title: Text(
                  context.l10n.contentPreferencesUseDeviceLanguage,
                  style: const TextStyle(color: VineTheme.whiteText),
                ),
                subtitle: Text(
                  LanguagePreferenceService.displayNameFor(
                    PlatformDispatcher.instance.locale.languageCode,
                  ),
                  style: const TextStyle(
                    color: VineTheme.lightText,
                    fontSize: 12,
                  ),
                ),
                onTap: () async {
                  await languageService.clearContentLanguage();
                  if (context.mounted) {
                    setState(() {});
                    Navigator.pop(context);
                  }
                },
              ),
              const Divider(color: VineTheme.lightText, height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount:
                      LanguagePreferenceService.supportedLanguages.length,
                  itemBuilder: (context, index) {
                    final entry = LanguagePreferenceService
                        .supportedLanguages
                        .entries
                        .elementAt(index);
                    final code = entry.key;
                    final name = entry.value;
                    final isSelected = isCustom && currentCode == code;

                    return ListTile(
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: VineTheme.vineGreen,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(color: VineTheme.whiteText),
                      ),
                      subtitle: Text(
                        code.toUpperCase(),
                        style: const TextStyle(
                          color: VineTheme.lightText,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () async {
                        await languageService.setContentLanguage(code);
                        if (context.mounted) {
                          setState(() {});
                          Navigator.pop(context);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
        style: const TextStyle(
          color: VineTheme.whiteText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        context.l10n.contentPreferencesAudioSharingSubtitle,
        style: const TextStyle(color: VineTheme.lightText, fontSize: 14),
      ),
      activeThumbColor: VineTheme.vineGreen,
      secondary: const Icon(Icons.music_note, color: VineTheme.vineGreen),
    );
  }
}

class _AudioDeviceSelector extends ConsumerStatefulWidget {
  const _AudioDeviceSelector();

  @override
  ConsumerState<_AudioDeviceSelector> createState() =>
      _AudioDeviceSelectorState();
}

class _AudioDeviceSelectorState extends ConsumerState<_AudioDeviceSelector> {
  @override
  Widget build(BuildContext context) {
    final audioDevicePref = ref.watch(audioDevicePreferenceServiceProvider);

    return FutureBuilder<List<AudioDevice>>(
      future: DivineCamera.instance.listAudioDevices(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.length <= 1) {
          return const SizedBox.shrink();
        }

        final devices = snapshot.data!;
        final currentDevice = audioDevicePref.preferredDeviceId;

        String currentDisplayName;
        if (currentDevice == null) {
          currentDisplayName = context.l10n.contentPreferencesAutoRecommended;
        } else {
          final device = devices.where((d) => d.id == currentDevice);
          currentDisplayName = device.isNotEmpty
              ? _formatAudioDeviceName(device.first.name)
              : context.l10n.contentPreferencesAutoRecommended;
        }

        return ListTile(
          leading: const Icon(Icons.mic, color: VineTheme.vineGreen),
          title: Text(
            context.l10n.contentPreferencesAudioInputDevice,
            style: const TextStyle(
              color: VineTheme.whiteText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            currentDisplayName,
            style: const TextStyle(color: VineTheme.lightText, fontSize: 14),
          ),
          trailing: const Icon(Icons.chevron_right, color: VineTheme.lightText),
          onTap: () => _showAudioDevicePicker(devices, currentDevice),
        );
      },
    );
  }

  String _formatAudioDeviceName(String name) {
    if (name.isEmpty) return context.l10n.contentPreferencesUnknownMicrophone;
    return name;
  }

  Future<void> _showAudioDevicePicker(
    List<AudioDevice> devices,
    String? currentDevice,
  ) async {
    final audioDevicePref = ref.read(audioDevicePreferenceServiceProvider);

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
                context.l10n.contentPreferencesSelectAudioInput,
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: VineTheme.lightText, height: 1),
            ListTile(
              leading: Icon(
                currentDevice == null
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: VineTheme.vineGreen,
              ),
              title: Text(
                context.l10n.contentPreferencesAutoRecommended,
                style: const TextStyle(color: VineTheme.whiteText),
              ),
              subtitle: Text(
                context.l10n.contentPreferencesAutoSelectsBest,
                style: const TextStyle(
                  color: VineTheme.lightText,
                  fontSize: 12,
                ),
              ),
              onTap: () async {
                await audioDevicePref.setPreferredDeviceId(null);
                if (context.mounted) {
                  setState(() {});
                  Navigator.pop(context);
                }
              },
            ),
            const Divider(color: VineTheme.lightText, height: 1),
            ...devices.map(
              (device) => ListTile(
                leading: Icon(
                  currentDevice == device.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: VineTheme.vineGreen,
                ),
                title: Text(
                  _formatAudioDeviceName(device.name),
                  style: const TextStyle(color: VineTheme.whiteText),
                ),
                subtitle: Text(
                  device.id,
                  style: const TextStyle(
                    color: VineTheme.lightText,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () async {
                  await audioDevicePref.setPreferredDeviceId(device.id);
                  if (context.mounted) {
                    setState(() {});
                    Navigator.pop(context);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
