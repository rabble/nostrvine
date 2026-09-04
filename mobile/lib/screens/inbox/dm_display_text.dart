// ABOUTME: Bounds sender-controlled direct-message text before UI processing.
// ABOUTME: Keeps conversation bubbles and inbox previews within fixed work budgets.

/// Code units shown when a long direct message is first rendered.
const int dmInitialDisplayCodeUnits = 4096;

/// Additional code units revealed by each explicit "show more" action.
const int dmDisplayIncrementCodeUnits = 4096;

/// Hard ceiling for direct-message text rendered by a single widget.
///
/// This allows one explicit reveal beyond the initial prefix. It is
/// intentionally much smaller than the first-party send ceiling: paragraph
/// shaping cost is paid in code units, not serialized rumor bytes, and inbound
/// rumors can be substantially larger than either bound.
const int dmMaxDisplayCodeUnits =
    dmInitialDisplayCodeUnits + dmDisplayIncrementCodeUnits;

/// Work budget for the two-line inbox preview.
const int dmPreviewDisplayCodeUnits = dmInitialDisplayCodeUnits;

/// A bounded prefix of sender-controlled text.
class DmDisplayTextSlice {
  const DmDisplayTextSlice({required this.text, required this.hasMore});

  final String text;
  final bool hasMore;
}

/// Takes at most [maxCodeUnits] without splitting a valid surrogate pair.
///
/// This intentionally operates before sanitization, parsing, regex matching,
/// or line splitting so those operations never inspect the unbounded suffix.
DmDisplayTextSlice sliceDmDisplayText(String text, int maxCodeUnits) {
  assert(maxCodeUnits >= 0, 'maxCodeUnits must not be negative');
  if (text.length <= maxCodeUnits) {
    return DmDisplayTextSlice(text: text, hasMore: false);
  }

  var end = maxCodeUnits;
  if (end > 0 &&
      _isHighSurrogate(text.codeUnitAt(end - 1)) &&
      _isLowSurrogate(text.codeUnitAt(end))) {
    end--;
  }

  return DmDisplayTextSlice(text: text.substring(0, end), hasMore: true);
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;
