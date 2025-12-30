// ABOUTME: App-level LikesBloc provider wrapper
// ABOUTME: Provides LikesBloc to entire app using repository from Riverpod

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:openvine/blocs/likes/likes_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Provides [LikesBloc] to the entire widget tree.
///
/// This widget bridges Riverpod (for repository) and BLoC (for state management).
/// It watches the [likesRepositoryProvider] and creates/updates the BLoC
/// accordingly.
///
/// When the user is not authenticated, no BLoC is provided and descendants
/// should handle the absence of the BLoC gracefully.
class AppLikesBlocProvider extends ConsumerStatefulWidget {
  const AppLikesBlocProvider({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLikesBlocProvider> createState() =>
      _AppLikesBlocProviderState();
}

class _AppLikesBlocProviderState extends ConsumerState<AppLikesBlocProvider> {
  LikesBloc? _bloc;
  LikesRepository? _currentRepository;

  @override
  void dispose() {
    _bloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final likesRepository = ref.watch(likesRepositoryProvider);

    // If not authenticated, pass through without BLoC
    if (likesRepository == null) {
      Log.debug(
        'AppLikesBlocProvider: No repository (user not authenticated)',
        name: 'AppLikesBlocProvider',
        category: LogCategory.system,
      );
      // Close existing bloc if user logged out
      _bloc?.close();
      _bloc = null;
      _currentRepository = null;
      return widget.child;
    }

    // Create or recreate BLoC when repository changes
    if (_bloc == null || _currentRepository != likesRepository) {
      Log.info(
        'AppLikesBlocProvider: Creating LikesBloc '
        '(new=${_bloc == null}, repoChanged=${_currentRepository != likesRepository})',
        name: 'AppLikesBlocProvider',
        category: LogCategory.system,
      );
      _bloc?.close();
      _currentRepository = likesRepository;
      _bloc = LikesBloc(likesRepository: likesRepository)
        ..add(const LikesSyncRequested());
    }

    return BlocProvider<LikesBloc>.value(value: _bloc!, child: widget.child);
  }
}
