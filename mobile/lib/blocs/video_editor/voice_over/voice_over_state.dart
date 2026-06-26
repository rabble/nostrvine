part of 'voice_over_cubit.dart';

/// Lifecycle of the voice-over recorder.
enum VoiceOverStatus {
  /// Not recording. Ready to start a take.
  idle,

  /// Microphone permission was denied; the user must enable it in settings.
  permissionDenied,

  /// A take is currently being recorded.
  recording,

  /// An unexpected error occurred while starting or stopping a recording.
  error,
}

/// State for the voice-over recorder.
///
/// Holds the completed [takes], the elapsed [currentDuration] of the
/// in-progress recording, and a rolling [waveformBars] buffer used to draw the
/// live amplitude waveform. Per the project's state rules, no error strings or
/// exception objects live here — failures are surfaced via [status] and
/// reported through `addError`.
class VoiceOverState extends Equatable {
  /// Creates a voice-over state.
  const VoiceOverState({
    this.status = VoiceOverStatus.idle,
    this.takes = const [],
    this.currentDuration = Duration.zero,
    this.waveformBars = const [],
    this.availableDuration = Duration.zero,
    this.priorTakeCount = 0,
  });

  /// Current recorder lifecycle status.
  final VoiceOverStatus status;

  /// Completed recordings, in the order they were captured.
  final List<AudioEvent> takes;

  /// Elapsed duration of the in-progress recording.
  final Duration currentDuration;

  /// Rolling buffer of normalized (`0.0`–`1.0`) amplitude samples for the
  /// live waveform. Empty while idle.
  final List<double> waveformBars;

  /// Length of the video the voice-over will be laid over. Used to warn the
  /// user when the recorded audio exceeds the available room.
  final Duration availableDuration;

  /// Number of voice-over takes already on the editor timeline when this
  /// session opened. Only used to continue the take numbering — it is not
  /// counted in [recordingCount] or [totalRecordedDuration], which always
  /// reflect just this session.
  final int priorTakeCount;

  /// Whether a take is currently being recorded.
  bool get isRecording => status == VoiceOverStatus.recording;

  /// Number of recordings captured in this session.
  int get recordingCount => takes.length;

  /// Whether at least one take has been recorded in this session.
  bool get hasTakes => takes.isNotEmpty;

  /// 1-based number for the next take, continuing past takes already on the
  /// timeline so titles read "Recording 5", "Recording 6", …
  int get nextTakeNumber => priorTakeCount + takes.length + 1;

  /// Combined length of this session's completed takes plus the in-progress
  /// recording. Starts at zero each time the recorder is opened.
  Duration get totalRecordedDuration {
    var total = currentDuration;
    for (final take in takes) {
      total += Duration(milliseconds: ((take.duration ?? 0) * 1000).round());
    }
    return total;
  }

  /// Whether the recorded audio is longer than the available video room.
  bool get isOverAvailable =>
      availableDuration > Duration.zero &&
      totalRecordedDuration > availableDuration;

  /// Creates a copy with the given fields replaced.
  VoiceOverState copyWith({
    VoiceOverStatus? status,
    List<AudioEvent>? takes,
    Duration? currentDuration,
    List<double>? waveformBars,
    Duration? availableDuration,
    int? priorTakeCount,
  }) {
    return VoiceOverState(
      status: status ?? this.status,
      takes: takes ?? this.takes,
      currentDuration: currentDuration ?? this.currentDuration,
      waveformBars: waveformBars ?? this.waveformBars,
      availableDuration: availableDuration ?? this.availableDuration,
      priorTakeCount: priorTakeCount ?? this.priorTakeCount,
    );
  }

  @override
  List<Object?> get props => [
    status,
    takes,
    currentDuration,
    waveformBars,
    availableDuration,
    priorTakeCount,
  ];
}
