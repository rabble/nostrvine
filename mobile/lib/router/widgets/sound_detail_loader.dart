// ABOUTME: Loader widget for sound detail screen
// ABOUTME: Fetches sound by ID before displaying SoundDetailScreen

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';

/// Loader widget that fetches a sound by ID before displaying SoundDetailScreen.
/// Used when navigating via deep link without the sound object.
class SoundDetailLoader extends ConsumerWidget {
  const SoundDetailLoader({required this.soundId, super.key});

  final String soundId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundAsync = ref.watch(soundByIdProvider(soundId));

    return soundAsync.when(
      data: (sound) {
        if (sound == null) {
          return Scaffold(
            backgroundColor: VineTheme.backgroundColor,
            appBar: DiVineAppBar(title: context.l10n.soundDetailNotFoundTitle),
            body: Center(
              child: Text(
                context.l10n.soundDetailNotFoundMessage,
                style: const TextStyle(color: VineTheme.whiteText),
              ),
            ),
          );
        }
        return SoundDetailScreen(sound: sound);
      },
      loading: () => const BrandedLoadingScaffold(),
      error: (error, stack) => Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        appBar: DiVineAppBar(title: context.l10n.featureFlagError),
        body: Center(
          child: Text(
            context.l10n.soundDetailLoadError(error.toString()),
            style: const TextStyle(color: VineTheme.whiteText),
          ),
        ),
      ),
    );
  }
}
