// ABOUTME: Import verification screen showing C2PA validation results
// ABOUTME: Uses Page/View pattern with BLoC for state management

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_import/video_import_bloc.dart';
import 'package:openvine/models/c2pa_import_result.dart';
import 'package:openvine/services/c2pa_import_validation_service.dart';
import 'package:openvine/services/video_import_service.dart';

/// Page that provides the [VideoImportBloc] and dispatches the initial
/// [VideoImportReceived] event for the given [filePath].
class ImportVerificationPage extends StatelessWidget {
  const ImportVerificationPage({required this.filePath, super.key});

  /// Route name used by GoRouter.
  static const routeName = 'import-verification';

  /// URL path for this route.
  static const path = '/import-verification';

  /// The path of the video file to validate.
  final String filePath;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => VideoImportBloc(
        validationService: context.read<C2paImportValidationService>(),
        importService: context.read<VideoImportService>(),
      )..add(VideoImportReceived(filePath: filePath)),
      child: const ImportVerificationView(),
    );
  }
}

/// View that renders different UI states based on C2PA validation results.
@visibleForTesting
class ImportVerificationView extends StatelessWidget {
  const ImportVerificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<VideoImportBloc, VideoImportState>(
      listenWhen: (previous, current) =>
          current.status == VideoImportStatus.imported,
      listener: (context, state) {
        context.go('/video-metadata?draftId=${state.draftId}');
      },
      child: Scaffold(
        backgroundColor: VineTheme.surfaceBackground,
        body: BlocBuilder<VideoImportBloc, VideoImportState>(
          builder: (context, state) {
            return switch (state.status) {
              VideoImportStatus.initial ||
              VideoImportStatus.validating => const _ValidatingView(),
              VideoImportStatus.verified => _VerifiedView(
                sourceAppName: state.validationResult?.sourceAppName,
              ),
              VideoImportStatus.rejected => _RejectedView(
                result: state.validationResult,
              ),
              VideoImportStatus.importing ||
              VideoImportStatus.imported => const _ImportingView(),
              VideoImportStatus.error => _RejectedView(
                result: state.validationResult,
                isError: true,
              ),
            };
          },
        ),
      ),
    );
  }
}

class _ValidatingView extends StatelessWidget {
  const _ValidatingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 24,
        children: [
          const CircularProgressIndicator(color: VineTheme.primary),
          Text(
            'Verifying Content Credentials...',
            style: VineTheme.titleLargeFont(color: VineTheme.lightText),
          ),
        ],
      ),
    );
  }
}

class _VerifiedView extends StatelessWidget {
  const _VerifiedView({this.sourceAppName});

  final String? sourceAppName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            const Icon(Icons.verified, color: VineTheme.success, size: 64),
            Text(
              'Content Credentials Verified',
              style: VineTheme.titleLargeFont(color: VineTheme.lightText),
              textAlign: TextAlign.center,
            ),
            if (sourceAppName != null)
              Text(
                'Created with $sourceAppName',
                style: VineTheme.bodyMediumFont(
                  color: VineTheme.onSurfaceMuted,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.primary,
                  foregroundColor: VineTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  context.read<VideoImportBloc>().add(
                    const VideoImportConfirmed(),
                  );
                },
                child: Text(
                  'Continue to Publish',
                  style: VineTheme.bodyLargeFont(color: VineTheme.onPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectedView extends StatelessWidget {
  const _RejectedView({this.result, this.isError = false});

  final C2paImportResult? result;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final isAiGenerated = result?.status == C2paImportStatus.aiGenerated;

    final title = isAiGenerated
        ? 'AI-Generated Content Detected'
        : 'No Content Credentials';

    final description = isAiGenerated
        ? 'This video appears to contain AI-generated content. '
              'diVine is a platform for authentic human creativity only.'
        : 'This video does not have Content Credentials (C2PA). '
              'You can add them using apps like Adobe Premiere Pro '
              'or Adobe Fresco before sharing to diVine.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Icon(
              isAiGenerated ? Icons.smart_toy : Icons.shield_outlined,
              color: isAiGenerated ? VineTheme.error : VineTheme.onSurfaceMuted,
              size: 64,
            ),
            Text(
              title,
              style: VineTheme.titleLargeFont(color: VineTheme.lightText),
              textAlign: TextAlign.center,
            ),
            Text(
              description,
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (isError && result?.rejectionReason != null)
              Text(
                result!.rejectionReason!,
                style: VineTheme.bodySmallFont(color: VineTheme.error),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: VineTheme.lightText,
                  side: const BorderSide(color: VineTheme.onSurfaceMuted),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => context.go('/'),
                child: Text(
                  'Close',
                  style: VineTheme.bodyLargeFont(color: VineTheme.lightText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportingView extends StatelessWidget {
  const _ImportingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 24,
        children: [
          const CircularProgressIndicator(color: VineTheme.primary),
          Text(
            'Importing to your library...',
            style: VineTheme.titleLargeFont(color: VineTheme.lightText),
          ),
        ],
      ),
    );
  }
}
