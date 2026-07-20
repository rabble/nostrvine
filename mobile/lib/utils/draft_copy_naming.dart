// ABOUTME: Builds unique, numbered titles for duplicated drafts
// ABOUTME: Strips an existing copy suffix so repeated copies don't stack

/// Private-use sentinel char that is extremely unlikely to appear in a real
/// draft title, used to locate the title slot inside a localized copy title.
const String _titleSentinel = '\u{E000}';

/// Sentinel copy number. Kept below 1000 so no locale renders it with a
/// grouping separator, which would break the derived strip pattern.
const int _numberSentinel = 999;

/// Returns a unique numbered copy title for a duplicated draft.
///
/// [format] localizes a base title plus a numbered copy suffix, e.g.
/// `'Trip (copy 2)'`. Any existing copy suffix on [sourceTitle] is stripped
/// first — the strip pattern is derived from [format] itself, so it stays
/// correct in every locale — so duplicating a copy yields `'Trip (copy 3)'`,
/// never `'Trip (copy) (copy)'`. The number starts at 1 and increments until
/// the formatted result is absent from [existingTitles].
String nextDuplicateDraftTitle({
  required String sourceTitle,
  required Iterable<String> existingTitles,
  required String Function(String base, int number) format,
}) {
  final base = _stripCopySuffix(sourceTitle, format);
  final taken = existingTitles.toSet();
  var number = 1;
  while (taken.contains(format(base, number))) {
    number++;
  }
  return format(base, number);
}

/// Removes a trailing copy suffix produced by [format] from [title], returning
/// the bare base. Returns [title] unchanged when it does not end with a copy
/// suffix (e.g. a custom name, or a `(copy 2)` that isn't at the very end).
String _stripCopySuffix(
  String title,
  String Function(String base, int number) format,
) {
  final sample = format(_titleSentinel, _numberSentinel);
  final source = RegExp.escape(sample)
      .replaceFirst(_titleSentinel, '(.*)')
      .replaceFirst('$_numberSentinel', r'(\d+)');
  final match = RegExp('^$source\$').firstMatch(title);
  return match != null ? match.group(1)! : title;
}
