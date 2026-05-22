import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/markdown/markdown.dart';

void main() {
  group(InlineMarkdownParser, () {
    const parser = InlineMarkdownParser();

    group('plain text', () {
      test('returns empty list for empty input', () {
        expect(parser.parse(''), isEmpty);
      });

      test('returns single PlainNode for unformatted text', () {
        expect(
          parser.parse('hello world'),
          equals([
            const PlainNode('hello world'),
          ]),
        );
      });
    });

    group('bold', () {
      test('parses **text** to BoldNode', () {
        expect(
          parser.parse('**hi**'),
          equals([
            const BoldNode([PlainNode('hi')]),
          ]),
        );
      });

      test('parses bold surrounded by plain text', () {
        expect(
          parser.parse('say **hi** there'),
          equals([
            const PlainNode('say '),
            const BoldNode([PlainNode('hi')]),
            const PlainNode(' there'),
          ]),
        );
      });

      test('unclosed ** falls through as literal', () {
        expect(
          parser.parse('**unclosed'),
          equals([
            const PlainNode('**unclosed'),
          ]),
        );
      });

      test('empty bold **** falls through as literal', () {
        expect(parser.parse('****'), equals([const PlainNode('****')]));
      });

      test(r'escapes work: \*\*literal\*\* renders **literal**', () {
        expect(
          parser.parse(r'\*\*literal\*\*'),
          equals([
            const PlainNode('**literal**'),
          ]),
        );
      });
    });

    group('italic', () {
      test('parses _text_ to ItalicNode', () {
        expect(
          parser.parse('_hi_'),
          equals([
            const ItalicNode([PlainNode('hi')]),
          ]),
        );
      });

      test('snake_case identifier stays literal', () {
        expect(
          parser.parse('foo_bar_baz'),
          equals([
            const PlainNode('foo_bar_baz'),
          ]),
        );
      });

      test('italic surrounded by spaces parses', () {
        expect(
          parser.parse('say _hi_ there'),
          equals([
            const PlainNode('say '),
            const ItalicNode([PlainNode('hi')]),
            const PlainNode(' there'),
          ]),
        );
      });

      test('unclosed _ falls through as literal', () {
        expect(
          parser.parse('_incomplete'),
          equals([
            const PlainNode('_incomplete'),
          ]),
        );
      });
    });

    group('strikethrough', () {
      test('parses ~~text~~ to StrikeNode', () {
        expect(
          parser.parse('~~gone~~'),
          equals([
            const StrikeNode([PlainNode('gone')]),
          ]),
        );
      });

      test('unclosed ~~ falls through as literal', () {
        expect(parser.parse('~~half'), equals([const PlainNode('~~half')]));
      });
    });

    group('inline code', () {
      test('parses `text` to CodeNode', () {
        expect(parser.parse('`x = 1`'), equals([const CodeNode('x = 1')]));
      });

      test('code prevents nested markdown parsing', () {
        expect(
          parser.parse('`*not bold*`'),
          equals([
            const CodeNode('*not bold*'),
          ]),
        );
      });

      test('unclosed backtick falls through as literal', () {
        expect(parser.parse('`half'), equals([const PlainNode('`half')]));
      });

      test('empty backticks `` fall through as literal', () {
        expect(parser.parse('``'), equals([const PlainNode('``')]));
      });
    });

    group('nesting', () {
      test('**bold _italic_** nests italic inside bold', () {
        expect(
          parser.parse('**bold _italic_**'),
          equals([
            const BoldNode([
              PlainNode('bold '),
              ItalicNode([PlainNode('italic')]),
            ]),
          ]),
        );
      });

      test('_italic **bold**_ nests bold inside italic', () {
        expect(
          parser.parse('_italic **bold**_'),
          equals([
            const ItalicNode([
              PlainNode('italic '),
              BoldNode([PlainNode('bold')]),
            ]),
          ]),
        );
      });

      test('~~strike **bold**~~ nests bold inside strike', () {
        expect(
          parser.parse('~~strike **bold**~~'),
          equals([
            const StrikeNode([
              PlainNode('strike '),
              BoldNode([PlainNode('bold')]),
            ]),
          ]),
        );
      });

      test('code inside bold renders as CodeNode child', () {
        expect(
          parser.parse('**`code`**'),
          equals([
            const BoldNode([CodeNode('code')]),
          ]),
        );
      });
    });

    group('markdown links', () {
      test('parses [label](url) to LinkNode', () {
        expect(
          parser.parse('[click](https://example.com)'),
          equals([
            const LinkNode(
              label: [PlainNode('click')],
              url: 'https://example.com',
            ),
          ]),
        );
      });

      test('link label may contain formatting', () {
        expect(
          parser.parse('[**bold link**](https://x.io)'),
          equals([
            const LinkNode(
              label: [
                BoldNode([PlainNode('bold link')]),
              ],
              url: 'https://x.io',
            ),
          ]),
        );
      });

      test('missing url paren falls through as literal', () {
        expect(
          parser.parse('[a](no-paren'),
          equals([
            const PlainNode('[a](no-paren'),
          ]),
        );
      });

      test('empty url falls through as literal', () {
        expect(parser.parse('[a]()'), equals([const PlainNode('[a]()')]));
      });

      test('two links in a row both parse', () {
        expect(
          parser.parse('[a](https://a.com) and [b](https://b.com)'),
          equals([
            const LinkNode(
              label: [PlainNode('a')],
              url: 'https://a.com',
            ),
            const PlainNode(' and '),
            const LinkNode(
              label: [PlainNode('b')],
              url: 'https://b.com',
            ),
          ]),
        );
      });

      test('nested [ inside label aborts link parse', () {
        expect(
          parser.parse('[a[b](url)'),
          equals([
            const PlainNode('[a'),
            const LinkNode(
              label: [PlainNode('b')],
              url: 'url',
            ),
          ]),
        );
      });
    });

    group('safety', () {
      test('depth cap prevents stack blow on pathological input', () {
        // 32 nested asterisks — depth cap (8) should kick in and
        // surface the excess as literal without throwing.
        final stars = '*' * 32;
        final input = '${stars}x$stars';
        expect(() => parser.parse(input), returnsNormally);
      });

      test('lone delimiter characters are literal', () {
        expect(
          parser.parse('a * b _ c ~ d'),
          equals([
            const PlainNode('a * b _ c ~ d'),
          ]),
        );
      });

      test('backslash before non-delimiter passes through literal', () {
        expect(
          parser.parse(r'\n is not escaped here'),
          equals([
            const PlainNode(r'\n is not escaped here'),
          ]),
        );
      });
    });

    group('real-world chat shapes', () {
      test('mixed formatting and plain text', () {
        expect(
          parser.parse('Hey **bob**, check `code` and _this_'),
          equals([
            const PlainNode('Hey '),
            const BoldNode([PlainNode('bob')]),
            const PlainNode(', check '),
            const CodeNode('code'),
            const PlainNode(' and '),
            const ItalicNode([PlainNode('this')]),
          ]),
        );
      });

      test('text containing @ and # passes through verbatim for linkifier', () {
        // Markdown parser keeps these as plain text — the span builder
        // delegates the leaf to LinkifiedTextSpanBuilder.
        expect(
          parser.parse('hi @alice and #tag'),
          equals([
            const PlainNode('hi @alice and #tag'),
          ]),
        );
      });
    });
  });
}
