// ABOUTME: ProofMode verification badge widget for displaying video authenticity levels
// ABOUTME: Shows tiered "Human Made" badges (Gold, Silver, Bronze) plus original Vine badge

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Verification tier for "Human Made" badge display.
///
/// Tiers reflect the strength of evidence that a video is authentic:
/// - [platinum]: Device proof + AI scan confirms human
/// - [gold]: Device attestation + ProofMode + C2PA (hardware proof)
/// - [silver]: Web crypto proof, or AI scan confirms likely human
/// - [bronze]: Basic proof data present
/// - [unverified]: No proof data available
enum VerificationLevel {
  platinum,
  verifiedMobile,
  verifiedWeb,
  basicProof,
  unverified,
}

/// ProofMode verification badge widget
class ProofModeBadge extends StatelessWidget {
  const ProofModeBadge({
    required this.level,
    super.key,
    this.size = BadgeSize.small,
  });

  final VerificationLevel level;
  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final config = _getBadgeConfig(level);
    final dimensions = _getDimensions(size);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dimensions.horizontalPadding,
        vertical: dimensions.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(dimensions.borderRadius),
        border: Border.all(color: config.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: dimensions.iconSize, color: config.iconColor),
          SizedBox(width: dimensions.iconTextSpacing),
          Text(
            config.label,
            style: TextStyle(
              fontSize: dimensions.fontSize,
              fontWeight: FontWeight.w600,
              color: config.textColor,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _getBadgeConfig(VerificationLevel level) {
    switch (level) {
      case VerificationLevel.platinum:
        // Platinum — device proof + AI scan confirms human
        return const _BadgeConfig(
          label: 'Human Made',
          icon: Icons.verified,
          backgroundColor: Color(0xFF1A2A3A), // Dark platinum bg
          borderColor: Color(0xFFE5E4E2), // Platinum
          iconColor: Color(0xFFE5E4E2),
          textColor: Color(0xFFE5E4E2),
        );
      case VerificationLevel.verifiedMobile:
        // Gold — device attestation + ProofMode + C2PA
        return const _BadgeConfig(
          label: 'Human Made',
          icon: Icons.verified,
          backgroundColor: Color(0xFF3D2E00), // Dark gold bg
          borderColor: Color(0xFFFFD700), // Gold
          iconColor: Color(0xFFFFD700),
          textColor: Color(0xFFFFD700),
        );
      case VerificationLevel.verifiedWeb:
        // Silver — cryptographic proof without hardware attestation
        return const _BadgeConfig(
          label: 'Human Made',
          icon: Icons.verified_outlined,
          backgroundColor: Color(0xFF2A2A2A), // Dark silver bg
          borderColor: Color(0xFFC0C0C0), // Silver
          iconColor: Color(0xFFC0C0C0),
          textColor: Color(0xFFC0C0C0),
        );
      case VerificationLevel.basicProof:
        // Bronze — basic proof data
        return const _BadgeConfig(
          label: 'Human Made',
          icon: Icons.verified_outlined,
          backgroundColor: Color(0xFF2E1F0F), // Dark bronze bg
          borderColor: Color(0xFFCD7F32), // Bronze
          iconColor: Color(0xFFCD7F32),
          textColor: Color(0xFFCD7F32),
        );
      case VerificationLevel.unverified:
        return const _BadgeConfig(
          label: 'Unverified',
          icon: Icons.shield_outlined,
          backgroundColor: Color(0xFF1A1A1A), // Dark bg
          borderColor: Color(0xFF555555), // Muted grey
          iconColor: Color(0xFF888888),
          textColor: Color(0xFF888888),
        );
    }
  }

  _BadgeDimensions _getDimensions(BadgeSize size) {
    switch (size) {
      case BadgeSize.small:
        return const _BadgeDimensions(
          horizontalPadding: 6,
          verticalPadding: 2,
          borderRadius: 4,
          iconSize: 12,
          fontSize: 10,
          iconTextSpacing: 3,
        );
      case BadgeSize.medium:
        return const _BadgeDimensions(
          horizontalPadding: 8,
          verticalPadding: 4,
          borderRadius: 6,
          iconSize: 14,
          fontSize: 11,
          iconTextSpacing: 4,
        );
      case BadgeSize.large:
        return const _BadgeDimensions(
          horizontalPadding: 10,
          verticalPadding: 5,
          borderRadius: 8,
          iconSize: 16,
          fontSize: 12,
          iconTextSpacing: 5,
        );
    }
  }
}

/// Original content badge for user-created (non-repost) vines
class OriginalContentBadge extends StatelessWidget {
  const OriginalContentBadge({super.key, this.size = BadgeSize.small});

  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final dimensions = _getDimensions(size);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dimensions.horizontalPadding,
        vertical: dimensions.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFF00BCD4,
        ), // Cyan/teal - modern original content color
        borderRadius: BorderRadius.circular(dimensions.borderRadius),
        border: Border.all(
          color: const Color(0xFF0097A7), // Darker cyan border
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: dimensions.iconSize,
            color: VineTheme.whiteText,
          ),
          SizedBox(width: dimensions.iconTextSpacing),
          Text(
            'Original',
            style: GoogleFonts.pacifico(
              fontSize: dimensions.fontSize,
              fontWeight: FontWeight.w400,
              color: VineTheme.whiteText,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeDimensions _getDimensions(BadgeSize size) {
    switch (size) {
      case BadgeSize.small:
        return const _BadgeDimensions(
          horizontalPadding: 6,
          verticalPadding: 2,
          borderRadius: 12, // More pill-shaped
          iconSize: 10,
          fontSize: 10,
          iconTextSpacing: 3,
        );
      case BadgeSize.medium:
        return const _BadgeDimensions(
          horizontalPadding: 8,
          verticalPadding: 4,
          borderRadius: 14,
          iconSize: 12,
          fontSize: 11,
          iconTextSpacing: 4,
        );
      case BadgeSize.large:
        return const _BadgeDimensions(
          horizontalPadding: 10,
          verticalPadding: 5,
          borderRadius: 16,
          iconSize: 14,
          fontSize: 12,
          iconTextSpacing: 5,
        );
    }
  }
}

/// Original Vine badge for recovered vintage vines
class OriginalVineBadge extends StatelessWidget {
  const OriginalVineBadge({super.key, this.size = BadgeSize.small});

  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final dimensions = _getDimensions(size);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dimensions.horizontalPadding,
        vertical: dimensions.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF00BF8F), // Vine teal/green
        borderRadius: BorderRadius.circular(dimensions.borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'V',
            style: GoogleFonts.pacifico(
              fontSize: dimensions.fontSize + 2,
              fontWeight: FontWeight.w400,
              color: VineTheme.whiteText,
            ),
          ),
          SizedBox(width: dimensions.iconTextSpacing),
          Text(
            'Original',
            style: GoogleFonts.pacifico(
              fontSize: dimensions.fontSize,
              fontWeight: FontWeight.w400,
              color: VineTheme.whiteText,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeDimensions _getDimensions(BadgeSize size) {
    switch (size) {
      case BadgeSize.small:
        return const _BadgeDimensions(
          horizontalPadding: 6,
          verticalPadding: 2,
          borderRadius: 4,
          iconSize: 12,
          fontSize: 10,
          iconTextSpacing: 3,
        );
      case BadgeSize.medium:
        return const _BadgeDimensions(
          horizontalPadding: 8,
          verticalPadding: 4,
          borderRadius: 6,
          iconSize: 14,
          fontSize: 11,
          iconTextSpacing: 4,
        );
      case BadgeSize.large:
        return const _BadgeDimensions(
          horizontalPadding: 10,
          verticalPadding: 5,
          borderRadius: 8,
          iconSize: 16,
          fontSize: 12,
          iconTextSpacing: 5,
        );
    }
  }
}

/// "Not Divine" badge for external/unverified content
class NotDivineBadge extends StatelessWidget {
  const NotDivineBadge({super.key, this.size = BadgeSize.small});

  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final dimensions = _getDimensions(size);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dimensions.horizontalPadding,
        vertical: dimensions.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: VineTheme.backgroundColor,
        borderRadius: BorderRadius.circular(dimensions.borderRadius),
        border: Border.all(color: VineTheme.cardBackground),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.public_off,
            size: dimensions.iconSize,
            color: VineTheme.secondaryText,
          ),
          SizedBox(width: dimensions.iconTextSpacing),
          Text(
            'Not Divine Hosted',
            style: TextStyle(
              fontSize: dimensions.fontSize,
              fontWeight: FontWeight.w500,
              color: VineTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeDimensions _getDimensions(BadgeSize size) {
    switch (size) {
      case BadgeSize.small:
        return const _BadgeDimensions(
          horizontalPadding: 6,
          verticalPadding: 2,
          borderRadius: 4,
          iconSize: 10,
          fontSize: 10,
          iconTextSpacing: 3,
        );
      case BadgeSize.medium:
        return const _BadgeDimensions(
          horizontalPadding: 8,
          verticalPadding: 4,
          borderRadius: 6,
          iconSize: 12,
          fontSize: 11,
          iconTextSpacing: 4,
        );
      case BadgeSize.large:
        return const _BadgeDimensions(
          horizontalPadding: 10,
          verticalPadding: 5,
          borderRadius: 8,
          iconSize: 14,
          fontSize: 12,
          iconTextSpacing: 5,
        );
    }
  }
}

/// "Hosted on Divine" badge for Divine-hosted content without proof data
class DivineBadge extends StatelessWidget {
  const DivineBadge({super.key, this.size = BadgeSize.small});

  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final dimensions = _getDimensions(size);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dimensions.horizontalPadding,
        vertical: dimensions.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2818), // Dark green bg
        borderRadius: BorderRadius.circular(dimensions.borderRadius),
        border: Border.all(color: VineTheme.vineGreen.withAlpha(128)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_done_outlined,
            size: dimensions.iconSize,
            color: VineTheme.vineGreen,
          ),
          SizedBox(width: dimensions.iconTextSpacing),
          Text(
            'Hosted on Divine',
            style: TextStyle(
              fontSize: dimensions.fontSize,
              fontWeight: FontWeight.w500,
              color: VineTheme.vineGreen,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeDimensions _getDimensions(BadgeSize size) {
    switch (size) {
      case BadgeSize.small:
        return const _BadgeDimensions(
          horizontalPadding: 6,
          verticalPadding: 2,
          borderRadius: 4,
          iconSize: 10,
          fontSize: 10,
          iconTextSpacing: 3,
        );
      case BadgeSize.medium:
        return const _BadgeDimensions(
          horizontalPadding: 8,
          verticalPadding: 4,
          borderRadius: 6,
          iconSize: 12,
          fontSize: 11,
          iconTextSpacing: 4,
        );
      case BadgeSize.large:
        return const _BadgeDimensions(
          horizontalPadding: 10,
          verticalPadding: 5,
          borderRadius: 8,
          iconSize: 14,
          fontSize: 12,
          iconTextSpacing: 5,
        );
    }
  }
}

/// "Possibly AI-Generated" warning badge
class PossiblyAIBadge extends StatelessWidget {
  const PossiblyAIBadge({super.key, this.size = BadgeSize.small});

  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final dimensions = _getDimensions(size);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dimensions.horizontalPadding,
        vertical: dimensions.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2E1F00), // Dark amber bg
        borderRadius: BorderRadius.circular(dimensions.borderRadius),
        border: Border.all(color: VineTheme.warning),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber,
            size: dimensions.iconSize,
            color: VineTheme.warning,
          ),
          SizedBox(width: dimensions.iconTextSpacing),
          Text(
            'Possibly AI-Generated',
            style: TextStyle(
              fontSize: dimensions.fontSize,
              fontWeight: FontWeight.w500,
              color: VineTheme.warning,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeDimensions _getDimensions(BadgeSize size) {
    switch (size) {
      case BadgeSize.small:
        return const _BadgeDimensions(
          horizontalPadding: 6,
          verticalPadding: 2,
          borderRadius: 4,
          iconSize: 10,
          fontSize: 10,
          iconTextSpacing: 3,
        );
      case BadgeSize.medium:
        return const _BadgeDimensions(
          horizontalPadding: 8,
          verticalPadding: 4,
          borderRadius: 6,
          iconSize: 12,
          fontSize: 11,
          iconTextSpacing: 4,
        );
      case BadgeSize.large:
        return const _BadgeDimensions(
          horizontalPadding: 10,
          verticalPadding: 5,
          borderRadius: 8,
          iconSize: 14,
          fontSize: 12,
          iconTextSpacing: 5,
        );
    }
  }
}

/// Badge size enum
enum BadgeSize { small, medium, large }

/// Badge configuration
class _BadgeConfig {
  const _BadgeConfig({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
}

/// Badge dimensions based on size
class _BadgeDimensions {
  const _BadgeDimensions({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.borderRadius,
    required this.iconSize,
    required this.fontSize,
    required this.iconTextSpacing,
  });

  final double horizontalPadding;
  final double verticalPadding;
  final double borderRadius;
  final double iconSize;
  final double fontSize;
  final double iconTextSpacing;
}
