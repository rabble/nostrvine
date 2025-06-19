import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'navigation/app_router.dart';
import 'services/nostr_service.dart';
import 'services/nostr_service_interface.dart';
import 'services/nostr_key_manager.dart';
import 'services/video_event_service.dart';
import 'services/vine_publishing_service.dart';
import 'services/gif_service.dart';
import 'services/video_cache_service.dart';
import 'services/connection_status_service.dart';
import 'services/user_profile_service.dart';
import 'services/cloudinary_upload_service.dart';
import 'services/stream_upload_service.dart';
import 'services/upload_manager.dart';
import 'services/api_service.dart';
import 'services/video_event_publisher.dart';
import 'services/notification_service.dart';
import 'services/seen_videos_service.dart';
import 'services/search_service.dart';
import 'providers/video_feed_provider.dart';
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
        
        // Video cache service for managing video player controllers
        ChangeNotifierProvider(create: (_) => VideoCacheService()),
        
        // User profile service depends on Nostr service
        ChangeNotifierProxyProvider<INostrService, UserProfileService>(
          create: (context) => UserProfileService(context.read<INostrService>()),
          update: (_, nostrService, previous) => previous ?? UserProfileService(nostrService),
        ),
        
        // Notification service
        ChangeNotifierProvider(create: (_) => NotificationService.instance),
        
        // Search service depends on Nostr service
        ChangeNotifierProxyProvider<INostrService, SearchService>(
          create: (context) => SearchService(nostrService: context.read<INostrService>()),
          update: (_, nostrService, previous) => previous ?? SearchService(nostrService: nostrService),
        ),
        
        // Cloudinary upload service
        ChangeNotifierProvider(create: (_) => CloudinaryUploadService()),
        
        // Stream upload service
        ChangeNotifierProvider(create: (_) => StreamUploadService()),
        
        // Upload manager depends on Cloudinary service
        ChangeNotifierProxyProvider<CloudinaryUploadService, UploadManager>(
          create: (context) => UploadManager(cloudinaryService: context.read<CloudinaryUploadService>()),
          update: (_, cloudinaryService, previous) => previous ?? UploadManager(cloudinaryService: cloudinaryService),
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
        
        // Video feed provider depends on multiple services
        ChangeNotifierProxyProvider4<VideoEventService, INostrService, VideoCacheService, UserProfileService, VideoFeedProvider>(
          create: (context) => VideoFeedProvider(
            videoEventService: context.read<VideoEventService>(),
            nostrService: context.read<INostrService>(),
            videoCacheService: context.read<VideoCacheService>(),
            userProfileService: context.read<UserProfileService>(),
          ),
          update: (_, videoEventService, nostrService, videoCacheService, userProfileService, previous) => previous ?? VideoFeedProvider(
            videoEventService: videoEventService,
            nostrService: nostrService,
            videoCacheService: videoCacheService,
            userProfileService: userProfileService,
          ),
        ),
        
        // Vine publishing service depends on Nostr and Stream services
        ChangeNotifierProxyProvider2<INostrService, StreamUploadService, VinePublishingService>(
          create: (context) => VinePublishingService(
            gifService: GifService(),
            streamUploadService: context.read<StreamUploadService>(),
            nostrService: context.read<INostrService>(),
          ),
          update: (_, nostrService, streamUploadService, previous) => previous ?? VinePublishingService(
            gifService: GifService(),
            streamUploadService: streamUploadService,
            nostrService: nostrService,
          ),
        ),
      ],
      child: MaterialApp.router(
        title: 'NostrVine',
        debugShowCheckedModeBanner: false,
        routerConfig: AppRouter.router,
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.purple,
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.black,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.black,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
          ),
        ),
        builder: (context, child) => ResponsiveWrapper(
          child: child ?? const AppInitializer(),
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
      setState(() => _initializationStatus = 'Initializing notifications...');
      await context.read<NotificationService>().initialize();

      if (!mounted) return;
      setState(() => _initializationStatus = 'Initializing seen videos tracker...');
      await context.read<SeenVideosService>().initialize();

      if (!mounted) return;
      setState(() => _initializationStatus = 'Initializing upload manager...');
      await context.read<UploadManager>().initialize();

      if (!mounted) return;
      setState(() => _initializationStatus = 'Starting background publisher...');
      await context.read<VideoEventPublisher>().initialize();

      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _initializationStatus = 'Ready!';
      });
      
      debugPrint('✅ All services initialized successfully');
      
      // Navigate to the main feed after successful initialization
      if (mounted) {
        context.go(AppRouter.feedPath);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Service initialization failed: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isInitialized = true; // Continue anyway with basic functionality
          _initializationStatus = 'Initialization completed with errors';
        });
        
        // Still navigate to feed even with errors
        context.go(AppRouter.feedPath);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.purple),
              const SizedBox(height: 16),
              Text(
                _initializationStatus,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Navigation is now handled by the router
    return const SizedBox.shrink();
  }
}


/// ResponsiveWrapper limits the app width to iPad size on web platforms
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  
  // iPad Pro dimensions: 1024x1366 (we'll use 1024 as max width)
  static const double maxWidth = 1024.0;
  
  const ResponsiveWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      );
    }
    
    // On mobile, return child as-is (no constraints)
    return child;
  }
}
