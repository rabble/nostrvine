import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/markdown/markdown.dart';

void main() {
  group(MarkdownTextSpanBuilder, () {
    const defaultStyle = TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    const linkStyle = TextStyle(
      color: Color(0xFF27C58B),
      fontWeight: FontWeight.w500,
    );
    const codeStyle = TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 13,
      fontFamily: 'ChivoMono',
    );
    const codeBg = Color(0x1FFFFFFF);

    /// Test-only plain builder: yields a single span with the effective
    /// style. Real callers route through LinkifiedTextSpanBuilder.
    List<InlineSpan> identityPlain(String text, TextStyle style) => [
      TextSpan(text: text, style: style),
    ];

    MarkdownTextSpanBuilder makeBuilder({
      Future<void> Function(String)? onLinkTap,
      List<InlineSpan> Function(String, TextStyle)? buildPlainSpans,
    }) {
      return MarkdownTextSpanBuilder(
        defaultStyle: defaultStyle,
        codeStyle: codeStyle,
        codeBackgroundColor: codeBg,
        linkStyle: linkStyle,
        buildPlainSpans: buildPlainSpans ?? identityPlain,
        onLinkTap: onLinkTap,
      );
    }

    test('emits a single plain span for plain AST', () {
      final spans = makeBuilder().build(const [PlainNode('hello')]);
      expect(spans, hasLength(1));
      final span = spans.single as TextSpan;
      expect(span.text, equals('hello'));
      expect(span.style?.fontWeight, equals(FontWeight.w400));
    });

    test('BoldNode applies w700 weight to its plain children', () {
      final spans = makeBuilder().build(const [
        BoldNode([PlainNode('strong')]),
      ]);
      final span = spans.single as TextSpan;
      expect(span.text, equals('strong'));
      expect(span.style?.fontWeight, equals(FontWeight.w700));
    });

    test('ItalicNode applies FontStyle.italic to children', () {
      final spans = makeBuilder().build(const [
        ItalicNode([PlainNode('slant')]),
      ]);
      final span = spans.single as TextSpan;
      expect(span.text, equals('slant'));
      expect(span.style?.fontStyle, equals(FontStyle.italic));
    });

    test('StrikeNode applies lineThrough decoration', () {
      final spans = makeBuilder().build(const [
        StrikeNode([PlainNode('gone')]),
      ]);
      final span = spans.single as TextSpan;
      expect(span.text, equals('gone'));
      expect(span.style?.decoration, equals(TextDecoration.lineThrough));
    });

    test('nested Bold inside Italic merges fontWeight + fontStyle', () {
      final spans = makeBuilder().build(const [
        ItalicNode([
          BoldNode([PlainNode('both')]),
        ]),
      ]);
      final span = spans.single as TextSpan;
      expect(span.style?.fontWeight, equals(FontWeight.w700));
      expect(span.style?.fontStyle, equals(FontStyle.italic));
    });

    test(
      'CodeNode is terminal: single TextSpan with code style + background',
      () {
        final spans = makeBuilder().build(const [CodeNode('x = 1')]);
        expect(spans, hasLength(1));
        final span = spans.single as TextSpan;
        expect(span.text, equals('x = 1'));
        expect(span.style?.fontFamily, equals('ChivoMono'));
        expect(span.style?.background, isNotNull);
        expect(
          span.style?.background?.color.toARGB32(),
          equals(codeBg.toARGB32()),
        );
      },
    );

    test('LinkNode produces a parent TextSpan with TapGestureRecognizer', () {
      final tapped = <String>[];
      final spans =
          makeBuilder(
            onLinkTap: (url) async => tapped.add(url),
          ).build(const [
            LinkNode(
              label: [PlainNode('click me')],
              url: 'https://example.com',
            ),
          ]);
      expect(spans, hasLength(1));
      final parent = spans.single as TextSpan;
      expect(parent.recognizer, isA<TapGestureRecognizer>());
      (parent.recognizer! as TapGestureRecognizer).onTap?.call();
      expect(tapped, equals(['https://example.com']));

      // Label child carries the link style + the (unset) base
      // emphasis flags from the surrounding default style.
      final labelChild = parent.children!.single as TextSpan;
      expect(labelChild.text, equals('click me'));
      expect(labelChild.style?.color, equals(linkStyle.color));
    });

    test('LinkNode label honors surrounding bold', () {
      // **[label](url)** — bold wrapping a link.
      final spans = makeBuilder().build(const [
        BoldNode([
          LinkNode(label: [PlainNode('go')], url: 'https://x.io'),
        ]),
      ]);
      final parent = spans.single as TextSpan;
      final labelChild = parent.children!.single as TextSpan;
      expect(labelChild.style?.fontWeight, equals(FontWeight.w700));
    });

    test('plain builder receives merged style for delegation', () {
      final received = <(String, TextStyle)>[];
      final builder = makeBuilder(
        buildPlainSpans: (text, style) {
          received.add((text, style));
          return [TextSpan(text: text, style: style)];
        },
      );

      builder.build(const [
        BoldNode([PlainNode('hello @alice')]),
      ]);

      expect(received, hasLength(1));
      expect(received.single.$1, equals('hello @alice'));
      expect(received.single.$2.fontWeight, equals(FontWeight.w700));
    });

    test('mixed AST produces correctly ordered spans', () {
      final spans = makeBuilder().build(const [
        PlainNode('Hey '),
        BoldNode([PlainNode('bob')]),
        PlainNode(', '),
        CodeNode('x()'),
        PlainNode(' and '),
        ItalicNode([PlainNode('this')]),
      ]);
      expect(spans, hasLength(6));
      expect((spans[0] as TextSpan).text, equals('Hey '));
      expect((spans[1] as TextSpan).style?.fontWeight, equals(FontWeight.w700));
      expect((spans[2] as TextSpan).text, equals(', '));
      expect((spans[3] as TextSpan).style?.fontFamily, equals('ChivoMono'));
      expect((spans[4] as TextSpan).text, equals(' and '));
      expect((spans[5] as TextSpan).style?.fontStyle, equals(FontStyle.italic));
    });
  });
}
