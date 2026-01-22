// ABOUTME: Screen to handle email verification deep links
// ABOUTME: Receives token from verify-email URL and processes verification

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/unified_logger.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  /// Route name for navigation
  static const String routeName = 'verify-email';

  /// Path for navigation
  static const String path = '/verify-email';

  const EmailVerificationScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _isLoading = true;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _verifyEmail();
  }

  Future<void> _verifyEmail() async {
    Log.info(
      'Processing email verification token',
      name: 'EmailVerificationScreen',
      category: LogCategory.auth,
    );

    // TODO delete delay after testing
    await Future.delayed(const Duration(seconds: 7));

    final oauth = ref.read(oauthClientProvider);
    final result = await oauth.verifyEmail(token: widget.token);

    if (!mounted) return;

    if (result.success) {
      Log.info(
        'Email verification successful',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
    } else {
      Log.warning(
        'Email verification failed: ${result.error}',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _errorMessage = result.error ?? result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red,
              Colors.purple,
            ], //[VineTheme.vineGreen, Color(0xFF2D8B6F)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 24),
          Text(
            'Verifying your email...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (_isSuccess) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 80),
          const SizedBox(height: 24),
          const Text(
            'Email Verified!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your email has been successfully verified.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => context.go('/'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: VineTheme.vineGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }

    // Error state
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 80),
        const SizedBox(height: 24),
        const Text(
          'Verification Failed',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _errorMessage ?? 'Unable to verify your email. Please try again.',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => context.go('/'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: VineTheme.vineGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Go Back',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
