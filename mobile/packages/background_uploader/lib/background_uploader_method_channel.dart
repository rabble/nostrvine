// ABOUTME: Method-channel implementation of the background uploader platform.
// ABOUTME: Forwards enqueue/cancel to native and fans native events into Dart.

import 'dart:async';

import 'package:background_uploader/background_uploader_platform_interface.dart';
import 'package:background_uploader/src/models/background_upload_event.dart';
import 'package:background_uploader/src/models/background_upload_request.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An implementation of [BackgroundUploaderPlatform] that uses method channels.
class MethodChannelBackgroundUploader extends BackgroundUploaderPlatform {
  /// Constructor that wires the native event callback.
  MethodChannelBackgroundUploader() {
    methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('background_uploader');

  final StreamController<BackgroundUploadEvent> _eventController =
      StreamController<BackgroundUploadEvent>.broadcast();

  @override
  Stream<BackgroundUploadEvent> get events => _eventController.stream;

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onUploadEvent':
        final arguments = call.arguments;
        if (arguments is Map<dynamic, dynamic>) {
          final event = BackgroundUploadEvent.tryFromMap(arguments);
          if (event != null) {
            _eventController.add(event);
          }
        }
        return null;
      default:
        return null;
    }
  }

  @override
  Future<bool> isSupported() async {
    final result = await methodChannel.invokeMethod<bool>('isSupported');
    return result ?? false;
  }

  @override
  Future<void> enqueue(BackgroundUploadRequest request) {
    return methodChannel.invokeMethod<void>('enqueue', request.toMap());
  }

  @override
  Future<void> cancel(String taskId) {
    return methodChannel.invokeMethod<void>('cancel', <String, Object?>{
      'taskId': taskId,
    });
  }

  @override
  Future<void> beginForegroundSession(String sessionId) {
    return methodChannel.invokeMethod<void>(
      'beginForegroundSession',
      <String, Object?>{'sessionId': sessionId},
    );
  }

  @override
  Future<void> endForegroundSession(String sessionId) {
    return methodChannel.invokeMethod<void>(
      'endForegroundSession',
      <String, Object?>{'sessionId': sessionId},
    );
  }

  @override
  Future<List<String>> activeTaskIds() async {
    final result = await methodChannel.invokeListMethod<String>(
      'activeTaskIds',
    );
    return result ?? const <String>[];
  }
}
