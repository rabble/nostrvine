import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KeycastLoginButton extends ConsumerWidget {
  const KeycastLoginButton({super.key, required this.enabled});

  final bool enabled;

  Future<void> _handleKeycastLogin(BuildContext context, WidgetRef ref) async {
    try {
      throw 'Keycast login not implemented yet';
      // final oauth = ref.read(oauthClientProvider);

      // // 1. Generate Auth URL and PKCE verifier
      // final (url, verifier) = oauth.getAuthorizationUrl(
      //   scope: 'policy:social',
      //   defaultRegister: true,
      // );

      // // 2. Store verifier for token exchange when the app resumes
      // // Assuming pendingVerifierProvider is defined in your app_providers.dart
      // ref.read(pendingVerifierProvider.notifier).state = verifier;

      // // 3. Launch the system browser
      // final uri = Uri.parse(url);
      // if (await canLaunchUrl(uri)) {
      //   await launchUrl(uri, mode: LaunchMode.externalApplication);
      // } else {
      //   throw 'Could not launch browser';
      // }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Keycast Error: $e'),
            backgroundColor: Colors.black.withValues(alpha: 0.8),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.cloud_outlined),
        label: const Text(
          'Login with Keycast Account',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        onPressed: enabled ? () => _handleKeycastLogin(context, ref) : null,
        style:
            OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ).copyWith(
              side: WidgetStateProperty.resolveWith<BorderSide>((states) {
                if (states.contains(WidgetState.disabled)) {
                  return BorderSide(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 2,
                  );
                }
                return const BorderSide(color: Colors.white, width: 2);
              }),
            ),
      ),
    );
  }
}
