// ABOUTME: Dialog widget for requesting reserved usernames
// ABOUTME: Collects email and justification, submits via Riverpod notifier

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/reserved_username_request_notifier.dart';
import 'package:openvine/state/reserved_username_request_state.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Dialog for requesting a reserved username
///
/// Shows a form with the reserved username (read-only), email field,
/// and justification field. Submits via [ReservedUsernameRequestNotifier].
class ReservedUsernameRequestDialog extends ConsumerStatefulWidget {
  const ReservedUsernameRequestDialog({
    super.key,
    required this.username,
  });

  /// The reserved username being requested
  final String username;

  @override
  ConsumerState<ReservedUsernameRequestDialog> createState() =>
      _ReservedUsernameRequestDialogState();
}

class _ReservedUsernameRequestDialogState
    extends ConsumerState<ReservedUsernameRequestDialog> {
  final _emailController = TextEditingController();
  final _justificationController = TextEditingController();
  bool _isDisposed = false;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    // Initialize the notifier with the username
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Reset state first, then set username
        ref.read(reservedUsernameRequestProvider.notifier).reset();
        ref
            .read(reservedUsernameRequestProvider.notifier)
            .setUsername(widget.username);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _closeTimer?.cancel();
    _emailController.dispose();
    _justificationController.dispose();
    // Note: We don't reset the notifier here to avoid using ref in dispose
    // The notifier will be reset when the dialog is reopened
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final notifier = ref.read(reservedUsernameRequestProvider.notifier);

    // Update notifier with current field values
    notifier.setEmail(_emailController.text);
    notifier.setJustification(_justificationController.text);

    final success = await notifier.submitRequest();

    if (success && !_isDisposed && mounted) {
      // Close dialog after delay on success
      _closeTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!_isDisposed && mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reservedUsernameRequestProvider);

    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text(
        'Request Reserved Username',
        style: TextStyle(color: VineTheme.whiteText),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Username field (read-only)
              TextField(
                readOnly: true,
                controller: TextEditingController(text: widget.username),
                style: const TextStyle(color: VineTheme.whiteText),
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.lock, color: Colors.orange.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade900,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Email field
              TextField(
                controller: _emailController,
                enabled: !state.isSubmitting && !state.isSuccess,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: VineTheme.whiteText),
                decoration: InputDecoration(
                  labelText: 'Your Email',
                  labelStyle: TextStyle(color: Colors.grey.shade400),
                  hintText: 'We\'ll contact you about your request',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  border: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: VineTheme.vineGreen),
                  ),
                  errorText: _emailController.text.isNotEmpty &&
                          !_isValidEmail(_emailController.text)
                      ? 'Please enter a valid email'
                      : null,
                  errorStyle: const TextStyle(color: Colors.red),
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 16),

              // Justification field
              TextField(
                controller: _justificationController,
                enabled: !state.isSubmitting && !state.isSuccess,
                maxLines: 4,
                style: const TextStyle(color: VineTheme.whiteText),
                decoration: InputDecoration(
                  labelText: 'Why should you have this username?',
                  labelStyle: TextStyle(color: Colors.grey.shade400),
                  hintText:
                      'Explain your connection to this name (e.g., brand owner, public figure, original creator)',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: VineTheme.vineGreen),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 16),

              // Loading indicator
              if (state.isSubmitting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      color: VineTheme.vineGreen,
                    ),
                  ),
                ),

              // Success message
              if (state.isSuccess)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VineTheme.vineGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: VineTheme.vineGreen,
                    ),
                  ),
                  child: const Text(
                    'Request submitted! We\'ll review it and contact you at the email provided.',
                    style: TextStyle(color: VineTheme.vineGreen),
                  ),
                ),

              // Error message
              if (state.hasError && state.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        // Cancel button (hide after success)
        if (!state.isSuccess)
          TextButton(
            onPressed:
                state.isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),

        // Submit/Close button
        ElevatedButton(
          onPressed: state.isSuccess
              ? () => Navigator.of(context).pop()
              : (_canSubmit(state) ? _submitRequest : null),
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.vineGreen,
            foregroundColor: VineTheme.whiteText,
          ),
          child: Text(state.isSuccess ? 'Close' : 'Submit Request'),
        ),
      ],
    );
  }

  bool _canSubmit(ReservedUsernameRequestState state) {
    return !state.isSubmitting &&
        _emailController.text.isNotEmpty &&
        _isValidEmail(_emailController.text) &&
        _justificationController.text.isNotEmpty;
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    return emailRegex.hasMatch(email);
  }
}
