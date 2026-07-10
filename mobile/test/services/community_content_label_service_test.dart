import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/repositories/community_content_label_repository.dart';
import 'package:openvine/services/community_content_label_service.dart';
import 'package:openvine/services/content_filter_service.dart';

class _MockRepository extends Mock implements CommunityContentLabelRepository {}

class _MockContentFilterService extends Mock implements ContentFilterService {}

class _MockVideoEvent extends Mock implements VideoEvent {}

void main() {
  group(CommunityContentLabelService, () {
    late _MockRepository repository;
    late _MockContentFilterService contentFilter;
    late CommunityContentLabelService service;
    late _MockVideoEvent video;

    const videoId =
        'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2';

    setUpAll(() {
      registerFallbackValue(_MockVideoEvent());
      registerFallbackValue(ContentLabel.gambling);
    });

    setUp(() {
      repository = _MockRepository();
      contentFilter = _MockContentFilterService();
      service = CommunityContentLabelService(
        repository: repository,
        contentFilterService: contentFilter,
      );
      video = _MockVideoEvent();
      when(() => video.id).thenReturn(videoId);
      // By default no explicit preference (defaults to warn).
      when(
        () => contentFilter.getPreference(any()),
      ).thenReturn(ContentFilterPreference.warn);
    });

    test('warnLabelsFor is empty before prefetch', () {
      expect(service.warnLabelsFor(video), isEmpty);
    });

    test(
      'warnLabelsFor returns crossed-threshold labels after prefetch',
      () async {
        when(
          () => repository.communityLabelsForVideo(any()),
        ).thenAnswer((_) async => {'gambling'});

        await service.prefetch(video);

        expect(service.warnLabelsFor(video), equals({'gambling'}));
      },
    );

    test('warnLabelsFor excludes labels the viewer set to show', () async {
      when(
        () => repository.communityLabelsForVideo(any()),
      ).thenAnswer((_) async => {'gambling', 'violence'});
      when(
        () => contentFilter.getPreference(ContentLabel.gambling),
      ).thenReturn(ContentFilterPreference.show);

      await service.prefetch(video);

      expect(service.warnLabelsFor(video), equals({'violence'}));
    });

    test('prefetch queries the repository only once per video', () async {
      when(
        () => repository.communityLabelsForVideo(any()),
      ).thenAnswer((_) async => {'gambling'});

      await service.prefetch(video);
      await service.prefetch(video);

      verify(() => repository.communityLabelsForVideo(any())).called(1);
    });

    test('prefetch notifies listeners when results arrive', () async {
      when(
        () => repository.communityLabelsForVideo(any()),
      ).thenAnswer((_) async => {'gambling'});
      var notified = 0;
      service.addListener(() => notified++);

      await service.prefetch(video);

      expect(notified, greaterThan(0));
    });

    test('prefetch is a no-op when the repository is not ready', () async {
      final gatedService = CommunityContentLabelService(
        repository: null,
        contentFilterService: contentFilter,
      );

      await gatedService.prefetch(video);

      expect(gatedService.warnLabelsFor(video), isEmpty);
    });

    test('prefetch caches empty results without re-querying', () async {
      when(
        () => repository.communityLabelsForVideo(any()),
      ).thenAnswer((_) async => <String>{});

      await service.prefetch(video);
      await service.prefetch(video);

      expect(service.warnLabelsFor(video), isEmpty);
      verify(() => repository.communityLabelsForVideo(any())).called(1);
    });
  });
}
