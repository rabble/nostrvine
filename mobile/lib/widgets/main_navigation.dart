import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/feed_screen_v2.dart';
import '../screens/camera_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/notifications_screen.dart';
import '../services/notification_service_enhanced.dart';
import '../services/video_manager_interface.dart';
import '../widgets/notification_badge.dart';
import '../widgets/global_upload_indicator.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<Widget> _screens = [
    const FeedScreenV2(),
    const CameraScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.black,
          body: PageView(
            controller: _pageController,
            children: _screens,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey, width: 0.2),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.black,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          elevation: 0,
          onTap: (index) {
            // Pause all videos when switching to camera (index 1)
            if (index == 1) {
              final videoManager = context.read<IVideoManager>();
              videoManager.pauseAllVideos();
              debugPrint('🎥 Paused all videos before entering camera mode');
            }
            
            setState(() {
              _currentIndex = index;
            });
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                _currentIndex == 0 ? Icons.home : Icons.home_outlined,
                size: 28,
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _currentIndex == 1 ? Colors.purple : Colors.transparent,
                  border: Border.all(
                    color: _currentIndex == 1 ? Colors.purple : Colors.white,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.add,
                  size: 20,
                  color: _currentIndex == 1 ? Colors.white : Colors.white,
                ),
              ),
              label: 'Create',
            ),
            BottomNavigationBarItem(
              icon: Consumer<NotificationServiceEnhanced>(
                builder: (context, notificationService, _) {
                  return AnimatedNotificationBadge(
                    count: notificationService.unreadCount,
                    child: Icon(
                      _currentIndex == 2 ? Icons.notifications : Icons.notifications_outlined,
                      size: 28,
                    ),
                  );
                },
              ),
              label: 'Notifications',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                _currentIndex == 3 ? Icons.person : Icons.person_outline,
                size: 28,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    ),
    // Global upload indicator overlay
    const GlobalUploadIndicator(),
  ],
);
}
}