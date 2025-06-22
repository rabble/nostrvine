// ABOUTME: Settings screen for configuring camera recording parameters
// ABOUTME: Allows users to adjust duration, frame rate, quality, and other recording preferences

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/camera_service.dart';

class CameraSettingsScreen extends StatefulWidget {
  const CameraSettingsScreen({super.key});

  @override
  State<CameraSettingsScreen> createState() => _CameraSettingsScreenState();
}

class _CameraSettingsScreenState extends State<CameraSettingsScreen> {
  late CameraService _cameraService;
  
  @override
  void initState() {
    super.initState();
    _cameraService = context.read<CameraService>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Camera Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
      ),
      body: Consumer<CameraService>(
        builder: (context, cameraService, child) {
          final config = cameraService.configuration;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Recording Duration'),
                const SizedBox(height: 10),
                _buildDurationSlider(config),
                const SizedBox(height: 30),
                
                
                _buildSectionHeader('Recording Options'),
                const SizedBox(height: 10),
                _buildAutoStopSwitch(config),
                const SizedBox(height: 30),
                
                
                _buildSectionHeader('Quick Presets'),
                const SizedBox(height: 10),
                _buildPresetButtons(),
                const SizedBox(height: 30),
                
                _buildCurrentConfigInfo(config),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildDurationSlider(CameraConfiguration config) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recording Duration',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  '${config.recordingDuration.inSeconds}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Slider(
              value: config.recordingDuration.inSeconds.toDouble(),
              min: 3.0,
              max: 15.0,
              divisions: 12,
              activeColor: Colors.pink,
              inactiveColor: Colors.grey[600],
              onChanged: (value) {
                _cameraService.setRecordingDuration(
                  Duration(seconds: value.round()),
                );
              },
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('3s', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Text('15s', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildAutoStopSwitch(CameraConfiguration config) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-stop Recording',
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(height: 4),
                Text(
                  'Automatically stop when duration limit is reached',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            Switch(
              value: config.enableAutoStop,
              activeColor: Colors.pink,
              onChanged: (value) {
                _cameraService.useVineConfiguration(
                  duration: config.recordingDuration,
                  autoStop: value,
                );
              },
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPresetButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildPresetButton(
                'Vine Classic',
                '6 seconds',
                () => _cameraService.useVineConfiguration(),
                Colors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPresetButton(
                'Quick Snap',
                '3 seconds',
                () => _cameraService.useVineConfiguration(
                  duration: const Duration(seconds: 3),
                ),
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPresetButton(
                'Extended',
                '12 seconds',
                () => _cameraService.useVineConfiguration(
                  duration: const Duration(seconds: 12),
                ),
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPresetButton(
                'High Motion',
                '8 seconds',
                () => _cameraService.useVineConfiguration(
                  duration: const Duration(seconds: 8),
                ),
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPresetButton(String title, String description, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentConfigInfo(CameraConfiguration config) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Configuration',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Duration:', '${config.recordingDuration.inSeconds}s'),
            _buildInfoRow('Auto-stop:', config.enableAutoStop ? 'Enabled' : 'Disabled'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}