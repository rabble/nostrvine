import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';

void main() {
  group(ScrollPaginationMixin, () {
    testWidgets(
      'triggers load more near the bottom once per in-flight request',
      (tester) async {
        final completer = Completer<void>();
        var loadMoreCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _TestWidget(
              canLoadMore: () => true,
              onLoadMore: () {
                loadMoreCalls++;
                return completer.future;
              },
            ),
          ),
        );

        final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));
        final scrollController = state.paginationScrollController;

        expect(scrollController.hasClients, isTrue);
        expect(scrollController.position.maxScrollExtent, greaterThan(0));

        scrollController.jumpTo(
          scrollController.position.maxScrollExtent - 100,
        );
        await tester.pump();

        expect(loadMoreCalls, 1);

        // Second scroll while first load is pending — should be ignored
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pump();

        expect(loadMoreCalls, 1);

        completer.complete();
        await tester.pump();

        // Scroll away from bottom, then back — should trigger again
        scrollController.jumpTo(0);
        await tester.pump();
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pump();

        expect(loadMoreCalls, 2);
      },
    );

    testWidgets(
      'does not trigger when canLoadMore returns false',
      (tester) async {
        var canLoadMore = false;
        var loadMoreCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _TestWidget(
              canLoadMore: () => canLoadMore,
              onLoadMore: () async {
                loadMoreCalls++;
              },
            ),
          ),
        );

        final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));
        final scrollController = state.paginationScrollController;

        expect(scrollController.hasClients, isTrue);
        expect(scrollController.position.maxScrollExtent, greaterThan(0));

        scrollController.jumpTo(
          scrollController.position.maxScrollExtent - 100,
        );
        await tester.pump();

        expect(loadMoreCalls, 0);

        canLoadMore = true;
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pump();

        expect(loadMoreCalls, 1);
      },
    );
  });
}

/// Test widget that uses [ScrollPaginationMixin].
class _TestWidget extends StatefulWidget {
  const _TestWidget({
    required this.canLoadMore,
    required this.onLoadMore,
  });

  final bool Function() canLoadMore;
  final FutureOr<void> Function() onLoadMore;

  @override
  State<_TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<_TestWidget> with ScrollPaginationMixin {
  final _scrollController = ScrollController();

  @override
  ScrollController get paginationScrollController => _scrollController;

  @override
  bool canLoadMore() => widget.canLoadMore();

  @override
  FutureOr<void> onLoadMore() => widget.onLoadMore();

  @override
  void initState() {
    super.initState();
    initPagination();
  }

  @override
  void dispose() {
    disposePagination();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: 100,
      itemBuilder: (context, index) => SizedBox(
        height: 80,
        child: Text('Item $index'),
      ),
    );
  }
}
