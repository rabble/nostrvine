import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'theme/vine_theme.dart';
import 'screens/universal_camera_screen.dart';
import 'screens/feed_screen_v2.dart';
import 'screens/profile_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/web_auth_screen.dart';
import 'widgets/age_verification_dialog.dart';
import 'widgets/app_lifecycle_handler.dart';
import 'services/nostr_service.dart';
import 'services/auth_service.dart';
import 'services/key_storage_service.dart';
import 'services/secure_key_storage_service.dart';
import 'services/nostr_service_interface.dart';
import 'services/nostr_key_manager.dart';
import 'services/video_event_service.dart';
import 'services/logging_config_service.dart';
import 'utils/unified_logger.dart';
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
import 'services/hashtag_service.dart';
import 'services/video_manager_interface.dart';
import 'services/video_manager_service.dart';
import 'services/video_event_bridge.dart';
import 'services/video_visibility_manager.dart';
import 'services/curation_service.dart';
import 'services/explore_video_manager.dart';
import 'services/content_reporting_service.dart';
import 'services/curated_list_service.dart';
import 'services/video_sharing_service.dart';
import 'services/content_deletion_service.dart';
import 'services/content_blocklist_service.dart';
import 'services/fake_shared_preferences.dart';
import 'services/analytics_service.dart';
import 'services/subscription_manager.dart';
import 'services/profile_cache_service.dart';
import 'services/nip05_service.dart';
import 'services/age_verification_service.dart';
// import 'providers/video_feed_provider.dart'; // Removed - FeedScreenV2 uses VideoManager directly
import 'providers/profile_stats_provider.dart';
import 'providers/profile_videos_provider.dart';
import 'models/video_event.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  // Ensure bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logging configuration first
  await LoggingConfigService.instance.initialize();
  
  // Set default log level based on build mode if not already configured
  if (const String.fromEnvironment('LOG_LEVEL').isEmpty) {
    if (kDebugMode) {
      // Debug builds: enable debug logging for development visibility
      UnifiedLogger.setLogLevel(LogLevel.debug);
      UnifiedLogger.enableCategories({LogCategory.system, LogCategory.auth, LogCategory.relay, LogCategory.video});
    } else {
      // Release builds: minimal logging to reduce performance impact
      UnifiedLogger.setLogLevel(LogLevel.warning);
      UnifiedLogger.enableCategories({LogCategory.system, LogCategory.auth});
    }
  }
  
  // Store original debugPrint to avoid recursion
  final originalDebugPrint = debugPrint;
  
  // Override debugPrint to respect logging levels
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null && UnifiedLogger.isLevelEnabled(LogLevel.debug)) {
      originalDebugPrint(message, wrapWidth: wrapWidth);
    }
  };
  
  // Handle Flutter framework errors more gracefully
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log the error but don't crash the app for known framework issues
    if (details.exception.toString().contains('KeyDownEvent') ||
        details.exception.toString().contains('HardwareKeyboard')) {
      Log.warning('Known Flutter framework keyboard issue (ignoring): ${details.exception}', name: 'Main');
      return;
    }
    
    // For other errors, use default handling
    FlutterError.presentError(details);
  };
  
  // Initialize Hive for local data storage
  await Hive.initFlutter();
  
  Log.info('🚀 OpenVine starting...', name: 'Main');
  Log.info('📊 Log level: ${UnifiedLogger.currentLevel.name}', name: 'Main');
  
  runApp(const OpenVineApp());
}

class OpenVineApp extends StatelessWidget {
  const OpenVineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Connection status service
        ChangeNotifierProvider(create: (_) => ConnectionStatusService()),
        
        // Video visibility manager - ensures videos only play when visible
        ChangeNotifierProvider(create: (_) => VideoVisibilityManager()),
        
        // Analytics service (with opt-out support)
        ChangeNotifierProvider(create: (_) {
          final service = AnalyticsService();
          service.initialize(); // Initialize asynchronously
          return service;
        }),
        
        // Age verification service
        ChangeNotifierProvider(create: (_) {
          final service = AgeVerificationService();
          service.initialize(); // Initialize asynchronously
          return service;
        }),
        
        // Secure key storage service (foundational service)
        ChangeNotifierProvider(create: (_) => SecureKeyStorageService()),
        
        // Legacy key storage service (for migration only)
        ChangeNotifierProvider(create: (_) => KeyStorageService()),
        
        // Web authentication service (for web platform only)
        ChangeNotifierProvider(create: (_) => WebAuthService()),
        
        // Authentication service depends on secure key storage
        ChangeNotifierProxyProvider<SecureKeyStorageService, AuthService>(
          create: (context) => AuthService(keyStorage: context.read<SecureKeyStorageService>()),
          update: (_, secureKeyStorageService, previous) => previous ?? AuthService(keyStorage: secureKeyStorageService),
        ),
        
        // Nostr key manager
        ChangeNotifierProvider(create: (_) => NostrKeyManager()),
        
        // Core Nostr service using nostr_sdk
        ChangeNotifierProxyProvider<NostrKeyManager, INostrService>(
          create: (context) {
            final keyManager = context.read<NostrKeyManager>();
            Log.debug('Creating NostrService with nostr_sdk RelayPool', name: 'Main');
            return NostrService(keyManager);
          },
          update: (_, keyManager, previous) {
            if (previous != null) return previous;
            Log.debug('Creating NostrService with nostr_sdk RelayPool', name: 'Main');
            return NostrService(keyManager);
          },
        ),
        
        // Subscription manager for centralized subscription management
        ChangeNotifierProxyProvider<INostrService, SubscriptionManager>(
          create: (context) => SubscriptionManager(context.read<INostrService>()),
          update: (_, nostrService, previous) => previous ?? SubscriptionManager(nostrService),
        ),
        
        // Profile cache service for persistent profile storage
        ChangeNotifierProvider(
          create: (_) {
            final service = ProfileCacheService();
            // Initialize asynchronously to avoid blocking UI
            service.initialize().catchError((e) {
              Log.error('Failed to initialize ProfileCacheService', name: 'Main', error: e);
            });
            return service;
          },
        ),
        
        // Seen videos service for tracking viewed content
        ChangeNotifierProvider(create: (_) => SeenVideosService()),
        
        // Content blocklist service for filtering unwanted content from feeds
        ChangeNotifierProvider(create: (_) => ContentBlocklistService()),
        
        // Video event service depends on Nostr, SeenVideos, Blocklist, and SubscriptionManager services
        ChangeNotifierProxyProvider4<INostrService, SeenVideosService, ContentBlocklistService, SubscriptionManager, VideoEventService>(
          create: (context) {
            final service = VideoEventService(
              context.read<INostrService>(),
              seenVideosService: context.read<SeenVideosService>(),
              subscriptionManager: context.read<SubscriptionManager>(),
            );
            service.setBlocklistService(context.read<ContentBlocklistService>());
            return service;
          },
          update: (_, nostrService, seenVideosService, blocklistService, subscriptionManager, previous) {
            if (previous != null) {
              previous.setBlocklistService(blocklistService);
              return previous;
            }
            final service = VideoEventService(
              nostrService,
              seenVideosService: seenVideosService,
              subscriptionManager: subscriptionManager,
            );
            service.setBlocklistService(blocklistService);
            return service;
          },
        ),
        
        // Hashtag service depends on Video event service
        ChangeNotifierProxyProvider<VideoEventService, HashtagService>(
          create: (context) => HashtagService(context.read<VideoEventService>()),
          update: (_, videoService, previous) => previous ?? HashtagService(videoService),
        ),
        
        // User profile service depends on Nostr service, SubscriptionManager, and ProfileCacheService
        ChangeNotifierProxyProvider3<INostrService, SubscriptionManager, ProfileCacheService, UserProfileService>(
          create: (context) {
            final service = UserProfileService(
              context.read<INostrService>(),
              subscriptionManager: context.read<SubscriptionManager>(),
            );
            service.setPersistentCache(context.read<ProfileCacheService>());
            return service;
          },
          update: (_, nostrService, subscriptionManager, profileCache, previous) {
            if (previous != null) {
              previous.setPersistentCache(profileCache);
              return previous;
            }
            final service = UserProfileService(
              nostrService,
              subscriptionManager: subscriptionManager,
            );
            service.setPersistentCache(profileCache);
            return service;
          },
        ),
        
        // NIP-05 service for username registration and verification
        ChangeNotifierProvider(create: (_) => Nip05Service()),
        
        // Social service depends on Nostr service, Auth service, and SubscriptionManager
        ChangeNotifierProxyProvider3<INostrService, AuthService, SubscriptionManager, SocialService>(
          create: (context) => SocialService(
            context.read<INostrService>(),
            context.read<AuthService>(),
            subscriptionManager: context.read<SubscriptionManager>(),
          ),
          update: (_, nostrService, authService, subscriptionManager, previous) => previous ?? SocialService(
            nostrService,
            authService,
            subscriptionManager: subscriptionManager,
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
        
        // Profile videos provider depends on Nostr service and VideoEventService
        ChangeNotifierProxyProvider2<INostrService, VideoEventService, ProfileVideosProvider>(
          create: (context) {
            final provider = ProfileVideosProvider(
              context.read<INostrService>(),
            );
            provider.setVideoEventService(context.read<VideoEventService>());
            return provider;
          },
          update: (_, nostrService, videoEventService, previous) {
            if (previous != null) {
              previous.setVideoEventService(videoEventService);
              return previous;
            }
            final provider = ProfileVideosProvider(nostrService);
            provider.setVideoEventService(videoEventService);
            return provider;
          },
        ),
        
        // Enhanced notification service with Nostr integration (lazy loaded)
        ChangeNotifierProxyProvider3<INostrService, UserProfileService, VideoEventService, NotificationServiceEnhanced>(
          create: (context) {
            final service = NotificationServiceEnhanced();
            // Delay initialization until after critical path is loaded
            if (!kIsWeb) {
              // Initialize immediately on mobile
              final nostrService = context.read<INostrService>();
              final profileService = context.read<UserProfileService>();
              final videoService = context.read<VideoEventService>();
              
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  await service.initialize(
                    nostrService: nostrService,
                    profileService: profileService,
                    videoService: videoService,
                  );
                } catch (e) {
                  Log.error('Failed to initialize enhanced notification service: $e', name: 'Main', category: LogCategory.system);
                }
              });
            } else {
              // On web, delay initialization by 3 seconds to allow main UI to load first
              Timer(const Duration(seconds: 3), () async {
                try {
                  final nostrService = context.read<INostrService>();
                  final profileService = context.read<UserProfileService>();
                  final videoService = context.read<VideoEventService>();
                  
                  await service.initialize(
                    nostrService: nostrService,
                    profileService: profileService,
                    videoService: videoService,
                  );
                } catch (e) {
                  Log.error('Failed to initialize enhanced notification service: $e', name: 'Main', category: LogCategory.system);
                }
              });
            }
            
            return service;
          },
          update: (_, nostrService, profileService, videoService, previous) => previous ?? NotificationServiceEnhanced(),
        ),
        
        // Video Manager Service - single source of truth for video state with smart ordering
        ProxyProvider2<SeenVideosService, ContentBlocklistService, IVideoManager>(
          create: (context) {
            final videoManager = VideoManagerService(
              config: VideoManagerConfig.wifi(), // Default to WiFi optimized
              seenVideosService: context.read<SeenVideosService>(),
              blocklistService: context.read<ContentBlocklistService>(),
            );
            // Filter any existing videos that might have been loaded before blocklist
            videoManager.filterExistingVideos();
            return videoManager;
          },
          update: (_, seenVideosService, blocklistService, previous) {
            if (previous is VideoManagerService) {
              // If blocklist changed, filter existing videos
              previous.filterExistingVideos();
              return previous;
            }
            final videoManager = VideoManagerService(
              config: VideoManagerConfig.wifi(),
              seenVideosService: seenVideosService,
              blocklistService: blocklistService,
            );
            videoManager.filterExistingVideos();
            return videoManager;
          },
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
        
        // API service depends on auth service
        ChangeNotifierProxyProvider<Nip98AuthService, ApiService>(
          create: (context) => ApiService(authService: context.read<Nip98AuthService>()),
          update: (_, authService, previous) => previous ?? ApiService(authService: authService),
        ),
        
        // Video event publisher depends on multiple services
        ChangeNotifierProxyProvider4<UploadManager, INostrService, ApiService, AuthService, VideoEventPublisher>(
          create: (context) => VideoEventPublisher(
            uploadManager: context.read<UploadManager>(),
            nostrService: context.read<INostrService>(),
            authService: context.read<AuthService>(),
            fetchReadyEvents: () => context.read<ApiService>().getReadyEvents(),
            cleanupRemoteEvent: (publicId) => context.read<ApiService>().cleanupRemoteEvent(publicId),
          ),
          update: (_, uploadManager, nostrService, apiService, authService, previous) => previous ?? VideoEventPublisher(
            uploadManager: uploadManager,
            nostrService: nostrService,
            authService: authService,
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
            socialService: context.read<SocialService>(),
          ),
          dispose: (_, bridge) => bridge.dispose(),
        ),

        // Curation Service - manages NIP-51 video curation sets
        ChangeNotifierProxyProvider3<INostrService, VideoEventService, SocialService, CurationService>(
          create: (context) => CurationService(
            nostrService: context.read<INostrService>(),
            videoEventService: context.read<VideoEventService>(),
            socialService: context.read<SocialService>(),
          ),
          update: (_, nostrService, videoEventService, socialService, previous) => previous ?? CurationService(
            nostrService: nostrService,
            videoEventService: videoEventService,
            socialService: socialService,
          ),
        ),
        
        // ExploreVideoManager - bridges CurationService with separate VideoManager instance
        ChangeNotifierProxyProvider3<CurationService, SeenVideosService, ContentBlocklistService, ExploreVideoManager>(
          create: (context) {
            // Create a separate video manager instance specifically for explore
            final exploreVideoManager = VideoManagerService(
              config: VideoManagerConfig.wifi(),
              seenVideosService: context.read<SeenVideosService>(),
              blocklistService: context.read<ContentBlocklistService>(),
            );
            exploreVideoManager.filterExistingVideos();
            
            return ExploreVideoManager(
              curationService: context.read<CurationService>(),
              videoManager: exploreVideoManager,
            );
          },
          update: (_, curationService, seenVideosService, blocklistService, previous) {
            if (previous != null) {
              return previous;
            }
            
            // Create new separate video manager for explore
            final exploreVideoManager = VideoManagerService(
              config: VideoManagerConfig.wifi(),
              seenVideosService: seenVideosService,
              blocklistService: blocklistService,
            );
            exploreVideoManager.filterExistingVideos();
            
            return ExploreVideoManager(
              curationService: curationService,
              videoManager: exploreVideoManager,
            );
          },
        ),
        
        // Content reporting service for NIP-56 compliance (temporarily using FakeSharedPreferences)
        ChangeNotifierProxyProvider<INostrService, ContentReportingService>(
          create: (context) => ContentReportingService(
            nostrService: context.read<INostrService>(),
            prefs: FakeSharedPreferences(),
          ),
          update: (_, nostrService, previous) => previous ?? ContentReportingService(
            nostrService: nostrService,
            prefs: FakeSharedPreferences(),
          ),
        ),
        
        // Curated list service for NIP-51 lists (temporarily using FakeSharedPreferences)
        ChangeNotifierProxyProvider2<INostrService, AuthService, CuratedListService>(
          create: (context) => CuratedListService(
            nostrService: context.read<INostrService>(),
            authService: context.read<AuthService>(),
            prefs: FakeSharedPreferences(),
          ),
          update: (_, nostrService, authService, previous) => previous ?? CuratedListService(
            nostrService: nostrService,
            authService: authService,
            prefs: FakeSharedPreferences(),
          ),
        ),
        
        // Video sharing service
        ChangeNotifierProxyProvider3<INostrService, AuthService, UserProfileService, VideoSharingService>(
          create: (context) => VideoSharingService(
            nostrService: context.read<INostrService>(),
            authService: context.read<AuthService>(),
            userProfileService: context.read<UserProfileService>(),
          ),
          update: (_, nostrService, authService, userProfileService, previous) => previous ?? VideoSharingService(
            nostrService: nostrService,
            authService: authService,
            userProfileService: userProfileService,
          ),
        ),
        
        // Content deletion service for NIP-09 delete events (temporarily using FakeSharedPreferences)
        ChangeNotifierProxyProvider<INostrService, ContentDeletionService>(
          create: (context) => ContentDeletionService(
            nostrService: context.read<INostrService>(),
            prefs: FakeSharedPreferences(),
          ),
          update: (_, nostrService, previous) => previous ?? ContentDeletionService(
            nostrService: nostrService,
            prefs: FakeSharedPreferences(),
          ),
        ),
        
        // Note: VideoFeedProvider removed - FeedScreenV2 uses main VideoManager directly
        // ExploreVideoManager creates its own separate VideoManager instance to avoid video conflicts
        // Note: VinePublishingService removed - using video-based approach now
      ],
      child: AppLifecycleHandler(
        child: MaterialApp(
          title: 'OpenVine',
          debugShowCheckedModeBanner: false,
          theme: VineTheme.theme,
          home: const ResponsiveWrapper(child: AppInitializer()),
        ),
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
        Log.error('Nostr service initialization failed: $e', name: 'Main', category: LogCategory.system);
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
        Log.error('VideoEventPublisher initialization failed (backend endpoint missing): $e', name: 'Main', category: LogCategory.system);
        // Continue anyway - this is for background publishing optimization
      }

      if (!mounted) return;
      setState(() => _initializationStatus = 'Connecting video feed...');
      await context.read<VideoEventBridge>().initialize();

      if (!mounted) return;
      setState(() => _initializationStatus = 'Loading curated content...');
      await context.read<CurationService>().subscribeToCurationSets();

      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _initializationStatus = 'Ready!';
      });
      
      Log.info('All services initialized successfully', name: 'Main', category: LogCategory.system);
    } catch (e, stackTrace) {
      Log.error('Service initialization failed: $e', name: 'Main', category: LogCategory.system);
      Log.verbose('� Stack trace: $stackTrace', name: 'Main', category: LogCategory.system);
      
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
  final int? initialTabIndex;
  final VideoEvent? startingVideo;
  
  const MainNavigationScreen({
    super.key,
    this.initialTabIndex,
    this.startingVideo,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalKey<State<FeedScreenV2>> _feedScreenKey = GlobalKey<State<FeedScreenV2>>();
  DateTime? _lastFeedTap;
  
  late List<Widget> _screens; // Created once to preserve state

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex ?? 0;
    // Create screens once - IndexedStack will preserve their state
    _screens = [
      FeedScreenV2(
        key: _feedScreenKey,
        startingVideo: widget.startingVideo,
      ),
      const ActivityScreen(),
      const ExploreScreen(),
      const ProfileScreen(),
    ];
  }

  void _onTabTapped(int index) {
    // Check for double-tap on feed icon
    if (index == 0 && _currentIndex == 0) {
      final now = DateTime.now();
      if (_lastFeedTap != null && now.difference(_lastFeedTap!).inMilliseconds < 500) {
        // Double tap detected - scroll to top and refresh
        _scrollToTopAndRefresh();
        _lastFeedTap = null; // Reset to prevent triple tap
        return;
      }
      _lastFeedTap = now;
    }
    
    // Pause videos when leaving any tab that has video playback
    if (_currentIndex != index) {
      if (_currentIndex == 0) {
        // Leaving feed screen
        _pauseFeedVideos();
      } else if (_currentIndex == 2) {
        // Leaving explore screen
        _pauseExploreVideos();
      }
    }
    
    // Resume videos when returning to a tab with video playback
    if (_currentIndex != index) {
      if (index == 0) {
        // Returning to feed screen - just resume, state is preserved by IndexedStack
        _resumeFeedVideos();
      }
      // Note: Explore screen handles its own resume logic
    }
    
    setState(() {
      _currentIndex = index;
    });
  }
  
  void _pauseFeedVideos() {
    try {
      FeedScreenV2.pauseVideos(_feedScreenKey);
      Log.debug('Paused feed videos when navigating away', name: 'Main', category: LogCategory.system);
    } catch (e) {
      Log.error('Error pausing feed videos: $e', name: 'Main', category: LogCategory.system);
    }
  }
  
  void _resumeFeedVideos() {
    try {
      FeedScreenV2.resumeVideos(_feedScreenKey);
      Log.debug('▶️ Resumed feed videos when returning to feed', name: 'Main', category: LogCategory.system);
    } catch (e) {
      Log.error('Error resuming feed videos: $e', name: 'Main', category: LogCategory.system);
    }
  }
  
  void _pauseExploreVideos() {
    try {
      // Access the explore screen through the screens list
      final exploreScreen = _screens[2];
      if (exploreScreen is ExploreScreen) {
        // The ExploreScreen already handles pausing in its dispose method,
        // but we can force pause all videos here for immediate effect
        final exploreVideoManager = Provider.of<ExploreVideoManager>(context, listen: false);
        exploreVideoManager.pauseAllVideos();
        Log.debug('Paused explore videos when navigating away', name: 'Main', category: LogCategory.system);
      }
    } catch (e) {
      Log.error('Error pausing explore videos: $e', name: 'Main', category: LogCategory.system);
    }
  }
  
  void _scrollToTopAndRefresh() {
    try {
      // Use the static method to scroll to top and refresh
      FeedScreenV2.scrollToTopAndRefresh(_feedScreenKey);
      Log.info('🔄 Double-tap: Scrolling to top and refreshing feed', name: 'Main', category: LogCategory.ui);
    } catch (e) {
      Log.error('Error scrolling to top and refreshing: $e', name: 'Main', category: LogCategory.ui);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
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
        onPressed: () async {
          // Pause videos from any tab before opening camera
          if (_currentIndex == 0) {
            _pauseFeedVideos();
          } else if (_currentIndex == 2) {
            _pauseExploreVideos();
          }
          
          // Check age verification before opening camera
          final ageVerificationService = context.read<AgeVerificationService>();
          final isVerified = await ageVerificationService.checkAgeVerification();
          
          if (!isVerified && mounted) {
            // Show age verification dialog
            final result = await AgeVerificationDialog.show(context);
            if (result) {
              // User confirmed they are 16+
              await ageVerificationService.setAgeVerified(true);
              if (mounted) {
                // Use universal camera screen that works on all platforms
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UniversalCameraScreen()),
                );
                
                // After returning from camera, refresh profile if on profile tab
                if (mounted && _currentIndex == 3) {
                  Log.debug('Refreshing profile after camera return', name: 'Main', category: LogCategory.system);
                  final profileVideosProvider = context.read<ProfileVideosProvider>();
                  profileVideosProvider.refreshVideos();
                }
              }
            } else {
              // User is under 16 or declined
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You must be 16 or older to create content'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } else if (mounted) {
            // Already verified, go to camera
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const UniversalCameraScreen()),
            );
            
            // After returning from camera, refresh profile if on profile tab
            if (mounted && _currentIndex == 3) {
              Log.debug('Refreshing profile after camera return', name: 'Main', category: LogCategory.system);
              final profileVideosProvider = context.read<ProfileVideosProvider>();
              profileVideosProvider.refreshVideos();
            }
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
  
  // Web responsive width: Allow up to 1200px for desktop experience
  // This provides a proper web experience while still maintaining some constraints
  static const double maxWidth = 1200.0;
  
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
      // For web, use full width without constraints for a proper web experience
      return Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: widget.child,
      );
    }
    
    // On mobile, return child as-is (no constraints)
    return widget.child;
  }
}
