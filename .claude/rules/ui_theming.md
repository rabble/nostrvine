# UI & Theming

Flutter uses Material Design with Material 3 enabled by default (since Flutter 3.16).

---

## ThemeData

### Use ThemeData, Not Conditional Logic
Widgets should inherit styles from the theme, not use conditional brightness checks:

**Bad:**
```dart
class BadWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Conditional logic - hard to maintain!
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : Colors.black,
      child: Text(
        'Bad',
        style: TextStyle(
          fontSize: 16,
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.black
              : Colors.white,
        ),
      ),
    );
  }
}
```

**Good:**
```dart
class GoodWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return ColoredBox(
      color: colorScheme.surface,
      child: Text(
        'Good',
        style: textTheme.bodyLarge,
      ),
    );
  }
}
```

Design updates now only require changing `ThemeData`, not every widget.

---

## Typography

### Custom Text Styles
Centralize text styles:

```dart
abstract class AppTextStyle {
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );
}
```

### TextTheme Integration
Connect custom styles to `ThemeData`:

```dart
ThemeData(
  textTheme: TextTheme(
    titleLarge: AppTextStyle.titleLarge,
    bodyMedium: AppTextStyle.bodyMedium,
  ),
);
```

### Usage
```dart
Text(
  'Title',
  style: Theme.of(context).textTheme.titleLarge,
);
```

---

## Colors

### Custom Colors Class
```dart
abstract class AppColors {
  static const primaryColor = Color(0xFF4F46E5);
  static const secondaryColor = Color(0xFF9C27B0);
  static const errorColor = Color(0xFFDC2626);
}
```

### ColorScheme Integration
```dart
ThemeData(
  colorScheme: ColorScheme(
    primary: AppColors.primaryColor,
    secondary: AppColors.secondaryColor,
    error: AppColors.errorColor,
    // ... other required colors
  ),
);
```

### Usage
```dart
Container(
  color: Theme.of(context).colorScheme.primary,
);
```

---

## Spacing

### Centralized Spacing System
```dart
abstract class AppSpacing {
  static const double spaceUnit = 16;
  static const double xs = 0.375 * spaceUnit;  // 6
  static const double sm = 0.5 * spaceUnit;    // 8
  static const double md = 0.75 * spaceUnit;   // 12
  static const double lg = spaceUnit;          // 16
  static const double xl = 1.5 * spaceUnit;    // 24
}
```

### Usage
```dart
Padding(
  padding: const EdgeInsets.all(AppSpacing.md),
  child: Column(
    children: [
      const Text('Title'),
      const SizedBox(height: AppSpacing.sm),
      const Text('Subtitle'),
    ],
  ),
);
```

---

## Component Theming

Customize Material components via `ThemeData` rather than inline styles:

```dart
ThemeData(
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(72, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(),
    contentPadding: EdgeInsets.all(12),
  ),
);
```

---

## Widget Structure

### Page/View Pattern
Separate routing concerns from UI implementation:

```dart
// Page - handles dependencies and routing
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final authRepository = context.read<AuthenticationRepository>();
        return LoginBloc(authenticationRepository: authRepository);
      },
      child: const LoginView(),
    );
  }
}

// View - UI implementation (testable in isolation)
class LoginView extends StatelessWidget {
  @visibleForTesting
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    // UI implementation
  }
}
```

**Why `@visibleForTesting`?** Prevents accidental use of View without Page's dependencies.

### Testing the View
```dart
void main() {
  group('LoginView', () {
    late LoginBloc loginBloc;

    setUp(() {
      loginBloc = _MockLoginBloc();
    });

    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        BlocProvider<LoginBloc>.value(
          value: loginBloc,
          child: const LoginView(),
        ),
      );

      expect(find.byType(LoginView), findsOneWidget);
    });
  });
}
```

---

## Widget Composition

### Widgets Over Methods
Always create separate widget classes instead of methods returning widgets.

**Good:**
```dart
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MyText('Hello World!');
  }
}

class _MyText extends StatelessWidget {
  const _MyText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text);
  }
}
```

**Bad:**
```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _getText('Hello World!');
  }

  // Don't do this!
  Text _getText(String text) {
    return Text(text);
  }
}
```

**Benefits:**
- **Testability:** Test widgets in isolation
- **Maintainability:** Smaller widgets, own BuildContext
- **Reusability:** Easy to compose larger widgets
- **Performance:** Only rebuilt widget updates, not entire parent

---

## Layout Best Practices

### Row/Column Sizing

| Property | Purpose |
|----------|---------|
| `MainAxisSize.min` | Shrink to fit children |
| `MainAxisSize.max` | Expand to fill available space |
| `mainAxisAlignment` | Position children along main axis |
| `crossAxisAlignment` | Position children along cross axis |

### Flexible vs Expanded

| Widget | Behavior |
|--------|----------|
| `Flexible` | Child can be smaller than available space |
| `Expanded` | Child must fill available space |

```dart
Row(
  children: [
    Expanded(child: TextField()),  // Fill remaining space
    const SizedBox(width: 8),
    ElevatedButton(onPressed: () {}, child: Text('Submit')),
  ],
);
```

### Handling Overflow
Use `SingleChildScrollView` or `ListView.builder`:

```dart
// For dynamic lists
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
);

// For fixed content that might overflow
SingleChildScrollView(
  child: Column(
    children: [...],
  ),
);
```

---

## Accessibility

### Color Contrast
- **Normal text:** Minimum 4.5:1 contrast ratio
- **Large text (18pt+):** Minimum 3:1 contrast ratio

### Dynamic Font Sizes
Test with system font size increased to ensure UI remains usable.

### Testing Accessibility
- Test with screen readers (TalkBack on Android, VoiceOver on iOS)
- Use Flutter's accessibility inspector
- Verify touch targets are at least 48x48 dp

### Semantic Labels
Use `Semantics` widget for screen readers:

```dart
Semantics(
  label: 'Play video',
  button: true,
  child: IconButton(
    icon: const Icon(Icons.play_arrow),
    onPressed: () {},
  ),
);
```
