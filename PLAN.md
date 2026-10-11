# Rename App to "Prep Ethiopia" and Remove Images

## Goal
Rename the app from "Lumo" to "Prep Ethiopia" and remove all image assets from the project.

## Files to Update (App Name)
1. `pubspec.yaml` - Update `name:` field and description
2. `android/app/src/main/AndroidManifest.xml` - Update `android:label`
3. `ios/Runner/Info.plist` - Update `CFBundleDisplayName` and `CFBundleName`
4. `lib/main.dart` - Update app title
5. `lib/features/auth/presentation/onboarding_screen.dart` - Update text references
6. `lib/features/auth/presentation/login_screen.dart` - Update text references
7. `lib/core/localization/app_localizations.dart` - Update `appName`

## Files to Remove (Images)
1. `assets/logo.png`
2. `assets/logo.svg`
3. `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png` (all icon files)
4. `ios/Runner/Assets.xcassets/LaunchImage.imageset/*.png` (all launch images)
5. `macos/Runner/Assets.xcassets/AppIcon.appiconset/*.png` (all icon files)
6. `android/app/src/main/res/mipmap-*/ic_launcher.png` (all icon files)
7. `web/icons/*.png` (all icon files)
8. `web/favicon.png`
9. `Lumo.png` (root)
10. `Lumo.svg` (root)
11. `stitch_frontend_temp/**/*.png` (temp screenshot files - optional)

## Files to Update (pubspec.yaml)
- Remove `assets/logo.png` and `assets/logo.svg` from flutter assets
- Update `flutter_launcher_icons` section (image_path)

## Notes
- Build artifacts in `build/` directory are auto-generated and should be cleaned with `flutter clean`
- `node_modules/` images are third-party and should not be removed
- The `stitch_frontend_temp/` directory appears to be temporary frontend files