# استيراد هيكلة المشاريع من Excel (كميات كبيرة)

## ماذا يفعل؟

يحوّل ملف Excel بنفس أسلوب `DDD.xlsx` إلى جمل SQL (أو تنفيذ مباشر على Neon):

- **الع عمود B** في الورقة = **موقع فرعي** (`type = folder`)
- **العمود C** = **موقع عمل** (`type = work_site`)
- إذا كان **B** فارغاً، يُعتمد **آخر موقع فرعي** ظهر فوقه (مثل الملف الأصلي).

## المتطلبات

```bash
cd backend
npm install
```

ضع **`DATABASE_URL`** في **`backend/.env`** عند استخدام **`--execute`** (انسخه من **Render** ليكون **نفس** قاعدة Neon التي يستخدمها التطبيق).

## أمثلة

### 1) توليد ملف SQL فقط (للصق في Neon SQL Editor)

```bash
node scripts/import_project_locations_from_xlsx.js ^
  --file="C:\Users\home\Downloads\DDD.xlsx" ^
  --sheet="Z1_EMAAR_F" ^
  --project="Z1_EMAAR_F" ^
  --out="scripts/out_z1.sql"
```

### 2) تنفيذ مباشر على Neon (بعد ضبط `DATABASE_URL`)

```bash
node scripts/import_project_locations_from_xlsx.js ^
  --file="C:\Users\home\Downloads\DDD.xlsx" ^
  --sheet="Z1_EMAAR_F" ^
  --project="Z1_EMAAR_F" ^
  --execute
```

`--execute` ينشئ صف المشروع في **`projects`** إن لم يكن موجوداً، ثم يُدرج **`project_locations`**.

### 3) ورقة أخرى (مثلاً `44-ZED EAST`)

يجب أن يطابق **`--project`** الاسم **بالضبط** كما في جدول `projects` في التطبيق:

```bash
node scripts/import_project_locations_from_xlsx.js ^
  --file="..." ^
  --sheet="44-ZED EAST" ^
  --project="اسم_المشروع_كما_في_التطبيق" ^
  --execute
```

## ملفات ذات صلة

| الملف | الوظيفة |
|--------|---------|
| `scripts/lib/xlsx_project_locations.js` | المنطق المشترك (تحليل + SQL) |
| `scripts/import_project_locations_from_xlsx.js` | أداة عامة من أي ورقة/مشروع |
| `scripts/generate_z1_emaar_locations_sql.js` | توليد `seed_z1_emaar_f_project_locations.sql` فقط |
| `scripts/run_z1_emaar_seed_neon.js` | تنفيذ ملف الـ seed الجاهز لـ Z1 |
| `scripts/seed_z1_emaar_f_project_locations.sql` | SQL جاهز لمشروع Z1 |

## ظهور البيانات في الهاتف

لا حاجة لبناء APK جديد إذا لم تغيّر `apiBaseUrl`. تأكد أن **نفس** `DATABASE_URL` على Render هو الذي نفّذت عليه `--execute` أو لصق SQL.
