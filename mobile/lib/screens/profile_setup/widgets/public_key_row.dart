import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_rows.dart';

/// The signed-in account's npub, with a copy action.
///
/// Read-only: the key is not something the profile form can change, so the row
/// offers the one thing a user wants from it.
class PublicKeyRow extends ConsumerWidget {
  /// Creates the npub row.
  const PublicKeyRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final npub = ref.watch(authServiceProvider).currentNpub;
    if (npub == null || npub.isEmpty) return const SizedBox.shrink();

    return ProfileValueRow(
      label: context.l10n.profileSetupPublicKeyLabel,
      // Held whole — the row ellipsises on overflow, it never shortens the
      // identifier itself.
      value: npub,
      // A bare green glyph, not a chip: the design puts the copy icon in the
      // same slot the other cards use for their caret.
      trailing: DivineIconButton(
        icon: DivineIconName.copy,
        size: DivineIconButtonSize.small,
        backgroundColor: VineTheme.transparent,
        foregroundColor: VineTheme.primary,
        tooltip: context.l10n.profilePublicKeyCopied,
        semanticLabel: context.l10n.profileSetupPublicKeyLabel,
        onPressed: () => _copy(context, npub),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String npub) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.profilePublicKeyCopied;
    await Clipboard.setData(ClipboardData(text: npub));
    messenger.showSnackBar(DivineSnackbarContainer.snackBar(message));
  }
}
