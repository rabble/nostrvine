import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/scroll_pagination_controller.dart';

void main() {
  group('ScrollPaginationController', () {
    testWidgets(
      'triggers load more near the bottom once per in-flight request',
      (tester) async {
        final scrollController = ScrollController();
        final completer = Completer<void>();
        var loadMoreCalls = 0;

        late final ScrollPaginationController paginationController;
        paginationController = ScrollPaginationController(
          scrollController: scrollController,
          canLoadMore: () => true,
          onLoadMore: () {
            loadMoreCalls++;
            return completer.future;
          },
        );

        addTearDown(() {
          paginationController.dispose();
          scrollController.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: ListView.builder(
              controller: scrollController,
              itemCount: 100,
              itemBuilder: (context, index) => SizedBox(
                height: 80,
                child: Text('Item $index'),
              ),
            ),
          ),
        );

        expect(scrollController.hasClients, isTrue);
        expect(scrollController.position.maxScrollExtent, greaterThan(0));

        scrollController.jumpTo(
          scrollController.position.maxScrollExtent - 100,
        );
        await tester.pump();

        expect(loadMoreCalls, 1);

        completer.complete();
        await tester.pump();

        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pump();

        expect(loadMoreCalls, 2);
      },
    );

    testWidgets(
      'does not trigger when hasMore is false or loading is blocked',
      (tester) async {
        final scrollController = ScrollController();
        var canLoadMore = false;
        var loadMoreCalls = 0;

        late final ScrollPaginationController paginationController;
        paginationController = ScrollPaginationController(
          scrollController: scrollController,
          canLoadMore: () => canLoadMore,
          onLoadMore: () async {
            loadMoreCalls++;
          },
        );

        addTearDown(() {
          paginationController.dispose();
          scrollController.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: ListView.builder(
              controller: scrollController,
              itemCount: 100,
              itemBuilder: (context, index) => SizedBox(
                height: 80,
                child: Text('Item $index'),
              ),
            ),
          ),
        );

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
