import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VideoMetadataHelpSheet extends StatelessWidget {
  const VideoMetadataHelpSheet({
    required this.title,
    required this.message,
    required this.assetPath,
    super.key,
  });

  final String title;
  final String message;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const .only(top: 8.0, bottom: 16),
              child: Image.asset(assetPath, height: 132, width: 132),
            ),

            Text(
              title,
              style: VineTheme.headlineSmallFont(),
              textAlign: .center,
            ),
            const SizedBox(height: 8),

            Text(
              message,
              style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
              textAlign: .center,
            ),
            const SizedBox(height: 32),

            Semantics(
              button: true,
              // TODO(l10n): Replace with context.l10n when localization is added.
              label: 'Dismiss help dialog',
              child: Material(
                color: VineTheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(
                    width: 2,
                    color: VineTheme.outlineMuted,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: InkWell(
                  onTap: () => context.pop(),
                  borderRadius: .circular(20),
                  child: Container(
                    width: double.infinity,
                    padding: const .symmetric(horizontal: 24, vertical: 12),
                    child: Text(
                      // TODO(l10n): Replace with context.l10n when localization is added.
                      'Got it!',
                      textAlign: TextAlign.center,
                      style: VineTheme.titleMediumFont(
                        color: VineTheme.primary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
