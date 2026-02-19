// ABOUTME: Screen for importing existing Nostr private keys (nsec or hex format)
// ABOUTME: Also supports NIP-46 bunker URLs for remote signing
// ABOUTME: Validates keys and imports them securely for existing Nostr users

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/welcome_screen.dart';
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
      backgroundColor: VineTheme.surfaceBackground,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Stack(
            children: [
              // Scrollable content fills entire safe area
              _KeyImportFormContent(
                formKey: _formKey,
                keyController: _keyController,
                isImporting: _isImporting,
                onImport: _importKey,
                onPaste: _pasteFromClipboard,
                onSignUp: _navigateToSignUp,
              ),

              // Back button overlays top-left
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: DivineIconButton(
                  icon: DivineIconName.caretLeft,
                  type: DivineIconButtonType.secondary,
                  size: DivineIconButtonSize.small,
                  onPressed: () => context.pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToSignUp() {
    context.push('${WelcomeScreen.authNativePath}?mode=register');
  }

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
        // This ensures profile data is available when user navigates
        // to profile
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

/// Form content for the key import screen.
///
/// Mirrors the layout of [_AuthFormContent] in [DivineAuthScreen]:
/// same title/subtitle styles, spacing, and bottom-aligned actions.
class _KeyImportFormContent extends StatelessWidget {
  const _KeyImportFormContent({
    required this.formKey,
    required this.keyController,
    required this.isImporting,
    required this.onImport,
    required this.onPaste,
    required this.onSignUp,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController keyController;
  final bool isImporting;
  final VoidCallback onImport;
  final VoidCallback onPaste;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Space for back button overlay
                  const SizedBox(height: 72),

                  // Title
                  Text(
                    'Import your Nostr ID',
                    style: VineTheme.headlineLargeFont(),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'Import your existing Nostr identity using '
                    'your private key or a bunker URL.',
                    style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
                  ),
                  const SizedBox(height: 48),

                  // Key input field
                  DivineAuthTextField(
                    label: 'Private key or bunker URL',
                    controller: keyController,
                    obscureText: true,
                    autocorrect: false,
                    keyboardType: TextInputType.text,
                    validator: _validateKey,
                  ),
                  const SizedBox(height: 32),

                  // Import button
                  DivineButton(
                    label: 'Import Nostr ID',
                    expanded: true,
                    isLoading: isImporting,
                    onPressed: isImporting ? null : onImport,
                  ),

                  // Push sign up prompt to bottom
                  const Spacer(),
                  const SizedBox(height: 32),

                  // Sign up prompt
                  _SignUpPrompt(onSignUp: onSignUp),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _validateKey(String? value) {
    if (value == null || value.trim().isEmpty) {
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
      return 'Invalid format. Use nsec, hex, or bunker://';
    }

    if (trimmed.startsWith('nsec') && trimmed.length != 63) {
      return 'Invalid nsec format. Should be 63 characters';
    }

    return null;
  }
}

/// Bottom prompt encouraging users without a Nostr identity to sign up.
class _SignUpPrompt extends StatelessWidget {
  const _SignUpPrompt({required this.onSignUp});

  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "Don't have a Nostr identity? ",
                style: VineTheme.bodyLargeFont(
                  color: VineTheme.onSurfaceVariant,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    "We'll automatically create one for "
                    'you when you sign up for diVine.',
                style: VineTheme.bodyLargeFont(
                  color: VineTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        DivineButton(
          label: 'Sign up',
          type: DivineButtonType.secondary,
          expanded: true,
          onPressed: onSignUp,
        ),
      ],
    );
  }
}
