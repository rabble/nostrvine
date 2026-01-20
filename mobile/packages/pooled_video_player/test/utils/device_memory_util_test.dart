import 'package:flutter_test/flutter_test.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

void main() {
  group('DeviceMemoryUtil', () {
    late DeviceMemoryUtil classifier;

    setUp(() {
      classifier = DeviceMemoryUtil();
    });

    tearDown(() {
      classifier.resetCache();
    });

    group('MemoryTier', () {
      test('has correct enum values', () {
        expect(MemoryTier.values.length, 3);
        expect(MemoryTier.low.name, 'low');
        expect(MemoryTier.medium.name, 'medium');
        expect(MemoryTier.high.name, 'high');
      });
    });

    group('iOS Device Classification', () {
      group('iPhone 14 and above returns high memory tier', () {
        test('iPhone14,1 (iPhone 14)', () {
          final tier = classifier.classifyIOSDevice('iPhone14,1');
          expect(tier, MemoryTier.high);
        });

        test('iPhone15,2 (iPhone 15)', () {
          final tier = classifier.classifyIOSDevice('iPhone15,2');
          expect(tier, MemoryTier.high);
        });

        test('iPhone16,1 (iPhone 16)', () {
          final tier = classifier.classifyIOSDevice('iPhone16,1');
          expect(tier, MemoryTier.high);
        });

        test('iPhone20,5 (future iPhone)', () {
          final tier = classifier.classifyIOSDevice('iPhone20,5');
          expect(tier, MemoryTier.high);
        });
      });

      group('iPhone 11-13 returns medium memory tier', () {
        test('iPhone11,8 (iPhone 11)', () {
          final tier = classifier.classifyIOSDevice('iPhone11,8');
          expect(tier, MemoryTier.medium);
        });

        test('iPhone12,1 (iPhone 12 mini)', () {
          final tier = classifier.classifyIOSDevice('iPhone12,1');
          expect(tier, MemoryTier.medium);
        });

        test('iPhone13,2 (iPhone 13)', () {
          final tier = classifier.classifyIOSDevice('iPhone13,2');
          expect(tier, MemoryTier.medium);
        });

        test('iPhone13,4 (iPhone 13 Pro Max)', () {
          final tier = classifier.classifyIOSDevice('iPhone13,4');
          expect(tier, MemoryTier.medium);
        });
      });

      group('iPhone below 11 returns low memory tier', () {
        test('iPhone10,4 (iPhone 8)', () {
          final tier = classifier.classifyIOSDevice('iPhone10,4');
          expect(tier, MemoryTier.low);
        });

        test('iPhone9,1 (iPhone 7)', () {
          final tier = classifier.classifyIOSDevice('iPhone9,1');
          expect(tier, MemoryTier.low);
        });

        test('iPhone8,1 (iPhone 6s)', () {
          final tier = classifier.classifyIOSDevice('iPhone8,1');
          expect(tier, MemoryTier.low);
        });

        test('iPhone1,1 (original iPhone)', () {
          final tier = classifier.classifyIOSDevice('iPhone1,1');
          expect(tier, MemoryTier.low);
        });
      });

      group('iPad returns high memory tier', () {
        test('iPad8,1 (iPad Pro 11" 3rd gen)', () {
          final tier = classifier.classifyIOSDevice('iPad8,1');
          expect(tier, MemoryTier.high);
        });

        test('iPad14,1 (iPad Pro 11" 4th gen)', () {
          final tier = classifier.classifyIOSDevice('iPad14,1');
          expect(tier, MemoryTier.high);
        });

        test('iPad6,11 (iPad 5th gen)', () {
          final tier = classifier.classifyIOSDevice('iPad6,11');
          expect(tier, MemoryTier.high);
        });

        test('iPad1,1 (original iPad)', () {
          final tier = classifier.classifyIOSDevice('iPad1,1');
          expect(tier, MemoryTier.high);
        });
      });

      group('Edge cases return medium as fallback', () {
        test('malformed iPhone model without comma gets parsed as version', () {
          // "iPhone14" -> version part "14" -> parsed as major version 14
          final tier = classifier.classifyIOSDevice('iPhone14');
          expect(tier, MemoryTier.high); // 14 >= 14
        });

        test('iPhone model with empty version part defaults to 0', () {
          // "iPhone,1" -> version part ",1" -> parts = ["", "1"]
          // int.tryParse("") = null, defaults to 0
          final tier = classifier.classifyIOSDevice('iPhone,1');
          expect(tier, MemoryTier.low); // 0 < 11
        });

        test('iPhone model with non-numeric major version defaults to 0', () {
          // "iPhoneX,1" -> version part "X,1" -> parts = ["X", "1"]
          // int.tryParse("X") = null, defaults to 0
          final tier = classifier.classifyIOSDevice('iPhoneX,1');
          expect(tier, MemoryTier.low); // 0 < 11
        });

        test('empty model string', () {
          final tier = classifier.classifyIOSDevice('');
          expect(tier, MemoryTier.medium);
        });

        test('unknown iOS device (iPod)', () {
          final tier = classifier.classifyIOSDevice('iPod9,1');
          expect(tier, MemoryTier.medium);
        });

        test('unknown iOS device (Apple TV)', () {
          final tier = classifier.classifyIOSDevice('AppleTV11,1');
          expect(tier, MemoryTier.medium);
        });

        test('unknown iOS device (HomePod)', () {
          final tier = classifier.classifyIOSDevice('AudioAccessory5,1');
          expect(tier, MemoryTier.medium);
        });
      });
    });

    group('Android Device Classification', () {
      group('SDK 29+ with 64-bit support returns high memory tier', () {
        test('Android 10 (SDK 29) with arm64-v8a', () {
          final tier = classifier.classifyAndroidDevice(
            29,
            ['arm64-v8a'],
          );
          expect(tier, MemoryTier.high);
        });

        test('Android 11 (SDK 30) with arm64-v8a', () {
          final tier = classifier.classifyAndroidDevice(
            30,
            ['arm64-v8a'],
          );
          expect(tier, MemoryTier.high);
        });

        test('Android 13 (SDK 33) with multiple 64-bit ABIs', () {
          final tier = classifier.classifyAndroidDevice(
            33,
            ['arm64-v8a', 'x86_64'],
          );
          expect(tier, MemoryTier.high);
        });

        test('Android 14 (SDK 34) with arm64-v8a', () {
          final tier = classifier.classifyAndroidDevice(
            34,
            ['arm64-v8a'],
          );
          expect(tier, MemoryTier.high);
        });
      });

      group('SDK 26-28 with 64-bit support returns medium memory tier', () {
        test('Android 8.0 (SDK 26) with arm64-v8a', () {
          final tier = classifier.classifyAndroidDevice(
            26,
            ['arm64-v8a'],
          );
          expect(tier, MemoryTier.medium);
        });

        test('Android 8.1 (SDK 27) with arm64-v8a', () {
          final tier = classifier.classifyAndroidDevice(
            27,
            ['arm64-v8a'],
          );
          expect(tier, MemoryTier.medium);
        });

        test('Android 9.0 (SDK 28) with arm64-v8a', () {
          final tier = classifier.classifyAndroidDevice(
            28,
            ['arm64-v8a'],
          );
          expect(tier, MemoryTier.medium);
        });

        test('Android 8.0 (SDK 26) with multiple 64-bit ABIs', () {
          final tier = classifier.classifyAndroidDevice(
            26,
            ['arm64-v8a', 'x86_64'],
          );
          expect(tier, MemoryTier.medium);
        });
      });

      group('Low-end devices return low memory tier', () {
        test('SDK below 26 returns low', () {
          final tier = classifier.classifyAndroidDevice(
            25,
            ['arm64-v8a'],
          );
          expect(tier, MemoryTier.low);
        });

        test('Android 7.1 (SDK 25) with arm64-v8a', () {
          final tier = classifier.classifyAndroidDevice(
            25,
            ['arm64-v8a'],
          );
          expect(tier, MemoryTier.low);
        });

        test('Android 6.0 (SDK 23) with arm64-v8a', () {
          final tier = classifier.classifyAndroidDevice(
            23,
            ['arm64-v8a'],
          );
          expect(tier, MemoryTier.low);
        });

        test('SDK 29+ without 64-bit support (edge case)', () {
          final tier = classifier.classifyAndroidDevice(
            29,
            [], // No 64-bit ABIs
          );
          expect(tier, MemoryTier.low);
        });

        test('SDK 26-28 without 64-bit support', () {
          final tier = classifier.classifyAndroidDevice(
            26,
            [], // No 64-bit ABIs
          );
          expect(tier, MemoryTier.low);
        });

        test('SDK 29+ with only 32-bit ABIs (no 64-bit support)', () {
          // Note: supported64BitAbis from AndroidDeviceInfo is already filtered
          // to only contain 64-bit ABIs. If device only has 32-bit,
          // supported64BitAbis will be empty.
          final tier = classifier.classifyAndroidDevice(
            29,
            [], // No 64-bit ABIs (32-bit only device)
          );
          expect(tier, MemoryTier.low);
        });
      });

      group('Edge cases', () {
        test('very high SDK version (SDK 50)', () {
          final tier = classifier.classifyAndroidDevice(
            50,
            ['arm64-v8a'],
          );
          expect(tier, MemoryTier.high);
        });

        test('very low SDK version (SDK 10)', () {
          final tier = classifier.classifyAndroidDevice(
            10,
            ['armeabi'],
          );
          expect(tier, MemoryTier.low);
        });

        test('empty ABI list', () {
          final tier = classifier.classifyAndroidDevice(
            30,
            [],
          );
          expect(tier, MemoryTier.low);
        });

        test('SDK exactly 29 with 64-bit (boundary)', () {
          final tier = classifier.classifyAndroidDevice(
            29,
            ['arm64-v8a'],
          );
          expect(tier, MemoryTier.high);
        });

        test('SDK exactly 26 with 64-bit (boundary)', () {
          final tier = classifier.classifyAndroidDevice(
            26,
            ['arm64-v8a'],
          );
          expect(tier, MemoryTier.medium);
        });

        test('SDK 28 at upper boundary of medium tier', () {
          final tier = classifier.classifyAndroidDevice(
            28,
            ['arm64-v8a'],
          );
          expect(tier, MemoryTier.medium);
        });
      });
    });

    group('Integration - Memory Tier to Pool Size Mapping', () {
      test('documents expected pool sizes', () {
        // This documents the relationship between MemoryTier
        // and pool size for future reference
        expect(MemoryTier.low.name, 'low'); // Expected pool size: 2
        expect(MemoryTier.medium.name, 'medium'); // Expected pool size: 3
        expect(MemoryTier.high.name, 'high'); // Expected pool size: 4
      });

      test('all memory tiers are distinct', () {
        final tiers = MemoryTier.values.toSet();
        expect(tiers.length, MemoryTier.values.length);
      });

      test('memory tiers are ordered by capacity', () {
        const tiers = MemoryTier.values;
        expect(tiers[0], MemoryTier.low);
        expect(tiers[1], MemoryTier.medium);
        expect(tiers[2], MemoryTier.high);
      });
    });
  });
}
