// ABOUTME: Universal Vine recording UI controls that work across all platforms
// ABOUTME: Provides press-to-record button, progress bar, and recording state feedback

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../services/vine_recording_controller.dart';
import '../theme/vine_theme.dart';

/// Progress bar that shows recording progress with segments
class VineRecordingProgressBar extends StatelessWidget {
  final VineRecordingController controller;
  
  const VineRecordingProgressBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final progressWidth = constraints.maxWidth * controller.progress.clamp(0.0, 1.0);
          
          return Stack(
            children: [
              // Background
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Progress fill
              AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                width: progressWidth,
                decoration: BoxDecoration(
                  color: controller.state == VineRecordingState.recording
                      ? VineTheme.vineGreen
                      : Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The main record button with press-to-record functionality
class VineRecordButton extends StatefulWidget {
  final VineRecordingController controller;
  final VoidCallback? onRecordingComplete;
  
  const VineRecordButton({
    super.key,
    required this.controller,
    this.onRecordingComplete,
  });

  @override
  State<VineRecordButton> createState() => _VineRecordButtonState();
}

class _VineRecordButtonState extends State<VineRecordButton>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    // Listen for recording completion
    widget.controller.addListener(_onRecordingStateChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onRecordingStateChanged);
    _animationController.dispose();
    super.dispose();
  }
  
  void _onRecordingStateChanged() {
    if (widget.controller.state == VineRecordingState.completed) {
      widget.onRecordingComplete?.call();
    }
  }

  void _onTapDown(TapDownDetails details) {
    debugPrint('🎬 Record button tap down - canRecord: ${widget.controller.canRecord}, state: ${widget.controller.state}');
    if (!widget.controller.canRecord) return;
    
    setState(() => _isPressed = true);
    _animationController.forward();
    widget.controller.startRecording();
  }

  void _onTapUp(TapUpDetails details) {
    debugPrint('🎬 Record button tap up - isPressed: $_isPressed, state: ${widget.controller.state}');
    if (!_isPressed || !mounted) return;
    
    setState(() => _isPressed = false);
    _animationController.reverse();
    widget.controller.stopRecording();
  }

  void _onTapCancel() {
    debugPrint('🎬 Record button tap cancel - isPressed: $_isPressed, state: ${widget.controller.state}');
    if (!_isPressed || !mounted) return;
    
    setState(() => _isPressed = false);
    _animationController.reverse();
    widget.controller.stopRecording();
  }

  @override
  Widget build(BuildContext context) {
    // Use press-and-hold behavior for all platforms
    return Listener(
      onPointerDown: (event) {
        _onTapDown(TapDownDetails(globalPosition: event.position));
      },
      onPointerUp: (event) {
        _onTapUp(TapUpDetails(kind: event.kind));
      },
      onPointerCancel: (event) {
        _onTapCancel();
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        // Add pan events for better web support
        onPanStart: (details) => _onTapDown(TapDownDetails(globalPosition: details.globalPosition)),
        onPanEnd: (details) => _onTapUp(TapUpDetails(kind: PointerDeviceKind.touch)),
        onPanCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getButtonColor(),
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: _isPressed ? [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ] : null,
                ),
                child: Icon(
                  _getButtonIcon(),
                  color: Colors.white,
                  size: 40,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getButtonColor() {
    switch (widget.controller.state) {
      case VineRecordingState.recording:
        return Colors.red;
      case VineRecordingState.completed:
        return Colors.green;
      case VineRecordingState.error:
        return Colors.orange;
      case VineRecordingState.processing:
        return Colors.blue;
      default:
        return widget.controller.canRecord ? VineTheme.vineGreen : Colors.grey;
    }
  }

  IconData _getButtonIcon() {
    switch (widget.controller.state) {
      case VineRecordingState.recording:
        return Icons.fiber_manual_record;
      case VineRecordingState.completed:
        return Icons.check;
      case VineRecordingState.processing:
        return Icons.hourglass_empty;
      case VineRecordingState.error:
        return Icons.error;
      default:
        return Icons.videocam;
    }
  }
}

/// Recording instructions and feedback text
class VineRecordingInstructions extends StatelessWidget {
  final VineRecordingController controller;
  
  const VineRecordingInstructions({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Duration display
        Text(
          _getDurationText(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Instructions
        Text(
          _getInstructionText(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getDurationText() {
    final recorded = controller.totalRecordedDuration.inSeconds;
    final remaining = controller.remainingDuration.inSeconds;
    
    switch (controller.state) {
      case VineRecordingState.recording:
        return '$recorded"/${VineRecordingController.maxRecordingDuration.inSeconds}" • Recording...';
      case VineRecordingState.completed:
        return 'Recording Complete!';
      case VineRecordingState.processing:
        return 'Processing...';
      case VineRecordingState.error:
        return 'Error occurred';
      default:
        if (controller.hasSegments) {
          return '$recorded"/${VineRecordingController.maxRecordingDuration.inSeconds}" • ${remaining}s remaining';
        }
        return '${VineRecordingController.maxRecordingDuration.inSeconds}s Vine • Press and hold to record';
    }
  }

  String _getInstructionText() {
    switch (controller.state) {
      case VineRecordingState.recording:
        return 'Release to pause • Recording segment ${controller.segments.length + 1}';
      case VineRecordingState.paused:
        return 'Press and hold to continue recording';
      case VineRecordingState.completed:
        return 'Tap next to add caption and share';
      case VineRecordingState.processing:
        return 'Compiling your vine...';
      case VineRecordingState.error:
        return 'Something went wrong. Try again.';
      default:
        return 'Press and hold to record, release to pause';
    }
  }
}

/// Complete Vine recording UI that combines all components
class VineRecordingUI extends StatelessWidget {
  final VineRecordingController controller;
  final VoidCallback? onRecordingComplete;
  final VoidCallback? onCancel;
  
  const VineRecordingUI({
    super.key,
    required this.controller,
    this.onRecordingComplete,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Progress bar at top
            VineRecordingProgressBar(controller: controller),
            
            const Spacer(),
            
            // Recording controls at bottom
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Instructions
                VineRecordingInstructions(controller: controller),
                
                const SizedBox(height: 30),
                
                // Control buttons
                SizedBox(
                  height: 80, // Fixed height to prevent overflow
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Cancel/Reset button
                      if (controller.hasSegments || controller.state == VineRecordingState.error) ...[
                        GestureDetector(
                          onTap: () {
                            controller.reset();
                            onCancel?.call();
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white24,
                              border: Border.all(color: Colors.white54, width: 2),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 50), // Placeholder for spacing
                      ],
                      
                      // Main record button
                      VineRecordButton(
                        controller: controller,
                        onRecordingComplete: onRecordingComplete,
                      ),
                      
                      // Done/Next button
                      if (controller.hasSegments && controller.state != VineRecordingState.recording) ...[
                        GestureDetector(
                          onTap: onRecordingComplete,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: VineTheme.vineGreen,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 50), // Placeholder for spacing
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}