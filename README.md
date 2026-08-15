# fsocial

A macOS social media management app with embedded browsers, quick-reply templates, content scheduling, and post composer.

## Features

- **Embedded Browsers** - X, Instagram, Threads, TikTok, Facebook, LinkedIn
- **Quick Replies** - Pre-written templates for fast engagement
- **Content Calendar** - Schedule posts with notifications
- **Post Composer** - Create posts with images/videos for multiple platforms
- **Persistent Sessions** - Stay logged in across app launches

## Requirements

- **macOS 12.0** (Monterey) or later
- Works on both **Intel and Apple Silicon** Macs

## Development

### Building for Release

**IMPORTANT:** Always build as Universal Binary to support both Intel and Apple Silicon Macs.

```bash
./build-release.sh
```

This script:
1. Builds Universal Binary (x86_64 + arm64)
2. Signs with Developer ID
3. Notarizes with Apple
4. Creates DMG
5. Publishes to GitHub Releases

### Manual Build (if needed)

```bash
xcodebuild -project fsocial.xcodeproj -scheme fsocial -configuration Release \
    ARCHS="x86_64 arm64" \
    ONLY_ACTIVE_ARCH=NO \
    build
```

### Build Requirements

- Xcode 14+
- Developer ID Application certificate
- App-specific password for notarization (stored in keychain as `fsocial-notary`)

## Distribution

Download the latest release:
```
https://github.com/masonearl/fsocial/releases/latest/download/fsocial.dmg
```

## Architecture

| Component | Description |
|-----------|-------------|
| `ContentView.swift` | Main layout with sidebar and browser |
| `SidebarView.swift` | Platform list, quick replies, navigation |
| `BrowserView.swift` | WebKit browser with controls |
| `SchedulerView.swift` | Content calendar and scheduling |
| `ComposerView.swift` | Post composer with media support |
| `WebView.swift` | WKWebView wrapper with session persistence |
| `Models.swift` | Data models (Platform, QuickReply, ScheduledPost, Draft) |
| `*Store.swift` | Persistence stores using UserDefaults |
