import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/go_live/go_live_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/live_providers.dart';
import 'package:openvine/screens/live/go_live_view.dart';

class GoLivePage extends ConsumerWidget {
  const GoLivePage({super.key});

  static const String routeName = 'goLive';
  static const String path = '/live/go';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserPubkey =
        ref.watch(authServiceProvider).currentPublicKeyHex ?? '';

    return BlocProvider(
      create: (_) => GoLiveCubit(
        liveApiService: ref.watch(liveApiServiceProvider),
        liveRepository: ref.watch(liveRepositoryProvider),
        currentUserPubkey: currentUserPubkey,
      ),
      child: const GoLiveView(),
    );
  }
}
