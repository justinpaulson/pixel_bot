# Pixel for iOS and Android

A small, bundled mobile interface for the existing Pixel service. Native projects use [Capacitor 8](https://capacitorjs.com/docs); React renders the screens, and the web game's existing Stimulus controllers render the same sanitized, synchronized drawings. The app never loads the hosted website as its UI.

- Solo and private rooms for up to 12 players; web and mobile players share rooms.
- Eight categories, three artists with previews, and 3/5/10 rounds.
- Animated drawings, warm-up sketchbook, hints, repeated guesses, scores, automatic round changes, and the finished gallery.
- Correct guesses celebrate once with confetti, a success haptic, and the awarded points. The banner stays through the reveal, clears next round, and respects reduced motion.
- Native share sheet, haptics, saved nickname/setup, resume, invite links, background recovery, and connection errors.
- No account setup. Guest credentials are stored in iOS Keychain or encrypted with Android Keystore. Preferences store only nickname, setup, and the last room ID. Tokens expire after 180 days; expired sessions return to the menu.

## Run

Requires Node 22+, Xcode 26+ for iOS, or JDK 21 and Android SDK 36 for Android. See [Capacitor environment setup](https://capacitorjs.com/docs/getting-started/environment-setup).

```sh
cd mobile
npm ci
npm run sync
npm run ios       # opens Xcode
npm run android   # opens Android Studio
```

The native applications connect to `https://pixel.justinpaulson.com/api/v1`. Deploy the Rails API before testing network play. No provider key is bundled in the apps. Production transport uses HTTPS only and does not enable arbitrary WebView navigation or cleartext exceptions.

For local browser development, start Rails on port 3000 from the repository root, then run `npm run dev` here. Vite proxies `/api` to Rails. Browser development uses a session-only credential; native builds use the platform vault.

## Build and check

```sh
npm run build
npm test                      # WebKit iPhone + Chromium Android interaction checks
npm run sync
xcodebuild -project ios/App/App.xcodeproj -scheme App \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ios/DerivedData build
cd android
./gradlew assembleDebug bundleRelease
```

Set `JAVA_HOME` to JDK 21 and configure `ANDROID_HOME` or an ignored `android/local.properties` with `sdk.dir`. Debug APK: `android/app/build/outputs/apk/debug/app-debug.apk`. Release bundle: `android/app/build/outputs/bundle/release/app-release.aab`. Release APK: `android/app/build/outputs/apk/release/app-release.apk`. An ignored `android/signing.properties` supplies `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`; keep the key and credentials outside source control. A build without this file is unsigned. iOS simulator app: `ios/DerivedData/Build/Products/Debug-iphonesimulator/App.app`.

`npm run icons` renders the existing Pixel mark into native icon and launch assets. `npm run sync` copies the interface and updates native dependency references. Keep both native projects in source control; generated web copies, SDK paths, credentials, and build outputs are ignored.

The dependency override for `xcode`'s `uuid` selects the patched CommonJS-compatible v11 implementation used by Capacitor's CLI. It does not alter the native runtime.

## Invites

Share sends the existing HTTPS room URL so friends can play on the web. In Pixel, tap **Join room** and paste that link. The registered `pixelguess://games/<room-uuid>` scheme also opens the join sheet (including cold launch). Arbitrary domains and malformed room IDs are rejected. Verified Universal Links / Android App Links require the final store signing identities and are not configured yet.

## Release

App identifiers: `com.lillybitgames.pixel` on both platforms; current version 1.0 (2). iOS supports iPhone and iPad on iOS 15+, Android supports API 24+. Gameplay requires an internet connection, just like the web game. No analytics, ads, tip jar, or purchases are included in the mobile client.

Beta releases use Lilly Bit Games / LILLY BIT LLC (Apple team `SD8D6GX2BC`). `release/ExportOptions.plist` uploads an archive to App Store Connect using the signed-in Xcode account. Public support and privacy pages are `/support` and `/privacy`. See `release/beta-1.0-2.json` for the latest verified distribution status (`release/beta-1.0.json` preserves the first beta receipt). Public store release still requires screenshots, complete store disclosures/ratings, and production review. The iOS privacy manifest declares the UserDefaults access used by Preferences; no tracking permission is requested.

## Physical Android beta smoke test

This opt-in instrumentation test uses the live service and creates one three-round solo game. It verifies the signed release's native HTTP bridge, drawing screen, wrong-guess response, saved credential/room recovery after activity recreation, three reveals, and return to the menu. It does not test a physical keyboard or native sharing.

A second test uses deterministic game responses in the test process to verify the correct-answer celebration on the physical device, including an immediate final reveal, the per-round award versus total score, and reset on leaving. Native storage and haptics remain real; fixture code is not included in the shipped app.

```sh
cd android
./gradlew assembleReleaseAndroidTest
adb -s DEVICE_SERIAL install -r app/build/outputs/apk/release/app-release.apk
adb -s DEVICE_SERIAL install -r app/build/outputs/apk/androidTest/release/app-release-androidTest.apk
adb -s DEVICE_SERIAL shell am instrument -w -r -e class com.lillybitgames.pixel.BetaSmokeTest com.lillybitgames.pixel.test/androidx.test.runner.AndroidJUnitRunner
```

The local sideload is signed with Pixel's upload key. Google Play uses its managed app-signing key; switching an already installed sideload to the Play version may require uninstalling the sideload first. Preserve any wanted room link before switching.
