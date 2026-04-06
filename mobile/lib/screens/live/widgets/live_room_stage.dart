import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

class LiveRoomStage extends StatelessWidget {
  const LiveRoomStage({
    required this.speakerPubkeys,
    required this.audienceCount,
    required this.statusLabel,
    super.key,
  });

  final List<String> speakerPubkeys;
  final int audienceCount;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF1B1711),
            Color(0xFF243528),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Stage',
                style: VineTheme.titleLargeFont(),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: VineTheme.scrim15,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: VineTheme.labelLargeFont(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: speakerPubkeys.isEmpty
                ? <Widget>[
                    Text(
                      'Waiting for speakers to join the stage.',
                      style: VineTheme.bodyMediumFont(
                        color: VineTheme.onSurfaceVariant,
                      ),
                    ),
                  ]
                : speakerPubkeys
                      .map(
                        (pubkey) => Container(
                          width: 150,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: VineTheme.scrim15,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: VineTheme.outlineMuted),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Speaker',
                                style: VineTheme.labelLargeFont(
                                  color: VineTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                pubkey,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: VineTheme.bodySmallFont(),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
          ),
          const SizedBox(height: 16),
          Text(
            '$audienceCount listeners in the room',
            style: VineTheme.bodyMediumFont(
              color: VineTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
