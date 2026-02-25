// ABOUTME: Screen for importing existing Nostr private keys (nsec or hex format)
// ABOUTME: Also supports NIP-46 bunker URLs for remote signing
// ABOUTME: Validates keys and imports them securely for existing Nostr users

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/auth_back_button.dart';
import 'package:openvine/widgets/divine_primary_button.dart';

class KeyImportScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'import-key';

  /// Path for this route.
  static const path = '/import-key';

  const KeyImportScreen({super.key});

  @override
  ConsumerState<KeyImportScreen> createState() => _KeyImportScreenState();
}

class _KeyImportScreenState extends ConsumerState<KeyImportScreen> {
  final _keyController = TextEditingController();
  bool _isImporting = false;
  String? _keyError;

  /// Cached reference to auth service, since ref is invalid after unmount.
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = ref.read(authServiceProvider);
  }

  @override
  void dispose() {
    _keyController.dispose();

    // Clear any authentication errors when leaving this screen.
    // Uses cached reference because Riverpod ref is invalid after unmount.
    _authService.clearError();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Back button
                    AuthBackButton(
                      onPressed: _isImporting ? null : () => context.pop(),
                    ),

                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      'Import your\nNostr identity',
                      style: TextStyle(
                        fontFamily: VineTheme.fontFamilyBricolage,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: VineTheme.whiteText,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Subtitle
                    const Text(
                      'Import your existing Nostr identity using your '
                      'private key or a bunker URL.',
                      style: TextStyle(
                        fontSize: 16,
                        color: VineTheme.secondaryText,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Key input field
                    DivineAuthTextField(
                      controller: _keyController,
                      label: 'Private key or bunker URL',
                      enabled: !_isImporting,
                      autocorrect: false,
                      errorText: _keyError,
                      onChanged: (_) {
                        if (_keyError != null) {
                          setState(() => _keyError = null);
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    // Import button
                    DivinePrimaryButton(
                      label: 'Import Nostr key',
                      isLoading: _isImporting,
                      onPressed: _importKey,
                    ),
                  ],
                ),
              ),
            ),

            // Pinned security warning with key overlay
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const _SecurityWarning(),
                  Positioned(
                    right: -60,
                    top: -130,
                    child: Transform.rotate(
                      angle: 12 * 3.1415926535 / 180,
                      child: Image.asset(
                        'assets/stickers/key.png',
                        width: 174,
                        height: 174,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String? _validateKey(String value) {
    if (value.trim().isEmpty) {
      return 'Please enter your private key or bunker URL';
    }

    final trimmed = value.trim();

    // Check if it's a bunker URL
    if (NostrRemoteSignerInfo.isBunkerUrl(trimmed)) {
      try {
        NostrRemoteSignerInfo.parseBunkerUrl(trimmed);
      } catch (e) {
        return 'Invalid bunker URL';
      }
      return null;
    }

    // Check if it looks like a valid key format
    if (!trimmed.startsWith('nsec') && trimmed.length != 64) {
      return 'Invalid format. Use nsec..., hex, or bunker://...';
    }

    if (trimmed.startsWith('nsec') && trimmed.length != 63) {
      return 'Invalid nsec format. Should be 63 characters';
    }

    return null;
  }

  Future<void> _importKey() async {
    final error = _validateKey(_keyController.text);
    if (error != null) {
      setState(() => _keyError = error);
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final keyText = _keyController.text.trim();
      final AuthResult result;

      if (NostrRemoteSignerInfo.isBunkerUrl(keyText)) {
        // Handle bunker URL (NIP-46 remote signing)
        result = await authService.connectWithBunker(keyText);
      } else if (keyText.startsWith('nsec')) {
        result = await authService.importFromNsec(keyText);
      } else {
        result = await authService.importFromHex(keyText);
      }

      if (result.success && mounted) {
        // Clear the text field for security
        _keyController.clear();

        // Start fetching the user's profile from relays in background
        // This ensures profile data is available when user navigates
        // to profile
        final pubkeyHex = authService.currentPublicKeyHex;
        if (pubkeyHex != null) {
          final userProfileService = ref.read(userProfileServiceProvider);
          unawaited(userProfileService.fetchProfile(pubkeyHex));
          Log.info(
            'Started background fetch for imported user profile',
            name: 'KeyImportScreen',
            category: LogCategory.auth,
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? 'Failed to import key or connect bunker',
            ),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }
}

/// Security warning box about private key safety.
class _SecurityWarning extends StatelessWidget {
  const _SecurityWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VineTheme.accentOrangeBackground),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: VineTheme.accentOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Keep your private key secure!',
                style: TextStyle(
                  color: VineTheme.accentOrange,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Never share your private key with anyone. This key '
            'gives full access to your Nostr identity.',
            style: TextStyle(color: VineTheme.accentOrange, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
