import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/appearance/bloc/appearance_cubit.dart';
import 'package:openvine/features/appearance/repositories/appearance_repository.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';

final appearanceRepositoryProvider = Provider<AppearanceRepository>((ref) {
  return AppearanceRepository(ref.watch(sharedPreferencesProvider));
});

final appearanceCubitProvider = Provider<AppearanceCubit>((ref) {
  final cubit = AppearanceCubit(ref.watch(appearanceRepositoryProvider));
  ref.onDispose(cubit.close);
  unawaited(cubit.load());
  return cubit;
});
