import 'package:app_update_repository/app_update_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows a dialog when the update urgency is moderate or urgent.
///
/// Place this as a [BlocListener] in the widget tree.
class UpdateDialogListener extends StatelessWidget {
  /// Creates an [UpdateDialogListener].
  const UpdateDialogListener({required this.child, super.key});

  /// The child widget.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppUpdateBloc, AppUpdateState>(
      listenWhen: (prev, curr) =>
          curr.status == AppUpdateStatus.resolved &&
          (curr.urgency == UpdateUrgency.moderate ||
              curr.urgency == UpdateUrgency.urgent) &&
          prev.urgency != curr.urgency,
      listener: (context, state) {
        showDialog<void>(
          context: context,
          builder: (_) => BlocProvider.value(
            value: context.read<AppUpdateBloc>(),
            child: _UpdateDialog(
              urgency: state.urgency,
              latestVersion: state.latestVersion ?? '',
              downloadUrl: state.downloadUrl ?? '',
              highlights: state.releaseHighlights,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({
    required this.urgency,
    required this.latestVersion,
    required this.downloadUrl,
    required this.highlights,
  });

  final UpdateUrgency urgency;
  final String latestVersion;
  final String downloadUrl;
  final List<String> highlights;

  @override
  Widget build(BuildContext context) {
    final isUrgent = urgency == UpdateUrgency.urgent;

    return AlertDialog(
      backgroundColor: VineTheme.surfaceBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        isUrgent ? UpdateCopy.urgentTitle : UpdateCopy.moderateTitle,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(color: VineTheme.primaryText),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlights.isNotEmpty) ...[
            Text(
              UpdateCopy.newIn(latestVersion),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: VineTheme.lightText.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            for (final highlight in highlights.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(color: VineTheme.vineGreen),
                    ),
                    Expanded(
                      child: Text(
                        highlight,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: VineTheme.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            context.read<AppUpdateBloc>().add(const AppUpdateDismissed());
            Navigator.of(context).pop();
          },
          child: Text(
            UpdateCopy.notNow,
            style: TextStyle(color: VineTheme.lightText.withValues(alpha: 0.6)),
          ),
        ),
        FilledButton(
          onPressed: () async {
            final uri = Uri.tryParse(downloadUrl);
            if (uri != null) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          style: FilledButton.styleFrom(backgroundColor: VineTheme.vineGreen),
          child: const Text(UpdateCopy.update),
        ),
      ],
    );
  }
}
