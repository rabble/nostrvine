import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_field_decorations.dart';

/// Display-name field for the profile-setup form.
///
/// The [focusNode] is owned by the parent so the Save action can focus this
/// field when the name is left empty; this widget only listens to it to drive
/// the focus-colored label.
class DisplayNameField extends StatefulWidget {
  const DisplayNameField({
    required this.controller,
    required this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  State<DisplayNameField> createState() => _DisplayNameFieldState();
}

class _DisplayNameFieldState extends State<DisplayNameField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onChange);
  }

  @override
  void didUpdateWidget(DisplayNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onChange);
      widget.focusNode.addListener(_onChange);
    }
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    widget.focusNode.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 16),
          child: Text(
            context.l10n.profileSetupDisplayNameLabel,
            style: VineTheme.labelMediumFont(
              color: widget.focusNode.hasFocus
                  ? VineTheme.primary
                  : VineTheme.onSurfaceMuted,
            ),
          ),
        ),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
          decoration: InputDecoration(
            isCollapsed: true,
            hintText: context.l10n.profileSetupDisplayNameHint,
            helperText: context.l10n.profileSetupDisplayNameHelper,
            helperStyle: const TextStyle(
              color: VineTheme.onSurfaceMuted,
              fontSize: 12,
            ),
            hintStyle: profileFieldHintStyle,
            border: profileFieldBorder,
            enabledBorder: profileFieldBorder,
            focusedBorder: profileFieldBorder,
            errorBorder: profileFieldBorder,
            focusedErrorBorder: profileFieldBorder,
            contentPadding: const EdgeInsets.all(16),
          ),
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return context.l10n.profileSetupDisplayNameRequired;
            }
            return null;
          },
        ),
      ],
    );
  }
}
