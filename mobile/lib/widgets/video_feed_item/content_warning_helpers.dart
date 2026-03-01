// ABOUTME: Shared content warning overlay and label helpers.
// ABOUTME: Used by FeedVideoOverlay, PooledFullscreenVideoFeedScreen,
// ABOUTME: and the old VideoFeedItem.

import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Full-screen content warning overlay with blur for videos with warn labels.
///
/// Shows a blurred backdrop with warning text, matched content labels,
/// and a "View Anyway" button to reveal the video.
class ContentWarningBlurOverlay extends StatelessWidget {
  const ContentWarningBlurOverlay({
    required this.labels,
    required this.onReveal,
    super.key,
  });

  final List<String> labels;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: VineTheme.backgroundColor.withValues(alpha: 0.6),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: VineTheme.contentWarningAmber,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sensitive Content',
                      style: TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      labels.map(humanizeContentLabel).join(', '),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: VineTheme.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: onReveal,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VineTheme.whiteText,
                        side: const BorderSide(color: VineTheme.onSurfaceMuted),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('View Anyway'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Convert a NIP-32 content-warning label value to a human-readable string.
String humanizeContentLabel(String label) {
  switch (label) {
    case 'nudity':
      return 'Nudity';
    case 'sexual':
      return 'Sexual Content';
    case 'porn':
      return 'Pornography';
    case 'graphic-media':
      return 'Graphic Media';
    case 'violence':
      return 'Violence';
    case 'self-harm':
      return 'Self-Harm';
    case 'drugs':
      return 'Drug Use';
    case 'alcohol':
      return 'Alcohol';
    case 'tobacco':
      return 'Tobacco';
    case 'gambling':
      return 'Gambling';
    case 'profanity':
      return 'Profanity';
    case 'flashing-lights':
      return 'Flashing Lights';
    case 'ai-generated':
      return 'AI-Generated';
    case 'spoiler':
      return 'Spoiler';
    case 'content-warning':
      return 'Sensitive Content';
    default:
      return 'Content Warning';
  }
}
