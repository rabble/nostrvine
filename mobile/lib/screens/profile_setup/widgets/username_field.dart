import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_rows.dart';
import 'package:openvine/widgets/profile_editor/username_status_indicator.dart';

/// The divine.video handle field.
///
/// The suffix reads `@divine.video`, matching the design and the shape people
/// recognise from the NIP-05 screen.
///
/// Note this is display only — the controller holds the bare handle and that
/// is what gets claimed. It also does not spell the address the registry
/// currently issues, which is the `_@<handle>.divine.video` subdomain form;
/// `user_profile.dart` treats `<handle>@divine.video` as the legacy shape.
///
/// Disabled while the profile points at an external NIP-05: the two are
/// alternatives, and the external address is edited on its own screen.
class UsernameField extends StatelessWidget {
  const UsernameField({
    required this.controller,
    required this.nextFocusNode,
    super.key,
  });

  final TextEditingController controller;

  /// Focused when the keyboard's next key is pressed.
  ///
  /// Targeted rather than left to `nextFocus()`: the NIP-05 card sits between
  /// this field and the bio in traversal order, and it takes focus without
  /// bringing a keyboard — so next appeared to do nothing but dismiss it.
  final FocusNode nextFocusNode;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
      buildWhen: (prev, curr) => prev.nip05Mode != curr.nip05Mode,
      builder: (context, editorState) {
        final isExternal = editorState.nip05Mode == Nip05Mode.external_;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DivineTextField(
              controller: controller,
              enabled: !isExternal,
              labelText: context.l10n.profileSetupUsernameLabel,
              filled: true,
              fillColor: context.vineColors.surfaceContainer,
              fillBorderRadius: profileFormCardRadius,
              primaryWhenFilled: true,
              suffixText: '@divine.video',
              textCapitalization: .none,
              textInputAction: TextInputAction.next,
              // Replaces the default next-focus walk rather than running after
              // it, so focus lands on the bio in one hop.
              onEditingComplete: () {
                controller.clearComposing();
                nextFocusNode.requestFocus();
              },
              onChanged: (value) =>
                  context.read<ProfileEditorBloc>().add(UsernameChanged(value)),
              // Lowercase as the user types and restrict to canonical
              // subdomain characters. The name server stores and resolves
              // usernames as lowercase, so normalizing here avoids a confusing
              // "invalid format" error for a typed capital letter.
              inputFormatters: [
                const LowercaseTextInputFormatter(),
                FilteringTextInputFormatter.allow(RegExp('[a-z0-9-]')),
              ],
            ),
            if (isExternal)
              ProfileFieldSupportingText(
                context.l10n.profileSetupUsernameHelper,
              )
            else
              BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
                builder: (context, state) => UsernameStatusIndicator(
                  status: state.usernameStatus,
                  error: state.usernameError,
                  formatMessage: state.usernameFormatMessage,
                ),
              ),
          ],
        );
      },
    );
  }
}
