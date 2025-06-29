// ABOUTME: Profile setup screen for new users to configure their display name, bio, and avatar
// ABOUTME: Publishes initial profile metadata to Nostr after setup is complete

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../services/nostr_service_interface.dart';
import '../services/direct_upload_service.dart';
import '../services/nip05_service.dart';
import '../utils/unified_logger.dart';
import '../utils/async_utils.dart';

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
  final _nip05Controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  bool _isPublishing = false;
  bool _isUploadingImage = false;
  bool _isCheckingUsername = false;
  bool? _usernameAvailable;
  String? _usernameError;
  File? _selectedImage;
  String? _uploadedImageUrl;

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
    _nip05Controller.dispose();
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
              
              // Extract username from NIP-05 if present
              if (profile.nip05 != null && profile.nip05!.endsWith('@openvine.co')) {
                final username = profile.nip05!.split('@')[0];
                _nip05Controller.text = username;
                _usernameAvailable = true; // Already registered
              }
            });
          }
        }
      } catch (e) {
        Log.error('Failed to load existing profile: $e', name: 'ProfileSetupScreen', category: LogCategory.ui);
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
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside text fields
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                    widget.isNewUser 
                        ? 'Welcome to OpenVine!'
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
                  autofocus: true, // Automatically focus on first field
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
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[700]!, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.person, color: Colors.grey),
                  ),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
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
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[700]!, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.info_outline, color: Colors.grey),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  maxLength: 160,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                const SizedBox(height: 16),

                // NIP-05 Username (optional)
                TextFormField(
                  controller: _nip05Controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Username (Optional)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'username',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[700]!, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.verified_user, color: Colors.grey),
                    suffixText: '@openvine.co',
                    suffixStyle: TextStyle(color: Colors.grey[500]),
                    errorMaxLines: 2,
                  ),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  onChanged: _onUsernameChanged,
                  validator: (value) {
                    if (value == null || value.isEmpty) return null; // Optional field
                    
                    final regex = RegExp(r'^[a-z0-9\-_.]+$', caseSensitive: false);
                    if (!regex.hasMatch(value)) {
                      return 'Username can only contain letters, numbers, dash, underscore, and dot';
                    }
                    if (value.length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    if (value.length > 20) {
                      return 'Username must be 20 characters or less';
                    }
                    if (_usernameError != null) {
                      return _usernameError;
                    }
                    return null;
                  },
                ),
                if (_isCheckingUsername)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Checking availability...',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                if (_usernameAvailable == true && !_isCheckingUsername && _nip05Controller.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Username available!',
                          style: TextStyle(color: Colors.green[400], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Profile Picture Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Picture (Optional)',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Stack(
                        children: [
                          // Profile picture preview
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[800],
                              border: Border.all(
                                color: _selectedImage != null || _uploadedImageUrl != null || _pictureController.text.isNotEmpty
                                    ? Colors.purple
                                    : Colors.grey[700]!,
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: _buildProfilePicturePreview(),
                            ),
                          ),
                          // Upload progress indicator
                          if (_isUploadingImage)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.7),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.purple,
                                    strokeWidth: 3,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Image source buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isUploadingImage ? null : () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt, size: 20),
                          label: const Text('Camera'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey[700]!),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _isUploadingImage ? null : () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library, size: 20),
                          label: const Text('Gallery'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey[700]!),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // URL input option
                    ExpansionTile(
                      title: Text(
                        'Or paste image URL',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                      tilePadding: EdgeInsets.zero,
                      children: [
                        TextFormField(
                          controller: _pictureController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'https://example.com/your-avatar.jpg',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[700]!, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.purple, width: 2),
                            ),
                            prefixIcon: const Icon(Icons.link, color: Colors.grey),
                          ),
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}), // Update preview
                          onFieldSubmitted: (_) => _publishProfile(),
                          keyboardType: TextInputType.url,
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
                      ],
                    ),
                  ],
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
                
                const SizedBox(height: 32),

                // Nostr explanation for new users
                if (widget.isNewUser)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.public, color: Colors.purple),
                            const SizedBox(width: 8),
                            const Text(
                              'Built on Nostr',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'OpenVine uses Nostr, a decentralized protocol where YOU own your identity and data. Unlike centralized platforms, no single company controls your account.',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.key, color: Colors.purple, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Your Identity Key (nsec)',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'We\'ve created a secure private key for you. Back it up in Profile > Settings to use your account in other Nostr apps.',
                                      style: TextStyle(
                                        color: Colors.grey[300],
                                        fontSize: 12,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () async {
                            final Uri url = Uri.parse('https://nostr.org');
                            try {
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
                            } catch (e) {
                              Log.debug('Could not launch nostr.org: $e', name: 'ProfileSetupScreen', category: LogCategory.ui);
                            }
                          },
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[300], size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Learn more about Nostr →',
                                style: TextStyle(
                                  color: Colors.blue[300],
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
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
        ),
      ),
    );
  }

  Future<void> _publishProfile() async {
    Log.info('🚀 Starting profile publish...', name: 'ProfileSetupScreen', category: LogCategory.ui);
    
    if (!_formKey.currentState!.validate()) {
      Log.warning('Form validation failed', name: 'ProfileSetupScreen', category: LogCategory.ui);
      return;
    }

    setState(() {
      _isPublishing = true;
    });

    try {
      final authService = context.read<AuthService>();
      final nostrService = context.read<INostrService>();
      final userProfileService = context.read<UserProfileService>();
      
      Log.info('Auth status: isAuthenticated=${authService.isAuthenticated}, publicKey=${authService.currentPublicKeyHex != null}', 
               name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('NostrService status: isInitialized=${nostrService.isInitialized}, connectedRelays=${nostrService.connectedRelays.length}', 
               name: 'ProfileSetupScreen', category: LogCategory.ui);
      
      // Log existing profile before update
      final currentPubkey = authService.currentPublicKeyHex!;
      final existingProfile = userProfileService.getCachedProfile(currentPubkey);
      if (existingProfile != null) {
        Log.info('📋 Existing profile before update:', name: 'ProfileSetupScreen', category: LogCategory.ui);
        Log.info('  - name: ${existingProfile.name}', name: 'ProfileSetupScreen', category: LogCategory.ui);
        Log.info('  - displayName: ${existingProfile.displayName}', name: 'ProfileSetupScreen', category: LogCategory.ui);
        Log.info('  - about: ${existingProfile.about}', name: 'ProfileSetupScreen', category: LogCategory.ui);
        Log.info('  - picture: ${existingProfile.picture}', name: 'ProfileSetupScreen', category: LogCategory.ui);
        Log.info('  - eventId: ${existingProfile.eventId}', name: 'ProfileSetupScreen', category: LogCategory.ui);
      } else {
        Log.info('📋 No existing profile found for ${currentPubkey.substring(0, 8)}...', name: 'ProfileSetupScreen', category: LogCategory.ui);
      }
      
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
      
      Log.info('📝 Profile data to publish:', name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - name: ${profileData['name']}', name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - about: ${profileData['about'] ?? 'not set'}', name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - picture: ${profileData['picture'] ?? 'not set'}', name: 'ProfileSetupScreen', category: LogCategory.ui);
      
      // Handle NIP-05 registration if username provided
      String? nip05Identifier;
      if (_nip05Controller.text.trim().isNotEmpty && _usernameAvailable == true) {
        try {
          final nip05Service = Nip05Service();
          final username = _nip05Controller.text.trim();
          final nostrService = context.read<INostrService>();
          final relays = nostrService.connectedRelays.toList();
          
          final registered = await nip05Service.registerUsername(
            username,
            authService.currentPublicKeyHex!,
            relays,
          );
          
          if (registered) {
            nip05Identifier = '$username@openvine.co';
            profileData['nip05'] = nip05Identifier;
          }
        } catch (e) {
          Log.error('Failed to register NIP-05: $e', name: 'ProfileSetupScreen', category: LogCategory.ui);
          // Continue with profile creation even if NIP-05 fails
        }
      }

      // Create NIP-01 kind 0 profile event
      Log.info('🔨 Creating kind 0 event...', name: 'ProfileSetupScreen', category: LogCategory.ui);
      
      final event = await authService.createAndSignEvent(
        kind: 0,
        content: jsonEncode(profileData),
      );
      
      if (event == null) {
        Log.error('❌ Failed to create profile event - createAndSignEvent returned null', name: 'ProfileSetupScreen', category: LogCategory.ui);
        throw Exception('Failed to create profile event');
      }

      // Log the created event
      Log.info('✅ Created kind 0 event:', name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - Event ID: ${event.id}', name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - Pubkey: ${event.pubkey}', name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - Kind: ${event.kind}', name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - Content: ${event.content}', name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - Created at: ${event.createdAt}', name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - Signature: ${event.sig}', name: 'ProfileSetupScreen', category: LogCategory.ui);
      Log.info('  - Tags: ${event.tags}', name: 'ProfileSetupScreen', category: LogCategory.ui);
      
      // Check if event is valid
      final isValid = event.isSigned;
      Log.info('🔍 Event signature valid: $isValid', name: 'ProfileSetupScreen', category: LogCategory.ui);

      // Publish to Nostr relays
      Log.info('📡 Publishing profile event to Nostr relays...', name: 'ProfileSetupScreen', category: LogCategory.ui);
      
      final result = await nostrService.broadcastEvent(event);
      final success = result.isSuccessful;
      
      Log.info('Broadcast result: success=$success, successCount=${result.successCount}/${result.totalRelays}', 
               name: 'ProfileSetupScreen', category: LogCategory.ui);
      if (result.errors.isNotEmpty) {
        Log.error('Broadcast errors: ${result.errors}', name: 'ProfileSetupScreen', category: LogCategory.ui);
      }
      
      // Immediate verification: try to query the event back from relay
      Log.info('🔍 Immediate verification: checking if event was actually stored...', name: 'ProfileSetupScreen', category: LogCategory.ui);
      await Future.delayed(const Duration(seconds: 1)); // Brief delay to let relay process
      
      try {
        final verificationProfile = await userProfileService.fetchProfile(currentPubkey, forceRefresh: true);
        if (verificationProfile != null) {
          Log.info('✅ Immediate verification: found profile with event ID ${verificationProfile.eventId}', name: 'ProfileSetupScreen', category: LogCategory.ui);
          if (verificationProfile.eventId == event.id) {
            Log.info('🎯 Immediate verification: Event ID matches! Relay stored our event correctly.', name: 'ProfileSetupScreen', category: LogCategory.ui);
          } else {
            Log.warning('⚠️ Immediate verification: Event ID mismatch. Expected ${event.id}, got ${verificationProfile.eventId}', name: 'ProfileSetupScreen', category: LogCategory.ui);
          }
        } else {
          Log.warning('⚠️ Immediate verification: No profile found. Relay may have rejected the event.', name: 'ProfileSetupScreen', category: LogCategory.ui);
        }
      } catch (e) {
        Log.error('❌ Immediate verification failed: $e', name: 'ProfileSetupScreen', category: LogCategory.ui);
      }
      
      // Add delay to give relay time to process (temporary debugging)
      Log.info('⏳ Waiting 2 seconds for relay to process event...', name: 'ProfileSetupScreen', category: LogCategory.ui);
      await Future.delayed(const Duration(seconds: 2));

      if (success) {
        // Force refresh the user's profile in auth service
        if (mounted) {
          Log.info('🔄 Attempting to force refresh profile after successful broadcast...', 
                   name: 'ProfileSetupScreen', category: LogCategory.ui);
          
          final userProfileService = context.read<UserProfileService>();
          final beforeRefreshProfile = userProfileService.getCachedProfile(currentPubkey);
          
          Log.info('📋 Profile before refresh:', name: 'ProfileSetupScreen', category: LogCategory.ui);
          if (beforeRefreshProfile != null) {
            Log.info('  - name: ${beforeRefreshProfile.name}', name: 'ProfileSetupScreen', category: LogCategory.ui);
            Log.info('  - about: ${beforeRefreshProfile.about}', name: 'ProfileSetupScreen', category: LogCategory.ui);
            Log.info('  - eventId: ${beforeRefreshProfile.eventId}', name: 'ProfileSetupScreen', category: LogCategory.ui);
          } else {
            Log.info('  - No cached profile', name: 'ProfileSetupScreen', category: LogCategory.ui);
          }
          
          // Use proper retry logic to wait for relay to process the new event
          Log.info('🔄 Using retry logic to wait for relay to process profile update...', 
                   name: 'ProfileSetupScreen', category: LogCategory.ui);
          
          final refreshedProfile = await AsyncUtils.retryWithBackoff(
            operation: () async {
              Log.info('🔄 Retry attempt: clearing cache and fetching profile...', 
                       name: 'ProfileSetupScreen', category: LogCategory.ui);
              
              // Log current relay status
              final relayStatus = nostrService.getRelayStatus();
              Log.info('🔗 Current relay status: $relayStatus', name: 'ProfileSetupScreen', category: LogCategory.ui);
              
              userProfileService.removeProfile(currentPubkey);
              final profile = await userProfileService.fetchProfile(currentPubkey, forceRefresh: true);
              
              Log.info('📋 Profile fetch result:', name: 'ProfileSetupScreen', category: LogCategory.ui);
              Log.info('  - Expected event ID: ${event.id}', name: 'ProfileSetupScreen', category: LogCategory.ui);
              Log.info('  - Expected timestamp: ${event.createdAt} (${DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000)})', name: 'ProfileSetupScreen', category: LogCategory.ui);
              if (profile != null) {
                Log.info('  - Fetched profile event ID: ${profile.eventId}', name: 'ProfileSetupScreen', category: LogCategory.ui);
                Log.info('  - Fetched profile timestamp: ${profile.createdAt.millisecondsSinceEpoch ~/ 1000} (${profile.createdAt})', name: 'ProfileSetupScreen', category: LogCategory.ui);
                Log.info('  - Profile name: ${profile.name}', name: 'ProfileSetupScreen', category: LogCategory.ui);
                Log.info('  - Profile about: ${profile.about}', name: 'ProfileSetupScreen', category: LogCategory.ui);
              } else {
                Log.warning('  - Profile is null', name: 'ProfileSetupScreen', category: LogCategory.ui);
              }
              
              // Verify we got the updated profile by checking event ID or timestamp
              final eventIdMatches = profile?.eventId == event.id;
              final timestampMatches = profile?.createdAt != null && 
                                     profile!.createdAt.millisecondsSinceEpoch >= (event.createdAt * 1000 - 1000);
              
              Log.info('🔍 Profile validation:', name: 'ProfileSetupScreen', category: LogCategory.ui);
              Log.info('  - Event ID matches: $eventIdMatches', name: 'ProfileSetupScreen', category: LogCategory.ui);
              Log.info('  - Timestamp valid: $timestampMatches', name: 'ProfileSetupScreen', category: LogCategory.ui);
              
              if (eventIdMatches || timestampMatches) {
                Log.info('✅ Profile validation passed - using fetched profile', name: 'ProfileSetupScreen', category: LogCategory.ui);
                return profile;
              }
              
              Log.warning('❌ Profile validation failed - relay hasn\'t processed new event yet', name: 'ProfileSetupScreen', category: LogCategory.ui);
              throw Exception('Profile not yet updated on relay - retrying...');
            },
            maxRetries: 3,
            baseDelay: const Duration(seconds: 1),
            debugName: 'profile-refresh-after-publish',
          );
          
          // Check what we got back
          if (refreshedProfile != null) {
            Log.info('✅ Profile refreshed successfully:', name: 'ProfileSetupScreen', category: LogCategory.ui);
            Log.info('  - name: ${refreshedProfile.name}', name: 'ProfileSetupScreen', category: LogCategory.ui);
            Log.info('  - about: ${refreshedProfile.about}', name: 'ProfileSetupScreen', category: LogCategory.ui);
            Log.info('  - eventId: ${refreshedProfile.eventId}', name: 'ProfileSetupScreen', category: LogCategory.ui);
          } else {
            Log.warning('⚠️ fetchProfile returned null after refresh', name: 'ProfileSetupScreen', category: LogCategory.ui);
            
            // Check cache again
            final afterRefreshProfile = userProfileService.getCachedProfile(currentPubkey);
            if (afterRefreshProfile != null) {
              Log.info('📋 But profile IS in cache after refresh:', name: 'ProfileSetupScreen', category: LogCategory.ui);
              Log.info('  - name: ${afterRefreshProfile.name}', name: 'ProfileSetupScreen', category: LogCategory.ui);
              Log.info('  - about: ${afterRefreshProfile.about}', name: 'ProfileSetupScreen', category: LogCategory.ui);
              Log.info('  - eventId: ${afterRefreshProfile.eventId}', name: 'ProfileSetupScreen', category: LogCategory.ui);
            } else {
              Log.error('❌ Profile NOT in cache after refresh', name: 'ProfileSetupScreen', category: LogCategory.ui);
            }
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile published successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
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
          if (mounted) {
            Navigator.of(context).pop(true); // Return true to indicate success
          }
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
  
  Widget _buildProfilePicturePreview() {
    // Priority: selected image > uploaded URL > manual URL > placeholder
    if (_selectedImage != null) {
      return Image.file(
        _selectedImage!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
      );
    } else if (_uploadedImageUrl != null) {
      return Image.network(
        _uploadedImageUrl!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.person, color: Colors.grey, size: 50);
        },
      );
    } else if (_pictureController.text.isNotEmpty) {
      return Image.network(
        _pictureController.text,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.person, color: Colors.grey, size: 50);
        },
      );
    } else {
      return const Icon(Icons.person, color: Colors.grey, size: 50);
    }
  }
  
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _uploadedImageUrl = null; // Clear previous upload
          _pictureController.clear(); // Clear manual URL
        });
        
        // Upload the image
        await _uploadImage();
      }
    } catch (e) {
      Log.error('Error picking image: $e', name: 'ProfileSetupScreen', category: LogCategory.ui);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;
    
    setState(() {
      _isUploadingImage = true;
    });
    
    try {
      final authService = context.read<AuthService>();
      final uploadService = DirectUploadService();
      
      if (authService.currentPublicKeyHex == null) {
        throw Exception('No public key available');
      }
      
      final result = await uploadService.uploadProfilePicture(
        imageFile: _selectedImage!,
        nostrPubkey: authService.currentPublicKeyHex!,
        onProgress: (progress) {
          Log.debug('Upload progress: ${(progress * 100).toStringAsFixed(0)}%', name: 'ProfileSetupScreen', category: LogCategory.ui);
        },
      );
      
      if (result.success && result.cdnUrl != null) {
        setState(() {
          _uploadedImageUrl = result.cdnUrl;
          _pictureController.text = result.cdnUrl!;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(result.errorMessage ?? 'Upload failed');
      }
    } catch (e) {
      Log.error('Error uploading image: $e', name: 'ProfileSetupScreen', category: LogCategory.ui);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Timer? _usernameCheckTimer;

  void _onUsernameChanged(String value) {
    // Cancel any existing timer
    _usernameCheckTimer?.cancel();
    
    // Reset state
    setState(() {
      _usernameAvailable = null;
      _usernameError = null;
    });
    
    // Don't check if empty or too short
    if (value.isEmpty || value.length < 3) {
      return;
    }
    
    // Validate format locally first
    final regex = RegExp(r'^[a-z0-9\-_.]+$', caseSensitive: false);
    if (!regex.hasMatch(value)) {
      return;
    }
    
    // Debounce the check
    _usernameCheckTimer = Timer(const Duration(milliseconds: 500), () {
      _checkUsernameAvailability(value);
    });
  }
  
  Future<void> _checkUsernameAvailability(String username) async {
    setState(() {
      _isCheckingUsername = true;
    });
    
    try {
      final nip05Service = Nip05Service();
      final isAvailable = await nip05Service.checkUsernameAvailability(username);
      
      if (mounted) {
        setState(() {
          _usernameAvailable = isAvailable;
          _usernameError = isAvailable ? null : 'Username already taken';
          _isCheckingUsername = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _usernameError = 'Failed to check username';
          _isCheckingUsername = false;
        });
      }
    }
  }
}