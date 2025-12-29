// ABOUTME: Dialog widget for requesting reserved usernames
// ABOUTME: Collects email and justification, submits via Riverpod notifier

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/reserved_username_request_notifier.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Dialog for requesting a reserved username
///
/// Shows a form with the reserved username (read-only), email field,
/// and justification field. Submits via [ReservedUsernameRequestNotifier].
class ReservedUsernameRequestDialog extends ConsumerWidget {
  const ReservedUsernameRequestDialog({super.key, required this.username});

  /// The reserved username being requested
  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reservedUsernameRequestProvider);
    final notifier = ref.read(reservedUsernameRequestProvider.notifier);

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
              InputDecorator(
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
                child: Text(
                  username,
                  style: const TextStyle(
                    fontSize: 16,
                    color: VineTheme.whiteText,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                enabled: !state.isSubmitting && !state.isSuccess,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: VineTheme.whiteText),
                decoration: InputDecoration(
                  labelText: 'Your Email',
                  labelStyle: TextStyle(color: Colors.grey.shade400),
                  hintText: 'We\'ll contact you here',
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
                  errorText: !notifier.isEmailValid
                      ? 'Please enter a valid email'
                      : null,
                  errorStyle: const TextStyle(color: Colors.red),
                ),
                onChanged: (value) => notifier.setEmail(value),
              ),

              const SizedBox(height: 16),

              TextField(
                enabled: !state.isSubmitting && !state.isSuccess,
                maxLines: 4,
                style: const TextStyle(color: VineTheme.whiteText),
                decoration: InputDecoration(
                  labelText: 'Reason for Request',
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
                onChanged: (value) => notifier.setJustification(value),
              ),

              const SizedBox(height: 16),

              if (state.isSubmitting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      color: VineTheme.vineGreen,
                    ),
                  ),
                ),

              if (state.isSuccess)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VineTheme.vineGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: VineTheme.vineGreen),
                  ),
                  child: const Text(
                    'Request submitted! We\'ll review it and contact you at the email provided.',
                    style: TextStyle(color: VineTheme.vineGreen),
                  ),
                ),

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
        if (!state.isSuccess)
          TextButton(
            onPressed: state.isSubmitting
                ? null
                : () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),

        ElevatedButton(
          onPressed: state.isSuccess
              ? () => Navigator.of(context).pop()
              : (notifier.canSubmit
                    ? () => notifier.submitRequest(username: username.trim())
                    : null),
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.vineGreen,
            foregroundColor: VineTheme.whiteText,
          ),
          child: Text(state.isSuccess ? 'Close' : 'Submit Request'),
        ),
      ],
    );
  }
}
