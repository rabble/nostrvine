import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/models/live/live_presence.dart';

class LiveSpeakerQueueSheet extends StatelessWidget {
  const LiveSpeakerQueueSheet({
    required this.hostPubkey,
    required this.presence,
    required this.speakerPubkeys,
    required this.onPromote,
    required this.onDemote,
    super.key,
  });

  final String hostPubkey;
  final List<LivePresence> presence;
  final List<String> speakerPubkeys;
  final ValueChanged<String> onPromote;
  final ValueChanged<String> onDemote;

  @override
  Widget build(BuildContext context) {
    final rows = presence
        .where((member) {
          if (member.pubkey == hostPubkey) {
            return false;
          }
          return member.handRaised || speakerPubkeys.contains(member.pubkey);
        })
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manage speakers',
          style: VineTheme.titleMediumFont(),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Text(
            'Raised hands and active speakers will show up here.',
            style: VineTheme.bodyMediumFont(
              color: VineTheme.onSurfaceVariant,
            ),
          ),
        for (final member in rows) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VineTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: VineTheme.outlineMuted),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    member.pubkey,
                    style: VineTheme.labelLargeFont(),
                  ),
                ),
                DivineButton(
                  label: speakerPubkeys.contains(member.pubkey)
                      ? 'Demote'
                      : 'Promote',
                  size: DivineButtonSize.small,
                  type: DivineButtonType.secondary,
                  onPressed: () {
                    if (speakerPubkeys.contains(member.pubkey)) {
                      onDemote(member.pubkey);
                    } else {
                      onPromote(member.pubkey);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
