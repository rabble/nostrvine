// ABOUTME: Profile setup screen for new users to configure their display name, bio, and avatar
// ABOUTME: Publishes initial profile metadata to Nostr after setup is complete

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../services/nostr_service_interface.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isNewUser;
  
  const ProfileSetupScreen({
    super.key,
    required this.isNewUser,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _pictureController = TextEditingController();
  
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _pictureController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    if (!widget.isNewUser) {
      // For imported users, try to load their existing profile
      try {
        final userProfileService = context.read<UserProfileService>();
        final authService = context.read<AuthService>();
        
        if (authService.currentPublicKeyHex != null) {
          final profile = await userProfileService.fetchProfile(authService.currentPublicKeyHex!);
          if (profile != null && mounted) {
            setState(() {
              _nameController.text = profile.displayName ?? '';
              _bioController.text = profile.about ?? '';
              _pictureController.text = profile.picture ?? '';
            });
          }
        }
      } catch (e) {
        debugPrint('Failed to load existing profile: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.isNewUser ? 'Set Up Profile' : 'Update Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Don't show back button for setup flow
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isNewUser 
                      ? 'Welcome to NostrVine!'
                      : 'Update Your Profile',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isNewUser
                      ? 'Let\'s set up your profile to get started'
                      : 'Your profile information will be published to Nostr',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[300],
                  ),
                ),
                const SizedBox(height: 32),

                // Display Name
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'How should people know you?',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.person, color: Colors.grey),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a display name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Bio
                TextFormField(
                  controller: _bioController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Bio (Optional)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'Tell people about yourself...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.info_outline, color: Colors.grey),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  maxLength: 160,
                ),
                const SizedBox(height: 16),

                // Profile Picture URL
                TextFormField(
                  controller: _pictureController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Profile Picture URL (Optional)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'https://example.com/your-avatar.jpg',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.image, color: Colors.grey),
                  ),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      // Basic URL validation
                      final uri = Uri.tryParse(value.trim());
                      if (uri == null || !uri.hasAbsolutePath) {
                        return 'Please enter a valid URL';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Action buttons
                Row(
                  children: [
                    if (!widget.isNewUser)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isPublishing ? null : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                    if (!widget.isNewUser) const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isPublishing ? null : _publishProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isPublishing
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Publishing...'),
                                ],
                              )
                            : Text(
                                widget.isNewUser ? 'Get Started' : 'Update Profile',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Skip option for new users
                if (widget.isNewUser)
                  Center(
                    child: TextButton(
                      onPressed: _isPublishing ? null : _skipProfileSetup,
                      child: Text(
                        'Skip for now',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                
                const Spacer(),

                // Key info for new users
                if (widget.isNewUser)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.key, color: Colors.purple),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Identity',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'We\'ve created a secure identity for you. You can view and backup your keys in Profile > Settings.',
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _publishProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isPublishing = true;
    });

    try {
      final authService = context.read<AuthService>();
      final nostrService = context.read<INostrService>();
      
      // Create profile metadata
      final profileData = <String, dynamic>{
        'name': _nameController.text.trim(),
      };
      
      if (_bioController.text.trim().isNotEmpty) {
        profileData['about'] = _bioController.text.trim();
      }
      
      if (_pictureController.text.trim().isNotEmpty) {
        profileData['picture'] = _pictureController.text.trim();
      }

      // Create NIP-01 kind 0 profile event
      final event = await authService.createAndSignEvent(
        kind: 0,
        content: jsonEncode(profileData),
      );
      
      if (event == null) {
        throw Exception('Failed to create profile event');
      }

      // Publish to Nostr relays
      final result = await nostrService.broadcastEvent(event);
      final success = result.isSuccessful;

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile published successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back or to main app
        if (widget.isNewUser) {
          // For new users, wait a moment to show success message, then navigate to main app
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            // Navigate to main app by popping back to the auth flow
            // The auth service should already be in authenticated state
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        } else {
          Navigator.of(context).pop();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to publish profile. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error publishing profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  void _skipProfileSetup() {
    if (widget.isNewUser) {
      // For new users, navigate back to the auth flow
      // The auth service should already be in authenticated state
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      // For existing users, just go back to previous screen
      Navigator.of(context).pop();
    }
  }
}