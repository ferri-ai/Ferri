# Building for Release

> How to build signed release APKs and AABs for Ferri, and the steps to publish on Google Play.

---

## Prerequisites

- Flutter 3.22+
- Go 1.22+
- Android NDK 28.2.13676358
- A Java Development Kit (for `keytool`)

---

## 1. Generate a Signing Keystore

```bash
keytool -genkey -v \
  -keystore android/ferri-release.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias ferri
```

You'll be prompted for a keystore password and identity details.

**Important:**
- This file is already in `.gitignore` — never commit it.
- **Back up the keystore.** If lost, you cannot update the app on Play Store (unless using Play App Signing).

---

## 2. Create key.properties

Create `android/key.properties`:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=ferri
storeFile=../ferri-release.jks
```

This file is also gitignored.

---

## 3. Build the Go Engine

```bash
# For physical devices (ARM64)
NDK_HOME=$ANDROID_HOME/ndk/28.2.13676358 make build-engine-android-arm64

# For emulator (x86_64)
NDK_HOME=$ANDROID_HOME/ndk/28.2.13676358 make build-engine-android-x86
```

The engine binary lands at `android/app/src/main/jniLibs/arm64-v8a/libferri.so`.

---

## 4. Build the Release AAB

For Play Store distribution (App Bundle):

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

For direct APK install (sideloading):

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## 5. Verify the Build

```bash
# Check the AAB exists and is a reasonable size (15-40 MB with Go engine)
ls -lh build/app/outputs/bundle/release/app-release.aab

# Test-install on a physical device
adb install build/app/outputs/flutter-apk/app-release.apk
```

Always test the release build on a real device — behavior can differ from debug builds.

---

## 6. Version Bumping

In `pubspec.yaml`:

```yaml
version: 0.1.0+1
#        ^^^^^  ^ version code (increment each upload)
#        |||||
#        version name (semantic versioning)
```

Play Console rejects uploads with a previously used version code. Always increment the `+N` suffix.

---

## 7. Play Store Publishing

### Internal Testing (Quickest Path)

1. Create a [Google Play Developer account](https://play.google.com/console) ($25 one-time fee)
2. Create app: name "Ferri", category "Tools", free
3. Go to **Release > Testing > Internal testing**
4. Upload `app-release.aab`
5. Add testers by email (up to 100)
6. Share the opt-in link

Internal testing has no review process — builds are available within minutes.

### Required Metadata

| Field | Value |
|---|---|
| App name | Ferri |
| Short description | AI assistant that connects to your phone's capabilities |
| App icon | 512x512 PNG |
| Feature graphic | 1024x500 PNG |
| Category | Tools |
| Contact email | Required |

### Path to Production

1. **Internal testing** — immediate, no review
2. **Closed testing** — requires 12 opted-in testers for 14 continuous days
3. **Production** — full Google review, all policies enforced

### Policy Considerations

Before production release, review these Google Play policies:

- **SMS/Call Log permissions** — restricted to default handler apps. May need to remove from Play builds.
- **Accessibility Service** — Google prohibits autonomous AI-driven actions. May need to remove from Play builds.
- **Background Location** — requires a Permissions Declaration Form. Geofencing is a commonly approved use case.
- **Health Connect** — requires a Permissions Declaration Form.
- **AI-generated content** — requires an in-app reporting mechanism for offensive content.

See the [Play Store Release Guide](../play-store-release-guide.md) for full policy analysis.

---

## Key Paths

| Item | Path |
|---|---|
| Version config | `pubspec.yaml` |
| Android build config | `android/app/build.gradle.kts` |
| Android manifest | `android/app/src/main/AndroidManifest.xml` |
| Signing keystore | `android/ferri-release.jks` |
| Key properties | `android/key.properties` |
| Go engine output | `android/app/src/main/jniLibs/arm64-v8a/libferri.so` |
| Release AAB | `build/app/outputs/bundle/release/app-release.aab` |
| Brand colors | `lib/theme/colors.dart` |

---

**See also:** [Getting Started](Getting-Started.md), [Architecture Overview](Architecture-Overview.md)
