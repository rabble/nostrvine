// ABOUTME: Shared utilities for support dialogs (bug reports, feature requests)
// ABOUTME: Contains common input decoration styling for consistency

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Build consistent input decoration for support dialog text fields
InputDecoration buildSupportInputDecoration({
  required String label,
  required String hint,
  String? helper,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.grey.shade400),
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade600),
    helperText: helper,
    helperStyle: TextStyle(color: Colors.grey.shade600),
    border: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade700),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: VineTheme.vineGreen),
    ),
  );
}
