# Publish Android App to Google Play

## Goal

Get your Android app on Google Play now.  
Later, you can make the iOS version separately.

This folder is a **Flutter** app (Android + web). For Play you ship an Android build; from the project root you typically use `flutter build appbundle` once signing is set up in `android/`.

---

## 1) Make sure you have the Android app ready

You need:

- Android project working
- release version ready
- package name decided
- app icon
- app name
- screenshots
- privacy policy link if needed

Google Play now mainly expects you to upload an **Android App Bundle (.aab)** for new apps, not just an APK. See [Android App Bundle](https://developer.android.com/guide/app-bundle).

---

## 2) Create a Google Play developer account

- Go to **Google Play Console**
- Sign up with your Google account
- Pay the registration fee
- Finish account verification
- Accept the Developer Distribution Agreement

You need a Play Console developer account before publishing apps. [Register for Google Play Console](https://play.google.com/console/signup).

---

## 3) Create the app in Play Console

In Play Console:

- Click **Create app**
- Enter app name
- Choose default language
- Select whether it is an app or game
- Choose free or paid
- Complete the required declarations

This is the first app setup step inside Play Console. [Create and set up your app](https://support.google.com/googleplay/android-developer/answer/9859152).

---

## 4) Prepare the release build

**Flutter (this project):** from the project root, run `flutter build appbundle` after you configure release signing (key + `android` Gradle settings). You can also open the `android` folder in Android Studio if you prefer that workflow.

**Android Studio (generic):**

- open the Android project
- make sure version name/version code are correct
- build a **signed release**
- generate a **signed .aab**

Basic path in Android Studio:

- **Build**
- **Generate Signed Bundle / APK**
- choose **Android App Bundle**

For release publishing, you build a signed release version, then upload it to Play Console. [Build your app for release](https://developer.android.com/build/build-for-release).

---

## 5) Use Play App Signing

When uploading a new app:

- enroll in **Play App Signing**
- keep your upload key safe
- use that upload key to sign future uploads

Play App Signing is the required way for new apps uploaded to Google Play. [Use Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756).

---

## 6) Fill the store listing

Add:

- app title
- short description
- full description
- app icon
- feature graphic
- phone screenshots
- tablet screenshots if needed

You must complete the store listing before publishing. [Add preview assets (screenshots, graphics)](https://support.google.com/googleplay/android-developer/answer/9866151).

---

## 7) Complete App content / policy forms

Inside Play Console, complete the required sections such as:

- privacy policy
- app access
- ads declaration
- target audience
- content rating
- data safety

Google requires app content and review-related information before rollout. [App content and policy declarations](https://support.google.com/googleplay/android-developer/answer/10787469).

---

## 8) Set pricing and countries

Choose:

- free or paid
- countries/regions where the app will be available

Pricing setup is required before release. [Set pricing and distribution](https://support.google.com/googleplay/android-developer/answer/6334373).

---

## 9) Upload the app bundle

In Play Console:

- go to **Testing** or **Production**
- create a new release
- upload the **.aab** file
- add release notes
- save

Google Play uses the uploaded app bundle to generate optimized APKs for devices. [Prepare and roll out a release](https://support.google.com/googleplay/android-developer/answer/7159011).

---

## 10) Test first before full release

Best simple order:

- use **Internal testing** first
- install and test on real devices
- fix issues
- then move to production

Play Console supports internal and other testing tracks before production release. [Set up testing tracks](https://support.google.com/googleplay/android-developer/answer/9845334).

---

## 11) Review errors and warnings

Before publishing:

- open the release page
- check **Errors summary**
- fix all required errors
- warnings can sometimes still allow publish, but better fix them too

Google Play blocks publishing if required errors are unresolved. Fix issues from the **Errors summary** on the release page; see [Prepare and roll out a release](https://support.google.com/googleplay/android-developer/answer/7159011).

---

## 12) Send for review / publish

When everything is ready:

- start rollout
- send changes for review if requested
- after approval, release to production

For a first production release, starting rollout publishes the app to Google Play users in your selected countries once requirements are satisfied. [Publish your app](https://support.google.com/googleplay/android-developer/answer/9859751).

---

## 13) Update the app later

For every new update:

- increase the **version code**
- build a new signed **.aab**
- upload it as a new release
- roll it out again

Google Play requires a higher version code for app updates. [Version your app](https://developer.android.com/studio/publish/versioning).

---

## 14) Very simple real flow

1. Finish Android app
2. Create Play Console account
3. Create app in Play Console
4. Build signed **.aab**
5. Fill store listing
6. Complete policy/content forms
7. Set pricing and countries
8. Upload **.aab**
9. Test internally
10. Fix issues
11. Roll out to production

---

## 15) What you should do right now

1. Convert/build your Android app as **AAB**
2. Create Play Console account
3. Create the app entry
4. Prepare screenshots + description
5. Upload to **Internal testing**
6. Test on your phone
7. Publish to production after testing

---

## 16) Important note

For Android publishing, focus on:

- Android app working correctly
- signed **AAB**
- Play Console setup
- policy/store listing completed

iOS is separate later through the Apple App Store.
