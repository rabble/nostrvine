// ABOUTME: Shared hero section widget for auth/invite screens
// ABOUTME: Large tagline text with decorative 3D emoji stickers and Divine logo

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/l10n/l10n.dart';

/// Hero section with large tagline text and decorative 3D emoji stickers.
///
/// Displays "Authentic moments." in green and "Human creativity." in white,
/// with positioned sticker images and the Divine wordmark logo.
class AuthHeroSection extends StatelessWidget {
  const AuthHeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hero text with positioned emoji stickers
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Main text
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    // "Authentic moments." - green, BricolageGrotesque font
                    Text(
                      context.l10n.authHeroTaglineAuthentic,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: VineTheme.fontFamilyBricolage,
                        fontSize: 48,
                        fontWeight: FontWeight.w800, // ExtraBold
                        color: VineTheme.vineGreen,
                        height: 1.1,
                      ),
                    ),
                    // "Human creativity." - white, BricolageGrotesque font
                    Text(
                      context.l10n.authHeroTaglineHuman,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: VineTheme.fontFamilyBricolage,
                        fontSize: 48,
                        fontWeight: FontWeight.w800, // ExtraBold
                        color: VineTheme.whiteText,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),

              // Camera emoji - top left
              const Positioned(
                top: -30,
                left: 10,
                child: _StickerImage(
                  path: 'assets/stickers/video_camera.svg',
                  size: 60,
                ),
              ),

              // Teeth emoji - top right
              const Positioned(
                top: -5,
                right: -20,
                child: _StickerImage(
                  path: 'assets/stickers/teeth.svg',
                  size: 70,
                ),
              ),

              // Balloon dog emoji - bottom left
              const Positioned(
                bottom: -34,
                left: 15,
                child: _StickerImage(
                  path: 'assets/stickers/balloon_dog.svg',
                  size: 80,
                ),
              ),

              // Disco ball emoji - bottom right
              const Positioned(
                bottom: -10,
                right: -10,
                child: _StickerImage(
                  path: 'assets/stickers/disco_ball.svg',
                  size: 65,
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Divine wordmark. `logo.svg` is the current logotype (geometric
          // heart-V); the cursive brand-pack files in assets/icon/ are the
          // retired one. Pinned by auth_hero_section_test.dart so a swap back
          // to the old mark fails CI instead of shipping (see #6282).
          SvgPicture.asset(
            'assets/icon/logo.svg',
            width: 120,
            semanticsLabel: context.l10n.authHeroLogoSemanticLabel,
          ),
        ],
      ),
    );
  }
}

/// Decorative sticker image widget.
class _StickerImage extends StatelessWidget {
  const _StickerImage({required this.path, required this.size});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Decorative: a bare SvgPicture still exports an `isImage` node with an
    // empty label to the platform accessibility tree. Flutter's own traversal
    // skips those, so this is tree hygiene rather than a fix for an audible
    // bug — but it keeps the four stickers out of what we hand to TalkBack
    // and VoiceOver, leaving the wordmark as the only image on the screen.
    return ExcludeSemantics(
      child: SvgPicture.asset(path, width: size, height: size),
    );
  }
}
