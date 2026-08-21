import 'dart:io';

import 'package:divine_video_player/src/video_clip.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// Debug-only source swap that makes the feed play a known clip, so a loop
/// seam can be compared against the `perfect_loop` prototype instead of
/// against whatever the feed happened to scroll to.
///
/// Two fixtures are bundled:
///
///  * [LoopSeamProbeVariant.vine] is the exact video of the prototype's
///    `editfix + audio xfade` variant -- the one that loops flawlessly there.
///    It is the file-or-app test: if it stutters here, the file is exonerated.
///  * [LoopSeamProbeVariant.fixed] is divine's own CDN clip with its container
///    corrected (empty video edit dropped, `mvhd` and the audio edit clamped to
///    where the picture ends). Its `mdat` is byte-identical to what the CDN
///    serves.
///
/// The app never hands the player a CDN URL -- it downloads into
/// `openvine_video_cache` and plays a file path -- so matching on the URL alone
/// missed most plays. The probe therefore replaces every clip, and puts the
/// resolved source on screen, because a test that depends on trusting the
/// tester is not a test.
enum LoopSeamProbeVariant {
  /// The prototype's flawless clip.
  vine('vine'),

  /// Divine's CDN clip, container corrected.
  fixed('fixed'),

  /// The same clip with a 90-degree display matrix.
  ///
  /// Proves the rotation guard: a rotated track must fall back to the
  /// composition, because the direct path hands the pixel buffer over as
  /// decoded and would show it on its side.
  rotated('rotated'),

  /// The reference clip with its audio track removed.
  ///
  /// Isolates ExoPlayer's audio path: as long as a media item carries audio,
  /// media3 drains and re-anchors its audio sink at every loop discontinuity,
  /// on the same thread that releases video frames.
  vineNoAudio('vinenoaudio'),

  /// Show the perfect_loop prototype's own player instead of ours.
  prototype('prototype'),

  /// Show our own player alone on the same bare screen.
  bare('bare'),

  /// Play the real source, but still label it.
  observe('observe'),

  /// Leave every source alone, and show nothing.
  off('off');

  const LoopSeamProbeVariant(this.flag);

  /// Value accepted by the `LOOP_SEAM_PROBE` define.
  final String flag;

  static LoopSeamProbeVariant _parse(String value) {
    for (final variant in LoopSeamProbeVariant.values) {
      if (variant.flag == value) return variant;
    }
    return LoopSeamProbeVariant.off;
  }
}

/// Substitutes a bundled fixture for the clips the app is about to play.
abstract final class LoopSeamProbe {
  /// Bumped per test build so the banner names the run on screen.
  static const testNumber = 27;

  static const _assetRoot =
      'packages/divine_video_player/assets/loop_seam_probe';

  /// Selected by `--dart-define=LOOP_SEAM_PROBE=`
  /// `vine|vinenoaudio|fixed|rotated|prototype|bare|observe|off`.
  static final LoopSeamProbeVariant variant = LoopSeamProbeVariant._parse(
    const String.fromEnvironment('LOOP_SEAM_PROBE', defaultValue: 'off'),
  );

  /// Replace every clip, not just one known video. See the class docs.
  static const substituteEveryVideo = true;

  static final Map<String, Future<String>> _extracted = {};

  /// Whether the picture comes from the prototype's player instead of ours.
  static bool get usesPrototypePlayer =>
      kDebugMode && variant == LoopSeamProbeVariant.prototype;

  /// Whether to show our own player alone on a bare screen.
  static bool get usesBarePlayer =>
      kDebugMode && variant == LoopSeamProbeVariant.bare;

  /// Whether the probe swaps the source.
  static bool get substitutes =>
      kDebugMode && variant != LoopSeamProbeVariant.off;

  /// Whether the overlay is shown.
  ///
  /// Independent of [substitutes] so that `observe` labels the real source:
  /// without that, a missing overlay is ambiguous between "not substituted"
  /// and "overlay broken", and both happened during this investigation. Off by
  /// default, because a debug default that rewrites every video is a trap, and
  /// because widget tests pin the player's tree.
  static bool get isActive => kDebugMode && variant != LoopSeamProbeVariant.off;

  /// Rewrites the clips to the selected fixture.
  ///
  /// The label names what this player really got -- the fixture or the real
  /// source. It is per call, so the overlay marks the individual player rather
  /// than every player on screen, and it is never null while the probe is on:
  /// a missing overlay then means the overlay itself is broken, which is a
  /// different problem from "the fixture did not help".
  static Future<({List<VideoClip> clips, String? label})> apply(
    List<VideoClip> clips,
  ) async {
    if (!isActive) return (clips: clips, label: null);
    // Ein fehlendes Overlay waere mehrdeutig -- nicht ersetzt, oder Overlay
    // kaputt. Deshalb meldet der Probe auch die *echte* Quelle.
    String real() => 'T$testNumber  ·  ECHT  ·  ${_name(clips)}';
    if (!substitutes) return (clips: clips, label: real());
    final asset = switch (variant) {
      LoopSeamProbeVariant.vine => 'loop_editfix_a0.mp4',
      LoopSeamProbeVariant.fixed => 'divine_cdn_fixed.mp4',
      LoopSeamProbeVariant.rotated => 'loop_rotated.mp4',
      LoopSeamProbeVariant.vineNoAudio => 'loop_vine_noaudio.mp4',
      LoopSeamProbeVariant.prototype => 'loop_editfix_a0.mp4',
      LoopSeamProbeVariant.bare => 'loop_editfix_a0.mp4',
      LoopSeamProbeVariant.observe => null,
      LoopSeamProbeVariant.off => null,
    };
    if (asset == null) return (clips: clips, label: real());

    final String path;
    try {
      final pending = _extracted[asset] ?? _extract(asset);
      _extracted[asset] = pending;
      path = await pending;
    } on Object catch (error) {
      // Drop the failed attempt so a later clip can retry the extraction.
      _extracted.removeWhere((key, _) => key == asset);
      Log.error(
        'Loop-seam probe could not extract $asset: $error',
        name: 'LoopSeamProbe',
        category: LogCategory.video,
      );
      return (clips: clips, label: real());
    }

    return (
      clips: [for (final clip in clips) _substitute(clip, path)],
      label: 'T$testNumber  ·  FIXTURE  ·  $asset',
    );
  }

  static String _name(List<VideoClip> clips) {
    final uri = clips.isEmpty ? '' : clips.first.uri;
    return uri.startsWith('http')
        ? Uri.tryParse(uri)?.host ?? uri
        : uri.split('/').last;
  }

  static VideoClip _substitute(VideoClip clip, String path) {
    Log.warning(
      'Loop-seam probe active: serving ${variant.flag} fixture instead of '
      '${clip.uri}',
      name: 'LoopSeamProbe',
      category: LogCategory.video,
    );
    return VideoClip.file(
      path,
      start: clip.start,
      end: clip.end,
      volume: clip.volume,
      playbackSpeed: clip.playbackSpeed,
      trimToCommonTrackEnd: clip.trimToCommonTrackEnd,
    );
  }

  /// Copies a bundled fixture to a real file, because the native players
  /// cannot read out of the Flutter asset bundle.
  static Future<String> _extract(String asset) async {
    final (data, dir) = await (
      rootBundle.load('$_assetRoot/$asset'),
      getTemporaryDirectory(),
    ).wait;
    final file = File('${dir.path}/loop_seam_probe/$asset');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file.path;
  }
}
