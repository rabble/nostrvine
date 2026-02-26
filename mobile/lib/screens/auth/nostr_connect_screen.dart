// ABOUTME: Screen for NIP-46 nostrconnect:// client-initiated connections.
// ABOUTME: Displays QR code and URL for user to scan/copy into signer app.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/auth_back_button.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Screen for NIP-46 client-initiated connections via nostrconnect:// URL.
class NostrConnectScreen extends ConsumerStatefulWidget {
  /// Route path for this screen.
  static const String path = '/nostr-connect';

  /// Route name for this screen.
  static const String routeName = 'nostr-connect';

  const NostrConnectScreen({super.key});

  @override
  ConsumerState<NostrConnectScreen> createState() => _NostrConnectScreenState();
}

class _NostrConnectScreenState extends ConsumerState<NostrConnectScreen> {
  String? _connectUrl;
  NostrConnectState _sessionState = NostrConnectState.idle;
  String? _errorMessage;
  StreamSubscription<NostrConnectState>? _stateSubscription;
  bool _isWaiting = false;
  bool _switchedToBunker = false;
  final Stopwatch _elapsedTimer = Stopwatch();
  Timer? _uiTimer;

  // Cache AuthService for use in dispose (can't use ref.read in dispose)
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = ref.read(authServiceProvider);
    _startSession();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _uiTimer?.cancel();
    _elapsedTimer.stop();
    // Cancel the session if user leaves the screen
    _authService.cancelNostrConnect();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() {
      _sessionState = NostrConnectState.generating;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final session = await authService.initiateNostrConnect();

      if (!mounted) return;

      setState(() {
        _connectUrl = session.connectUrl;
        _sessionState = NostrConnectState.listening;
      });

      // Listen to state changes
      _stateSubscription = session.stateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          _sessionState = state;
        });
      });

      // Start the timer for UI updates
      _elapsedTimer.start();
      _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });

      // Start waiting for the connection
      _waitForConnection();
    } catch (e) {
      Log.error(
        'Failed to start nostrconnect session: $e',
        name: 'NostrConnectScreen',
        category: LogCategory.auth,
      );
      if (!mounted) return;
      setState(() {
        _sessionState = NostrConnectState.error;
        _errorMessage = 'Failed to start session: $e';
      });
    }
  }

  Future<void> _waitForConnection() async {
    if (_isWaiting) return;
    _isWaiting = true;

    final authService = ref.read(authServiceProvider);
    final result = await authService.waitForNostrConnectResponse();

    _isWaiting = false;
    _elapsedTimer.stop();
    _uiTimer?.cancel();

    if (!mounted) return;

    // If the user switched to a bunker connection via the paste dialog,
    // ignore the nostrconnect session result to avoid interfering with
    // the bunker auth flow.
    if (_switchedToBunker) return;

    if (result.success) {
      // Navigate to home on success
      context.go(VideoFeedPage.pathForIndex(0));
    } else {
      setState(() {
        _errorMessage = result.errorMessage;
      });
    }
  }

  void _retry() {
    _elapsedTimer.reset();
    _startSession();
  }

  Future<void> _copyUrl() async {
    if (_connectUrl == null) return;

    await Clipboard.setData(ClipboardData(text: _connectUrl!));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('URL copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareUrl() async {
    if (_connectUrl == null) return;

    await SharePlus.instance.share(
      ShareParams(text: _connectUrl, title: 'Connect to Divine'),
    );
  }

  Future<void> _showPasteBunkerDialog() async {
    final controller = TextEditingController();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VineTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VineTheme.onSurfaceMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Paste bunker:// URL',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(
                color: VineTheme.primaryText,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'bunker:// URL',
                hintStyle: const TextStyle(color: VineTheme.vineGreen),
                filled: true,
                fillColor: VineTheme.surfaceContainer,
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: VineTheme.vineGreen),
                  borderRadius: BorderRadius.circular(16),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: VineTheme.vineGreen,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
              onSubmitted: (value) => Navigator.pop(context, value.trim()),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (result == null || result.isEmpty || !mounted) return;

    // Validate it's a bunker URL
    if (!NostrRemoteSignerInfo.isBunkerUrl(result)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid bunker URL. It should start with bunker://',
          ),
          backgroundColor: VineTheme.error,
        ),
      );
      return;
    }

    // Cancel the current nostrconnect session and prevent its completion
    // callback from interfering with the bunker auth flow.
    _switchedToBunker = true;
    _authService.cancelNostrConnect();
    _stateSubscription?.cancel();
    _uiTimer?.cancel();
    _elapsedTimer.stop();

    // Show loading state
    setState(() {
      _sessionState = NostrConnectState.connected;
    });

    // Authenticate with bunker URL
    try {
      final authService = ref.read(authServiceProvider);
      final authResult = await authService.connectWithBunker(result);

      if (!mounted) return;

      if (authResult.success) {
        context.go(VideoFeedPage.pathForIndex(0));
      } else {
        setState(() {
          _sessionState = NostrConnectState.error;
          _errorMessage = authResult.errorMessage ?? 'Failed to connect';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sessionState = NostrConnectState.error;
        _errorMessage = 'Failed to connect: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      body: SafeArea(
        child: switch (_sessionState) {
          NostrConnectState.idle || NostrConnectState.generating =>
            const _LoadingContent(message: 'Generating connection...'),
          NostrConnectState.listening => _QrContent(
            connectUrl: _connectUrl ?? '',
            elapsedSeconds: _elapsedTimer.elapsed.inSeconds,
            onBack: () => context.pop(),
            onCopyUrl: _copyUrl,
            onShareUrl: _shareUrl,
            onAddBunker: _showPasteBunkerDialog,
          ),
          NostrConnectState.connected => const _LoadingContent(
            message: 'Connected! Authenticating...',
          ),
          NostrConnectState.timeout => _ErrorContent(
            title: 'Connection timed out',
            message:
                'Make sure you approved the connection in your signer app.',
            onRetry: _retry,
            onBack: () => context.pop(),
          ),
          NostrConnectState.cancelled => _ErrorContent(
            title: 'Connection cancelled',
            message: 'The connection was cancelled.',
            onRetry: _retry,
            onBack: () => context.pop(),
          ),
          NostrConnectState.error => _ErrorContent(
            title: 'Connection failed',
            message: _errorMessage ?? 'An unknown error occurred.',
            onRetry: _retry,
            onBack: () => context.pop(),
          ),
        },
      ),
    );
  }
}

/// Loading state with spinner and message.
class _LoadingContent extends StatelessWidget {
  const _LoadingContent({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Space for close button overlay
          const SizedBox(height: 72),
          Text(
            'Scan with your\nsigner app to connect.',
            style: VineTheme.headlineLargeFont(),
          ),
          const Spacer(),
          const CircularProgressIndicator(color: VineTheme.vineGreen),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              color: VineTheme.secondaryText,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

/// Main QR code content with actions and compatibility table.
class _QrContent extends StatelessWidget {
  const _QrContent({
    required this.connectUrl,
    required this.elapsedSeconds,
    required this.onBack,
    required this.onCopyUrl,
    required this.onShareUrl,
    required this.onAddBunker,
  });

  final String connectUrl;
  final int elapsedSeconds;
  final VoidCallback onBack;
  final VoidCallback onCopyUrl;
  final VoidCallback onShareUrl;
  final VoidCallback onAddBunker;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Back button
          AuthBackButton(onPressed: onBack),

          const SizedBox(height: 32),

          // Title
          const Text(
            'Scan with your\nsigner app to connect.',
            style: TextStyle(
              fontFamily: VineTheme.fontFamilyBricolage,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: VineTheme.whiteText,
            ),
          ),

          const SizedBox(height: 32),

          // QR code card
          _QrCodeCard(connectUrl: connectUrl),

          const SizedBox(height: 20),

          // Waiting indicator
          _WaitingIndicator(elapsedSeconds: elapsedSeconds),

          const SizedBox(height: 32),

          // Action bar
          _ActionBar(
            onCopyUrl: onCopyUrl,
            onShareUrl: onShareUrl,
            onAddBunker: onAddBunker,
          ),

          const SizedBox(height: 24),

          // Compatibility table
          const _CompatibilityTable(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// QR code displayed in a rounded card.
class _QrCodeCard extends StatelessWidget {
  const _QrCodeCard({required this.connectUrl});

  final String connectUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VineTheme.outlineVariant),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: QrImageView(
            data: connectUrl,
            size: 200,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),
      ),
    );
  }
}

/// Waiting spinner with elapsed time.
class _WaitingIndicator extends StatelessWidget {
  const _WaitingIndicator({required this.elapsedSeconds});

  final int elapsedSeconds;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: VineTheme.vineGreen,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Waiting for connection... ${elapsedSeconds}s',
            style: const TextStyle(
              color: VineTheme.secondaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom action bar with Copy URL, Share, and Add bunker buttons.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.onCopyUrl,
    required this.onShareUrl,
    required this.onAddBunker,
  });

  final VoidCallback onCopyUrl;
  final VoidCallback onShareUrl;
  final VoidCallback onAddBunker;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VineTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: const Icon(
                Icons.link,
                color: VineTheme.vineGreen,
                size: 24,
              ),
              label: 'Copy URL',
              onTap: onCopyUrl,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: SvgPicture.asset(
                'assets/icon/share_fat.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  VineTheme.vineGreen,
                  BlendMode.srcIn,
                ),
              ),
              label: 'Share',
              onTap: onShareUrl,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: const Icon(Icons.add, color: VineTheme.vineGreen, size: 24),
              label: 'Add bunker',
              onTap: onAddBunker,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single action button in the action bar.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: VineTheme.vineGreen,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compatibility table showing signer apps and their platform support.
class _CompatibilityTable extends StatelessWidget {
  const _CompatibilityTable();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Compatible Signer apps',
                  style: TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ),
              _platformIcon(Icons.adb),
              const SizedBox(width: 24),
              _platformIcon(Icons.apple),
              const SizedBox(width: 24),
              _platformIcon(Icons.language),
            ],
          ),
        ),

        // Signer rows
        const _SignerRow(name: 'Amber', android: true, ios: false, web: false),
        const _SignerRow(name: 'Primal', android: true, ios: true, web: true),
        const _SignerRow(
          name: 'Nostr Connect',
          android: true,
          ios: true,
          web: false,
        ),
        const _SignerRow(
          name: 'nsecBunker',
          android: false,
          ios: false,
          web: true,
        ),
      ],
    );
  }

  Widget _platformIcon(IconData icon) {
    return Icon(icon, color: VineTheme.secondaryText, size: 22);
  }
}

/// Single row in the signer compatibility table.
class _SignerRow extends StatelessWidget {
  const _SignerRow({
    required this.name,
    required this.android,
    required this.ios,
    required this.web,
  });

  final String name;
  final bool android;
  final bool ios;
  final bool web;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: VineTheme.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: VineTheme.whiteText,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _checkOrEmpty(android),
          const SizedBox(width: 24),
          _checkOrEmpty(ios),
          const SizedBox(width: 24),
          _checkOrEmpty(web),
        ],
      ),
    );
  }

  Widget _checkOrEmpty(bool supported) {
    return SizedBox(
      width: 22,
      child: supported
          ? const Icon(Icons.check, color: VineTheme.vineGreen, size: 22)
          : const SizedBox.shrink(),
    );
  }
}

/// Error state with retry option.
class _ErrorContent extends StatelessWidget {
  const _ErrorContent({
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AuthBackButton(onPressed: onBack),
          const Spacer(),
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: VineTheme.error,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VineTheme.vineGreen,
                      foregroundColor: VineTheme.backgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Try Again',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
