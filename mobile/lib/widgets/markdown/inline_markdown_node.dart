// ABOUTME: Sealed AST for inline markdown produced by InlineMarkdownParser.
// ABOUTME: Markdown_text_span_builder walks this tree to emit InlineSpans.

import 'package:equatable/equatable.dart';

/// Inline markdown node.
///
/// Sealed: parser produces only the variants defined here so the span
/// builder's switch stays exhaustive.
sealed class InlineMarkdownNode extends Equatable {
  const InlineMarkdownNode();
}

/// Terminal: literal text with no inline formatting applied. Leaf
/// rendering delegates this back to the existing linkified-text span
/// builder so URLs / @mentions / #hashtags / nostr references inside a
/// formatted run remain tappable.
class PlainNode extends InlineMarkdownNode {
  const PlainNode(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// `**bold**` run. Children are inline nodes so `**hello _world_**`
/// resolves to a `BoldNode` containing a `PlainNode('hello ')` and an
/// `ItalicNode([PlainNode('world')])`.
class BoldNode extends InlineMarkdownNode {
  const BoldNode(this.children);

  final List<InlineMarkdownNode> children;

  @override
  List<Object?> get props => [children];
}

/// `_italic_` run. Snake-case identifiers like `foo_bar_baz` are kept
/// as a single [PlainNode] by enforcing a word-boundary rule on the
/// opening `_` in the parser.
class ItalicNode extends InlineMarkdownNode {
  const ItalicNode(this.children);

  final List<InlineMarkdownNode> children;

  @override
  List<Object?> get props => [children];
}

/// `~~strikethrough~~` run.
class StrikeNode extends InlineMarkdownNode {
  const StrikeNode(this.children);

  final List<InlineMarkdownNode> children;

  @override
  List<Object?> get props => [children];
}

/// Terminal: `` `inline code` ``. Contents are rendered as a literal
/// monospace run — no nested formatting, no linkification.
class CodeNode extends InlineMarkdownNode {
  const CodeNode(this.literal);

  final String literal;

  @override
  List<Object?> get props => [literal];
}

/// `[label](url)` run. [label] is parsed as inline markdown so
/// `[**bold link**](https://example.com)` works; [url] is taken
/// verbatim and tapping the rendered label opens it.
class LinkNode extends InlineMarkdownNode {
  const LinkNode({required this.label, required this.url});

  final List<InlineMarkdownNode> label;
  final String url;

  @override
  List<Object?> get props => [label, url];
}
