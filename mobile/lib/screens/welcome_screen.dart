// ABOUTME: Welcome screen for new users with onboarding flow for Nostr identity setup
// ABOUTME: Provides options to create new identity or import existing keys

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'key_import_screen.dart';
import 'profile_setup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App branding
              const Icon(
                Icons.video_library,
                size: 80,
                color: Colors.purple,
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome to NostrVine',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Create and share short videos on the decentralized web',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Main action buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _createNewIdentity(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Create New Identity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _importExistingIdentity(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Import Existing Identity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Educational content
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.purple,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'What is Nostr?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nostr is a decentralized protocol that gives you control over your data and identity. Your identity is portable across all Nostr apps.',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createNewIdentity(BuildContext context) async {
    final authService = context.read<AuthService>();
    
    // Generate new identity
    final result = await authService.createNewIdentity();
    
    if (result.success && context.mounted) {
      // Navigate to profile setup
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ProfileSetupScreen(isNewUser: true),
        ),
      );
    } else if (context.mounted) {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Failed to create identity'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _importExistingIdentity(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const KeyImportScreen(),
      ),
    );
  }
}