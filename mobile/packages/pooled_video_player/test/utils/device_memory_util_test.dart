import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

class MockDeviceInfoPlugin extends Mock implements DeviceInfoPlugin {}

class MockIosDeviceInfo extends Mock implements IosDeviceInfo {}

class MockIosUtsname extends Mock implements IosUtsname {}

class MockAndroidDeviceInfo extends Mock implements AndroidDeviceInfo {}

class MockAndroidBuildVersion extends Mock implements AndroidBuildVersion {}

class MockPlatformChecker extends Mock implements PlatformChecker {}

void main() {
  group('DeviceMemoryUtil', () {
    late MockDeviceInfoPlugin mockDeviceInfo;
    late MockPlatformChecker mockPlatformChecker;

    setUp(() {
      mockDeviceInfo = MockDeviceInfoPlugin();
      mockPlatformChecker = MockPlatformChecker();
    });

    group('MemoryTier', () {
      test('has correct enum values', () {
        expect(MemoryTier.values.length, 3);
        expect(MemoryTier.low.name, 'low');
        expect(MemoryTier.medium.name, 'medium');
        expect(MemoryTier.high.name, 'high');
      });
    });

    group('PlatformType', () {
      test('has correct enum values', () {
        expect(PlatformType.values.length, 3);
        expect(PlatformType.ios.name, 'ios');
        expect(PlatformType.android.name, 'android');
        expect(PlatformType.other.name, 'other');
      });
    });

    group('getMemoryTier', () {
      group('iOS platform', () {
        late MockIosDeviceInfo mockIosInfo;
        late MockIosUtsname mockUtsname;

        setUp(() {
          mockIosInfo = MockIosDeviceInfo();
          mockUtsname = MockIosUtsname();
          when(() => mockIosInfo.utsname).thenReturn(mockUtsname);
          when(
            () => mockDeviceInfo.iosInfo,
          ).thenAnswer((_) async => mockIosInfo);
          when(
            () => mockPlatformChecker.currentPlatform,
          ).thenReturn(PlatformType.ios);
        });

        group('iPhone 14+ returns high memory tier', () {
          test('iPhone14,1', () async {
            when(() => mockUtsname.machine).thenReturn('iPhone14,1');

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.high);
          });

          test('iPhone15,2', () async {
            when(() => mockUtsname.machine).thenReturn('iPhone15,2');

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.high);
          });

          test('iPhone16,1', () async {
            when(() => mockUtsname.machine).thenReturn('iPhone16,1');

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.high);
          });
        });

        group('iPhone 11-13 returns medium memory tier', () {
          test('iPhone11,8', () async {
            when(() => mockUtsname.machine).thenReturn('iPhone11,8');

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.medium);
          });

          test('iPhone12,1', () async {
            when(() => mockUtsname.machine).thenReturn('iPhone12,1');

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.medium);
          });

          test('iPhone13,4', () async {
            when(() => mockUtsname.machine).thenReturn('iPhone13,4');

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.medium);
          });
        });

        group('iPhone below 11 returns low memory tier', () {
          test('iPhone10,4', () async {
            when(() => mockUtsname.machine).thenReturn('iPhone10,4');

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.low);
          });

          test('iPhone9,1', () async {
            when(() => mockUtsname.machine).thenReturn('iPhone9,1');

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.low);
          });

          test('iPhone1,1', () async {
            when(() => mockUtsname.machine).thenReturn('iPhone1,1');

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.low);
          });
        });

        group('iPad returns high memory tier', () {
          test('iPad8,1', () async {
            when(() => mockUtsname.machine).thenReturn('iPad8,1');

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.high);
          });

          test('iPad14,1', () async {
            when(() => mockUtsname.machine).thenReturn('iPad14,1');

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.high);
          });
        });

        group('Edge cases return medium as fallback', () {
          test('empty model string', () async {
            when(() => mockUtsname.machine).thenReturn('');

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.medium);
          });

          test('unknown iOS device (iPod)', () async {
            when(() => mockUtsname.machine).thenReturn('iPod9,1');

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.medium);
          });

          test('iPhone model with non-numeric version', () async {
            when(() => mockUtsname.machine).thenReturn('iPhoneX,1');

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.low);
          });

          test('iPhone model without comma', () async {
            when(() => mockUtsname.machine).thenReturn('iPhone14');

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.high);
          });
        });
      });

      group('Android platform', () {
        late MockAndroidDeviceInfo mockAndroidInfo;
        late MockAndroidBuildVersion mockBuildVersion;

        setUp(() {
          mockAndroidInfo = MockAndroidDeviceInfo();
          mockBuildVersion = MockAndroidBuildVersion();
          when(() => mockAndroidInfo.version).thenReturn(mockBuildVersion);
          when(
            () => mockDeviceInfo.androidInfo,
          ).thenAnswer((_) async => mockAndroidInfo);
          when(
            () => mockPlatformChecker.currentPlatform,
          ).thenReturn(PlatformType.android);
        });

        group('SDK 29+ with 64-bit support returns high memory tier', () {
          test('SDK 29 with arm64-v8a', () async {
            when(() => mockBuildVersion.sdkInt).thenReturn(29);
            when(
              () => mockAndroidInfo.supported64BitAbis,
            ).thenReturn(['arm64-v8a']);

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.high);
          });

          test('SDK 33 with multiple 64-bit ABIs', () async {
            when(() => mockBuildVersion.sdkInt).thenReturn(33);
            when(
              () => mockAndroidInfo.supported64BitAbis,
            ).thenReturn(['arm64-v8a', 'x86_64']);

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.high);
          });
        });

        group('SDK 26-28 with 64-bit support returns medium memory tier', () {
          test('SDK 26 with arm64-v8a', () async {
            when(() => mockBuildVersion.sdkInt).thenReturn(26);
            when(
              () => mockAndroidInfo.supported64BitAbis,
            ).thenReturn(['arm64-v8a']);

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.medium);
          });

          test('SDK 28 with arm64-v8a', () async {
            when(() => mockBuildVersion.sdkInt).thenReturn(28);
            when(
              () => mockAndroidInfo.supported64BitAbis,
            ).thenReturn(['arm64-v8a']);

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.medium);
          });
        });

        group('Low-end devices return low memory tier', () {
          test('SDK below 26', () async {
            when(() => mockBuildVersion.sdkInt).thenReturn(25);
            when(
              () => mockAndroidInfo.supported64BitAbis,
            ).thenReturn(['arm64-v8a']);

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.low);
          });

          test('SDK 29+ without 64-bit support', () async {
            when(() => mockBuildVersion.sdkInt).thenReturn(29);
            when(() => mockAndroidInfo.supported64BitAbis).thenReturn([]);

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.low);
          });

          test('SDK 26-28 without 64-bit support', () async {
            when(() => mockBuildVersion.sdkInt).thenReturn(26);
            when(() => mockAndroidInfo.supported64BitAbis).thenReturn([]);

            final classifier = DeviceMemoryUtil(
              deviceInfo: mockDeviceInfo,
              platformChecker: mockPlatformChecker,
            );

            expect(await classifier.getMemoryTier(), MemoryTier.low);
          });
        });
      });

      group('Other platform', () {
        test('returns medium memory tier', () async {
          when(
            () => mockPlatformChecker.currentPlatform,
          ).thenReturn(PlatformType.other);

          final classifier = DeviceMemoryUtil(
            deviceInfo: mockDeviceInfo,
            platformChecker: mockPlatformChecker,
          );

          expect(await classifier.getMemoryTier(), MemoryTier.medium);
        });
      });

      group('Caching', () {
        test('caches result after first call', () async {
          when(
            () => mockPlatformChecker.currentPlatform,
          ).thenReturn(PlatformType.other);

          final classifier = DeviceMemoryUtil(
            deviceInfo: mockDeviceInfo,
            platformChecker: mockPlatformChecker,
          );

          final tier1 = await classifier.getMemoryTier();
          final tier2 = await classifier.getMemoryTier();

          expect(tier1, tier2);
          // Platform should only be checked once
          verify(() => mockPlatformChecker.currentPlatform).called(1);
        });

        test('resetCache allows fresh detection', () async {
          when(
            () => mockPlatformChecker.currentPlatform,
          ).thenReturn(PlatformType.other);

          final classifier = DeviceMemoryUtil(
            deviceInfo: mockDeviceInfo,
            platformChecker: mockPlatformChecker,
          );

          await classifier.getMemoryTier();
          classifier.resetCache();
          await classifier.getMemoryTier();

          // Platform should be checked twice after reset
          verify(() => mockPlatformChecker.currentPlatform).called(2);
        });
      });

      group('Error handling', () {
        test('returns medium tier on exception', () async {
          when(
            () => mockPlatformChecker.currentPlatform,
          ).thenReturn(PlatformType.ios);
          when(
            () => mockDeviceInfo.iosInfo,
          ).thenThrow(Exception('Device info error'));

          final classifier = DeviceMemoryUtil(
            deviceInfo: mockDeviceInfo,
            platformChecker: mockPlatformChecker,
          );

          expect(await classifier.getMemoryTier(), MemoryTier.medium);
        });
      });
    });

    group('Integration - Memory Tier to Pool Size Mapping', () {
      test('documents expected pool sizes', () {
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
