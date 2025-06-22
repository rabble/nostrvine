import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'theme/vine_theme.dart';
import 'screens/camera_screen.dart';
import 'screens/web_camera_placeholder.dart';
import 'screens/feed_screen_v2.dart';
import 'screens/profile_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/web_auth_screen.dart';
import 'services/nostr_service.dart';
import 'services/auth_service.dart';
import 'services/key_storage_service.dart';
import 'services/nostr_service_interface.dart';
import 'services/nostr_key_manager.dart';
import 'services/video_event_service.dart';
// import 'services/vine_publishing_service.dart'; // Removed - using video-based approach
// import 'services/gif_service.dart'; // Removed - using video-based approach
// import 'services/video_cache_service.dart'; // Removed - using VideoManager instead
import 'services/connection_status_service.dart';
import 'services/user_profile_service.dart';
import 'services/direct_upload_service.dart';
import 'services/nip98_auth_service.dart';
import 'services/stream_upload_service.dart';
import 'services/upload_manager.dart';
import 'services/api_service.dart';
import 'services/video_event_publisher.dart';
import 'services/notification_service_enhanced.dart';
import 'services/seen_videos_service.dart';
import 'services/web_auth_service.dart';
import 'services/social_service.dart';
import 'services/video_manager_interface.dart';
import 'services/video_manager_service.dart';
import 'services/video_event_bridge.dart';
// import 'providers/video_feed_provider.dart'; // Removed - FeedScreenV2 uses VideoManager directly
import 'providers/profile_stats_provider.dart';
import 'providers/profile_videos_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  // Handle Flutter framework errors more gracefully
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log the error but don't crash the app for known framework issues
    if (details.exception.toString().contains('KeyDownEvent') ||
        details.exception.toString().contains('HardwareKeyboard')) {
      debugPrint('⚠️ Known Flutter framework keyboard issue (ignoring): ${details.exception}');
      return;
    }
    
    // For other errors, use default handling
    FlutterError.presentError(details);
  };
  
  // Ensure bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local data storage
  await Hive.initFlutter();
  
  runApp(const NostrVineApp());
}

class NostrVineApp extends StatelessWidget {
  const NostrVineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Connection status service
        ChangeNotifierProvider(create: (_) => ConnectionStatusService()),
        
        // Key storage service (foundational service)
        ChangeNotifierProvider(create: (_) => KeyStorageService()),
        
        // Web authentication service (for web platform only)
        ChangeNotifierProvider(create: (_) => WebAuthService()),
        
        // Authentication service depends on key storage
        ChangeNotifierProxyProvider<KeyStorageService, AuthService>(
          create: (context) => AuthService(keyStorage: context.read<KeyStorageService>()),
          update: (_, keyStorageService, previous) => previous ?? AuthService(keyStorage: keyStorageService),
        ),
        
        // Nostr key manager
        ChangeNotifierProvider(create: (_) => NostrKeyManager()),
        
        // Core Nostr service - platform-specific implementation
        ChangeNotifierProxyProvider<NostrKeyManager, INostrService>(
          create: (context) {
            final keyManager = context.read<NostrKeyManager>();
            // Always use regular NostrService for now
            debugPrint('📱 Creating NostrService for platform');
            return NostrService(keyManager);
          },
          update: (_, keyManager, previous) {
            if (previous != null) return previous;
            // Always use regular NostrService for now
            debugPrint('📱 Creating NostrService for platform');
            return NostrService(keyManager);
          },
        ),
        
        // Seen videos service for tracking viewed content
        ChangeNotifierProvider(create: (_) => SeenVideosService()),
        
        // Video event service depends on Nostr and SeenVideos services
        ChangeNotifierProxyProvider2<INostrService, SeenVideosService, VideoEventService>(
          create: (context) => VideoEventService(
            context.read<INostrService>(),
            seenVideosService: context.read<SeenVideosService>(),
          ),
          update: (_, nostrService, seenVideosService, previous) => previous ?? VideoEventService(
            nostrService,
            seenVideosService: seenVideosService,
          ),
        ),
        
        
        // User profile service depends on Nostr service
        ChangeNotifierProxyProvider<INostrService, UserProfileService>(
          create: (context) => UserProfileService(context.read<INostrService>()),
          update: (_, nostrService, previous) => previous ?? UserProfileService(nostrService),
        ),
        
        // Social service depends on Nostr service and Auth service
        ChangeNotifierProxyProvider2<INostrService, AuthService, SocialService>(
          create: (context) => SocialService(
            context.read<INostrService>(),
            context.read<AuthService>(),
          ),
          update: (_, nostrService, authService, previous) => previous ?? SocialService(
            nostrService,
            authService,
          ),
        ),
        
        // Profile stats provider depends on Social service
        ChangeNotifierProxyProvider<SocialService, ProfileStatsProvider>(
          create: (context) => ProfileStatsProvider(
            context.read<SocialService>(),
          ),
          update: (_, socialService, previous) => previous ?? ProfileStatsProvider(
            socialService,
          ),
        ),
        
        // Profile videos provider depends on Nostr service
        ChangeNotifierProxyProvider<INostrService, ProfileVideosProvider>(
          create: (context) => ProfileVideosProvider(
            context.read<INostrService>(),
          ),
          update: (_, nostrService, previous) => previous ?? ProfileVideosProvider(
            nostrService,
          ),
        ),
        
        // Enhanced notification service with Nostr integration
        ChangeNotifierProxyProvider3<INostrService, UserProfileService, VideoEventService, NotificationServiceEnhanced>(
          create: (context) {
            final service = NotificationServiceEnhanced();
            final nostrService = context.read<INostrService>();
            final profileService = context.read<UserProfileService>();
            final videoService = context.read<VideoEventService>();
            
            // Initialize asynchronously after frame
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                await service.initialize(
                  nostrService: nostrService,
                  profileService: profileService,
                  videoService: videoService,
                );
              } catch (e) {
                debugPrint('❌ Failed to initialize enhanced notification service: $e');
              }
            });
            
            return service;
          },
          update: (_, nostrService, profileService, videoService, previous) => previous ?? NotificationServiceEnhanced(),
        ),
        
        // Video Manager Service - single source of truth for video state
        Provider<IVideoManager>(
          create: (_) => VideoManagerService(
            config: VideoManagerConfig.wifi(), // Default to WiFi optimized
          ),
          dispose: (_, videoManager) => videoManager.dispose(),
        ),
        
        // NIP-98 authentication service
        ChangeNotifierProxyProvider<AuthService, Nip98AuthService>(
          create: (context) => Nip98AuthService(authService: context.read<AuthService>()),
          update: (_, authService, previous) => previous ?? Nip98AuthService(authService: authService),
        ),
        
        // Direct upload service with auth
        ChangeNotifierProxyProvider<Nip98AuthService, DirectUploadService>(
          create: (context) => DirectUploadService(authService: context.read<Nip98AuthService>()),
          update: (_, authService, previous) => previous ?? DirectUploadService(authService: authService),
        ),
        
        // Stream upload service
        ChangeNotifierProvider(create: (_) => StreamUploadService()),
        
        // Upload manager depends on direct upload service
        ChangeNotifierProxyProvider<DirectUploadService, UploadManager>(
          create: (context) => UploadManager(uploadService: context.read<DirectUploadService>()),
          update: (_, uploadService, previous) => previous ?? UploadManager(uploadService: uploadService),
        ),
        
        // API service
        ChangeNotifierProvider(create: (_) => ApiService()),
        
        // Video event publisher depends on multiple services
        ChangeNotifierProxyProvider3<UploadManager, INostrService, ApiService, VideoEventPublisher>(
          create: (context) => VideoEventPublisher(
            uploadManager: context.read<UploadManager>(),
            nostrService: context.read<INostrService>(),
            fetchReadyEvents: () => context.read<ApiService>().getReadyEvents(),
            cleanupRemoteEvent: (publicId) => context.read<ApiService>().cleanupRemoteEvent(publicId),
          ),
          update: (_, uploadManager, nostrService, apiService, previous) => previous ?? VideoEventPublisher(
            uploadManager: uploadManager,
            nostrService: nostrService,
            fetchReadyEvents: () => apiService.getReadyEvents(),
            cleanupRemoteEvent: (publicId) => apiService.cleanupRemoteEvent(publicId),
          ),
        ),
        
        // Video Event Bridge - connects VideoEventService to VideoManager
        Provider<VideoEventBridge>(
          create: (context) => VideoEventBridge(
            videoEventService: context.read<VideoEventService>(),
            videoManager: context.read<IVideoManager>(),
            userProfileService: context.read<UserProfileService>(),
          ),
          dispose: (_, bridge) => bridge.dispose(),
        ),
        
        // Note: VideoFeedProvider removed - FeedScreenV2 uses IVideoManager directly
        // Note: VinePublishingService removed - using video-based approach now
      ],
      child: MaterialApp(
        title: 'NostrVine',
        debugShowCheckedModeBanner: false,
        theme: VineTheme.theme,
        home: const ResponsiveWrapper(child: AppInitializer()),
      ),
    );
  }
}

/// AppInitializer handles the async initialization of services
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;
  String _initializationStatus = 'Initializing services...';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      if (!mounted) return;
      setState(() => _initializationStatus = 'Checking authentication...');
      await context.read<AuthService>().initialize();

      if (!mounted) return;
      setState(() => _initializationStatus = 'Connecting to Nostr network...');
      try {
        await context.read<INostrService>().initialize();
      } catch (e) {
        debugPrint('⚠️ Nostr service initialization failed: $e');
        // This is critical - rethrow
        rethrow;
      }

      // NotificationServiceEnhanced is initialized automatically via provider

      if (!mounted) return;
      setState(() => _initializationStatus = 'Initializing seen videos tracker...');
      await context.read<SeenVideosService>().initialize();

      if (!mounted) return;
      setState(() => _initializationStatus = 'Initializing upload manager...');
      await context.read<UploadManager>().initialize();

      if (!mounted) return;
      setState(() => _initializationStatus = 'Starting background publisher...');
      try {
        await context.read<VideoEventPublisher>().initialize();
      } catch (e) {
        debugPrint('⚠️ VideoEventPublisher initialization failed (backend endpoint missing): $e');
        // Continue anyway - this is for background publishing optimization
      }

      if (!mounted) return;
      setState(() => _initializationStatus = 'Connecting video feed...');
      await context.read<VideoEventBridge>().initialize();

      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _initializationStatus = 'Ready!';
      });
      
      debugPrint('✅ All services initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Service initialization failed: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isInitialized = true; // Continue anyway with basic functionality
          _initializationStatus = 'Initialization completed with errors';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: VineTheme.vineGreen),
              const SizedBox(height: 16),
              Text(
                _initializationStatus,
                style: const TextStyle(color: VineTheme.primaryText, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Check authentication state and show appropriate screen
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        switch (authService.authState) {
          case AuthState.unauthenticated:
            // On web platform, show the web authentication screen
            if (kIsWeb) {
              return const WebAuthScreen();
            }
            
            // Show error screen only if there's an actual error, not for TikTok-style auto-creation
            if (authService.lastError != null) {
              return Scaffold(
                backgroundColor: VineTheme.backgroundColor,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Authentication Error',
                        style: const TextStyle(color: VineTheme.primaryText, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        authService.lastError!,
                        style: const TextStyle(color: VineTheme.secondaryText, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => authService.initialize(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VineTheme.vineGreen,
                          foregroundColor: VineTheme.whiteText,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            // If no error, fall through to loading screen (auto-creation in progress)
            return Scaffold(
              backgroundColor: VineTheme.backgroundColor,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: VineTheme.vineGreen),
                    const SizedBox(height: 16),
                    const Text(
                      'Creating your identity...',
                      style: TextStyle(color: VineTheme.primaryText, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          case AuthState.checking:
          case AuthState.authenticating:
            return Scaffold(
              backgroundColor: VineTheme.backgroundColor,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: VineTheme.vineGreen),
                    const SizedBox(height: 16),
                    Text(
                      authService.authState == AuthState.checking
                          ? 'Getting things ready...'
                          : 'Setting up your identity...',
                      style: const TextStyle(color: VineTheme.primaryText, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          case AuthState.authenticated:
            return const MainNavigationScreen();
        }
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalKey<State<FeedScreenV2>> _feedScreenKey = GlobalKey<State<FeedScreenV2>>();
  
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      FeedScreenV2(key: _feedScreenKey),
      const ActivityScreen(),
      const ExploreScreen(),
      const ProfileScreen(),
    ];
  }

  void _onTabTapped(int index) {
    // If leaving the feed screen (index 0), pause all videos
    if (_currentIndex == 0 && index != 0) {
      _pauseFeedVideos();
    }
    
    setState(() {
      _currentIndex = index;
    });
  }
  
  void _pauseFeedVideos() {
    try {
      FeedScreenV2.pauseVideos(_feedScreenKey);
      debugPrint('🎬 Paused feed videos when navigating away');
    } catch (e) {
      debugPrint('⚠️ Error pausing feed videos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => _onTabTapped(index),
        backgroundColor: VineTheme.vineGreen,
        selectedItemColor: VineTheme.whiteText,
        unselectedItemColor: VineTheme.whiteText.withValues(alpha: 0.7),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'FEED',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'ACTIVITY',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'EXPLORE',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'PROFILE',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Pause feed videos before opening camera
          if (_currentIndex == 0) {
            _pauseFeedVideos();
          }
          // Show different screen based on platform
          if (kIsWeb) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WebCameraPlaceholder()),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CameraScreen()),
            );
          }
        },
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: VineTheme.whiteText,
        child: const Icon(Icons.videocam, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

/// ResponsiveWrapper limits the app width to mobile phone size on web platforms
class ResponsiveWrapper extends StatefulWidget {
  final Widget child;
  
  // iPhone 14 Pro dimensions: 393x852 (we'll use 393 as max width for vertical video format)
  static const double maxWidth = 393.0;
  
  const ResponsiveWrapper({super.key, required this.child});

  @override
  State<ResponsiveWrapper> createState() => _ResponsiveWrapperState();
}

class _ResponsiveWrapperState extends State<ResponsiveWrapper> {
  @override
  void initState() {
    super.initState();
    
    // Force rebuilds on window resize for web
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Listen to media query changes which includes window resizing
        MediaQuery.of(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Use MediaQuery to get real-time screen dimensions
      final mediaQuery = MediaQuery.of(context);
      final screenWidth = mediaQuery.size.width;
      final screenHeight = mediaQuery.size.height;
      
      return Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: screenWidth > ResponsiveWrapper.maxWidth ? ResponsiveWrapper.maxWidth : screenWidth,
              minHeight: screenHeight,
            ),
            child: widget.child,
          ),
        ),
      );
    }
    
    // On mobile, return child as-is (no constraints)
    return widget.child;
  }
}
