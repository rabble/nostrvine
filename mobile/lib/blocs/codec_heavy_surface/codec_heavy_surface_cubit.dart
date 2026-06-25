// ABOUTME: Tracks whether a codec-heavy surface (camera/editor/exporter) is open
// ABOUTME: so background video feeds release every hardware decoder they hold.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'codec_heavy_surface_state.dart';

/// Tracks whether a codec-heavy surface — the camera, the video editor, or the
/// exporter — is currently on screen.
///
/// These surfaces need exclusive access to the device's scarce hardware video
/// codecs (decoder + encoder). Video feeds that stay mounted in the background
/// (e.g. the home feed inside a `StatefulShellRoute`) keep their *current*
/// player warm across tab switches for instant resume, but must hand back every
/// native decoder while one of these surfaces is open — otherwise the editor's
/// decode/encode init fails on codec-limited devices (observed as
/// `DECODER_INIT_FAILED` on the preview and an encoder `RENDER_ERROR` on
/// export).
///
/// Reference-counted via [CodecHeavySurfaceState.activeCount] so nested
/// codec-heavy routes (e.g. an export/metadata screen pushed over the editor)
/// keep the signal asserted until the last one leaves. Call [enter] from
/// `initState` and [exit] from `dispose` of each such screen.
class CodecHeavySurfaceCubit extends Cubit<CodecHeavySurfaceState> {
  CodecHeavySurfaceCubit() : super(const CodecHeavySurfaceState());

  /// Registers a codec-heavy surface as visible. Safe to call from `initState`.
  void enter() =>
      emit(CodecHeavySurfaceState(activeCount: state.activeCount + 1));

  /// Registers a codec-heavy surface as gone. Safe to call from `dispose`.
  void exit() => emit(
    CodecHeavySurfaceState(
      activeCount: state.activeCount > 0 ? state.activeCount - 1 : 0,
    ),
  );
}
