# Building and running the Android APK

This project ships a **release APK** that talks to the backend when `apiBaseUrl` is set in `assets/config.json`. Without it, the app uses on-device storage (see `lib/services/storage_service.dart`).

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and on your `PATH`.
- Android toolchain: Android SDK, accepted licenses (`flutter doctor --android-licenses`).
- A working Flutter environment: run `flutter doctor` and fix any **errors** (warnings are often fine).

## 1. Point the app at your API (optional but typical)

Edit **`assets/config.json`**:

```json
{
  "apiBaseUrl": "https://your-api-host.example.com"
```

- Use your real backend base URL (no trailing slash required; paths are joined in code).
- **Rebuild the APK** after every URL change; the file is bundled at compile time.

## 2. Build the release APK

From the **repository root** (`wood_and_more_app`):

```bash
flutter build apk --release
```

### Output

- **APK file:** `build/app/outputs/flutter-apk/app-release.apk`

On Windows the full path is typically:

`build\app\outputs\flutter-apk\app-release.apk`

## 3. Install on a phone

1. Copy `app-release.apk` to the device (USB, cloud drive, email, etc.).
2. Open the file on the phone and install.
3. If Android blocks the install: **Settings → Security** (or **Apps → Special access**) → allow install from your file manager / source (“unknown sources” or “install unknown apps”).

## 4. Run and test

1. If you use **`apiBaseUrl`**: start your **API server** (and database) so the phone can reach that URL (HTTPS recommended for production; local LAN IP works for same-network tests).
2. Launch the **Wood & More** app from the launcher.
3. If login or data fails, check: correct URL in `assets/config.json`, server running, firewall, and HTTPS / certificate issues.

## Optional: smaller or split APKs

- **Per-ABI (smaller downloads):**  
  `flutter build apk --release --split-per-abi`  
  Outputs under the same folder, e.g. `app-armeabi-v7a-release.apk`, `app-arm64-v8a-release.apk`.

## Troubleshooting

| Issue | What to try |
|--------|--------------|
| `flutter` not found | Add Flutter `bin` to PATH or use full path to `flutter.bat`. |
| Gradle / SDK errors | Run `flutter doctor -v`, install missing Android SDK components. |
| `PathAccessException` / “file is being used by another process” during build | Close other Flutter/Android Studio processes, stop any running `flutter run`, then run `flutter build apk --release` again (or `flutter clean` first if the error persists). |
| App has no data / cannot log in | Rebuild after fixing `assets/config.json`; confirm API is reachable from the phone’s network. |
