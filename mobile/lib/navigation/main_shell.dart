// ABOUTME: Main shell component that provides bottom navigation for the app
// ABOUTME: Wraps main tab screens and provides consistent navigation UI

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/upload_manager.dart';

/// Main shell that provides bottom navigation bar for primary app screens
class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  /// Map of routes to their bottom nav indices
  static const Map<String, int> _routeToIndex = {
    '/': 0,           // Feed
    '/camera': 1,     // Camera
    '/profile': 2,    // Profile
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCurrentIndex();
  }

  void _updateCurrentIndex() {
    final currentLocation = GoRouterState.of(context).uri.path;
    final newIndex = _routeToIndex[currentLocation] ?? 0;
    if (_currentIndex != newIndex) {
      setState(() {
        _currentIndex = newIndex;
      });
    }
  }

  void _onTapBottomNavItem(int index) {
    if (_currentIndex == index) return; // Already on this tab

    setState(() {
      _currentIndex = index;
    });

    // Navigate to the corresponding route
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/camera');
        break;
      case 2:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onTapBottomNavItem,
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
      floatingActionButton: Consumer<UploadManager>(
        builder: (context, uploadManager, child) {
          final activeCount = uploadManager.activeUploadCount;
          final queuedCount = uploadManager.queuedUploadCount;
          final hasUploads = activeCount > 0 || queuedCount > 0;

          // Only show FAB when there are uploads to manage
          if (!hasUploads) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: () {
              context.push('/uploads');
            },
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            icon: Stack(
              children: [
                const Icon(Icons.cloud_upload),
                if (activeCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        activeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: Text('${activeCount + queuedCount}'),
          );
        },
      ),
    );
  }
}