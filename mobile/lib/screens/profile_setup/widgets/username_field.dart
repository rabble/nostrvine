import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_field_decorations.dart';
import 'package:openvine/widgets/profile_editor/username_status_indicator.dart';

class UsernameField extends StatefulWidget {
  const UsernameField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  State<UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends State<UsernameField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
      buildWhen: (prev, curr) => prev.nip05Mode != curr.nip05Mode,
      builder: (context, editorState) {
        final isExternal = editorState.nip05Mode == Nip05Mode.external_;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
              ),
              child: Text(
                context.l10n.profileSetupUsernameLabel,
                style: VineTheme.labelMediumFont(
                  color: _focusNode.hasFocus && !isExternal
                      ? VineTheme.primary
                      : VineTheme.onSurfaceMuted,
                ),
              ),
            ),
            TextFormField(
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: !isExternal,
              style: VineTheme.bodyLargeFont(
                color: isExternal
                    ? VineTheme.onSurfaceMuted
                    : VineTheme.onSurface,
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                isCollapsed: true,
                hintText: context.l10n.profileSetupUsernameHint,
                helperText: context.l10n.profileSetupUsernameHelper,
                helperStyle: const TextStyle(
                  color: VineTheme.onSurfaceMuted,
                  fontSize: 12,
                ),
                hintStyle: const TextStyle(
                  color: VineTheme.onSurfaceMuted,
                ),
                border: profileFieldBorder,
                enabledBorder: profileFieldBorder,
                disabledBorder: profileFieldBorder,
                focusedBorder: profileFieldBorder,
                errorBorder: profileFieldBorder,
                focusedErrorBorder: profileFieldBorder,
                contentPadding: const EdgeInsets.all(
                  16,
                ),
                prefixText: '@',
                prefixStyle: VineTheme.bodyLargeFont(
                  color: VineTheme.onSurfaceMuted,
                ),
                suffixText: '.divine.video',
                suffixStyle: VineTheme.bodyLargeFont(
                  color: VineTheme.onSurfaceMuted,
                ),
                errorMaxLines: 2,
              ),
              // Lowercase as the user types and
              // restrict to canonical subdomain
              // characters. The name server stores
              // and resolves usernames as lowercase,
              // so normalizing here avoids a
              // confusing "invalid format" error
              // for a typed capital letter.
              inputFormatters: [
                const LowercaseTextInputFormatter(),
                FilteringTextInputFormatter.allow(
                  RegExp('[a-z0-9-]'),
                ),
              ],
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              onChanged: (value) =>
                  context.read<ProfileEditorBloc>().add(UsernameChanged(value)),
            ),
            // Username status indicators
            if (!isExternal)
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
