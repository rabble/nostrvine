// ABOUTME: Cubit driving the video editor's voice-over recorder.
// ABOUTME: Gates the mic permission, captures takes, and feeds the waveform.

import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/services/video_editor/voice_over_recorder_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permissions_service/permissions_service.dart';

part 'voice_over_state.dart';

/// Manages recording one or more voice-over takes without leaving the screen.
///
/// Each completed take is stored as a draft-local [AudioEvent] (via
/// [AudioEvent.fromLocalImport]); the screen commits them to the editor
/// timeline when the user taps Done. Recording is gated behind a microphone
/// permission check using the injected [PermissionsService].
class VoiceOverCubit extends Cubit<VoiceOverState> {
  /// Creates a [VoiceOverCubit].
  ///
  /// [takeTitleBuilder] returns the localized title for a take given its
  /// 1-based number (resolved by the UI so this layer stays l10n-free), e.g.
  /// "Recording 1". [availableDuration] is the length of the video the
  /// voice-over will be laid over, used to warn when the recording runs too
  /// long. A [storageDirectoryProvider] can be injected for testing; it
  /// defaults to a `voice_over_recordings` folder under the app documents
  /// directory.
  VoiceOverCubit({
    required VoiceOverRecorderService recorder,
    required PermissionsService permissionsService,
    required String Function(int takeNumber) takeTitleBuilder,
    Duration availableDuration = Duration.zero,
    int priorTakeCount = 0,
    Future<Directory> Function()? storageDirectoryProvider,
  }) : _recorder = recorder,
       _permissionsService = permissionsService,
       _takeTitleBuilder = takeTitleBuilder,
       _storageDirectoryProvider =
           storageDirectoryProvider ?? _defaultStorageDirectory,
       super(
         VoiceOverState(
           availableDuration: availableDuration,
           priorTakeCount: priorTakeCount,
         ),
       );

  /// Id prefix shared by every voice-over take, so the editor can later
  /// recognise prior voice-over tracks among all audio on the timeline.
  static const voiceOverIdPrefix = '${AudioEvent.localImportMarker}_voice_over';

  final VoiceOverRecorderService _recorder;
  final PermissionsService _permissionsService;
  final String Function(int takeNumber) _takeTitleBuilder;
  final Future<Directory> Function() _storageDirectoryProvider;

  StreamSubscription<double>? _amplitudeSubscription;
  String? _currentPath;

  /// Maximum number of amplitude bars retained for the live waveform.
  ///
  /// Kept well above the bar count any phone width can show (the painter draws
  /// a few-px bar per sample and clips the overflow on the left) so the strip
  /// always fills the full width instead of leaving an empty band.
  static const _maxWaveformBars = 256;

  /// The interval between amplitude samples emitted by the recorder. The
  /// elapsed recording time is advanced by this amount on each sample, so it
  /// must stay in sync with the recorder service's reporting interval.
  static const _amplitudeInterval = Duration(milliseconds: 100);

  /// Toggles recording: stops the current take or starts a new one.
  Future<void> toggleRecording() =>
      state.isRecording ? stop() : requestPermissionAndStart();

  /// Requests microphone permission if needed, then starts a new take.
  ///
  /// Emits [VoiceOverStatus.permissionDenied] when the user declines.
  Future<void> requestPermissionAndStart() async {
    if (state.isRecording) return;
    try {
      var status = await _permissionsService.checkMicrophoneStatus();
      if (status == PermissionStatus.canRequest) {
        status = await _permissionsService.requestMicrophonePermission();
      }
      if (status != PermissionStatus.granted) {
        emit(state.copyWith(status: VoiceOverStatus.permissionDenied));
        return;
      }
      await _start();
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: VoiceOverStatus.error));
    }
  }

  /// Opens the OS app-settings page so the user can grant microphone access
  /// after a permanent denial.
  Future<void> openSettings() => _permissionsService.openAppSettings();

  Future<void> _start() async {
    final directory = await _storageDirectoryProvider();
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    final path = p.join(
      directory.path,
      'voice_over_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    _currentPath = path;
    await _recorder.start(path);

    emit(
      state.copyWith(
        status: VoiceOverStatus.recording,
        currentDuration: Duration.zero,
        waveformBars: const [],
      ),
    );

    _amplitudeSubscription = _recorder.amplitudeStream.listen(_onAmplitude);
  }

  void _onAmplitude(double amplitude) {
    if (!state.isRecording) return;
    final bars = [...state.waveformBars, amplitude];
    if (bars.length > _maxWaveformBars) {
      bars.removeRange(0, bars.length - _maxWaveformBars);
    }
    emit(
      state.copyWith(
        waveformBars: bars,
        currentDuration: state.currentDuration + _amplitudeInterval,
      ),
    );
  }

  /// Stops the in-progress take and appends it to [VoiceOverState.takes].
  ///
  /// A take with zero duration is discarded.
  Future<void> stop() async {
    if (!state.isRecording) return;
    await _stopMetering();

    try {
      final path = await _recorder.stop() ?? _currentPath;
      final duration = state.currentDuration;
      _currentPath = null;

      if (path == null || duration <= Duration.zero) {
        emit(
          state.copyWith(
            status: VoiceOverStatus.idle,
            currentDuration: Duration.zero,
            waveformBars: const [],
          ),
        );
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final take = AudioEvent.fromLocalImport(
        id: '${voiceOverIdPrefix}_$now',
        filePath: path,
        createdAt: now ~/ 1000,
        title: _takeTitleBuilder(state.nextTakeNumber),
        mimeType: 'audio/mp4',
        duration: duration.inMilliseconds / 1000,
      );

      emit(
        state.copyWith(
          status: VoiceOverStatus.idle,
          takes: [...state.takes, take],
          currentDuration: Duration.zero,
          waveformBars: const [],
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: VoiceOverStatus.error));
    }
  }

  /// Removes the most recently recorded take and deletes its file.
  ///
  /// No-op while recording or when there are no takes.
  Future<void> deleteLastTake() async {
    if (state.isRecording || state.takes.isEmpty) return;
    final takes = state.takes;
    await _deleteFile(takes.last.localFilePath);
    emit(state.copyWith(takes: takes.sublist(0, takes.length - 1)));
  }

  /// Discards every recorded take (deleting their files) and resets to idle.
  ///
  /// Stops any in-progress recording first. Used by the close action, whose
  /// recordings are never committed to the timeline.
  Future<void> discardAll() async {
    if (state.isRecording) {
      await _stopMetering();
      await _safeStopRecorder();
    }
    await _deleteTakeFiles(state.takes);
    if (_currentPath != null) {
      await _deleteFile(_currentPath);
      _currentPath = null;
    }
    emit(const VoiceOverState());
  }

  Future<void> _stopMetering() async {
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
  }

  Future<void> _safeStopRecorder() async {
    try {
      await _recorder.stop();
    } catch (e, stackTrace) {
      addError(e, stackTrace);
    }
  }

  Future<void> _deleteTakeFiles(List<AudioEvent> takes) async {
    for (final take in takes) {
      await _deleteFile(take.localFilePath);
    }
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (!file.existsSync()) return;
    try {
      await file.delete();
    } catch (e, stackTrace) {
      addError(e, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    await _stopMetering();
    await _recorder.dispose();
    return super.close();
  }

  static Future<Directory> _defaultStorageDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'voice_over_recordings'));
  }
}
