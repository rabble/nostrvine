// ABOUTME: Support form text field that caps its length and says when it did
// ABOUTME: Keeps a silently truncated paste from looking like an accepted one

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvine/l10n/l10n.dart';

/// A [DivineTextField] with a hard character cap that tells the user when the
/// cap dropped what they pasted.
///
/// The cap exists because sanitization runs on the main isolate and its cost
/// scales with field size; without it a large paste freezes submission. It is
/// applied as an input formatter rather than `maxLength` so the form does not
/// grow a Material character counter under every field, in styling the design
/// system does not own.
///
/// The formatter alone would drop the tail of a pasted crash log without
/// saying so, and that tail can be the exception the user meant to report -
/// nothing else in the payload carries it, since attachments are images only
/// and the log summary comes from in-app logs. So the helper text switches to
/// a "maximum reached" message once the field is full, which is the point at
/// which truncation is either happening or about to.
class SupportCappedTextField extends StatefulWidget {
  const SupportCappedTextField({
    required this.controller,
    required this.maxLength,
    super.key,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.helperText,
    this.enabled,
    this.minLines,
    this.maxLines,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final int maxLength;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final bool? enabled;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<SupportCappedTextField> createState() => _SupportCappedTextFieldState();
}

class _SupportCappedTextFieldState extends State<SupportCappedTextField> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final atLimit = value.text.length >= widget.maxLength;
        return DivineTextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          labelText: widget.labelText,
          hintText: widget.hintText,
          helperText: atLimit
              ? context.l10n.supportFieldLimitReached
              : widget.helperText,
          enabled: widget.enabled,
          filled: true,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType ?? TextInputType.text,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          inputFormatters: [
            LengthLimitingTextInputFormatter(widget.maxLength),
          ],
        );
      },
    );
  }
}
