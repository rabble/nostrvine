import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_field_decorations.dart';

class BioField extends StatefulWidget {
  const BioField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  State<BioField> createState() => _BioFieldState();
}

class _BioFieldState extends State<BioField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onChange);
    // Rebuild the character counter on both user input and programmatic
    // seeding (e.g. when an existing profile loads into the controller).
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(BioField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
    }
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onChange)
      ..dispose();
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.profileSetupBioLabel,
                style: VineTheme.labelMediumFont(
                  color: _focusNode.hasFocus
                      ? VineTheme.primary
                      : VineTheme.onSurfaceMuted,
                ),
              ),
              Text(
                '${widget.controller.text.length}/360',
                style: VineTheme.labelMediumFont(
                  color: VineTheme.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
          decoration: InputDecoration(
            isCollapsed: true,
            hintText: context.l10n.profileSetupBioHint,
            hintStyle: profileFieldHintStyle,
            border: profileFieldBorder,
            enabledBorder: profileFieldBorder,
            focusedBorder: profileFieldBorder,
            errorBorder: profileFieldBorder,
            focusedErrorBorder: profileFieldBorder,
            contentPadding: const EdgeInsets.all(16),
            counterText: '',
          ),
          maxLines: null,
          minLines: 1,
          maxLength: 360,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
      ],
    );
  }
}
