import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'screens/camera_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/profile_screen.dart';
import 'services/nostr_service.dart';
import 'services/nostr_service_interface.dart';
import 'services/nostr_key_manager.dart';
import 'services/video_event_service.dart';
import 'services/vine_publishing_service.dart';
import 'services/gif_service.dart';
import 'providers/video_feed_provider.dart';

void main() {
  runApp(const NostrVineApp());
}

class NostrVineApp extends StatelessWidget {
  const NostrVineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
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
        
        // Video event service depends on Nostr service
        ChangeNotifierProxyProvider<INostrService, VideoEventService>(
          create: (context) => VideoEventService(context.read<INostrService>()),
          update: (_, nostrService, previous) => previous ?? VideoEventService(nostrService),
        ),
        
        // Video feed provider depends on both services
        ChangeNotifierProxyProvider2<VideoEventService, INostrService, VideoFeedProvider>(
          create: (context) => VideoFeedProvider(
            videoEventService: context.read<VideoEventService>(),
            nostrService: context.read<INostrService>(),
          ),
          update: (_, videoEventService, nostrService, previous) => previous ?? VideoFeedProvider(
            videoEventService: videoEventService,
            nostrService: nostrService,
          ),
        ),
        
        // Vine publishing service depends on Nostr service
        ChangeNotifierProxyProvider<INostrService, VinePublishingService>(
          create: (context) => VinePublishingService(
            gifService: GifService(),
            nostrService: context.read<INostrService>(),
          ),
          update: (_, nostrService, previous) => previous ?? VinePublishingService(
            gifService: GifService(),
            nostrService: nostrService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'NostrVine',
        debugShowCheckedModeBanner: false,
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
        home: const ResponsiveWrapper(child: MainNavigationScreen()),
      ),
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
  
  final List<Widget> _screens = [
    const FeedScreen(),
    const CameraScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Camera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
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
