// ABOUTME: Backend processing status monitoring service for NIP-96 file uploads
// ABOUTME: Handles async processing monitoring and status polling for video/GIF processing

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/nip94_metadata.dart';

/// Status of backend file processing
enum ProcessingStatus {
  pending,      // Processing not yet started
  processing,   // Currently processing
  completed,    // Processing completed successfully
  failed,       // Processing failed with error
  timeout,      // Processing timed out
  cancelled,    // Processing was cancelled
}

/// Backend upload and processing response
class BackendUploadResponse {
  final String status;           // 'success' | 'error' | 'processing'
  final String? message;         // Status message or error description
  final NIP94Metadata? nip94Event; // Final metadata if completed
  final String? processingUrl;   // URL for status checking
  final String? jobId;           // Processing job identifier
  final Map<String, dynamic>? rawResponse; // Full backend response
  
  const BackendUploadResponse({
    required this.status,
    this.message,
    this.nip94Event,
    this.processingUrl,
    this.jobId,
    this.rawResponse,
  });
  
  factory BackendUploadResponse.fromJson(Map<String, dynamic> json) {
    return BackendUploadResponse(
      status: json['status'] as String,
      message: json['message'] as String?,
      nip94Event: json['nip94_event'] != null 
        ? NIP94Metadata.fromJson(json['nip94_event'] as Map<String, dynamic>)
        : null,
      processingUrl: json['processing_url'] as String?,
      jobId: json['job_id'] as String?,
      rawResponse: json,
    );
  }
  
  bool get isSuccess => status == 'success';
  bool get isError => status == 'error';
  bool get isProcessing => status == 'processing';
  bool get hasProcessingUrl => processingUrl != null && processingUrl!.isNotEmpty;
  bool get hasJobId => jobId != null && jobId!.isNotEmpty;
}

/// Processing status response from backend
class ProcessingStatusResponse {
  final ProcessingStatus status;
  final String? message;
  final double? progress;        // 0.0 to 1.0
  final NIP94Metadata? metadata; // Available when completed
  final String? error;           // Error details if failed
  final Map<String, dynamic>? processingInfo; // Additional processing details
  final DateTime timestamp;
  
  const ProcessingStatusResponse({
    required this.status,
    this.message,
    this.progress,
    this.metadata,
    this.error,
    this.processingInfo,
    required this.timestamp,
  });
  
  factory ProcessingStatusResponse.fromJson(Map<String, dynamic> json) {
    ProcessingStatus status;
    switch (json['status'] as String) {
      case 'pending':
        status = ProcessingStatus.pending;
        break;
      case 'processing':
        status = ProcessingStatus.processing;
        break;
      case 'completed':
        status = ProcessingStatus.completed;
        break;
      case 'failed':
        status = ProcessingStatus.failed;
        break;
      case 'timeout':
        status = ProcessingStatus.timeout;
        break;
      case 'cancelled':
        status = ProcessingStatus.cancelled;
        break;
      default:
        status = ProcessingStatus.failed;
    }
    
    return ProcessingStatusResponse(
      status: status,
      message: json['message'] as String?,
      progress: (json['progress'] as num?)?.toDouble(),
      metadata: json['metadata'] != null 
        ? NIP94Metadata.fromJson(json['metadata'] as Map<String, dynamic>)
        : null,
      error: json['error'] as String?,
      processingInfo: json['processing_info'] as Map<String, dynamic>?,
      timestamp: DateTime.now(),
    );
  }
  
  bool get isCompleted => status == ProcessingStatus.completed;
  bool get isFailed => status == ProcessingStatus.failed || status == ProcessingStatus.timeout;
  bool get isProcessing => status == ProcessingStatus.processing || status == ProcessingStatus.pending;
  String get displayMessage => message ?? _getDefaultMessage();
  
  String _getDefaultMessage() {
    switch (status) {
      case ProcessingStatus.pending:
        return 'Queued for processing';
      case ProcessingStatus.processing:
        return progress != null 
          ? 'Processing... ${(progress! * 100).toInt()}%'
          : 'Processing your content';
      case ProcessingStatus.completed:
        return 'Processing completed successfully';
      case ProcessingStatus.failed:
        return error ?? 'Processing failed';
      case ProcessingStatus.timeout:
        return 'Processing timed out';
      case ProcessingStatus.cancelled:
        return 'Processing was cancelled';
    }
  }
}

/// Exception thrown during processing monitoring
class ProcessingMonitorException implements Exception {
  final String message;
  final ProcessingStatus? lastStatus;
  final bool isRetryable;
  
  const ProcessingMonitorException(
    this.message, [
    this.lastStatus,
    this.isRetryable = false,
  ]);
  
  @override
  String toString() => 'ProcessingMonitorException: $message';
}

/// Service for monitoring backend processing status
class ProcessingStatusMonitor extends ChangeNotifier {
  final http.Client _httpClient;
  final Map<String, StreamController<ProcessingStatusResponse>> _statusStreams = {};
  final Map<String, Timer> _pollTimers = {};
  
  // Configuration - More conservative polling to reduce CPU usage
  static const Duration defaultPollInterval = Duration(seconds: 5); // Reduced from 2s to 5s
  static const Duration defaultTimeout = Duration(minutes: 5);
  static const int maxRetries = 60; // Adjusted for longer interval
  
  ProcessingStatusMonitor({http.Client? httpClient}) 
    : _httpClient = httpClient ?? http.Client();
  
  /// Monitor processing status with real-time updates
  Stream<ProcessingStatusResponse> monitorProcessing({
    required String processingUrl,
    Duration pollInterval = defaultPollInterval,
    Duration timeout = defaultTimeout,
    String? jobId,
  }) {
    final streamKey = jobId ?? processingUrl;
    
    // Return existing stream if already monitoring
    if (_statusStreams.containsKey(streamKey)) {
      return _statusStreams[streamKey]!.stream;
    }
    
    final controller = StreamController<ProcessingStatusResponse>.broadcast(
      onCancel: () => _stopMonitoring(streamKey),
    );
    
    _statusStreams[streamKey] = controller;
    
    // Start polling
    _startPolling(
      streamKey: streamKey,
      processingUrl: processingUrl,
      controller: controller,
      pollInterval: pollInterval,
      timeout: timeout,
    );
    
    return controller.stream;
  }
  
  /// Wait for processing completion with timeout
  Future<NIP94Metadata> waitForProcessing(
    String processingUrl, {
    Duration timeout = defaultTimeout,
    Duration pollInterval = defaultPollInterval,
    String? jobId,
  }) async {
    final completer = Completer<NIP94Metadata>();
    
    late StreamSubscription subscription;
    late Timer timeoutTimer;
    
    // Set up timeout
    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.completeError(ProcessingMonitorException(
          'Processing timed out after ${timeout.inSeconds} seconds',
          ProcessingStatus.timeout,
          false,
        ));
      }
    });
    
    try {
      subscription = monitorProcessing(
        processingUrl: processingUrl,
        pollInterval: pollInterval,
        jobId: jobId,
      ).listen(
        (status) {
          if (status.isCompleted && status.metadata != null) {
            timeoutTimer.cancel();
            subscription.cancel();
            if (!completer.isCompleted) {
              completer.complete(status.metadata!);
            }
          } else if (status.isFailed) {
            timeoutTimer?.cancel();
            subscription.cancel();
            if (!completer.isCompleted) {
              completer.completeError(ProcessingMonitorException(
                status.error ?? 'Processing failed',
                status.status,
                status.status == ProcessingStatus.timeout,
              ));
            }
          }
        },
        onError: (error) {
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );
      
      return await completer.future;
    } catch (e) {
      timeoutTimer.cancel();
      subscription.cancel();
      rethrow;
    }
  }
  
  /// Get current processing status (single check)
  Future<ProcessingStatusResponse> getProcessingStatus(String processingUrl) async {
    try {
      final response = await _httpClient.get(
        Uri.parse(processingUrl),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'NostrVine/1.0',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return ProcessingStatusResponse.fromJson(jsonData);
      } else {
        throw ProcessingMonitorException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          null,
          response.statusCode >= 500, // Server errors are retryable
        );
      }
    } catch (e) {
      if (e is ProcessingMonitorException) rethrow;
      
      debugPrint('❌ Error checking processing status: $e');
      throw ProcessingMonitorException(
        'Failed to check processing status: $e',
        null,
        true, // Network errors are retryable
      );
    }
  }
  
  /// Start polling for status updates
  void _startPolling({
    required String streamKey,
    required String processingUrl,
    required StreamController<ProcessingStatusResponse> controller,
    required Duration pollInterval,
    required Duration timeout,
  }) {
    int attemptCount = 0;
    final startTime = DateTime.now();
    
    final timer = Timer.periodic(pollInterval, (timer) async {
      // Check timeout
      if (DateTime.now().difference(startTime) > timeout) {
        timer.cancel();
        _pollTimers.remove(streamKey);
        
        if (!controller.isClosed) {
          final timeoutResponse = ProcessingStatusResponse(
            status: ProcessingStatus.timeout,
            message: 'Processing timed out after ${timeout.inSeconds} seconds',
            timestamp: DateTime.now(),
          );
          controller.add(timeoutResponse);
          controller.close();
        }
        return;
      }
      
      try {
        final status = await getProcessingStatus(processingUrl);
        attemptCount++;
        
        if (!controller.isClosed) {
          controller.add(status);
        }
        
        // Stop polling if completed or failed
        if (status.isCompleted || status.isFailed) {
          timer.cancel();
          _pollTimers.remove(streamKey);
          
          if (!controller.isClosed) {
            controller.close();
          }
        }
        
        // Stop polling if too many attempts
        if (attemptCount >= maxRetries) {
          timer.cancel();
          _pollTimers.remove(streamKey);
          
          if (!controller.isClosed) {
            final timeoutResponse = ProcessingStatusResponse(
              status: ProcessingStatus.timeout,
              message: 'Maximum polling attempts reached',
              timestamp: DateTime.now(),
            );
            controller.add(timeoutResponse);
            controller.close();
          }
        }
        
      } catch (e) {
        debugPrint('⚠️ Status polling error (attempt $attemptCount): $e');
        
        if (!controller.isClosed) {
          controller.addError(e);
        }
        
        // Stop polling on non-retryable errors
        if (e is ProcessingMonitorException && !e.isRetryable) {
          timer.cancel();
          _pollTimers.remove(streamKey);
          
          if (!controller.isClosed) {
            controller.close();
          }
        }
      }
    });
    
    _pollTimers[streamKey] = timer;
  }
  
  /// Stop monitoring a specific processing job
  void _stopMonitoring(String streamKey) {
    _pollTimers[streamKey]?.cancel();
    _pollTimers.remove(streamKey);
    
    final controller = _statusStreams.remove(streamKey);
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
    
    debugPrint('🛑 Stopped monitoring processing: $streamKey');
  }
  
  /// Cancel monitoring for a specific job
  void cancelMonitoring(String processingUrlOrJobId) {
    _stopMonitoring(processingUrlOrJobId);
  }
  
  /// Cancel all active monitoring
  void cancelAllMonitoring() {
    final keys = List<String>.from(_statusStreams.keys);
    for (final key in keys) {
      _stopMonitoring(key);
    }
    
    debugPrint('🛑 Cancelled all processing monitoring');
  }
  
  /// Get list of currently monitored jobs
  List<String> get activeMonitoring => List.unmodifiable(_statusStreams.keys);
  
  /// Check if a job is being monitored
  bool isMonitoring(String processingUrlOrJobId) {
    return _statusStreams.containsKey(processingUrlOrJobId);
  }
  
  @override
  void dispose() {
    debugPrint('🧹 ProcessingStatusMonitor disposing - cleaning up ${_pollTimers.length} timers');
    cancelAllMonitoring();
    
    // Force cleanup any remaining timers
    for (final timer in _pollTimers.values) {
      timer.cancel();
    }
    _pollTimers.clear();
    
    // Force cleanup any remaining streams
    for (final controller in _statusStreams.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _statusStreams.clear();
    
    _httpClient.close();
    super.dispose();
  }
}