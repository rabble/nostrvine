import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/l10n/l10n.dart';

// TODO(SofiaRey): revisit when designs are ready
/// Screen shown when the target user has blocked us.
class UserNotAvailableScreen extends StatelessWidget {
  const UserNotAvailableScreen({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: DiVineAppBar(
        title: context.l10n.profileTitle,
        showBackButton: true,
        onBackPressed: onBack,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                DivineIconName.prohibit.assetPath,
                width: 48,
                height: 48,
                colorFilter: const ColorFilter.mode(
                  VineTheme.secondaryText,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.userNotAvailableTitle,
                style: VineTheme.titleLargeFont(),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.userNotAvailableBody,
                style: VineTheme.bodyLargeFont(color: VineTheme.secondaryText),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
