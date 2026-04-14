// ABOUTME: Progress bottom sheet for saving original video (no watermark)
// ABOUTME: Shows downloading -> saving stages with completion actions

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/watermark_download_provider.dart';
import 'package:openvine/services/watermark_download_service.dart';
import 'package:share_plus/share_plus.dart';

/// Shows a bottom sheet that tracks original video save progress.
///
/// Call this to start the save-original flow. The sheet displays
/// progress through downloading and saving stages (no watermark step).
Future<void> showSaveOriginalSheet({
  required BuildContext context,
  required WidgetRef ref,
  required VideoEvent video,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: VineTheme.surfaceBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(VineTheme.bottomSheetBorderRadius),
      ),
    ),
    builder: (sheetContext) =>
        _SaveOriginalProgressSheet(video: video, ref: ref),
  );
}

class _SaveOriginalProgressSheet extends StatefulWidget {
  const _SaveOriginalProgressSheet({required this.video, required this.ref});

  final VideoEvent video;
  final WidgetRef ref;

  @override
  State<_SaveOriginalProgressSheet> createState() =>
      _SaveOriginalProgressSheetState();
}

class _SaveOriginalProgressSheetState
    extends State<_SaveOriginalProgressSheet> {
  OriginalSaveStage _stage = OriginalSaveStage.downloading;
  WatermarkDownloadResult? _result;
  bool _isProcessing = true;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    final service = widget.ref.read(watermarkDownloadServiceProvider);

    final result = await service.downloadOriginal(
      video: widget.video,
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
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
              Text(
                _stageLabel(l10n),
                style: VineTheme.titleMediumFont(),
              ),
              const SizedBox(height: 8),
              Text(
                _stageDescription(l10n),
                style: VineTheme.bodySmallFont(
                  color: VineTheme.secondaryText,
                ),
              ),
            ] else if (_result is WatermarkDownloadSuccess) ...[
              const Icon(
                Icons.check_circle,
                color: VineTheme.vineGreen,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.saveOriginalSavedToCameraRoll,
                style: VineTheme.titleMediumFont(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _shareFile,
                  icon: const Icon(Icons.share),
                  label: Text(l10n.saveOriginalShare),
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
                  l10n.saveOriginalDone,
                  style: VineTheme.labelLargeFont(
                    color: VineTheme.secondaryText,
                  ),
                ),
              ),
            ] else if (_result is WatermarkDownloadPermissionDenied) ...[
              const Icon(
                Icons.lock_outline,
                color: VineTheme.vineGreen,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.saveOriginalPhotosAccessNeeded,
                style: VineTheme.titleMediumFont(),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.saveOriginalPhotosAccessMessage,
                style: VineTheme.bodySmallFont(
                  color: VineTheme.secondaryText,
                ),
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
                  child: Text(l10n.saveOriginalOpenSettings),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  l10n.saveOriginalNotNow,
                  style: VineTheme.labelLargeFont(
                    color: VineTheme.secondaryText,
                  ),
                ),
              ),
            ] else if (_result is WatermarkDownloadFailure) ...[
              const Icon(
                Icons.error_outline,
                color: VineTheme.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.saveOriginalDownloadFailed,
                style: VineTheme.titleMediumFont(),
              ),
              const SizedBox(height: 8),
              Text(
                (_result! as WatermarkDownloadFailure).reason,
                style: VineTheme.bodySmallFont(
                  color: VineTheme.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  l10n.saveOriginalDismiss,
                  style: VineTheme.labelLargeFont(
                    color: VineTheme.secondaryText,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _stageLabel(AppLocalizations l10n) => switch (_stage) {
    OriginalSaveStage.downloading => l10n.saveOriginalDownloadingVideo,
    OriginalSaveStage.saving => l10n.saveOriginalSavingToCameraRoll,
  };

  String _stageDescription(AppLocalizations l10n) => switch (_stage) {
    OriginalSaveStage.downloading => l10n.saveOriginalFetchingVideo,
    OriginalSaveStage.saving => l10n.saveOriginalSavingVideo,
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
