// ABOUTME: Progress bottom sheet for watermark video download
// ABOUTME: Shows downloading -> watermarking -> saving stages with completion actions

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/watermark_download_provider.dart';
import 'package:openvine/services/watermark_download_service.dart';
import 'package:share_plus/share_plus.dart';

/// Shows a bottom sheet that tracks watermark download progress.
///
/// Call this to start the watermark download flow. The sheet displays
/// progress through downloading, watermarking, and saving stages.
Future<void> showWatermarkDownloadSheet({
  required BuildContext context,
  required WidgetRef ref,
  required VideoEvent video,
  required String username,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: VineTheme.surfaceBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(VineTheme.bottomSheetBorderRadius),
      ),
    ),
    builder: (sheetContext) => _WatermarkDownloadProgressSheet(
      video: video,
      username: username,
      ref: ref,
    ),
  );
}

class _WatermarkDownloadProgressSheet extends StatefulWidget {
  const _WatermarkDownloadProgressSheet({
    required this.video,
    required this.username,
    required this.ref,
  });

  final VideoEvent video;
  final String username;
  final WidgetRef ref;

  @override
  State<_WatermarkDownloadProgressSheet> createState() =>
      _WatermarkDownloadProgressSheetState();
}

class _WatermarkDownloadProgressSheetState
    extends State<_WatermarkDownloadProgressSheet> {
  WatermarkDownloadStage _stage = WatermarkDownloadStage.downloading;
  WatermarkDownloadResult? _result;
  bool _isProcessing = true;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    final service = widget.ref.read(watermarkDownloadServiceProvider);

    final result = await service.downloadWithWatermark(
      video: widget.video,
      username: widget.username,
      onProgress: (stage) {
        if (mounted) {
          setState(() => _stage = stage);
        }
      },
    );

    if (mounted) {
      setState(() {
        _result = result;
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: VineTheme.onSurfaceMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          if (_isProcessing) ...[
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: VineTheme.vineGreen,
              ),
            ),
            const SizedBox(height: 16),
            Text(_stageLabel, style: VineTheme.titleMediumFont()),
            const SizedBox(height: 8),
            Text(
              _stageDescription,
              style: VineTheme.bodySmallFont(color: VineTheme.secondaryText),
            ),
          ] else if (_result is WatermarkDownloadSuccess) ...[
            const Icon(
              Icons.check_circle,
              color: VineTheme.vineGreen,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text('Saved to Camera Roll', style: VineTheme.titleMediumFont()),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _shareFile,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                style: FilledButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                  foregroundColor: VineTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Done',
                style: VineTheme.labelLargeFont(color: VineTheme.secondaryText),
              ),
            ),
          ] else if (_result is WatermarkDownloadPermissionDenied) ...[
            const Icon(
              Icons.lock_outline,
              color: VineTheme.vineGreen,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text('Photos Access Needed', style: VineTheme.titleMediumFont()),
            const SizedBox(height: 8),
            Text(
              'To save videos, allow Photos access in Settings.',
              style: VineTheme.bodySmallFont(color: VineTheme.secondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _openSettings,
                style: FilledButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                  foregroundColor: VineTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Open Settings'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Not Now',
                style: VineTheme.labelLargeFont(color: VineTheme.secondaryText),
              ),
            ),
          ] else if (_result is WatermarkDownloadFailure) ...[
            const Icon(Icons.error_outline, color: VineTheme.error, size: 48),
            const SizedBox(height: 16),
            Text('Download Failed', style: VineTheme.titleMediumFont()),
            const SizedBox(height: 8),
            Text(
              (_result! as WatermarkDownloadFailure).reason,
              style: VineTheme.bodySmallFont(color: VineTheme.secondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Dismiss',
                style: VineTheme.labelLargeFont(color: VineTheme.secondaryText),
              ),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  String get _stageLabel => switch (_stage) {
    WatermarkDownloadStage.downloading => 'Downloading Video',
    WatermarkDownloadStage.watermarking => 'Adding Watermark',
    WatermarkDownloadStage.saving => 'Saving to Camera Roll',
  };

  String get _stageDescription => switch (_stage) {
    WatermarkDownloadStage.downloading =>
      'Fetching the video from the network...',
    WatermarkDownloadStage.watermarking => 'Applying the diVine watermark...',
    WatermarkDownloadStage.saving =>
      'Saving the watermarked video to your camera roll...',
  };

  Future<void> _openSettings() async {
    final permissionsService = widget.ref.read(permissionsServiceProvider);
    await permissionsService.openAppSettings();
  }

  Future<void> _shareFile() async {
    final result = _result;
    if (result is WatermarkDownloadSuccess) {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(result.filePath)]),
      );
    }
  }
}
