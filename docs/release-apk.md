# Release APK (GitHub Actions)

The workflow `.github/workflows/release-apk.yml` builds release APKs for **Wood & More**, uploads them as workflow artifacts, and attaches them to the GitHub Release **`v<version>`** (for example `v1.0.1`). The version comes from `pubspec.yaml` (`version: 1.0.1+3` → version `1.0.1`, build `3`).

The Android application id stays **`com.example.wood_and_more_app`**. Do not change it: `android/app/google-services.json` is registered to that id, and a new id would be a different app for people who already installed it.

`assets/config.json` is bundled as it is in the repository. It already points at `https://wood-more-1qtv.onrender.com/`.

## Run it

1. Push the version bump to the branch you want to build (usually `main`).
2. Open **Actions → Release APK → Run workflow**.
3. Choose the branch.
4. **Also build a universal APK** defaults to on. **Also build an x86_64 APK** defaults to off (emulators only).
5. Download the files from the run’s **Artifacts**, or from the GitHub Release `v<version>`.

A push of a tag `v*` also runs the workflow. The tag’s `X.Y.Z` must match `pubspec.yaml`. `v1.0.1` is the usual tag. `v1.0.1+3` is accepted only when `+3` matches the pubspec build number. Any other tag fails the job. Tag runs always build the universal APK.

Re-running the workflow replaces the APKs on the existing `v<version>` release.

File names:

- `wood-more-<version>-<build>-arm64-v8a.apk` — most phones
- `wood-more-<version>-<build>-armeabi-v7a.apk` — older 32-bit phones
- `wood-more-<version>-<build>-universal.apk` — one file for every ABI
- `wood-more-<version>-<build>-x86_64.apk` — only if you asked for x86_64

The workflow uses Flutter **3.44.9** (stable channel, Dart 3.12.2). That satisfies `sdk: ^3.11.0` and the lockfile (`Flutter >= 3.44`, `Dart >= 3.12`) and still builds with the current Android Gradle setup.

## Optional signing secrets

Repository **Settings → Secrets and variables → Actions**. All four must be set together. If none are set, the build still succeeds and Gradle signs with the Android debug key (`android/app/build.gradle.kts` already falls back when `android/key.properties` is absent). A later release key cannot update an install that used the debug key; people would have to uninstall first. Create the release keystore before the first APK you expect phones to keep.

| Secret | Value |
| --- | --- |
| `KEYSTORE_BASE64` | Base64 of the `.jks` / `.keystore` file, one line |
| `KEYSTORE_PASSWORD` | Store password |
| `KEY_ALIAS` | Key alias (the local script uses `upload`) |
| `KEY_PASSWORD` | Key password |

```bash
base64 -w 0 upload-keystore.jks
```

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))
```

The workflow decodes the keystore to `android/app/upload-keystore.jks` and writes `android/key.properties` (`storeFile=app/upload-keystore.jks`). Those files are gitignored. The log never prints the passwords, alias, or keystore contents.

Local signing is still `build-and-sign-apk.ps1` (see `BUILD_SIGN_README.md`). Keep a backup of the keystore and the passwords. GitHub cannot show a secret again after you save it.

---

# إصدار APK من GitHub Actions

ملف `.github/workflows/release-apk.yml` يبني نسخة Release، يرفعها في artifacts، ويرفقها بإصدار GitHub باسم **`v<version>`** (مثال `v1.0.1`). الرقم يُقرأ من `pubspec.yaml` (`version: 1.0.1+3` يعني النسخة `1.0.1` والبناء `3`).

معرّف التطبيق يبقى **`com.example.wood_and_more_app`**. لا تغيّره: ملف `android/app/google-services.json` مسجّل على هذا المعرّف، وتغييره يجعل التطبيق تطبيقًا جديدًا ويفقد المستخدم المثبّت بياناته.

ملف `assets/config.json` يُضمَّن كما هو في المستودع، وهو أصلًا يشير إلى `https://wood-more-1qtv.onrender.com/`.

## التشغيل

1. ادفع تعديل رقم النسخة على الفرع المطلوب (عادة `main`).
2. افتح **Actions → Release APK → Run workflow**.
3. اختر الفرع.
4. **Also build a universal APK** مفعّل افتراضيًا. **Also build an x86_64 APK** مطفأ افتراضيًا (للمحاكي فقط).
5. نزّل الملفات من **Artifacts** في التشغيل، أو من إصدار GitHub `v<version>`.

دفع تاج `v*` يشغّل نفس الـ workflow. جزء `X.Y.Z` في التاج لازم يطابق `pubspec.yaml`. التاج المعتاد `v1.0.1`. التاج `v1.0.1+3` مقبول فقط إذا `+3` هو رقم البناء في pubspec. غير ذلك يفشل التشغيل. تشغيل التاج يبني دائمًا ملف universal.

إعادة التشغيل تستبدل ملفات الـ APK على نفس الإصدار `v<version>`.

أسماء الملفات:

- `wood-more-<version>-<build>-arm64-v8a.apk` لمعظم الموبايلات
- `wood-more-<version>-<build>-armeabi-v7a.apk` للموبايلات الأقدم ٣٢ بت
- `wood-more-<version>-<build>-universal.apk` ملف واحد لكل المعماريات
- `wood-more-<version>-<build>-x86_64.apk` فقط إذا طلبت x86_64

البناء يستخدم Flutter **3.44.9** (قناة stable، وDart 3.12.2). هذا يحقق قيد `sdk: ^3.11.0` وقيد ملف القفل (`Flutter >= 3.44` و `Dart >= 3.12`) ويشتغل مع إعداد Gradle الحالي.

## أسرار التوقيع (اختيارية)

من **Settings → Secrets and variables → Actions**. الأربعة لازم يتحطوا مع بعض. لو ولا واحد موجود، البناء ينجح وGradle يمضي بمفتاح التجريب (debug)، لأن `android/app/build.gradle.kts` يعمل كده أصلًا لما `android/key.properties` غير موجود. مفتاح الإصدار لاحقًا لا يحدّث تطبيقًا اتثبت بمفتاح التجريب؛ لازم المستخدم يمسح التطبيق ويثبته من جديد. اعمل مفتاح الإصدار قبل أول APK الناس هتفضّل مثبّتاه.

| السر | القيمة |
| --- | --- |
| `KEYSTORE_BASE64` | ملف الـ `.jks` أو `.keystore` بعد تحويله لـ Base64 في سطر واحد |
| `KEYSTORE_PASSWORD` | كلمة سر المخزن |
| `KEY_ALIAS` | اسم المفتاح (السكربت المحلي يستخدم `upload`) |
| `KEY_PASSWORD` | كلمة سر المفتاح |

```bash
base64 -w 0 upload-keystore.jks
```

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))
```

الـ workflow يفك الملف إلى `android/app/upload-keystore.jks` ويكتب `android/key.properties` مع `storeFile=app/upload-keystore.jks`. الملفين متجاهلين في git. السجل لا يطبع كلمات السر ولا اسم المفتاح ولا محتوى الـ keystore.

التوقيع المحلي لسه عبر `build-and-sign-apk.ps1` (راجع `BUILD_SIGN_README.md`). احتفظ بنسخة من ملف المفتاح وكلمات السر. GitHub لا يعرض السر مرة ثانية بعد الحفظ.
