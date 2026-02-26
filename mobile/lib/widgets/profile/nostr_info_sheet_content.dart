// ABOUTME: Content widget explaining Nostr for new users
// ABOUTME: Shows npub, nsec, and username explanations with bullet points

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Content widget for the Nostr information bottom sheet.
///
/// Explains Nostr basics including npub, nsec, and Nostr usernames
/// with formatted bullet points and a "Learn more" link.
class NostrInfoSheetContent extends StatelessWidget {
  /// Creates a Nostr info sheet content widget.
  const NostrInfoSheetContent({this.onDismiss, super.key});

  /// Called when the "Got it!" button is pressed.
  /// If null, uses Navigator.pop.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Introduction paragraph
          RichText(
            text: TextSpan(
              style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
              children: const [
                TextSpan(
                  text: 'DiVine is built on Nostr,',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text:
                      ' a censorship-resistant open protocol that lets people communicate online without relying on a single company or platform. ',
                ),
                TextSpan(
                  text:
                      'When you sign up for Divine, you get a new Nostr identity.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nostr lets you own your content, identity and social graph, which '
            'you can use across many apps. The result is more choice, less '
            'lock-in, and a healthier, more resilient social internet.',
            style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
          ),
          const SizedBox(height: 16),
          Text(
            'Nostr lingo:',
            style: VineTheme.titleSmallFont(color: VineTheme.onSurface),
          ),
          const SizedBox(height: 8),
          // npub explanation
          const _NostrBulletPoint(
            boldText: 'npub:',
            normalText:
                " Your public Nostr address. It's safe to share and lets others "
                'find, follow, or message you across Nostr apps.',
          ),
          const SizedBox(height: 8),
          // nsec explanation
          const _NostrBulletPoint(
            boldText: 'nsec:',
            normalText:
                ' Your private key and proof of ownership. It gives full '
                'control of your Nostr identity, so ',
            italicSuffix: 'always keep it secret!',
          ),
          const SizedBox(height: 8),
          // Nostr username explanation
          const _NostrBulletPoint(
            boldText: 'Nostr username:',
            normalText:
                ' A human-readable name (like @name.divine.video) that links to '
                'your npub. It makes your Nostr identity easier to recognize '
                'and verify, similar to an email address.',
          ),
          const SizedBox(height: 16),
          // Learn more link
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse('https://divine.video/about');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: RichText(
              text: TextSpan(
                style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
                children: const [
                  TextSpan(text: 'Learn more at '),
                  TextSpan(
                    text: 'divine.video/about',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      decorationColor: VineTheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Got it button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onDismiss ?? () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                backgroundColor: VineTheme.surfaceContainer,
                foregroundColor: VineTheme.vineGreen,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                side: const BorderSide(color: VineTheme.outlineMuted, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Got it!',
                style: VineTheme.titleMediumFont(color: VineTheme.vineGreen),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A bullet point with bold label, normal text, and optional italic suffix.
class _NostrBulletPoint extends StatelessWidget {
  const _NostrBulletPoint({
    required this.boldText,
    required this.normalText,
    this.italicSuffix,
  });

  final String boldText;
  final String normalText;
  final String? italicSuffix;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ', style: VineTheme.bodyLargeFont(color: VineTheme.onSurface)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
              children: [
                TextSpan(
                  text: boldText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: normalText),
                if (italicSuffix != null)
                  TextSpan(
                    text: italicSuffix,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
