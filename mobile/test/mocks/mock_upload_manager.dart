// ABOUTME: Mock implementation of upload manager for testing camera screen upload flows
// ABOUTME: Provides controllable upload states and progress simulation for UI testing

import 'dart:io';
import 'package:nostrvine_app/services/upload_manager.dart';
import 'package:nostrvine_app/models/pending_upload.dart';

class MockUploadManager implements UploadManager {
  final List<PendingUpload> _uploads = [];
  
  @override
  Future<PendingUpload> startUpload({
    required File videoFile,
    required String nostrPubkey,
    String? thumbnailPath,
    String? title,
    String? description,
    List<String>? hashtags,
  }) async {
    final upload = PendingUpload.create(
      localVideoPath: videoFile.path,
      nostrPubkey: nostrPubkey,
      thumbnailPath: thumbnailPath,
      title: title,
      description: description,
      hashtags: hashtags,
    );
    
    _uploads.add(upload);
    return upload;
  }

  @override
  Future<void> retryUpload(String uploadId) async {
    // In a real implementation, this would restart the upload process
    // For testing, we just simulate the retry
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> cancelUpload(String uploadId) async {
    _uploads.removeWhere((u) => u.id == uploadId);
  }

  // Mock control methods for testing
  void addUpload(PendingUpload upload) {
    _uploads.add(upload);
  }

  void clearUploads() {
    _uploads.clear();
  }

  List<PendingUpload> get uploads => List.unmodifiable(_uploads);

  // Implement other required interface methods as no-ops for testing
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}