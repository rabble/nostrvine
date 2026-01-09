import 'package:flutter/material.dart';

class VideoEditorMetaInput extends StatelessWidget {
  const VideoEditorMetaInput({
    super.key,
    required this.label,
    required this.placeholder,
    required this.controller,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = .none,
    this.minLines,
    this.maxLines,
    this.onSubmitted,
  });

  final String label;
  final String placeholder;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF070708),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 16),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 4,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'BricolageGrotesque',
              fontWeight: .w800,
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: 0.1,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          TextField(
            controller: controller,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: .w400,
              fontSize: 18,
              height: 24 / 18,
              letterSpacing: 0.15,
              color: Colors.white,
            ),
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization,
            minLines: minLines,
            maxLines: maxLines,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(
                fontFamily: 'Inter',
                fontWeight: .w400,
                fontSize: 18,
                height: 24 / 18,
                letterSpacing: 0.15,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              border: .none,
              contentPadding: .zero,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
