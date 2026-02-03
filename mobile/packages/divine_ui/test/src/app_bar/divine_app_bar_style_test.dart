import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiVineAppBarStyle', () {
    group('constructor', () {
      test('creates with default values', () {
        // Testing constructor directly, not the named constant.
        // ignore: use_named_constants
        const style = DiVineAppBarStyle();

        expect(style.height, 72);
        expect(style.leadingWidth, 80);
        expect(style.iconButtonSize, 48);
        expect(style.iconSize, 32);
        expect(style.iconButtonBorderRadius, 20);
        expect(style.iconButtonBackgroundColor, isNull);
        expect(style.iconColor, isNull);
        expect(style.titleStyle, isNull);
        expect(style.subtitleStyle, isNull);
        expect(style.actionButtonSpacing, 8);
        expect(style.horizontalPadding, 16);
        expect(style.dropdownCaretSize, 16);
      });

      test('creates with custom values', () {
        const titleStyle = TextStyle(fontSize: 24);
        const subtitleStyle = TextStyle(fontSize: 12);

        const style = DiVineAppBarStyle(
          height: 64,
          leadingWidth: 72,
          iconButtonSize: 56,
          iconSize: 40,
          iconButtonBorderRadius: 28,
          iconButtonBackgroundColor: Colors.red,
          iconColor: Colors.blue,
          titleStyle: titleStyle,
          subtitleStyle: subtitleStyle,
          actionButtonSpacing: 12,
          horizontalPadding: 24,
          dropdownCaretSize: 20,
        );

        expect(style.height, 64);
        expect(style.leadingWidth, 72);
        expect(style.iconButtonSize, 56);
        expect(style.iconSize, 40);
        expect(style.iconButtonBorderRadius, 28);
        expect(style.iconButtonBackgroundColor, Colors.red);
        expect(style.iconColor, Colors.blue);
        expect(style.titleStyle, titleStyle);
        expect(style.subtitleStyle, subtitleStyle);
        expect(style.actionButtonSpacing, 12);
        expect(style.horizontalPadding, 24);
        expect(style.dropdownCaretSize, 20);
      });
    });

    group('defaultStyle', () {
      test('returns constant with default values', () {
        const style = DiVineAppBarStyle.defaultStyle;

        expect(style.height, 72);
        expect(style.leadingWidth, 80);
        expect(style.iconButtonSize, 48);
        expect(style.iconSize, 32);
        expect(style.iconButtonBorderRadius, 20);
        expect(style.iconButtonBackgroundColor, isNull);
        expect(style.iconColor, isNull);
        expect(style.titleStyle, isNull);
        expect(style.subtitleStyle, isNull);
        expect(style.actionButtonSpacing, 8);
        expect(style.horizontalPadding, 16);
        expect(style.dropdownCaretSize, 16);
      });
    });

    group('copyWith', () {
      test('returns new instance with updated values', () {
        const original = DiVineAppBarStyle(
          iconColor: Colors.white,
        );

        final copied = original.copyWith(
          iconButtonSize: 56,
          iconButtonBackgroundColor: Colors.red,
        );

        expect(copied.iconButtonSize, 56);
        expect(copied.iconButtonBackgroundColor, Colors.red);
        expect(copied.iconColor, Colors.white);
      });

      test('returns identical values when no changes specified', () {
        const original = DiVineAppBarStyle(
          iconButtonSize: 56,
          iconSize: 40,
          iconButtonBorderRadius: 28,
          iconButtonBackgroundColor: Colors.red,
          iconColor: Colors.blue,
        );

        final copied = original.copyWith();

        expect(copied.iconButtonSize, original.iconButtonSize);
        expect(copied.iconSize, original.iconSize);
        expect(copied.iconButtonBorderRadius, original.iconButtonBorderRadius);
        expect(
          copied.iconButtonBackgroundColor,
          original.iconButtonBackgroundColor,
        );
        expect(copied.iconColor, original.iconColor);
      });

      test('can update titleStyle', () {
        const style = DiVineAppBarStyle.defaultStyle;
        const newTitleStyle = TextStyle(fontSize: 30);

        final copied = style.copyWith(titleStyle: newTitleStyle);

        expect(copied.titleStyle, newTitleStyle);
      });

      test('can update subtitleStyle', () {
        const style = DiVineAppBarStyle.defaultStyle;
        const newSubtitleStyle = TextStyle(fontSize: 14);

        final copied = style.copyWith(subtitleStyle: newSubtitleStyle);

        expect(copied.subtitleStyle, newSubtitleStyle);
      });

      test('can update actionButtonSpacing', () {
        const style = DiVineAppBarStyle.defaultStyle;

        final copied = style.copyWith(actionButtonSpacing: 12);

        expect(copied.actionButtonSpacing, 12);
      });

      test('can update horizontalPadding', () {
        const style = DiVineAppBarStyle.defaultStyle;

        final copied = style.copyWith(horizontalPadding: 24);

        expect(copied.horizontalPadding, 24);
      });

      test('can update dropdownCaretSize', () {
        const style = DiVineAppBarStyle.defaultStyle;

        final copied = style.copyWith(dropdownCaretSize: 20);

        expect(copied.dropdownCaretSize, 20);
      });

      test('can update height', () {
        const style = DiVineAppBarStyle.defaultStyle;

        final copied = style.copyWith(height: 64);

        expect(copied.height, 64);
      });

      test('can update leadingWidth', () {
        const style = DiVineAppBarStyle.defaultStyle;

        final copied = style.copyWith(leadingWidth: 72);

        expect(copied.leadingWidth, 72);
      });
    });

    group('merge', () {
      test('returns this when other is null', () {
        const style = DiVineAppBarStyle(iconButtonSize: 56);
        final merged = style.merge(null);

        expect(merged, style);
      });

      test('other style takes precedence for non-null color values', () {
        const base = DiVineAppBarStyle(
          iconButtonBackgroundColor: Colors.red,
          iconColor: Colors.blue,
        );
        const other = DiVineAppBarStyle(
          iconButtonBackgroundColor: Colors.green,
        );

        final merged = base.merge(other);

        expect(merged.iconButtonBackgroundColor, Colors.green);
        expect(merged.iconColor, Colors.blue);
      });

      test('other style dimension values always take precedence', () {
        const base = DiVineAppBarStyle.defaultStyle;
        const other = DiVineAppBarStyle(
          height: 64,
          leadingWidth: 72,
          iconButtonSize: 56,
          iconSize: 40,
          iconButtonBorderRadius: 28,
          actionButtonSpacing: 12,
          horizontalPadding: 24,
          dropdownCaretSize: 20,
        );

        final merged = base.merge(other);

        expect(merged.height, 64);
        expect(merged.leadingWidth, 72);
        expect(merged.iconButtonSize, 56);
        expect(merged.iconSize, 40);
        expect(merged.iconButtonBorderRadius, 28);
        expect(merged.actionButtonSpacing, 12);
        expect(merged.horizontalPadding, 24);
        expect(merged.dropdownCaretSize, 20);
      });

      test('merges text styles correctly', () {
        const baseTitleStyle = TextStyle(fontSize: 20);
        const baseSubtitleStyle = TextStyle(fontSize: 12);
        const otherTitleStyle = TextStyle(fontSize: 24);

        const base = DiVineAppBarStyle(
          titleStyle: baseTitleStyle,
          subtitleStyle: baseSubtitleStyle,
        );
        const other = DiVineAppBarStyle(
          titleStyle: otherTitleStyle,
        );

        final merged = base.merge(other);

        expect(merged.titleStyle, otherTitleStyle);
        expect(merged.subtitleStyle, baseSubtitleStyle);
      });
    });

    group('equality', () {
      test('equal instances are equal', () {
        const style1 = DiVineAppBarStyle(
          iconButtonBackgroundColor: Colors.red,
          iconColor: Colors.white,
        );
        const style2 = DiVineAppBarStyle(
          iconButtonBackgroundColor: Colors.red,
          iconColor: Colors.white,
        );

        expect(style1, equals(style2));
      });

      test('different instances are not equal', () {
        const style1 = DiVineAppBarStyle.defaultStyle;
        const style2 = DiVineAppBarStyle(iconButtonSize: 56);

        expect(style1, isNot(equals(style2)));
      });

      test('hashCode is consistent for equal objects', () {
        const style1 = DiVineAppBarStyle(
          iconColor: Colors.white,
        );
        const style2 = DiVineAppBarStyle(
          iconColor: Colors.white,
        );

        expect(style1.hashCode, equals(style2.hashCode));
      });

      test('hashCode differs for different objects', () {
        const style1 = DiVineAppBarStyle.defaultStyle;
        const style2 = DiVineAppBarStyle(iconButtonSize: 56);

        expect(style1.hashCode, isNot(equals(style2.hashCode)));
      });
    });
  });
}
