import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/camera_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/profile_screen.dart';
import 'services/nostr_service.dart';
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
        
        // Core Nostr service
        ChangeNotifierProxyProvider<NostrKeyManager, NostrService>(
          create: (context) => NostrService(context.read<NostrKeyManager>()),
          update: (_, keyManager, __) => NostrService(keyManager),
        ),
        
        // Video event service depends on Nostr service
        ChangeNotifierProxyProvider<NostrService, VideoEventService>(
          create: (context) => VideoEventService(context.read<NostrService>()),
          update: (_, nostrService, __) => VideoEventService(nostrService),
        ),
        
        // Video feed provider depends on both services
        ChangeNotifierProxyProvider2<VideoEventService, NostrService, VideoFeedProvider>(
          create: (context) => VideoFeedProvider(
            videoEventService: context.read<VideoEventService>(),
            nostrService: context.read<NostrService>(),
          ),
          update: (_, videoEventService, nostrService, __) => VideoFeedProvider(
            videoEventService: videoEventService,
            nostrService: nostrService,
          ),
        ),
        
        // Vine publishing service depends on Nostr service
        ChangeNotifierProxyProvider<NostrService, VinePublishingService>(
          create: (context) => VinePublishingService(
            gifService: GifService(),
            nostrService: context.read<NostrService>(),
          ),
          update: (_, nostrService, __) => VinePublishingService(
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
        home: const MainNavigationScreen(),
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
