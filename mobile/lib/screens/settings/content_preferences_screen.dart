// ABOUTME: Content preferences screen for language, audio sharing, and content filters
// ABOUTME: Composes three small Cubits (one per independent sub-setting).

import 'dart:ui';

import 'package:divine_camera/divine_camera.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/audio_device/audio_device_cubit.dart';
import 'package:openvine/blocs/audio_sharing/audio_sharing_cubit.dart';
import 'package:openvine/blocs/language_setting/language_setting_cubit.dart';
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
              const _ContentFiltersTile(),
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

class _ContentFiltersTile extends StatelessWidget {
  const _ContentFiltersTile();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const DivineIcon(
        icon: DivineIconName.funnelSimple,
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
        style: const TextStyle(color: VineTheme.lightText, fontSize: 14),
      ),
      trailing: const DivineIcon(
        icon: DivineIconName.caretRight,
        color: VineTheme.lightText,
      ),
      onTap: () => context.push(ContentFiltersScreen.path),
    );
  }
}

class _LanguageSetting extends ConsumerWidget {
  const _LanguageSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(languagePreferenceServiceProvider);
    return BlocProvider(
      key: ValueKey(service),
      create: (_) => LanguageSettingCubit(service: service)..load(),
      child: const _LanguageSettingTile(),
    );
  }
}

class _LanguageSettingTile extends StatelessWidget {
  const _LanguageSettingTile();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LanguageSettingCubit>().state;
    final currentCode = state.currentCode;
    final isCustom = state.isCustomLanguageSet;
    final displayName = LanguagePreferenceService.displayNameFor(currentCode);
    final subtitle = isCustom
        ? displayName
        : context.l10n.contentPreferencesContentLanguageDeviceDefault(
            displayName,
          );

    return ListTile(
      leading: const DivineIcon(
        icon: DivineIconName.globe,
        color: VineTheme.vineGreen,
      ),
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
      trailing: const DivineIcon(
        icon: DivineIconName.caretRight,
        color: VineTheme.lightText,
      ),
      onTap: () => _showLanguagePicker(context),
    );
  }

  Future<void> _showLanguagePicker(BuildContext context) async {
    final cubit = context.read<LanguageSettingCubit>();
    final state = cubit.state;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: VineTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => SafeArea(
          child: _LanguagePickerContent(
            scrollController: scrollController,
            currentCode: state.currentCode,
            isCustomLanguageSet: state.isCustomLanguageSet,
            onUseDeviceLanguage: () async {
              await cubit.clearLanguage();
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            },
            onSelectLanguage: (code) async {
              await cubit.setLanguage(code);
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            },
          ),
        ),
      ),
    );
  }
}

class _LanguagePickerContent extends StatelessWidget {
  const _LanguagePickerContent({
    required this.scrollController,
    required this.currentCode,
    required this.isCustomLanguageSet,
    required this.onUseDeviceLanguage,
    required this.onSelectLanguage,
  });

  final ScrollController scrollController;
  final String currentCode;
  final bool isCustomLanguageSet;
  final VoidCallback onUseDeviceLanguage;
  final ValueChanged<String> onSelectLanguage;

  @override
  Widget build(BuildContext context) {
    return Column(
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
            style: const TextStyle(color: VineTheme.lightText, fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: VineTheme.lightText, height: 1),
        ListTile(
          leading: Icon(
            !isCustomLanguageSet
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
            style: const TextStyle(color: VineTheme.lightText, fontSize: 12),
          ),
          onTap: onUseDeviceLanguage,
        ),
        const Divider(color: VineTheme.lightText, height: 1),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: LanguagePreferenceService.supportedLanguages.length,
            itemBuilder: (context, index) {
              final entry = LanguagePreferenceService.supportedLanguages.entries
                  .elementAt(index);
              final code = entry.key;
              final name = entry.value;
              final isSelected = isCustomLanguageSet && currentCode == code;

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
                onTap: () => onSelectLanguage(code),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AudioSharingToggle extends ConsumerWidget {
  const _AudioSharingToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(audioSharingPreferenceServiceProvider);
    return BlocProvider(
      key: ValueKey(service),
      create: (_) => AudioSharingCubit(service: service)..load(),
      child: const _AudioSharingToggleTile(),
    );
  }
}

class _AudioSharingToggleTile extends StatelessWidget {
  const _AudioSharingToggleTile();

  @override
  Widget build(BuildContext context) {
    final isEnabled = context.select(
      (AudioSharingCubit cubit) => cubit.state.isEnabled,
    );
    return SwitchListTile(
      value: isEnabled,
      onChanged: (value) => context.read<AudioSharingCubit>().setEnabled(value),
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
      secondary: const DivineIcon(
        icon: DivineIconName.musicNote,
        color: VineTheme.vineGreen,
      ),
    );
  }
}

class _AudioDeviceSelector extends ConsumerWidget {
  const _AudioDeviceSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(audioDevicePreferenceServiceProvider);
    return BlocProvider(
      key: ValueKey(service),
      create: (_) => AudioDeviceCubit(service: service)..load(),
      child: const _AudioDeviceSelectorTile(),
    );
  }
}

class _AudioDeviceSelectorTile extends StatelessWidget {
  const _AudioDeviceSelectorTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AudioDevice>>(
      future: DivineCamera.instance.listAudioDevices(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.length <= 1) {
          return const SizedBox.shrink();
        }
        final devices = snapshot.data!;
        final currentDeviceId = context.select(
          (AudioDeviceCubit cubit) => cubit.state.currentDeviceId,
        );
        final currentDisplayName = _resolveCurrentDisplayName(
          context,
          devices: devices,
          currentDeviceId: currentDeviceId,
        );

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
          trailing: const DivineIcon(
            icon: DivineIconName.caretRight,
            color: VineTheme.lightText,
          ),
          onTap: () => _showAudioDevicePicker(
            context,
            devices: devices,
            currentDeviceId: currentDeviceId,
          ),
        );
      },
    );
  }

  String _resolveCurrentDisplayName(
    BuildContext context, {
    required List<AudioDevice> devices,
    required String? currentDeviceId,
  }) {
    if (currentDeviceId == null) {
      return context.l10n.contentPreferencesAutoRecommended;
    }
    final match = devices.where((d) => d.id == currentDeviceId);
    if (match.isEmpty) {
      return context.l10n.contentPreferencesAutoRecommended;
    }
    return _formatAudioDeviceName(context, match.first.name);
  }

  Future<void> _showAudioDevicePicker(
    BuildContext context, {
    required List<AudioDevice> devices,
    required String? currentDeviceId,
  }) async {
    final cubit = context.read<AudioDeviceCubit>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: VineTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: _AudioDevicePickerContent(
          devices: devices,
          currentDeviceId: currentDeviceId,
          onUseAuto: () async {
            await cubit.setDeviceId(null);
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          },
          onSelectDevice: (deviceId) async {
            await cubit.setDeviceId(deviceId);
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          },
        ),
      ),
    );
  }
}

class _AudioDevicePickerContent extends StatelessWidget {
  const _AudioDevicePickerContent({
    required this.devices,
    required this.currentDeviceId,
    required this.onUseAuto,
    required this.onSelectDevice,
  });

  final List<AudioDevice> devices;
  final String? currentDeviceId;
  final VoidCallback onUseAuto;
  final ValueChanged<String> onSelectDevice;

  @override
  Widget build(BuildContext context) {
    return Column(
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
            currentDeviceId == null
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
            style: const TextStyle(color: VineTheme.lightText, fontSize: 12),
          ),
          onTap: onUseAuto,
        ),
        const Divider(color: VineTheme.lightText, height: 1),
        ...devices.map(
          (device) => ListTile(
            leading: Icon(
              currentDeviceId == device.id
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: VineTheme.vineGreen,
            ),
            title: Text(
              _formatAudioDeviceName(context, device.name),
              style: const TextStyle(color: VineTheme.whiteText),
            ),
            subtitle: Text(
              device.id,
              style: const TextStyle(color: VineTheme.lightText, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onSelectDevice(device.id),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

String _formatAudioDeviceName(BuildContext context, String name) {
  if (name.isEmpty) return context.l10n.contentPreferencesUnknownMicrophone;
  return name;
}
