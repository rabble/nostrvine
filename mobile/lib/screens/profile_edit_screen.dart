// ABOUTME: Profile editing screen for updating user's Nostr profile metadata
// ABOUTME: Allows users to edit display name, bio, avatar, banner, website, and location

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../widgets/character_counter_widget.dart';
import '../widgets/image_picker_widget.dart';

class ProfileEditScreen extends StatefulWidget {
  final UserProfile? existingProfile;

  const ProfileEditScreen({
    super.key,
    this.existingProfile,
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Text controllers
  final _displayNameController = TextEditingController();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();
  final _locationController = TextEditingController();
  final _nip05Controller = TextEditingController();
  
  // Focus nodes
  final _displayNameFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _bioFocus = FocusNode();
  final _websiteFocus = FocusNode();
  final _locationFocus = FocusNode();
  final _nip05Focus = FocusNode();
  
  // Image files
  File? _avatarImageFile;
  File? _bannerImageFile;
  
  // State
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  
  // Character limits
  static const int _maxDisplayNameLength = 50;
  static const int _maxNameLength = 50;
  static const int _maxBioLength = 300;
  static const int _maxWebsiteLength = 200;
  static const int _maxLocationLength = 100;
  static const int _maxNip05Length = 100;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
    _setupChangeListeners();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    _locationController.dispose();
    _nip05Controller.dispose();
    
    _displayNameFocus.dispose();
    _nameFocus.dispose();
    _bioFocus.dispose();
    _websiteFocus.dispose();
    _locationFocus.dispose();
    _nip05Focus.dispose();
    
    super.dispose();
  }

  void _loadExistingProfile() {
    final profile = widget.existingProfile;
    if (profile != null) {
      _displayNameController.text = profile.displayName ?? '';
      _nameController.text = profile.name ?? '';
      _bioController.text = profile.about ?? '';
      _websiteController.text = profile.website ?? '';
      _nip05Controller.text = profile.nip05 ?? '';
      // Note: location is not in the current UserProfile model
    }
  }

  void _setupChangeListeners() {
    void markChanged() {
      if (!_hasUnsavedChanges) {
        setState(() {
          _hasUnsavedChanges = true;
        });
      }
    }

    _displayNameController.addListener(markChanged);
    _nameController.addListener(markChanged);
    _bioController.addListener(markChanged);
    _websiteController.addListener(markChanged);
    _locationController.addListener(markChanged);
    _nip05Controller.addListener(markChanged);
  }

  void _onImageChanged() {
    setState(() {
      _hasUnsavedChanges = true;
    });
  }

  Future<bool> _showUnsavedChangesDialog() async {
    if (!_hasUnsavedChanges) return true;

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Unsaved Changes',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    ) ?? false;
  }

  String? _validateUrl(String? value) {
    if (value == null || value.isEmpty) return null;
    
    try {
      final uri = Uri.parse(value);
      if (!uri.hasScheme || !['http', 'https'].contains(uri.scheme)) {
        return 'Please enter a valid URL (https://...)';
      }
      return null;
    } catch (e) {
      return 'Please enter a valid URL';
    }
  }

  String? _validateNip05(String? value) {
    if (value == null || value.isEmpty) return null;
    
    // Basic NIP-05 validation: name@domain.tld
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid NIP-05 identifier (name@domain.com)';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final userProfileService = context.read<UserProfileService>();
      
      // Create updated profile data
      final profileData = {
        'display_name': _displayNameController.text.trim(),
        'name': _nameController.text.trim(),
        'about': _bioController.text.trim(),
        'website': _websiteController.text.trim(),
        'nip05': _nip05Controller.text.trim(),
      };
      
      // TODO: Upload images and add picture/banner URLs to profileData
      // if (_avatarImageFile != null) {
      //   final avatarUrl = await _uploadImage(_avatarImageFile!);
      //   profileData['picture'] = avatarUrl;
      // }
      // if (_bannerImageFile != null) {
      //   final bannerUrl = await _uploadImage(_bannerImageFile!);
      //   profileData['banner'] = bannerUrl;
      // }
      
      // Update profile via UserProfileService
      await userProfileService.updateProfile(profileData);
      
      if (mounted) {
        final navigator = Navigator.of(context);
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        
        setState(() {
          _hasUnsavedChanges = false;
        });
        
        navigator.pop();
        
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('✅ Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving profile: $e');
      
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldPop = await _showUnsavedChangesDialog();
        if (shouldPop && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final shouldPop = await _showUnsavedChangesDialog();
              if (shouldPop && mounted) {
                navigator.pop();
              }
            },
          ),
          title: const Text(
            'Edit Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: _hasUnsavedChanges ? Colors.purple : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner Image Section
                _buildBannerSection(),
                
                const SizedBox(height: 20),
                
                // Avatar Image Section
                _buildAvatarSection(),
                
                const SizedBox(height: 32),
                
                // Display Name
                _buildTextFieldSection(
                  label: 'Display Name',
                  controller: _displayNameController,
                  focusNode: _displayNameFocus,
                  hintText: 'Your display name',
                  maxLength: _maxDisplayNameLength,
                  keyboardType: TextInputType.text,
                ),
                
                const SizedBox(height: 20),
                
                // Username
                _buildTextFieldSection(
                  label: 'Username',
                  controller: _nameController,
                  focusNode: _nameFocus,
                  hintText: 'Your username',
                  maxLength: _maxNameLength,
                  keyboardType: TextInputType.text,
                ),
                
                const SizedBox(height: 20),
                
                // Bio
                _buildTextFieldSection(
                  label: 'Bio',
                  controller: _bioController,
                  focusNode: _bioFocus,
                  hintText: 'Tell people about yourself...',
                  maxLength: _maxBioLength,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                ),
                
                const SizedBox(height: 20),
                
                // Website
                _buildTextFieldSection(
                  label: 'Website',
                  controller: _websiteController,
                  focusNode: _websiteFocus,
                  hintText: 'https://yourwebsite.com',
                  maxLength: _maxWebsiteLength,
                  keyboardType: TextInputType.url,
                  validator: _validateUrl,
                ),
                
                const SizedBox(height: 20),
                
                // Location
                _buildTextFieldSection(
                  label: 'Location',
                  controller: _locationController,
                  focusNode: _locationFocus,
                  hintText: 'Your location',
                  maxLength: _maxLocationLength,
                  keyboardType: TextInputType.text,
                ),
                
                const SizedBox(height: 20),
                
                // NIP-05 Identifier
                _buildTextFieldSection(
                  label: 'NIP-05 Identifier',
                  controller: _nip05Controller,
                  focusNode: _nip05Focus,
                  hintText: 'yourname@domain.com',
                  maxLength: _maxNip05Length,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateNip05,
                  helpText: 'NIP-05 provides verification for your profile',
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Banner Image',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ImagePickerWidget(
          imageFile: _bannerImageFile,
          placeholder: widget.existingProfile?.banner,
          aspectRatio: 3.0, // Wide banner ratio
          height: 120,
          onImageChanged: (file) {
            setState(() {
              _bannerImageFile = file;
            });
            _onImageChanged();
          },
        ),
      ],
    );
  }

  Widget _buildAvatarSection() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile Picture',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ImagePickerWidget(
              imageFile: _avatarImageFile,
              placeholder: widget.existingProfile?.picture,
              aspectRatio: 1.0, // Square aspect ratio
              height: 80,
              width: 80,
              isCircular: true,
              onImageChanged: (file) {
                setState(() {
                  _avatarImageFile = file;
                });
                _onImageChanged();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextFieldSection({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required int maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? helpText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            CharacterCounterWidget(
              current: controller.text.length,
              max: maxLength,
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(color: Colors.white),
          maxLength: maxLength,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.purple, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            counterText: '', // Hide default counter
          ),
          onChanged: (value) {
            setState(() {}); // Update character counter
          },
        ),
        if (helpText != null) ...[
          const SizedBox(height: 4),
          Text(
            helpText,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}