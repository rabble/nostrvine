// ABOUTME: Walks an InlineMarkdownNode AST to emit a flat List<InlineSpan>
// ABOUTME: with style merging across nesting. PlainNode leaves are
// ABOUTME: delegated back to LinkifiedTextSpanBuilder so URLs / @mentions /
// ABOUTME: #hashtags / nostr references stay tappable inside markdown runs.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_span_builder.dart';
import 'package:openvine/widgets/markdown/inline_markdown_node.dart';

/// Builds a `List<InlineSpan>` from an [InlineMarkdownNode] tree.
///
/// The leaf-renderer closure ([buildPlainSpans]) is responsible for
/// turning a plain-text leaf into spans. In DM rendering that closure
/// wires the leaf into [LinkifiedTextSpanBuilder] with a per-style
/// override so that, e.g., a URL inside `**bold**` renders as a bold
/// tappable link.
///
/// Lifetime: each call to [build] returns fresh spans whose
/// [TapGestureRecognizer]s the caller owns and must dispose of when the
/// widget rebuilds or unmounts. Mirror the dispose helpers in
/// `LinkifiedText._disposeSpans` to handle nested children.
class MarkdownTextSpanBuilder {
  /// Creates a builder that paints inline markdown.
  ///
  /// Styles default to the same family as [defaultStyle] with the
  /// appropriate `fontWeight` / `fontStyle` / `decoration` overlaid.
  /// Callers can pass explicit styles for finer control (e.g. picking
  /// a bold weight other than `w700`).
  const MarkdownTextSpanBuilder({
    required this.defaultStyle,
    required this.codeStyle,
    required this.codeBackgroundColor,
    required this.linkStyle,
    required this.buildPlainSpans,
    this.onLinkTap,
    this.boldWeight = FontWeight.w700,
  });

  /// Base style applied to plain runs.
  final TextStyle defaultStyle;

  /// Style for `` `code` `` runs. Caller-supplied so the bubble can
  /// pick a Chivo Mono variant matching its own contrast budget.
  final TextStyle codeStyle;

  /// Painted background for code runs. Applied as
  /// `TextStyle.background` so wraps look acceptable without needing
  /// a `WidgetSpan` pill.
  final Color codeBackgroundColor;

  /// Style for `[label](url)` runs (the label).
  final TextStyle linkStyle;

  /// Tap handler for markdown-link nodes. The raw URL is passed through.
  final Future<void> Function(String rawUrl)? onLinkTap;

  /// Weight to apply for `**bold**` nodes.
  final FontWeight boldWeight;

  /// How a [PlainNode]'s text is converted to spans. In production
  /// this delegates to [LinkifiedTextSpanBuilder] so URLs / mentions /
  /// hashtags / nostr references remain tappable inside markdown runs.
  /// The closure receives the *effective* style derived from current
  /// nesting (e.g. bold-italic merged) so linkified tokens inherit
  /// the surrounding emphasis weight or slant.
  final List<InlineSpan> Function(String text, TextStyle effectiveStyle)
  buildPlainSpans;

  /// Walks [nodes] and emits a flat list of [InlineSpan]s.
  List<InlineSpan> build(List<InlineMarkdownNode> nodes) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      _emit(node, defaultStyle, spans);
    }
    return spans;
  }

  void _emit(
    InlineMarkdownNode node,
    TextStyle currentStyle,
    List<InlineSpan> sink,
  ) {
    switch (node) {
      case PlainNode():
        sink.addAll(buildPlainSpans(node.text, currentStyle));
      case BoldNode():
        final next = currentStyle.copyWith(fontWeight: boldWeight);
        for (final child in node.children) {
          _emit(child, next, sink);
        }
      case ItalicNode():
        final next = currentStyle.copyWith(fontStyle: FontStyle.italic);
        for (final child in node.children) {
          _emit(child, next, sink);
        }
      case StrikeNode():
        final existingDecoration = currentStyle.decoration;
        final mergedDecoration =
            existingDecoration == null ||
                existingDecoration == TextDecoration.none
            ? TextDecoration.lineThrough
            : TextDecoration.combine([
                existingDecoration,
                TextDecoration.lineThrough,
              ]);
        final next = currentStyle.copyWith(decoration: mergedDecoration);
        for (final child in node.children) {
          _emit(child, next, sink);
        }
      case CodeNode():
        sink.add(
          TextSpan(
            text: node.literal,
            style: codeStyle.copyWith(
              background: Paint()..color = codeBackgroundColor,
            ),
          ),
        );
      case LinkNode():
        final labelStyle = linkStyle.merge(
          TextStyle(
            fontWeight: currentStyle.fontWeight,
            fontStyle: currentStyle.fontStyle,
            decoration: currentStyle.decoration,
          ),
        );
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            final cb = onLinkTap;
            if (cb != null) unawaited(cb(node.url));
          };
        final children = <InlineSpan>[];
        for (final child in node.label) {
          _emit(child, labelStyle, children);
        }
        // Re-wrap children in a parent TextSpan with the tap
        // recognizer. Flutter's hit-testing applies the parent's
        // recognizer to children that don't have their own.
        sink.add(TextSpan(children: children, recognizer: recognizer));
    }
  }
}
