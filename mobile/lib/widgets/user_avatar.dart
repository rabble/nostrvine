// ABOUTME: Reusable rounded-square avatar with shared Figma-matched geometry
// ABOUTME: Supports network images, local image providers, and generated accent placeholders

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:unified_logger/unified_logger.dart';

enum UserAvatarPlaceholderTone {
  auto,
  yellow,
  lime,
  pink,
  orange,
  violet,
  purple,
  blue,
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.imageUrl,
    this.imageProvider,
    this.name,
    this.size = 44,
    this.onTap,
    this.semanticLabel,
    this.placeholderTone = UserAvatarPlaceholderTone.auto,
  });

  final String? imageUrl;
  final ImageProvider<Object>? imageProvider;
  final String? name;
  final double size;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final UserAvatarPlaceholderTone placeholderTone;

  static const List<UserAvatarPlaceholderTone> _paletteOrder = [
    UserAvatarPlaceholderTone.yellow,
    UserAvatarPlaceholderTone.lime,
    UserAvatarPlaceholderTone.pink,
    UserAvatarPlaceholderTone.orange,
    UserAvatarPlaceholderTone.violet,
    UserAvatarPlaceholderTone.purple,
    UserAvatarPlaceholderTone.blue,
  ];

  static const Map<UserAvatarPlaceholderTone, _AvatarPalette> _palettes = {
    UserAvatarPlaceholderTone.yellow: _AvatarPalette(
      base: VineTheme.accentYellow,
      figure: Color(0xFFAF9500),
      shadow: Color(0xFF665900),
    ),
    UserAvatarPlaceholderTone.lime: _AvatarPalette(
      base: VineTheme.accentLime,
      figure: Color(0xFF79A200),
      shadow: Color(0xFF445C00),
    ),
    UserAvatarPlaceholderTone.pink: _AvatarPalette(
      base: VineTheme.accentPink,
      figure: Color(0xFFCB4E82),
      shadow: Color(0xFF7E2351),
    ),
    UserAvatarPlaceholderTone.orange: _AvatarPalette(
      base: VineTheme.accentOrange,
      figure: Color(0xFFD74C17),
      shadow: Color(0xFF8A2805),
    ),
    UserAvatarPlaceholderTone.violet: _AvatarPalette(
      base: VineTheme.accentViolet,
      figure: Color(0xFF6D74D5),
      shadow: Color(0xFF41489B),
    ),
    UserAvatarPlaceholderTone.purple: _AvatarPalette(
      base: VineTheme.accentPurple,
      figure: Color(0xFF5C37F6),
      shadow: Color(0xFF321D8F),
    ),
    UserAvatarPlaceholderTone.blue: _AvatarPalette(
      base: VineTheme.accentBlue,
      figure: Color(0xFF0B84C3),
      shadow: Color(0xFF07577F),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final avatar = SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_cornerRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildContent(),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_cornerRadius),
                border: Border.all(
                  color: VineTheme.onSurfaceDisabled,
                  width: _borderWidth,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      label: semanticLabel ?? (name != null ? '$name avatar' : 'User avatar'),
      button: onTap != null,
      child: onTap == null
          ? avatar
          : GestureDetector(onTap: onTap, child: avatar),
    );
  }

  double get _cornerRadius => size <= 24 ? size / 3 : math.min(size * 0.4, 56);

  double get _borderWidth => size >= 120 ? 3 : 1;

  Widget _buildContent() {
    if (imageProvider != null) {
      return Image(
        image: imageProvider!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return VineCachedImage(
        imageUrl: imageUrl!,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) {
          if (error.toString().contains('Invalid image data') ||
              error.toString().contains('Image codec failed')) {
            UnifiedLogger.warning(
              '🖼️ Invalid image data for avatar URL: $url - Error: $error',
              name: 'UserAvatar',
            );
          } else {
            UnifiedLogger.debug(
              'Avatar image failed to load URL: $url - Error: $error',
              name: 'UserAvatar',
            );
          }
          return _buildPlaceholder();
        },
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    final palette = _palettes[_effectiveTone] ?? _palettes.values.first;
    final headSize = size * 0.42;
    final headInset = size * 0.215;
    final shoulderWidth = size * 0.84;
    final shoulderHeight = size * 0.38;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _lighten(palette.base, 0.22),
            palette.base,
            _darken(palette.base, 0.08),
          ],
          stops: const [0, 0.58, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.55, -0.9),
                radius: 1.15,
                colors: [
                  VineTheme.whiteText.withValues(alpha: 0.18),
                  VineTheme.transparent,
                ],
              ),
            ),
          ),
          Positioned(
            left: headInset,
            right: headInset,
            top: size * 0.16,
            child: Container(
              width: headSize,
              height: headSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.35),
                  radius: 1.05,
                  colors: [
                    _lighten(palette.figure, 0.18),
                    palette.figure,
                    palette.shadow,
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: (size - shoulderWidth) / 2,
            right: (size - shoulderWidth) / 2,
            bottom: -size * 0.13,
            child: Container(
              width: shoulderWidth,
              height: shoulderHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(shoulderHeight),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _lighten(palette.figure, 0.16),
                    palette.figure,
                    palette.shadow,
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(
              child: Container(
                height: size * 0.24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      VineTheme.transparent,
                      palette.shadow.withValues(alpha: 0.26),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  UserAvatarPlaceholderTone get _effectiveTone {
    if (placeholderTone != UserAvatarPlaceholderTone.auto) {
      return placeholderTone;
    }

    final seed = [
      name,
      imageUrl,
      semanticLabel,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join('|');

    if (seed.isEmpty) return UserAvatarPlaceholderTone.yellow;

    final index =
        seed.runes.fold<int>(0, (sum, rune) => sum + rune) %
        _paletteOrder.length;
    return _paletteOrder[index];
  }

  static Color _lighten(Color color, double amount) =>
      Color.lerp(color, VineTheme.whiteText, amount) ?? color;

  static Color _darken(Color color, double amount) =>
      Color.lerp(color, VineTheme.backgroundColor, amount) ?? color;
}

class _AvatarPalette {
  const _AvatarPalette({
    required this.base,
    required this.figure,
    required this.shadow,
  });

  final Color base;
  final Color figure;
  final Color shadow;
}
