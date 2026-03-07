# بناء وتوقيع APK للإصدار (Release)

## أيقونة التطبيق
أيقونة التطبيق مُولَّدة من الشعار الموجود في `assets/images/logo.png` (Wood & More).  
لتحديث الأيقونة: استبدل الملف `assets/images/logo.png` ثم نفّذ:
```bash
dart run flutter_launcher_icons
```

## بناء APK موقّع (Windows)

1. **تعيين كلمة مرور الـ Keystore (مرة واحدة في الجلسة)**  
   **لا تخزّن كلمة المرور في الملفات أو ترفعها إلى Git.**
   ```powershell
   $env:WMM_KEYSTORE_PASSWORD = "كلمة_المرور_الخاصة_بك"
   ```

2. **تشغيل السكربت**
   ```powershell
   .\build-and-sign-apk.ps1
   ```

السكربت يقوم تلقائياً بـ:
- إنشاء ملف التوقيع `upload-keystore.jks` في `android/app/` (إذا لم يكن موجوداً)
- نسخ احتياطي من المفتاح إلى سطح المكتب
- إنشاء `android/key.properties` واستخدامه في البناء
- تنفيذ `flutter build apk --release`

الـ APK الناتج: `build\app\outputs\flutter-apk\app-release.apk`

**مهم:** احتفظ بنسخة آمنة من `upload-keystore.jks` وكلمة المرور؛ بدونها لا يمكن تحديث التطبيق على المتجر أو للمستخدمين الحاليين.
