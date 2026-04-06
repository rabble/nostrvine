import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

class LiveHostControlsSheet extends StatelessWidget {
  const LiveHostControlsSheet({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Host controls',
              style: VineTheme.headlineSmallFont(),
            ),
            const SizedBox(height: 8),
            Text(
              'Publishing controls land in the next slice. For now you can keep the room open, share it, and manage the beta flow from here.',
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            const Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _HostControlChip(label: 'Camera'),
                _HostControlChip(label: 'Mic'),
                _HostControlChip(label: 'Flip'),
                _HostControlChip(label: 'End room'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HostControlChip extends StatelessWidget {
  const _HostControlChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VineTheme.outlineMuted),
      ),
      child: Text(
        label,
        style: VineTheme.labelLargeFont(),
      ),
    );
  }
}
