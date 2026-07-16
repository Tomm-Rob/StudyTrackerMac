# Study Tracker

A minimalist native macOS study-time tracker built with SwiftUI.

## What It Does

- Tracks study time for up to 50 classes.
- Lets each class have a name and custom color.
- Adds, edits, and deletes study sessions.
- Starts a study-session timer and logs the elapsed time directly.
- Shows a daily study-time bar graph.
- Shows total time by class in a circle chart.
- Shows an all-classes circle chart and class study-time leaderboard.
- Includes an adjustable Pomodoro timer with classic defaults.
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

If Finder does not open the app bundle from this project folder, double-click:

```text
Run Study Tracker.command
```

The default save file is created in Application Support, unless you choose another folder in the app settings.
