// ABOUTME: Tests for VideoImportService - importing C2PA-verified videos
// ABOUTME: Verifies file copy, clip creation, and draft creation flow

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/c2pa_import_result.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_import_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

class _FakeDivineVideoClip extends Fake implements DivineVideoClip {}

class _FakeDivineVideoDraft extends Fake implements DivineVideoDraft {}

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.tempDir);

  final String tempDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir;

  @override
  Future<String?> getTemporaryPath() async => tempDir;
}

void main() {
  group(VideoImportService, () {
    late _MockClipLibraryService mockClipLibraryService;
    late _MockDraftStorageService mockDraftStorageService;
    late VideoImportService service;
    late Directory tempDir;

    setUpAll(() {
      registerFallbackValue(_FakeDivineVideoClip());
      registerFallbackValue(_FakeDivineVideoDraft());
    });

    setUp(() async {
      mockClipLibraryService = _MockClipLibraryService();
      mockDraftStorageService = _MockDraftStorageService();

      service = VideoImportService(
        clipLibraryService: mockClipLibraryService,
        draftStorageService: mockDraftStorageService,
      );

      tempDir = await Directory.systemTemp.createTemp('video_import_test_');

      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);

      when(
        () => mockClipLibraryService.saveClip(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockDraftStorageService.saveDraft(any()),
      ).thenAnswer((_) async {});
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('imports video and returns draft ID', () async {
      // Create a fake video file
      final sourceDir = Directory(p.join(tempDir.path, 'source'));
      await sourceDir.create();
      final sourceFile = File(p.join(sourceDir.path, 'test_video.mp4'));
      await sourceFile.writeAsBytes([0, 1, 2, 3, 4, 5]);

      final validationResult = C2paImportResult.verified(
        claimGenerator: 'TestApp/1.0',
        digitalSourceType: C2paSourceClassification.humanCreated,
        digitalSourceTypeRaw: 'digitalCapture',
        title: 'My Test Video',
      );

      final draftId = await service.importVerifiedVideo(
        filePath: sourceFile.path,
        validationResult: validationResult,
      );

      // Verify draft ID is non-empty
      expect(draftId, isNotEmpty);
      expect(draftId, startsWith('draft_import_'));

      // Verify saveClip was called
      final clipCapture = verify(
        () => mockClipLibraryService.saveClip(captureAny()),
      ).captured;
      expect(clipCapture, hasLength(1));
      final savedClip = clipCapture.first as DivineVideoClip;
      expect(savedClip.id, startsWith('import_'));
      expect(savedClip.targetAspectRatio, model.AspectRatio.vertical);
      expect(savedClip.proofManifestJson, 'TestApp/1.0');

      // Verify saveDraft was called
      final draftCapture = verify(
        () => mockDraftStorageService.saveDraft(captureAny()),
      ).captured;
      expect(draftCapture, hasLength(1));
      final savedDraft = draftCapture.first as DivineVideoDraft;
      expect(savedDraft.id, draftId);
      expect(savedDraft.clips, hasLength(1));
      expect(savedDraft.title, 'My Test Video');
      expect(savedDraft.publishStatus, PublishStatus.draft);

      // Verify the file was copied to imports directory
      final importsDir = Directory(p.join(tempDir.path, 'imports'));
      expect(importsDir.existsSync(), isTrue);
      final importedFiles = importsDir.listSync();
      expect(importedFiles, hasLength(1));
      expect(
        (importedFiles.first as File).path,
        endsWith('.mp4'),
      );
    });

    test('uses empty title when validation result has no title', () async {
      final sourceFile = File(p.join(tempDir.path, 'no_title.mp4'));
      await sourceFile.writeAsBytes([0, 1, 2, 3]);

      final validationResult = C2paImportResult.verified(
        claimGenerator: 'TestApp/1.0',
        digitalSourceType: C2paSourceClassification.humanCreated,
        digitalSourceTypeRaw: 'digitalCapture',
      );

      await service.importVerifiedVideo(
        filePath: sourceFile.path,
        validationResult: validationResult,
      );

      final draftCapture = verify(
        () => mockDraftStorageService.saveDraft(captureAny()),
      ).captured;
      final savedDraft = draftCapture.first as DivineVideoDraft;
      expect(savedDraft.title, isEmpty);
    });

    test('preserves file extension from source', () async {
      final sourceFile = File(p.join(tempDir.path, 'test.mov'));
      await sourceFile.writeAsBytes([0, 1, 2]);

      final validationResult = C2paImportResult.verified(
        claimGenerator: 'TestApp/1.0',
        digitalSourceType: C2paSourceClassification.humanCreated,
        digitalSourceTypeRaw: 'digitalCapture',
      );

      await service.importVerifiedVideo(
        filePath: sourceFile.path,
        validationResult: validationResult,
      );

      final importsDir = Directory(p.join(tempDir.path, 'imports'));
      final importedFiles = importsDir.listSync();
      expect(
        (importedFiles.first as File).path,
        endsWith('.mov'),
      );
    });

    test('copied file exists at destination and has correct content', () async {
      final sourceFile = File(p.join(tempDir.path, 'check_copy.mp4'));
      final sourceBytes = [10, 20, 30, 40, 50];
      await sourceFile.writeAsBytes(sourceBytes);

      final validationResult = C2paImportResult.verified(
        claimGenerator: 'TestApp/1.0',
        digitalSourceType: C2paSourceClassification.humanCreated,
        digitalSourceTypeRaw: 'digitalCapture',
      );

      await service.importVerifiedVideo(
        filePath: sourceFile.path,
        validationResult: validationResult,
      );

      final importsDir = Directory(p.join(tempDir.path, 'imports'));
      final importedFiles = importsDir.listSync();
      expect(importedFiles, hasLength(1));

      final copiedFile = importedFiles.first as File;
      expect(copiedFile.existsSync(), isTrue);
      expect(await copiedFile.readAsBytes(), equals(sourceBytes));
    });

    test('throws when source file does not exist', () async {
      final validationResult = C2paImportResult.verified(
        claimGenerator: 'TestApp/1.0',
        digitalSourceType: C2paSourceClassification.humanCreated,
        digitalSourceTypeRaw: 'digitalCapture',
      );

      expect(
        () => service.importVerifiedVideo(
          filePath: '/nonexistent/path/video.mp4',
          validationResult: validationResult,
        ),
        throwsA(isA<PathNotFoundException>()),
      );
    });
  });
}
