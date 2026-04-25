// ABOUTME: Compact runtime permission prompt for vetted Nostr sandbox apps
// ABOUTME: Shows the requesting app, origin, and requested bridge capability

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

class NostrAppPermissionPromptSheet extends StatelessWidget {
  const NostrAppPermissionPromptSheet({
    required this.appName,
    required this.origin,
    required this.method,
    required this.capability,
    required this.onAllow,
    required this.onCancel,
    this.eventKind,
    super.key,
  });

  final String appName;
  final String origin;
  final String method;
  final String capability;
  final int? eventKind;
  final VoidCallback onAllow;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$appName wants your approval',
            style: VineTheme.titleLargeFont(color: VineTheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            "This app is requesting access through Divine's vetted sandbox.",
            style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          _DetailRow(label: 'Origin', value: origin),
          const SizedBox(height: 12),
          _DetailRow(label: 'Method', value: method),
          const SizedBox(height: 12),
          _DetailRow(label: 'Capability', value: capability),
          if (eventKind != null) ...[
            const SizedBox(height: 12),
            _DetailRow(label: 'Event kind', value: '$eventKind'),
          ],
          const SizedBox(height: 28),
          Column(
            spacing: 12,
            children: [
              DivineButton(label: 'Allow', onPressed: onAllow, expanded: true),
              DivineButton(
                label: 'Cancel',
                type: DivineButtonType.secondary,
                onPressed: onCancel,
                expanded: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VineTheme.outlineMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: VineTheme.titleSmallFont(color: VineTheme.onSurfaceMuted),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
          ),
        ],
      ),
    );
  }
}
