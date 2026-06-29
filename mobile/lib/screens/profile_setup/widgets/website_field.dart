import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_field_decorations.dart';

class WebsiteField extends StatefulWidget {
  const WebsiteField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  State<WebsiteField> createState() => _WebsiteFieldState();
}

class _WebsiteFieldState extends State<WebsiteField> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: 16,
          ),
          child: Text(
            context.l10n.profileSetupWebsiteLabel,
            style: VineTheme.labelMediumFont(
              color: _focusNode.hasFocus
                  ? VineTheme.primary
                  : VineTheme.onSurfaceMuted,
            ),
          ),
        ),
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          style: VineTheme.bodyLargeFont(
            color: VineTheme.onSurface,
          ),
          decoration: InputDecoration(
            isCollapsed: true,
            hintText: context.l10n.profileSetupWebsiteHint,
            hintStyle: profileFieldHintStyle,
            border: profileFieldBorder,
            enabledBorder: profileFieldBorder,
            focusedBorder: profileFieldBorder,
            errorBorder: profileFieldBorder,
            focusedErrorBorder: profileFieldBorder,
            contentPadding: const EdgeInsets.all(16),
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
      ],
    );
  }
}
