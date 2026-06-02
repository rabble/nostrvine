# divine_quick_actions

Flutter plugin for Android and iOS home-screen quick actions.

## Features

- Typed shortcut models with payload support.
- Cold-start shortcut consumption so launch actions are not lost.
- Runtime shortcut events exposed as a broadcast stream.
- Android dynamic shortcuts through `ShortcutManager`.
- iOS quick actions through `UIApplicationShortcutItem`.

```dart
final launchAction = await DivineQuickActions.instance.initialize(
  onAction: (action) {
    // Route from action.type and action.payload.
  },
);

await DivineQuickActions.instance.setActions([
  DivineQuickAction(
    type: 'record',
    title: 'Record',
    subtitle: 'Open the camera',
    androidIconName: 'ic_quick_record',
    iosIconName: 'video.fill',
    iosIconStyle: DivineQuickActionIosIconStyle.system,
  ),
]);
```
