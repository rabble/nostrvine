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
                
                const Spacer(),

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
                              debugPrint('Could not launch nostr.org: $e');
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
          debugPrint('Failed to register NIP-05: $e');
          // Continue with profile creation even if NIP-05 fails
        }
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

      if (success) {
        // Force refresh the user's profile in auth service
        if (mounted) {
          final userProfileService = context.read<UserProfileService>();
          await userProfileService.fetchProfile(authService.currentPublicKeyHex!);
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
      debugPrint('Error picking image: $e');
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
          debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
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
      debugPrint('Error uploading image: $e');
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