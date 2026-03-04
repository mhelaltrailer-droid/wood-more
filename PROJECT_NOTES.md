# WOOD AND MORE - ملاحظات المشروع (للاستكمال لاحقاً)

> **آخر تحديث:** مارس 2026  
> هذا الملف يحتوي على تفاصيل المحادثة والمشروع للاستكمال في أي وقت لاحق.

---

## نظرة عامة

نظام متكامل لإدارة شركة مقاولات صغيرة (Wood & More Interiors).  
التطبيق مبني بـ Flutter ويعمل على: **Android, iOS, Web (Chrome)**.

---

## الميزات المنفذة حالياً

### 1. تسجيل الحضور والانصراف للمهندسين
- **المهندس:** يرى أيقونة الحضور في الصفحة الرئيسية
- **شاشة التسجيل:** الاسم تلقائي من البريد، CHECK-IN/CHECK-OUT، التاريخ والوقت والموقع تلقائي، قائمة المشاريع، ملاحظات
- العودة للصفحة الرئيسية تلقائياً بعد الحفظ

### 2. تقارير الحضور لمدير المهندسين
- عرض جميع السجلات (عرض فقط - بدون تعديل)
- المدير لا يرى واجهة التسجيل، فقط التقارير

### 3. التصميم واللوجو
- شعار الشركة في `assets/images/logo.png`
- ألوان متناسقة مع اللوجو: أخضر غامق `#1B5E20`، أخضر أغمق `#0D3B0D`
- اللوجو يظهر في شاشة الدخول وفي شريط التطبيق

---

## الميزات المخططة (قادم)

1. **التقارير اليومية** من مهندسين المواقع
2. **التقارير المالية:** العهد، الصرف، التصفية
3. **المخازن وأرصدة المواقع**
4. **المشاريع وتفاصيلها:** مناطق، مباني، وحدات، نماذج، تشوينات، قطعيات
5. **Documentation:** مخزن ملفات المشاريع

---

## المستخدمون (12 مستخدماً)

| الاسم | البريد | الدور |
|------|--------|-------|
| Hany | hany.samir1708@gmail.com | مهندس موقع |
| Emam | amirelazab46@gmail.com | مهندس موقع |
| Mansur | saedm0566@gmail.com | مهندس موقع |
| Mahmud | mahmoudsiko630@gmail.com | مهندس موقع |
| Abdhusseny | abdallaelhosseny1011@gmail.com | مهندس موقع |
| Hamza | hamzamhamad704@gmail.com | مهندس موقع |
| Gohary | mohamedelgohary371@gmail.com | مهندس موقع |
| Amr | amrelshabrawy55@gmail.com | مهندس موقع |
| Hassan | mouhammed.helal@gmail.com | مهندس موقع |
| Helal | mouhamedhelal.cor@gmail.com | مدير مهندسين |
| Shams | islam.shams2050@gmail.com | مدير مهندسين |
| Abdrhman | AbdelrhmanEllaithy828@gmail.com | مدير مهندسين |

---

## المشاريع (27 مشروعاً)

UTC_Z5_CRC_F, Mivida 31_CRC_F, UTC_Z5_EMAAR Building C_F, Zed east_ORASCOM_F, Belle Vie_El-Hazek_F, CAIRO GATE elain (02)_CRC_F, Cairo gate_ACC_W, Z1_EMAAR_F, Community Center_CRC_W, Terrace Zayed_CRC_W, Silver Sands_REDCON_D, CAR SHADE_W&M_W, OLD CITY_ORASCOM_W, Cairo gate-Eden_ATRUM_F, AUC Campus Expansion_Orascom_W&F, UTC - 2 Villa- Link International_W, UTC - 2 Villa- Link International_F, City Gate_CCC_W, cairo gate - locanda_INOVOO_F, Village West _ club_FIT-OUT_W, Village West _Villa_W, Mivida gardens_Atrium_F, Village West_CRC_ F, Up Town Cairo _Z5 _EMAAR_W, Belle Vie _ EMAAR_W, Village West _ CRC_ W, Wood&More(head office)

---

## هيكل المشروع

```
lib/
├── main.dart
├── core/
│   └── app_theme.dart          # الثيم والألوان
├── models/
│   ├── user_model.dart
│   ├── project_model.dart
│   └── attendance_record_model.dart
├── screens/
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── attendance_screen.dart
│   └── attendance_reports_screen.dart
└── services/
    ├── storage_service.dart   # يختار ويب أو موبايل
    ├── database_service.dart  # SQLite للموبايل
    ├── web_storage_service.dart  # SharedPreferences للويب
    └── location_service.dart

assets/
└── images/
    └── logo.png               # شعار الشركة
```

---

## التخزين (قاعدة البيانات)

- **الموبايل (Android/iOS):** SQLite عبر `database_service.dart`
- **الويب (Chrome):** SharedPreferences عبر `web_storage_service.dart`
- يتم الاختيار تلقائياً حسب المنصة في `storage_service.dart`

---

## تشغيل التطبيق

```bash
cd D:\Helal\FlutterProjects\wood_and_more_app
flutter pub get
flutter run -d chrome
# أو
flutter run -d web-server --web-port=8081
# ثم افتح: http://localhost:8081
```

**بناء APK للأندرويد:**
```bash
flutter build apk --release
# الملف: build\app\outputs\flutter-apk\app-release.apk
```

---

## تعديل البيانات

- **المستخدمون:** `lib/services/database_service.dart` (دالة `_seedData`) و `lib/services/web_storage_service.dart` (دالة `_initData`)
- **المشاريع:** `lib/services/database_service.dart` (دالة `_seedProjects`) و `lib/services/web_storage_service.dart` (دالة `_initData`)

---

## ملاحظات تقنية

- للموبايل: تفعيل أذونات الموقع (AndroidManifest, Info.plist)
- للويب: مسح Local Storage إذا لم تظهر البيانات الجديدة
- المنفذ 8080 قد يكون مستخدماً؛ استخدم 8081 أو غيره

---

## للاستكمال

عند العودة للمشروع، راجع هذا الملف وقل: "أريد استكمال مشروع WOOD AND MORE" مع تحديد الميزة التالية المطلوبة.
