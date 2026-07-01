import 'dart:async';

import 'package:background_uploader/background_uploader.dart';
import 'package:background_uploader/background_uploader_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeBackgroundUploaderPlatform extends BackgroundUploaderPlatform
    with MockPlatformInterfaceMixin {
  final List<BackgroundUploadRequest> enqueued = <BackgroundUploadRequest>[];
  final List<String> cancelled = <String>[];
  final List<String> sessionsBegun = <String>[];
  final List<String> sessionsEnded = <String>[];

  @override
  Stream<BackgroundUploadEvent> get events =>
      const Stream<BackgroundUploadEvent>.empty();

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> enqueue(BackgroundUploadRequest request) async =>
      enqueued.add(request);

  @override
  Future<void> cancel(String taskId) async => cancelled.add(taskId);

  final List<String> activeTaskIdsResult = <String>[];

  @override
  Future<List<String>> activeTaskIds() async => activeTaskIdsResult;

  final Map<String, BackgroundUploadEvent> bufferedTerminals =
      <String, BackgroundUploadEvent>{};

  @override
  Future<BackgroundUploadEvent?> takeBufferedTerminalEvent(
    String taskId,
  ) async => bufferedTerminals.remove(taskId);

  @override
  Future<void> beginForegroundSession(String sessionId) async =>
      sessionsBegun.add(sessionId);

  @override
  Future<void> endForegroundSession(String sessionId) async =>
      sessionsEnded.add(sessionId);
}

void main() {
  group('BackgroundUploader.enqueue validation', () {
    late _FakeBackgroundUploaderPlatform fake;

    setUp(() {
      fake = _FakeBackgroundUploaderPlatform();
      BackgroundUploaderPlatform.instance = fake;
    });

    BackgroundUploadRequest request({
      String method = 'PUT',
      String url = 'https://media.divine.video/upload',
    }) {
      return BackgroundUploadRequest(
        taskId: 'task-1',
        url: Uri.parse(url),
        filePath: '/tmp/video.mp4',
        method: method,
      );
    }

    test('forwards a valid request to the platform', () async {
      await BackgroundUploader.instance.enqueue(request());
      expect(fake.enqueued.single.taskId, 'task-1');
    });

    test('rejects an empty HTTP method', () async {
      await expectLater(
        () => BackgroundUploader.instance.enqueue(request(method: '  ')),
        throwsArgumentError,
      );
      expect(fake.enqueued, isEmpty);
    });

    test('rejects a remote non-https URL', () async {
      await expectLater(
        () => BackgroundUploader.instance.enqueue(
          request(url: 'http://media.divine.video/upload'),
        ),
        throwsArgumentError,
      );
      expect(fake.enqueued, isEmpty);
    });

    test('allows cleartext http to loopback hosts (local stack)', () async {
      await BackgroundUploader.instance.enqueue(
        request(url: 'http://10.0.2.2:3000/upload'),
      );
      await BackgroundUploader.instance.enqueue(
        request(url: 'http://localhost/upload'),
      );
      await BackgroundUploader.instance.enqueue(
        request(url: 'http://127.0.0.1:8080/upload'),
      );
      expect(fake.enqueued, hasLength(3));
    });

    test('cancel forwards the task id', () async {
      await BackgroundUploader.instance.cancel('task-9');
      expect(fake.cancelled.single, 'task-9');
    });

    test('beginForegroundSession forwards the session id', () async {
      await BackgroundUploader.instance.beginForegroundSession('publish-1');
      expect(fake.sessionsBegun.single, 'publish-1');
    });

    test('beginForegroundSession rejects an empty session id', () async {
      await expectLater(
        () => BackgroundUploader.instance.beginForegroundSession(''),
        throwsArgumentError,
      );
      expect(fake.sessionsBegun, isEmpty);
    });

    test('endForegroundSession forwards the session id', () async {
      await BackgroundUploader.instance.endForegroundSession('publish-1');
      expect(fake.sessionsEnded.single, 'publish-1');
    });

    test('activeTaskIds forwards the platform result', () async {
      fake.activeTaskIdsResult.add('task-7');
      expect(await BackgroundUploader.instance.activeTaskIds(), <String>[
        'task-7',
      ]);
    });

    test('takeBufferedTerminalEvent forwards the platform result', () async {
      fake.bufferedTerminals['task-7'] = const BackgroundUploadEvent(
        taskId: 'task-7',
        status: BackgroundUploadStatus.completed,
        httpStatusCode: 200,
      );

      final claimed = await BackgroundUploader.instance
          .takeBufferedTerminalEvent('task-7');

      expect(claimed?.taskId, 'task-7');
      expect(
        await BackgroundUploader.instance.takeBufferedTerminalEvent('x'),
        isNull,
      );
    });
  });

  group('BackgroundUploadRequest', () {
    BackgroundUploadRequest request({String? notificationTitle}) {
      return BackgroundUploadRequest(
        taskId: 'task-1',
        url: Uri.parse('https://media.divine.video/upload'),
        filePath: '/tmp/video.mp4',
        notificationTitle: notificationTitle ?? 'Uploading',
      );
    }

    test('defaults the notification title and serializes it', () {
      final serialized = BackgroundUploadRequest(
        taskId: 'task-1',
        url: Uri.parse('https://media.divine.video/upload'),
        filePath: '/tmp/video.mp4',
      );
      expect(serialized.notificationTitle, 'Uploading');
      expect(serialized.toMap()['notificationTitle'], 'Uploading');
    });

    test('carries a custom notification title through toMap', () {
      expect(
        request(
          notificationTitle: 'Uploading video',
        ).toMap()['notificationTitle'],
        'Uploading video',
      );
    });
  });

  group('BackgroundUploadEvent', () {
    test('parses a terminal success map', () {
      final event = BackgroundUploadEvent.fromMap(const <String, Object?>{
        'taskId': 'task-1',
        'status': 'completed',
        'progress': 1.0,
        'httpStatusCode': 201,
        'responseBody': '{"ok":true}',
      });

      expect(event.status, BackgroundUploadStatus.completed);
      expect(event.isTerminal, isTrue);
      expect(event.httpStatusCode, 201);
      expect(event.responseBody, '{"ok":true}');
    });

    test('clamps out-of-range progress', () {
      final event = BackgroundUploadEvent.fromMap(const <String, Object?>{
        'taskId': 'task-1',
        'status': 'running',
        'progress': 4.2,
      });

      expect(event.progress, 1.0);
      expect(event.isTerminal, isFalse);
    });

    test('tryFromMap returns null without a taskId', () {
      expect(
        BackgroundUploadEvent.tryFromMap(<String, Object?>{
          'status': 'completed',
        }),
        isNull,
      );
    });

    test('tryFromMap returns null on an unknown status', () {
      expect(
        BackgroundUploadEvent.tryFromMap(<String, Object?>{
          'taskId': 'task-1',
          'status': 'teleported',
        }),
        isNull,
      );
    });
  });
}
