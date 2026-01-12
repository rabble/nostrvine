// ABOUTME: BLoC for managing current user's video count

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:videos_repository/videos_repository.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'my_videos_count_event.dart';
part 'my_videos_count_state.dart';

/// BLoC for managing the current user's video count.
class MyVideosCountBloc extends Bloc<MyVideosCountEvent, MyVideosCountState> {
  MyVideosCountBloc({required VideosRepository videosRepository})
    : _videosRepository = videosRepository,
      super(const MyVideosCountState()) {
    on<MyVideosCountStarted>(_onStarted);
  }

  final VideosRepository _videosRepository;

  /// Start listening to video count updates from the repository stream.
  Future<void> _onStarted(
    MyVideosCountStarted event,
    Emitter<MyVideosCountState> emit,
  ) async {
    await emit.forEach<int>(
      _videosRepository.myVideoCountStream,
      onData: (count) {
        Log.debug(
          'MyVideosCountBloc: Count updated to $count',
          name: 'MyVideosCountBloc',
          category: LogCategory.video,
        );
        return state.copyWith(
          status: MyVideosCountStatus.success,
          count: count,
        );
      },
      onError: (error, stackTrace) {
        Log.error(
          'MyVideosCountBloc: Stream error: $error',
          name: 'MyVideosCountBloc',
          category: LogCategory.video,
        );
        return state.copyWith(status: MyVideosCountStatus.failure);
      },
    );
  }
}
