// ABOUTME: Inline markdown parser that produces an InlineMarkdownNode AST.
// ABOUTME: Supports **bold**, _italic_, ~~strike~~, `code`, [label](url).
// ABOUTME: Code spans are literal (no nesting, no linkification).

import 'package:openvine/widgets/markdown/inline_markdown_node.dart';

/// Maximum nesting depth for inline markdown.
///
/// Beyond this, the opener that would push past the cap is rendered as
/// literal text so pathological inputs (`*****…*****`) can't blow the
/// stack.
const int _maxDepth = 8;

/// Inline markdown parser for chat-style text.
///
/// Scans left-to-right, recursive-descent for nestable runs
/// (`**`, `_`, `~~`, `[…](…)`). `` ` `` is terminal: contents are taken
/// verbatim until the matching closing backtick, no nesting allowed.
class InlineMarkdownParser {
  const InlineMarkdownParser();

  /// Parses [text] into a list of inline nodes. Returns an empty list
  /// for empty input. Never throws on malformed input — unmatched
  /// openers fall through as literal characters in a [PlainNode].
  List<InlineMarkdownNode> parse(String text) {
    if (text.isEmpty) return const [];
    final scanner = _Scanner(text);
    return scanner.parseUntil(_terminatorEnd, depth: 0);
  }
}

/// Terminator sentinel meaning "consume to end of input".
const String _terminatorEnd = '';

class _Scanner {
  _Scanner(this.input);

  final String input;
  int _pos = 0;

  /// Parses inline nodes from the current position until [terminator]
  /// is matched at the current position, or end-of-input.
  ///
  /// When the terminator is matched, the scanner advances past it and
  /// returns. Callers detect "matched" vs "ran to EOF" by checking
  /// whether `_pos` advanced past where the terminator would sit.
  List<InlineMarkdownNode> parseUntil(
    String terminator, {
    required int depth,
  }) {
    final nodes = <InlineMarkdownNode>[];
    final buffer = StringBuffer();

    void flushBuffer() {
      if (buffer.isEmpty) return;
      nodes.add(PlainNode(buffer.toString()));
      buffer.clear();
    }

    while (_pos < input.length) {
      if (terminator.isNotEmpty && _matchesAt(_pos, terminator)) {
        flushBuffer();
        _pos += terminator.length;
        return nodes;
      }

      final char = input[_pos];

      // Backslash escapes the next character (markdown delimiter or
      // backslash itself). Anything else falls through literal.
      if (char == r'\' && _pos + 1 < input.length) {
        final next = input[_pos + 1];
        if (_isEscapableDelimiter(next)) {
          buffer.write(next);
          _pos += 2;
          continue;
        }
      }

      // `code`: terminal, no nesting, no recursion. We deliberately
      // do not consume a leading backtick when no closing backtick
      // exists later in the input — fall through to literal.
      if (char == '`') {
        final close = input.indexOf('`', _pos + 1);
        if (close != -1 && close > _pos + 1) {
          flushBuffer();
          nodes.add(CodeNode(input.substring(_pos + 1, close)));
          _pos = close + 1;
          continue;
        }
      }

      // `**bold**`. Require non-empty content so `****` falls through
      // literal rather than producing an empty BoldNode.
      if (_matchesAt(_pos, '**') && depth < _maxDepth) {
        final savedPos = _pos;
        _pos += 2;
        final children = parseUntil('**', depth: depth + 1);
        if (_terminatorWasMatched(savedPos + 2, '**', _pos) &&
            children.isNotEmpty) {
          flushBuffer();
          nodes.add(BoldNode(children));
          continue;
        }
        // Unclosed or empty — restore and treat the openers as
        // literal so `**incomplete` and `****` both render verbatim.
        _pos = savedPos;
        buffer.write('**');
        _pos += 2;
        continue;
      }

      // `~~strike~~`.
      if (_matchesAt(_pos, '~~') && depth < _maxDepth) {
        final savedPos = _pos;
        _pos += 2;
        final children = parseUntil('~~', depth: depth + 1);
        if (_terminatorWasMatched(savedPos + 2, '~~', _pos) &&
            children.isNotEmpty) {
          flushBuffer();
          nodes.add(StrikeNode(children));
          continue;
        }
        _pos = savedPos;
        buffer.write('~~');
        _pos += 2;
        continue;
      }

      // `_italic_`. CommonMark left-flanking rule (simplified):
      // require the char before the opening `_` to not be a word
      // character, so `foo_bar_baz` stays literal. End delimiter
      // analogously requires the char after the closing `_` to not be
      // a word character.
      if (char == '_' && depth < _maxDepth && _isItalicOpener(_pos)) {
        final savedPos = _pos;
        _pos += 1;
        final children = parseUntilItalicClose(depth: depth + 1);
        if (children != null && children.isNotEmpty) {
          flushBuffer();
          nodes.add(ItalicNode(children));
          continue;
        }
        _pos = savedPos;
        buffer.write('_');
        _pos += 1;
        continue;
      }

      // `[label](url)`.
      if (char == '[' && depth < _maxDepth) {
        final link = _tryParseLink(depth);
        if (link != null) {
          flushBuffer();
          nodes.add(link);
          continue;
        }
      }

      buffer.write(char);
      _pos++;
    }

    flushBuffer();
    return nodes;
  }

  /// Variant of [parseUntil] specialised for italic, which has a
  /// word-boundary constraint on the closing delimiter. Returns the
  /// child nodes on success and advances past the closing `_`;
  /// returns `null` if no qualifying close was found before EOF.
  List<InlineMarkdownNode>? parseUntilItalicClose({required int depth}) {
    final nodes = <InlineMarkdownNode>[];
    final buffer = StringBuffer();

    void flushBuffer() {
      if (buffer.isEmpty) return;
      nodes.add(PlainNode(buffer.toString()));
      buffer.clear();
    }

    while (_pos < input.length) {
      final char = input[_pos];

      if (char == '_' && _isItalicCloser(_pos)) {
        flushBuffer();
        _pos += 1;
        return nodes;
      }

      // Nested formatting reuses the generic path so e.g.
      // `_a **b** c_` works. Backslash escapes apply as in the outer.
      if (char == r'\' && _pos + 1 < input.length) {
        final next = input[_pos + 1];
        if (_isEscapableDelimiter(next)) {
          buffer.write(next);
          _pos += 2;
          continue;
        }
      }

      if (char == '`') {
        final close = input.indexOf('`', _pos + 1);
        if (close != -1 && close > _pos + 1) {
          flushBuffer();
          nodes.add(CodeNode(input.substring(_pos + 1, close)));
          _pos = close + 1;
          continue;
        }
      }

      if (_matchesAt(_pos, '**') && depth < _maxDepth) {
        final savedPos = _pos;
        _pos += 2;
        final children = parseUntil('**', depth: depth + 1);
        if (_terminatorWasMatched(savedPos + 2, '**', _pos) &&
            children.isNotEmpty) {
          flushBuffer();
          nodes.add(BoldNode(children));
          continue;
        }
        _pos = savedPos;
        buffer.write('**');
        _pos += 2;
        continue;
      }

      if (_matchesAt(_pos, '~~') && depth < _maxDepth) {
        final savedPos = _pos;
        _pos += 2;
        final children = parseUntil('~~', depth: depth + 1);
        if (_terminatorWasMatched(savedPos + 2, '~~', _pos) &&
            children.isNotEmpty) {
          flushBuffer();
          nodes.add(StrikeNode(children));
          continue;
        }
        _pos = savedPos;
        buffer.write('~~');
        _pos += 2;
        continue;
      }

      if (char == '[' && depth < _maxDepth) {
        final link = _tryParseLink(depth);
        if (link != null) {
          flushBuffer();
          nodes.add(link);
          continue;
        }
      }

      buffer.write(char);
      _pos++;
    }

    // EOF without close — bail.
    return null;
  }

  /// Tries to parse a `[label](url)` starting at the current `[`.
  /// Returns `null` if the syntax doesn't match (including any
  /// nesting in label that escapes its closing `]`); leaves `_pos`
  /// unchanged in that case.
  LinkNode? _tryParseLink(int depth) {
    final start = _pos;
    // Find matching `]` allowing for escaped `\]` inside label.
    var labelEnd = -1;
    for (var i = _pos + 1; i < input.length; i++) {
      final c = input[i];
      if (c == r'\' && i + 1 < input.length) {
        i += 1;
        continue;
      }
      if (c == ']') {
        labelEnd = i;
        break;
      }
      if (c == '[') {
        // Nested `[` aborts — keep parser simple.
        break;
      }
    }
    if (labelEnd == -1) return null;
    if (labelEnd + 1 >= input.length || input[labelEnd + 1] != '(') {
      return null;
    }

    // Find matching `)` allowing for escaped `\)`.
    var urlEnd = -1;
    for (var i = labelEnd + 2; i < input.length; i++) {
      final c = input[i];
      if (c == r'\' && i + 1 < input.length) {
        i += 1;
        continue;
      }
      if (c == ')') {
        urlEnd = i;
        break;
      }
    }
    if (urlEnd == -1) return null;

    final labelText = input.substring(start + 1, labelEnd);
    final url = input.substring(labelEnd + 2, urlEnd).trim();
    if (url.isEmpty) return null;

    final labelNodes = const InlineMarkdownParser().parse(labelText);
    if (labelNodes.isEmpty) return null;

    _pos = urlEnd + 1;
    if (depth + 1 > _maxDepth) {
      // Should not happen with current cap, but guard anyway.
      return LinkNode(label: const [PlainNode('')], url: url);
    }
    return LinkNode(label: labelNodes, url: url);
  }

  bool _matchesAt(int pos, String needle) {
    if (pos + needle.length > input.length) return false;
    for (var i = 0; i < needle.length; i++) {
      if (input[pos + i] != needle[i]) return false;
    }
    return true;
  }

  /// True iff [parseUntil] consumed the terminator at the recursion
  /// it just returned from. We detect it by checking that `_pos`
  /// points past the location where the terminator would have sat
  /// AND the character there matches. Cheaper: compare `_pos` to
  /// `contentStart` — if equal, recursion bailed at EOF.
  bool _terminatorWasMatched(int contentStart, String terminator, int endPos) {
    if (endPos == input.length) {
      // EOF: check if last `terminator.length` chars match.
      final tailStart = endPos - terminator.length;
      if (tailStart < contentStart) return false;
      return _matchesAt(tailStart, terminator);
    }
    final tailStart = endPos - terminator.length;
    return tailStart >= contentStart && _matchesAt(tailStart, terminator);
  }

  /// Left-flanking constraint for opening italic `_`.
  ///
  /// Treat `_` as an opener only when the character immediately
  /// preceding it (or BOF) is not a word character, so `foo_bar` and
  /// `snake_case_thing` remain plain.
  bool _isItalicOpener(int pos) {
    if (pos == 0) return true;
    final prev = input.codeUnitAt(pos - 1);
    return !_isWordCodeUnit(prev);
  }

  /// Right-flanking constraint for closing italic `_`.
  ///
  /// Treat `_` as a closer only when the character immediately
  /// following it (or EOF) is not a word character.
  bool _isItalicCloser(int pos) {
    if (pos + 1 >= input.length) return true;
    final next = input.codeUnitAt(pos + 1);
    return !_isWordCodeUnit(next);
  }

  /// ASCII word character: `[A-Za-z0-9_]`. Non-ASCII characters
  /// (CJK, accented letters, emoji) are treated as non-word here
  /// to favour formatting over identifier protection in those
  /// scripts — adjust if it produces false positives in the wild.
  bool _isWordCodeUnit(int cu) {
    if (cu >= 0x30 && cu <= 0x39) return true; // 0-9
    if (cu >= 0x41 && cu <= 0x5A) return true; // A-Z
    if (cu >= 0x61 && cu <= 0x7A) return true; // a-z
    if (cu == 0x5F) return true; // _
    return false;
  }

  bool _isEscapableDelimiter(String char) {
    switch (char) {
      case '*':
      case '_':
      case '~':
      case '`':
      case '[':
      case ']':
      case '(':
      case ')':
      case r'\':
        return true;
      default:
        return false;
    }
  }
}
