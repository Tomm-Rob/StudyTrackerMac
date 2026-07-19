# Study Tracker

A minimalist native macOS study-time tracker built with SwiftUI.

## What It Does

- Tracks study time for up to 50 classes.
- Lets each class have a name and custom color.
- Adds, edits, and deletes study sessions.
- Archives classes without deleting their study history.
- Starts a study-session timer and logs the elapsed time directly.
- Shows class-colored daily study-time bars with pointer-following time details.
- Shows class and all-course circle charts with pointer-following time details.
- Provides customizable dashboard cards with saved ordering, sizing, and visibility.
- Includes date-filtered analytics, generated local insights, and weekly reviews.
- Supports daily, weekly, and course goals with pacing and projections.
- Captures optional focus, energy, distraction, and topic details for sessions.
- Shows a class study-time leaderboard.
- Includes an adjustable Pomodoro timer with settings saved alongside study data.
- Supports light, dark, and system appearance modes with matching app icons.
- Saves data locally in JSON, with a setting to choose the save folder.
- Includes a custom Dock/app icon.

## Build And Package

Run:

```sh
./scripts/package-app.sh
```

The packaged app will appear at:

```text
dist/Study Tracker.app
```

A shareable archive is also created at:

```text
dist/Study Tracker-1.0.0-macOS-arm64.zip
```

If Finder does not open the app bundle from this project folder, double-click:

```text
Run Study Tracker.command
```

The default save file is created in Application Support, unless you choose another folder in the app settings.

The local build is ad-hoc signed for use on this Mac. Public distribution still requires an Apple Developer ID signature and notarization.
