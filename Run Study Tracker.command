#!/bin/zsh
cd "$(dirname "$0")"
./scripts/package-app.sh
exec "./dist/Study Tracker.app/Contents/MacOS/StudyTracker"
