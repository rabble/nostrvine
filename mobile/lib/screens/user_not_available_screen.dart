import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
        title: 'Profile',
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
              Text('Account not available', style: VineTheme.titleLargeFont()),
              const SizedBox(height: 8),
              Text(
                "This account isn't available right now.",
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
