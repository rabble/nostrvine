// ABOUTME: Platform interface for the OS-backed background uploader.
// ABOUTME: Defines the enqueue / cancel / event contract implementations honor.

import 'dart:async';

import 'package:background_uploader/background_uploader_method_channel.dart';
import 'package:background_uploader/src/models/background_upload_event.dart';
import 'package:background_uploader/src/models/background_upload_request.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The interface that implementations of background_uploader must implement.
abstract class BackgroundUploaderPlatform extends PlatformInterface {
  /// Constructs a BackgroundUploaderPlatform.
  BackgroundUploaderPlatform() : super(token: _token);

  static final Object _token = Object();

  static BackgroundUploaderPlatform _instance =
      MethodChannelBackgroundUploader();

  /// The default instance of [BackgroundUploaderPlatform] to use.
  ///
  /// Defaults to [MethodChannelBackgroundUploader].
  static BackgroundUploaderPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [BackgroundUploaderPlatform] when
  /// they register themselves.
  static set instance(BackgroundUploaderPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Emits progress and terminal events for all enqueued uploads.
  Stream<BackgroundUploadEvent> get events {
    throw UnimplementedError('events has not been implemented.');
  }

  /// Whether the current platform can perform OS-backed background uploads.
  Future<bool> isSupported() {
    throw UnimplementedError('isSupported() has not been implemented.');
  }

  /// Hands [request] to the OS for background upload.
  Future<void> enqueue(BackgroundUploadRequest request) {
    throw UnimplementedError('enqueue() has not been implemented.');
  }

  /// Cancels the upload identified by [taskId], if it is still in flight.
  Future<void> cancel(String taskId) {
    throw UnimplementedError('cancel() has not been implemented.');
  }

  /// Returns the task ids the OS still has in flight.
  ///
  /// Used to reconcile state after the app is relaunched: an upload may have
  /// completed (or still be running) while Dart was not attached.
  Future<List<String>> activeTaskIds() {
    throw UnimplementedError('activeTaskIds() has not been implemented.');
  }
}
