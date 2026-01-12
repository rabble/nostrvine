# Settings Screen Structure

The Settings screen is a non-shell screen that manages its own Scaffold and AppBar.

## Widget Tree

```
┌─────────────────────────────────────────────────────────────────┐
│  Scaffold                                                       │
│  backgroundColor: VineTheme.backgroundColor (#000A06)           │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  AppBar                                                   │  │
│  │  backgroundColor: VineTheme.navGreen (#00150D)            │  │
│  │  toolbarHeight: 72                                        │  │
│  │  leadingWidth: 80                                         │  │
│  │                                                           │  │
│  │  ┌──────────┐                                             │  │
│  │  │ IconBtn  │  "Settings"                                 │  │
│  │  │ (back)   │  (titleFont)                                │  │
│  │  └──────────┘                                             │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  body: Align (topCenter)                                  │  │
│  │                                                           │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  ConstrainedBox (maxWidth: 600)                     │  │  │
│  │  │                                                     │  │  │
│  │  │  ┌───────────────────────────────────────────────┐  │  │  │
│  │  │  │  ListView                                     │  │  │  │
│  │  │  │                                               │  │  │  │
│  │  │  │  • _buildSectionHeader("Profile")             │  │  │  │
│  │  │  │  • _buildSettingsTile (Edit Profile)          │  │  │  │
│  │  │  │  • _buildSettingsTile (Key Management)        │  │  │  │
│  │  │  │                                               │  │  │  │
│  │  │  │  • _buildSectionHeader("Account")             │  │  │  │
│  │  │  │  • _buildSettingsTile (Log Out)               │  │  │  │
│  │  │  │  • _buildSettingsTile (Remove Keys)           │  │  │  │
│  │  │  │  • _buildSettingsTile (Delete Account)        │  │  │  │
│  │  │  │                                               │  │  │  │
│  │  │  │  • _buildSectionHeader("Network")             │  │  │  │
│  │  │  │  • ... more tiles                             │  │  │  │
│  │  │  └───────────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  (No bottom navigation bar)                                     │
└─────────────────────────────────────────────────────────────────┘
```

## Key Differences from AppShell Screens

| Aspect | AppShell Screens | Settings Screen |
|--------|------------------|-----------------|
| Bottom Nav | Yes | No |
| Drawer | Yes (VineDrawer) | No |
| Body wrapper | ColoredBox + Padding + ClipRRect | Direct body |
| Rounded corners | Yes (30px) | No |
| Side margins | 4px (navGreen visible) | None |
| AppBar | Shared via AppShell | Own AppBar |
| Background | Via ColoredBox wrapper | Scaffold backgroundColor |

## AppBar Configuration

```dart
AppBar(
  elevation: 0,
  scrolledUnderElevation: 0,
  toolbarHeight: 72,
  leadingWidth: 80,
  centerTitle: false,
  titleSpacing: 0,
  backgroundColor: VineTheme.navGreen,
  leading: IconButton(...),  // Back button with styled container
  title: Text('Settings', style: VineTheme.titleFont()),
)
```

## Body Structure

```dart
body: Align(
  alignment: Alignment.topCenter,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 600),
    child: ListView(
      children: [
        // Section headers and setting tiles
      ],
    ),
  ),
)
```

The `ConstrainedBox` with `maxWidth: 600` ensures the settings list doesn't become too wide on tablets/desktop while remaining centered.
