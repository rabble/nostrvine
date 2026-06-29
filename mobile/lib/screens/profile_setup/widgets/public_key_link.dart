import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/key_management_screen.dart';

class PublicKeyLink extends StatelessWidget {
  const PublicKeyLink({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: () => context.pushNamed(KeyManagementScreen.routeName),
        child: Text(
          l10n.profileEditPublicKeyLink,
          style: VineTheme.labelMediumFont(color: VineTheme.primary),
        ),
      ),
    );
  }
}
