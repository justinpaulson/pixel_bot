# Pixel for iOS and Android

A small, bundled mobile interface for the existing Pixel service. Native projects use [Capacitor 8](https://capacitorjs.com/docs); React renders the screens, and the web game's existing Stimulus controllers render the same sanitized, synchronized drawings. The app never loads the hosted website as its UI.

- Solo and private rooms for up to 12 players; web and mobile players share rooms.
- Eight categories, three artists with previews, and 3/5/10 rounds.
- Animated drawings, warm-up sketchbook, hints, repeated guesses, scores, automatic round changes, and the finished gallery.
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

Set `JAVA_HOME` to JDK 21 and configure `ANDROID_HOME` or an ignored `android/local.properties` with `sdk.dir`. Debug APK: `android/app/build/outputs/apk/debug/app-debug.apk`. Release bundle: `android/app/build/outputs/bundle/release/app-release.aab` (unsigned until a release signing configuration is supplied). iOS simulator app: `ios/DerivedData/Build/Products/Debug-iphonesimulator/App.app`.

`npm run icons` renders the existing Pixel mark into native icon and launch assets. `npm run sync` copies the interface and updates native dependency references. Keep both native projects in source control; generated web copies, SDK paths, credentials, and build outputs are ignored.

The dependency override for `xcode`'s `uuid` selects the patched CommonJS-compatible v11 implementation used by Capacitor's CLI. It does not alter the native runtime.

## Invites

Share sends the existing HTTPS room URL so friends can play on the web. In Pixel, tap **Join room** and paste that link. The registered `pixelguess://games/<room-uuid>` scheme also opens the join sheet (including cold launch). Arbitrary domains and malformed room IDs are rejected. Verified Universal Links / Android App Links require the final store signing identities and are not configured yet.

## Release

App identifiers: `com.lillybitgames.pixel` on both platforms; initial version 1.0 (1). iOS supports iPhone and iPad on iOS 15+, Android supports API 24+. Gameplay requires an internet connection, just like the web game. No analytics, ads, tip jar, or purchases are included in the mobile client.

These are application projects and development builds, not store submissions. Before a store release: configure the Apple team/provisioning and Android upload key, provide store privacy/support metadata and screenshots, verify a full game and native sharing on physical iPhone/iPad and Android, and upload through the normal review tracks. The iOS privacy manifest declares the UserDefaults access used by Preferences; no tracking permission is requested.
