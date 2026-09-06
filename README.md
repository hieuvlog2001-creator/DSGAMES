# DSGames 1.8 — clean rebuild

This repository is a clean-room UI/game-library rebuild based on the supplied DSGames 1.8 IPA's visible resources and metadata.

## Included
- SwiftUI iOS app
- Dark DSGames-style game library UI
- Search, Featured, Library, Tools and Settings tabs
- Extracted visual PNG assets from the supplied IPA
- iOS 16+ / iPhone + iPad
- GitHub Actions build workflow

## Intentionally excluded
The original binary contains process-injection, ESP/overlay, anti-debugging and device/security-bypass related routines. This rebuild does **not** reproduce those functions. It is limited to the normal app UI/library/resource experience.

## Build
Open `DSGames/DSGames.xcodeproj` in Xcode 16+ and select a signing team, or run the GitHub Actions workflow.
