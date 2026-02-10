// ABOUTME: Loader widget for sound detail screen
// ABOUTME: Fetches sound by ID before displaying SoundDetailScreen

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';

/// Loader widget that fetches a sound by ID before displaying SoundDetailScreen.
/// Used when navigating via deep link without the sound object.
class SoundDetailLoader extends ConsumerWidget {
  const SoundDetailLoader({super.key, required this.soundId});

  final String soundId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundAsync = ref.watch(soundByIdProvider(soundId));

    return soundAsync.when(
      data: (sound) {
        if (sound == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: const Text('Sound Not Found'),
            ),
            body: const Center(
              child: Text(
                'This sound could not be found',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }
        return SoundDetailScreen(sound: sound);
      },
      loading: () => const BrandedLoadingScaffold(),
      error: (error, stack) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('Error'),
        ),
        body: Center(
          child: Text(
            'Failed to load sound: $error',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
