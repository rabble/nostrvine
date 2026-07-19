# divine_blurhash

Spec-correct [BlurHash](https://blurha.sh) encoder and decoder for Divine.

Pure Dart — no Flutter, no `image` dependency. Both functions operate on
raw RGBA byte buffers (`width * height * 4`, `[r, g, b, a, …]`), so the
caller owns image decoding/resizing.

```dart
import 'package:divine_blurhash/divine_blurhash.dart';

final hash = encodeBlurHash(rgba, width, height, numCompX: 3, numCompY: 4);
final pixels = decodeBlurHash(hash, 32, 32, punch: 0.8); // RGBA
```

## Why this exists

We previously used [`blurhash_dart`](https://pub.dev/packages/blurhash_dart),
which is unmaintained (last release `1.2.1`, ~3 years ago) and ships two
decode bugs that produce visibly wrong placeholders:

- **Colour tint.** `decodeAc` divides with `/` where the spec requires
  integer division (`~/`), inflating red/green in every AC component.
  Grayscale content decodes with a blue/cream tint.
- **Broken punch.** Its `punch` (contrast) parameter skips the entire
  first AC row and column instead of scaling every AC term.

Since the package is abandoned there is no upstream fix to wait for, so
Divine owns a clean, spec-correct implementation instead. Encoding follows
the same reference algorithm and stays interoperable with any other
spec-compliant decoder (e.g. divine-web's JS decoder).

## API

- `String encodeBlurHash(Uint8List rgba, int width, int height, {int numCompX = 4, int numCompY = 3})`
- `Uint8List decodeBlurHash(String blurHash, int width, int height, {double punch = 1.0})`
  — throws [`BlurHashDecodeException`] on a malformed hash.
