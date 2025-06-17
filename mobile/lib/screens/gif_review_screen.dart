import 'dart:async';
import 'package:flutter/material.dart';
import '../services/gif_service.dart';
import '../services/camera_service.dart';
import '../services/vine_publishing_service.dart';

class GifReviewScreen extends StatefulWidget {
  final GifResult gifResult;
  final VineRecordingResult recordingResult;
  final VinePublishingService publishingService;

  const GifReviewScreen({
    super.key,
    required this.gifResult,
    required this.recordingResult,
    required this.publishingService,
  });

  @override
  State<GifReviewScreen> createState() => _GifReviewScreenState();
}

class _GifReviewScreenState extends State<GifReviewScreen> with WidgetsBindingObserver {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _hashtagsController = TextEditingController(text: 'nostrvine,vine');
  bool _isPublishing = false;
  Timer? _animationTimer;
  int _rebuildKey = 0;
  bool _isAppInForeground = true;
  
  // Intelligent backoff for animation timer
  static const Duration _initialAnimationInterval = Duration(milliseconds: 200);
  static const Duration _maxAnimationInterval = Duration(seconds: 5);
  static const double _backoffMultiplier = 1.3;
  Duration _currentAnimationInterval = _initialAnimationInterval;
  DateTime? _lastUserInteraction;
  int _consecutiveIdleCycles = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastUserInteraction = DateTime.now();
    // Start with fast animation, will backoff if no user interaction
    _startAnimationTimerWithBackoff();
    
    // Listen for user interactions to reset backoff
    _captionController.addListener(_onUserInteraction);
    _hashtagsController.addListener(_onUserInteraction);
  }
  
  void _startAnimationTimerWithBackoff() {
    // Only animate if we have valid GIF data, screen is mounted, and app is in foreground
    if (widget.gifResult.gifBytes.isNotEmpty && mounted && _isAppInForeground) {
      _animationTimer?.cancel(); // Cancel any existing timer
      
      _animationTimer = Timer.periodic(_currentAnimationInterval, (timer) {
        if (mounted && _isAppInForeground) {
          setState(() {
            _rebuildKey++;
          });
          
          // Implement intelligent backoff
          _updateAnimationBackoff();
        } else {
          timer.cancel();
        }
      });
    }
  }
  
  void _updateAnimationBackoff() {
    final now = DateTime.now();
    final timeSinceLastInteraction = now.difference(_lastUserInteraction ?? now);
    
    // If user hasn't interacted for 5 seconds, start backing off
    if (timeSinceLastInteraction.inSeconds > 5) {
      _consecutiveIdleCycles++;
      
      // Exponential backoff after idle period
      if (_consecutiveIdleCycles > 10) { // Wait 10 cycles before backing off
        final newInterval = Duration(
          milliseconds: (_currentAnimationInterval.inMilliseconds * _backoffMultiplier).round()
        );
        
        if (newInterval <= _maxAnimationInterval) {
          _currentAnimationInterval = newInterval;
          // Restart timer with new interval
          _stopAnimationTimer();
          _startAnimationTimerWithBackoff();
          
          debugPrint('🐌 GIF animation backing off to ${_currentAnimationInterval.inMilliseconds}ms (idle: ${timeSinceLastInteraction.inSeconds}s)');
        }
      }
    }
  }
  
  void _onUserInteraction() {
    _lastUserInteraction = DateTime.now();
    _consecutiveIdleCycles = 0;
    
    // Reset to fast animation on user interaction
    if (_currentAnimationInterval != _initialAnimationInterval) {
      _currentAnimationInterval = _initialAnimationInterval;
      _stopAnimationTimer();
      _startAnimationTimerWithBackoff();
      
      debugPrint('⚡ GIF animation reset to fast mode on user interaction');
    }
  }
  
  void _stopAnimationTimer() {
    _animationTimer?.cancel();
    _animationTimer = null;
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        _onUserInteraction(); // Reset backoff when app resumes
        _startAnimationTimerWithBackoff();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _isAppInForeground = false;
        _stopAnimationTimer();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAnimationTimer();
    _captionController.removeListener(_onUserInteraction);
    _hashtagsController.removeListener(_onUserInteraction);
    _captionController.dispose();
    _hashtagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onUserInteraction, // Reset backoff on screen taps
        child: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              children: [
                // Top bar with back and publish buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Review Your Vine',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: _isPublishing ? null : _publishVine,
                        child: _isPublishing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.purple,
                                ),
                              )
                            : const Text(
                                'Publish',
                                style: TextStyle(
                                  color: Colors.purple,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

            // GIF preview - fixed height for consistent display
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5, // 50% of screen height
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.gifResult.gifBytes.isNotEmpty
                        ? Image.memory(
                            widget.gifResult.gifBytes,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            isAntiAlias: true,
                            filterQuality: FilterQuality.medium,
                            // Use rebuild key to force animation updates
                            key: ValueKey(_rebuildKey),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.gif_box,
                                size: 64,
                                color: Colors.white54,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Loading GIF...',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),

            // GIF stats
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${widget.gifResult.frameCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Frames',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${widget.gifResult.fileSizeMB.toStringAsFixed(1)}MB',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Size',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          widget.gifResult.quality.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Quality',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Caption and hashtags input
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Caption',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _captionController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                        hintText: "What's happening?",
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Hashtags',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _hashtagsController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'nostrvine,vine,gif',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
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

  Future<void> _publishVine() async {
    if (_isPublishing) return;

    setState(() {
      _isPublishing = true;
    });

    try {
      final hashtags = _hashtagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      final result = await widget.publishingService.publishVine(
        recordingResult: widget.recordingResult,
        caption: _captionController.text.trim(),
        hashtags: hashtags,
        uploadToBackend: false,
      );

      if (mounted) {
        if (result.success) {
          // Show success and go back
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Vine published successfully to Nostr!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.pop(context);
        } else {
          // Show error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to publish: ${result.error ?? "Unknown error"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error publishing: $e'),
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
}