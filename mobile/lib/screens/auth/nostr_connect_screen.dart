// ABOUTME: Screen for NIP-46 nostrconnect:// client-initiated connections.
// ABOUTME: Displays QR code and URL for user to scan/copy into signer app.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';
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
    final result = await authService.waitForNostrConnectResponse(
      timeout: const Duration(minutes: 2),
    );

    _isWaiting = false;
    _elapsedTimer.stop();
    _uiTimer?.cancel();

    if (!mounted) return;

    if (result.success) {
      // Navigate to home on success
      context.go(HomeScreenRouter.pathForIndex(0));
    } else {
      // Update error message
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
      ShareParams(text: _connectUrl!, title: 'Connect to diVine'),
    );
  }

  Future<void> _showPasteBunkerDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Paste bunker:// URL',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'bunker://...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[700]!),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: VineTheme.vineGreen),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty || !mounted) return;

    // Validate it's a bunker URL
    if (!NostrRemoteSignerInfo.isBunkerUrl(result)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid bunker URL. It should start with bunker://'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Cancel the current nostrconnect session
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
        context.go(HomeScreenRouter.pathForIndex(0));
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Connect Signer App',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_sessionState) {
      case NostrConnectState.idle:
      case NostrConnectState.generating:
        return _buildLoading('Generating connection...');

      case NostrConnectState.listening:
        return _buildQrCode();

      case NostrConnectState.connected:
        return _buildLoading('Connected! Authenticating...');

      case NostrConnectState.timeout:
        return _buildError(
          'Connection timed out',
          'Make sure you approved the connection in your signer app.',
        );

      case NostrConnectState.cancelled:
        return _buildError(
          'Connection cancelled',
          'The connection was cancelled.',
        );

      case NostrConnectState.error:
        return _buildError(
          'Connection failed',
          _errorMessage ?? 'An unknown error occurred.',
        );
    }
  }

  Widget _buildLoading(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: VineTheme.vineGreen),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCode() {
    final elapsed = _elapsedTimer.elapsed;
    final elapsedText = '${elapsed.inSeconds}s';

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Instructions
          const Text(
            'Scan this QR code with your\nsigner app to connect',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // QR Code with white background for scannability
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: _connectUrl ?? '',
              version: QrVersions.auto,
              size: 240,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: 24),

          // Waiting indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: VineTheme.vineGreen,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Waiting for connection... $elapsedText',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyUrl,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy URL'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareUrl,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Paste bunker URL option
          TextButton.icon(
            onPressed: _showPasteBunkerDialog,
            icon: const Icon(Icons.content_paste, size: 18),
            label: const Text('Have a bunker:// URL? Paste it here'),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          ),
          const SizedBox(height: 24),

          // Supported signers
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Compatible signer apps:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSignerItem('Amber', 'Android'),
                _buildSignerItem('nsecBunker', 'Web / Self-hosted'),
                _buildSignerItem('Primal', 'iOS / Android / Web'),
                _buildSignerItem('Nostr Connect', 'iOS / Android'),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSignerItem(String name, String platform) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: VineTheme.vineGreen, size: 16),
          const SizedBox(width: 8),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            '($platform)',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String title, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _retry,
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.vineGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
