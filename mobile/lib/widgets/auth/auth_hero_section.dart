// ABOUTME: Shared hero section widget for auth/invite screens
// ABOUTME: Large tagline text with decorative 3D emoji stickers and divine logo

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Hero section with large tagline text and decorative 3D emoji stickers.
///
/// Displays "Authentic moments." in green and "Human creativity." in white,
/// with positioned sticker images and the divine wordmark logo.
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
          const Stack(
            clipBehavior: Clip.none,
            children: [
              // Main text
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    // "Authentic moments." - green, BricolageGrotesque font
                    Text(
                      'Authentic moments.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: VineTheme.fontFamilyBricolage,
                        fontSize: 48,
                        fontWeight: FontWeight.w800, // ExtraBold
                        color: VineTheme.vineGreen,
                        height: 1.1,
                      ),
                    ),
                    // "Human creativity." - white, BricolageGrotesque font
                    Text(
                      'Human creativity.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
              Positioned(
                top: -30,
                left: 10,
                child: _StickerImage(
                  path: 'assets/stickers/video_camera.png',
                  size: 60,
                ),
              ),

              // Teeth emoji - top right
              Positioned(
                top: -5,
                right: -20,
                child: _StickerImage(
                  path: 'assets/stickers/teeth.png',
                  size: 70,
                ),
              ),

              // Balloon dog emoji - bottom left
              Positioned(
                bottom: -34,
                left: 15,
                child: _StickerImage(
                  path: 'assets/stickers/balloon_dog.png',
                  size: 80,
                ),
              ),

              // Disco ball emoji - bottom right
              Positioned(
                bottom: -10,
                right: -10,
                child: _StickerImage(
                  path: 'assets/stickers/disco_ball.png',
                  size: 65,
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Divine wordmark (green SVG logo)
          SvgPicture.asset('assets/icon/logo.svg', width: 120),
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
    return Image.asset(path, width: size, height: size, fit: BoxFit.contain);
  }
}
