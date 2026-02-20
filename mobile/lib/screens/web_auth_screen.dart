// ABOUTME: Web authentication screen supporting NIP-07 and nsec bunker login
// ABOUTME: Provides user-friendly interface for Nostr authentication on web platform

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/web_auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

class WebAuthScreen extends ConsumerStatefulWidget {
  const WebAuthScreen({super.key});

  @override
  ConsumerState<WebAuthScreen> createState() => _WebAuthScreenState();
}

class _WebAuthScreenState extends ConsumerState<WebAuthScreen>
    with TickerProviderStateMixin {
  final TextEditingController _bunkerUriController = TextEditingController();
  bool _isAuthenticating = false;
  String? _errorMessage;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = FadeTransition(
      opacity: _fadeController,
      child: Container(),
    ).opacity;

    _fadeController.forward();

    // Check for existing session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingSession();
    });
  }

  @override
  void dispose() {
    _bunkerUriController.dispose();
    _fadeController.dispose();

    super.dispose();
  }

  Future<void> _checkExistingSession() async {
    final webAuth = ref.read(webAuthServiceProvider);
    await webAuth.checkExistingSession();

    if (webAuth.isAuthenticated && mounted) {
      _onAuthenticationSuccess();
    }
  }

  Future<void> _onAuthenticationSuccess() async {
    // Navigate to main app or trigger auth state update
    if (mounted) {
      final webAuth = ref.read(webAuthServiceProvider);

      try {
        // Set the public key in the main auth service
        // to trigger authenticated state
        if (webAuth.publicKey != null) {
          // Web authentication not supported in secure mode
          final scaffoldMessenger = ScaffoldMessenger.of(context);

          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: const Text(
                'Web authentication not supported in secure '
                'mode. Please use mobile app for secure '
                'key management.',
              ),
              backgroundColor: VineTheme.error,
            ),
          );
        }
      } catch (e) {
        Log.error(
          'Failed to integrate web auth with main auth '
          'service: $e',
          name: 'WebAuthScreen',
          category: LogCategory.ui,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Authentication integration failed: $e'),
              backgroundColor: VineTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _authenticateWithNip07() async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final webAuth = ref.read(webAuthServiceProvider);
      final result = await webAuth.authenticateWithNip07();

      if (mounted) {
        if (result.success) {
          _onAuthenticationSuccess();
        } else {
          setState(() {
            _errorMessage = result.errorMessage;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unexpected error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _authenticateWithBunker() async {
    final bunkerUri = _bunkerUriController.text.trim();
    if (bunkerUri.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a bunker URI';
      });
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final webAuth = ref.read(webAuthServiceProvider);
      final result = await webAuth.authenticateWithBunker(bunkerUri);

      if (mounted) {
        if (result.success) {
          _onAuthenticationSuccess();
        } else {
          setState(() {
            _errorMessage = result.errorMessage;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unexpected error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null && mounted) {
        _bunkerUriController.text = clipboardData!.text!;
      }
    } catch (e) {
      Log.error(
        'Failed to paste from clipboard: $e',
        name: 'WebAuthScreen',
        category: LogCategory.ui,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      body: Consumer(
        builder: (context, ref, child) {
          final webAuth = ref.watch(webAuthServiceProvider);
          return SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Logo
                                SvgPicture.asset(
                                  'assets/icon/logo.svg',
                                  height: 50,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Connect to divine',
                                  style: VineTheme.headlineLargeFont(),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Choose your preferred '
                                  'Nostr authentication '
                                  'method',
                                  style: VineTheme.bodyLargeFont(
                                    color: VineTheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 48),

                                // NIP-07 Authentication
                                if (webAuth.isNip07Available) ...[
                                  _Nip07AuthCard(
                                    subtitle: webAuth.getMethodDisplayName(
                                      WebAuthMethod.nip07,
                                    ),
                                    isAuthenticating: _isAuthenticating,
                                    onTap: _authenticateWithNip07,
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Bunker Authentication
                                _BunkerAuthCard(
                                  controller: _bunkerUriController,
                                  isAuthenticating: _isAuthenticating,
                                  onConnect: _authenticateWithBunker,
                                  onPaste: _pasteFromClipboard,
                                ),

                                // Error message
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 24),
                                  _WebAuthErrorMessage(message: _errorMessage!),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Help text
                    const _NostrHelpBox(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// NIP-07 browser extension auth card.
class _Nip07AuthCard extends StatelessWidget {
  const _Nip07AuthCard({
    required this.subtitle,
    required this.isAuthenticating,
    required this.onTap,
  });

  final String subtitle;
  final bool isAuthenticating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VineTheme.surfaceContainer,
      child: InkWell(
        onTap: isAuthenticating ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: VineTheme.primary, width: 2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VineTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const DivineIcon(
                  icon: DivineIconName.bracketsAngle,
                  color: VineTheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Browser Extension',
                          style: VineTheme.titleSmallFont(),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: VineTheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'RECOMMENDED',
                            style: VineTheme.labelSmallFont(
                              color: VineTheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: VineTheme.bodyMediumFont(
                        color: VineTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAuthenticating)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: VineTheme.onSurface,
                  ),
                )
              else
                const DivineIcon(
                  icon: DivineIconName.caretRight,
                  color: VineTheme.onSurfaceMuted,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bunker authentication card with URI input.
class _BunkerAuthCard extends StatelessWidget {
  const _BunkerAuthCard({
    required this.controller,
    required this.isAuthenticating,
    required this.onConnect,
    required this.onPaste,
  });

  final TextEditingController controller;
  final bool isAuthenticating;
  final VoidCallback onConnect;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VineTheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VineTheme.vineGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const DivineIcon(
                    icon: DivineIconName.linkSimple,
                    color: VineTheme.vineGreen,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('nsec bunker', style: VineTheme.titleSmallFont()),
                      Text(
                        'Connect to a remote signer',
                        style: VineTheme.bodyMediumFont(
                          color: VineTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              enabled: !isAuthenticating,
              enableInteractiveSelection: true,
              style: VineTheme.bodyMediumFont(color: VineTheme.onSurface),
              decoration: InputDecoration(
                hintText: 'bunker://pubkey?relay=wss://...',
                hintStyle: VineTheme.bodyMediumFont(
                  color: VineTheme.onSurfaceDisabled,
                ),
                filled: true,
                fillColor: VineTheme.surfaceBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: isAuthenticating ? null : onPaste,
                      icon: const DivineIcon(
                        icon: DivineIconName.clipboard,
                        color: VineTheme.onSurfaceMuted,
                      ),
                      tooltip: 'Paste from clipboard',
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            DivineButton(
              label: 'Connect to Bunker',
              expanded: true,
              isLoading: isAuthenticating,
              onPressed: isAuthenticating ? null : onConnect,
            ),
          ],
        ),
      ),
    );
  }
}

/// Error message container for web auth errors.
class _WebAuthErrorMessage extends StatelessWidget {
  const _WebAuthErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VineTheme.errorOverlay,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VineTheme.error),
      ),
      child: Row(
        children: [
          const DivineIcon(
            icon: DivineIconName.warningCircle,
            color: VineTheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: VineTheme.bodyMediumFont(color: VineTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// Help box explaining Nostr authentication options.
class _NostrHelpBox extends StatelessWidget {
  const _NostrHelpBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              DivineIcon(
                icon: DivineIconName.info,
                color: VineTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('New to Nostr?', style: VineTheme.titleSmallFont()),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Install a browser extension like Alby or '
            'nos2x for the easiest experience, or use '
            'nsec bunker for secure remote signing.',
            style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
