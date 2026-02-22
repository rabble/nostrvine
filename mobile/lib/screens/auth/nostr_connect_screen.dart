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
    final result = await authService.waitForNostrConnectResponse(
      timeout: const Duration(minutes: 2),
    );

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

    final result = await VineBottomSheet.show<String>(
      context: context,
      scrollable: false,
      showHeaderDivider: false,
      body: _PasteBunkerSheetContent(controller: controller),
    );

    if (result == null || result.isEmpty || !mounted) return;

    // Validate it's a bunker URL
    if (!NostrRemoteSignerInfo.isBunkerUrl(result)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
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
      backgroundColor: VineTheme.surfaceBackground,
      body: SafeArea(
        child: Stack(
          children: [
            // Content fills entire safe area
            switch (_sessionState) {
              NostrConnectState.idle || NostrConnectState.generating =>
                const _ConnectLoadingView(message: 'Generating connection...'),
              NostrConnectState.listening => _ConnectQrCodeView(
                connectUrl: _connectUrl ?? '',
                elapsedTimer: _elapsedTimer,
                onCopyUrl: _copyUrl,
                onShareUrl: _shareUrl,
                onAddBunker: _showPasteBunkerDialog,
              ),
              NostrConnectState.connected => const _ConnectLoadingView(
                message: 'Connected! Authenticating...',
              ),
              NostrConnectState.timeout => _ConnectErrorView(
                title: 'Connection timed out',
                message:
                    'Make sure you approved the connection '
                    'in your signer app.',
                onRetry: _retry,
              ),
              NostrConnectState.cancelled => _ConnectErrorView(
                title: 'Connection cancelled',
                message: 'The connection was cancelled.',
                onRetry: _retry,
              ),
              NostrConnectState.error => _ConnectErrorView(
                title: 'Connection failed',
                message: _errorMessage ?? 'An unknown error occurred.',
                onRetry: _retry,
              ),
            },

            // Close button overlays top-left
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: DivineIconButton(
                icon: DivineIconName.x,
                type: DivineIconButtonType.secondary,
                size: DivineIconButtonSize.small,
                onPressed: () => context.pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading view shown while generating or authenticating.
class _ConnectLoadingView extends StatelessWidget {
  const _ConnectLoadingView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
            style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// QR code view shown when listening for a signer connection.
class _ConnectQrCodeView extends StatelessWidget {
  const _ConnectQrCodeView({
    required this.connectUrl,
    required this.elapsedTimer,
    required this.onCopyUrl,
    required this.onShareUrl,
    required this.onAddBunker,
  });

  final String connectUrl;
  final Stopwatch elapsedTimer;
  final VoidCallback onCopyUrl;
  final VoidCallback onShareUrl;
  final VoidCallback onAddBunker;

  @override
  Widget build(BuildContext context) {
    final elapsed = elapsedTimer.elapsed;
    final elapsedText = '${elapsed.inSeconds}s';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Space for close button overlay
          const SizedBox(height: 72),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Scan with your\nsigner app to connect.',
              style: VineTheme.headlineLargeFont(),
            ),
          ),
          const SizedBox(height: 32),

          // QR card with border
          _QrCodeCard(
            connectUrl: connectUrl,
            elapsedText: elapsedText,
            onCopyUrl: onCopyUrl,
            onShareUrl: onShareUrl,
            onAddBunker: onAddBunker,
          ),
          const SizedBox(height: 24),

          // Compatible signers table
          const _CompatibleSignersTable(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// The bordered card containing the QR code and action links.
class _QrCodeCard extends StatelessWidget {
  const _QrCodeCard({
    required this.connectUrl,
    required this.elapsedText,
    required this.onCopyUrl,
    required this.onShareUrl,
    required this.onAddBunker,
  });

  final String connectUrl;
  final String elapsedText;
  final VoidCallback onCopyUrl;
  final VoidCallback onShareUrl;
  final VoidCallback onAddBunker;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: VineTheme.surfaceBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: VineTheme.outlineMuted),
        ),
        child: Column(
          children: [
            // QR section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 80, 16, 50),
              child: Column(
                children: [
                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: VineTheme.whiteText,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: connectUrl,
                      version: QrVersions.auto,
                      size: 208,
                      backgroundColor: VineTheme.whiteText,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Spinner
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: VineTheme.vineGreen,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Waiting text
                  Text(
                    'Waiting for connection... $elapsedText',
                    style: VineTheme.labelMediumFont(
                      color: VineTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            Container(height: 1, color: VineTheme.outlineMuted),

            // Action buttons row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionLink(
                      icon: DivineIconName.linkSimple,
                      label: 'Copy URL',
                      onTap: onCopyUrl,
                    ),
                  ),
                  Expanded(
                    child: _ActionLink(
                      icon: DivineIconName.shareFat,
                      label: 'Share',
                      onTap: onShareUrl,
                    ),
                  ),
                  Expanded(
                    child: _ActionLink(
                      icon: DivineIconName.plus,
                      label: 'Add bunker',
                      onTap: onAddBunker,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error view shown on timeout, cancellation, or failure.
class _ConnectErrorView extends StatelessWidget {
  const _ConnectErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Space for close button overlay
          const SizedBox(height: 72),
          Text(
            'Scan with your\nsigner app to connect.',
            style: VineTheme.headlineLargeFont(),
          ),
          const SizedBox(height: 32),
          const DivineSticker(sticker: DivineStickerName.policeSiren),
          const SizedBox(height: 32),
          Text(title, style: VineTheme.headlineSmallFont()),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
          ),
          const Spacer(),
          DivineButton(label: 'Try again', expanded: true, onPressed: onRetry),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// A vertically stacked icon + label link used in the action row.
class _ActionLink extends StatelessWidget {
  const _ActionLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DivineIcon(icon: icon, color: VineTheme.vineGreen, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: VineTheme.titleSmallFont(color: VineTheme.vineGreen),
          ),
        ],
      ),
    );
  }
}

/// Table showing compatible signer apps and their platform support.
class _CompatibleSignersTable extends StatelessWidget {
  const _CompatibleSignersTable();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        // Header row
        _SignerRow(
          name: 'Compatible Signer apps',
          isHeader: true,
          android: true,
          ios: true,
          web: true,
        ),
        Divider(height: 1, color: VineTheme.outlineMuted),
        // Amber - Android only
        _SignerRow(name: 'Amber', android: true),
        Divider(height: 1, color: VineTheme.outlineMuted),
        // Primal - all platforms
        _SignerRow(name: 'Primal', android: true, ios: true, web: true),
        Divider(height: 1, color: VineTheme.outlineMuted),
        // Nostr Connect - Android & iOS
        _SignerRow(name: 'Nostr Connect', android: true, ios: true),
        Divider(height: 1, color: VineTheme.outlineMuted),
        // nsecBunker - Web only
        _SignerRow(name: 'nsecBunker', web: true),
      ],
    );
  }
}

/// A single row in the compatible signers table.
class _SignerRow extends StatelessWidget {
  const _SignerRow({
    required this.name,
    this.isHeader = false,
    this.android = false,
    this.ios = false,
    this.web = false,
  });

  final String name;
  final bool isHeader;
  final bool android;
  final bool ios;
  final bool web;

  @override
  Widget build(BuildContext context) {
    final textStyle = isHeader
        ? VineTheme.labelMediumFont(color: VineTheme.onSurfaceMuted)
        : VineTheme.titleSmallFont(color: VineTheme.onSurface);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(name, style: textStyle)),
          Expanded(
            child: _PlatformCell(
              isHeader: isHeader,
              headerIcon: DivineIconName.androidLogo,
              isSupported: android,
            ),
          ),
          Expanded(
            child: _PlatformCell(
              isHeader: isHeader,
              headerIcon: DivineIconName.appleLogo,
              isSupported: ios,
            ),
          ),
          Expanded(
            child: _PlatformCell(
              isHeader: isHeader,
              headerIcon: DivineIconName.globe,
              isSupported: web,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single platform cell in the signers table row.
class _PlatformCell extends StatelessWidget {
  const _PlatformCell({
    required this.isHeader,
    required this.headerIcon,
    required this.isSupported,
  });

  final bool isHeader;
  final DivineIconName headerIcon;
  final bool isSupported;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: isHeader
          ? DivineIcon(
              icon: headerIcon,
              color: VineTheme.onSurfaceMuted,
              size: 20,
            )
          : isSupported
          ? const DivineIcon(
              icon: DivineIconName.check,
              color: VineTheme.vineGreen,
              size: 20,
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Bottom sheet content for pasting a bunker:// URL.
class _PasteBunkerSheetContent extends StatefulWidget {
  const _PasteBunkerSheetContent({required this.controller});

  final TextEditingController controller;

  @override
  State<_PasteBunkerSheetContent> createState() =>
      _PasteBunkerSheetContentState();
}

class _PasteBunkerSheetContentState extends State<_PasteBunkerSheetContent> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the text field after the sheet animates in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final value = widget.controller.text.trim();
    // Use Navigator.pop instead of context.pop (GoRouter) to ensure
    // the value is returned to showModalBottomSheet correctly.
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paste bunker:// URL', style: VineTheme.headlineSmallFont()),
          const SizedBox(height: 24),
          DivineAuthTextField(
            label: 'bunker:// URL',
            controller: widget.controller,
            focusNode: _focusNode,
            autocorrect: false,
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          DivineButton(label: 'Connect', expanded: true, onPressed: _submit),
        ],
      ),
    );
  }
}
