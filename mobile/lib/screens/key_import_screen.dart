// ABOUTME: Screen for importing existing Nostr private keys (nsec or hex format)
// ABOUTME: Also supports NIP-46 bunker URLs for remote signing
// ABOUTME: Validates keys and imports them securely for existing Nostr users

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

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
  final _formKey = GlobalKey<FormState>();
  bool _isImporting = false;
  bool _obscureKey = true;

  @override
  void dispose() {
    _keyController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text('Import Identity'),
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your private key or bunker URL',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Import your existing Nostr identity using your private key '
                '(nsec or hex format) or a NIP-46 bunker URL',
                style: TextStyle(fontSize: 16, color: Colors.grey[300]),
              ),
              const SizedBox(height: 32),

              // Private key input
              TextFormField(
                controller: _keyController,
                obscureText: _obscureKey,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Private Key or Bunker URL',
                  labelStyle: const TextStyle(color: Colors.grey),
                  hintText: 'nsec..., hex, or bunker://...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _obscureKey ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureKey = !_obscureKey;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.paste, color: Colors.grey),
                        onPressed: _pasteFromClipboard,
                      ),
                    ],
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your private key or bunker URL';
                  }

                  final trimmed = value.trim();

                  // Check if it's a bunker URL
                  if (NostrRemoteSignerInfo.isBunkerUrl(trimmed)) {
                    // Validate bunker URL format
                    final info = NostrRemoteSignerInfo.parseBunkerUrl(trimmed);
                    if (info == null) {
                      return 'Invalid bunker URL. Must include relay parameter';
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
                },
                minLines: 1,
              ),
              const SizedBox(height: 24),

              // Security warning
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade700),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade400),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Keep your private key secure! '
                        'Never share it with anyone. This key gives full '
                        'access to your Nostr identity.',
                        style: TextStyle(
                          color: Colors.orange.shade200,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Import button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isImporting ? null : _importKey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isImporting
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
                            Text('Connecting...'),
                          ],
                        )
                      : const Text(
                          'Connect Identity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),

              // Additional info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.help_outline,
                      color: Colors.purple,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Don't have a Nostr identity yet?",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Go back and create a new identity. We'll generate a "
                      "secure key pair for you.",
                      style: TextStyle(color: Colors.grey[300], fontSize: 14),
                      textAlign: TextAlign.center,
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

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        _keyController.text = clipboardData!.text!.trim();
      }
    } catch (e) {
      Log.error(
        'Failed to paste from clipboard: $e',
        name: 'KeyImportScreen',
        category: LogCategory.ui,
      );
    }
  }

  Future<void> _importKey() async {
    if (!_formKey.currentState!.validate()) {
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
        // This ensures profile data is available when user navigates to profile
        final pubkeyHex = authService.currentPublicKeyHex;
        if (pubkeyHex != null) {
          final userProfileService = ref.read(userProfileServiceProvider);
          unawaited(userProfileService.fetchProfile(pubkeyHex));
          Log.info(
            '📥 Started background fetch for imported user profile',
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
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
