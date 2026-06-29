import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/verified_accounts_row.dart';
import 'package:profile_repository/profile_repository.dart';

class VerifiedAccountsSection extends StatelessWidget {
  const VerifiedAccountsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final claims = context.select<MyProfileBloc, List<IdentityClaim>>((bloc) {
      final state = bloc.state;
      if (state is MyProfileLoaded) return state.verifiedClaims;
      if (state is MyProfileUpdated) return state.verifiedClaims;
      return const [];
    });
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              l10n.profileEditVerifiedAccountsTitle,
              style: VineTheme.labelMediumFont(color: VineTheme.lightText),
            ),
          ),
          if (claims.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VerifiedAccountsRow(claims: claims),
            ),
            const SizedBox(height: 8),
          ],
          const _GetVerifiedTile(),
        ],
      ),
    );
  }
}

class _GetVerifiedTile extends StatelessWidget {
  const _GetVerifiedTile();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      title: Text(
        l10n.profileEditGetVerifiedCta,
        style: VineTheme.titleMediumFont(),
      ),
      subtitle: Text(
        l10n.profileEditGetVerifiedSubtitle,
        style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
      ),
      trailing: const DivineIcon(
        icon: DivineIconName.caretRight,
        color: VineTheme.lightText,
      ),
      onTap: () => context.read<ProfileEditorBloc>().add(
        const VerifierLaunchRequested(),
      ),
    );
  }
}
