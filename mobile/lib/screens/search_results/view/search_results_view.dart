import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/screens/search_results/widgets/widgets.dart';

class SearchResultsView extends StatelessWidget {
  /// Use [SearchResultsPage] to ensure BLoC providers are wired.
  const SearchResultsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: VineTheme.backgroundColor,
      child: CustomScrollView(
        slivers: [
          PeopleSection(),
          TagsSection(),
          VideosSection(),
        ],
      ),
    );
  }
}
