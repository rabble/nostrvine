// ABOUTME: Placeholder screen for web platform where camera recording is disabled
// ABOUTME: Web version is viewer-only with sharing and interaction features

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/vine_theme.dart';

class WebCameraPlaceholder extends StatelessWidget {
  const WebCameraPlaceholder({super.key});

  String _getTitleText() {
    if (kIsWeb) {
      return 'Recording Not Available on Web';
    } else if (Platform.isLinux || Platform.isWindows) {
      return 'Recording Not Available on Desktop';
    } else {
      return 'Recording Not Available on Simulator';
    }
  }

  String _getSubtitleText() {
    if (kIsWeb) {
      return 'To create and upload vines, please use the mobile app on iOS or Android.';
    } else if (Platform.isLinux || Platform.isWindows) {
      return 'To create and upload vines, please use the mobile app on iOS or Android.';
    } else {
      return 'Camera functionality requires a real device. Please test on an actual iPhone or Android device.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        title: const Text(
          'Create',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_off,
                size: 80,
                color: VineTheme.secondaryText,
              ),
              const SizedBox(height: 24),
              Text(
                _getTitleText(),
                style: const TextStyle(
                  color: VineTheme.primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _getSubtitleText(),
                style: TextStyle(
                  color: VineTheme.secondaryText,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Download app buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Add App Store link
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('iOS app coming soon!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.apple),
                    label: const Text('App Store'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Add Play Store link
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Android app coming soon!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.android),
                    label: const Text('Play Store'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VineTheme.vineGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              // Features available on web
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'What you can do on web:',
                      style: TextStyle(
                        color: VineTheme.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureRow(Icons.play_circle_outline, 'Watch vines'),
                    _buildFeatureRow(Icons.favorite_outline, 'Like and interact'),
                    _buildFeatureRow(Icons.share, 'Share vines'),
                    _buildFeatureRow(Icons.person_add, 'Follow creators'),
                    _buildFeatureRow(Icons.search, 'Discover content'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: VineTheme.vineGreen, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}