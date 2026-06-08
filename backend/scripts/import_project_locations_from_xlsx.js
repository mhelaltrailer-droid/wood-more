/**
 * استيراد هيكلة المواقع من Excel إلى SQL أو مباشرة إلى PostgreSQL (Neon).
 *
 * تنسيق الورقة (مثل DDD.xlsx):
 *   العمود B = موقع فرعي (folder)، العمود C = موقع عمل (work_site)
 *   إذا B فارغ يُعتمد آخر موقع فرعي غير فارغ.
 *
 * الاستخدام:
 *   cd backend && npm install
 *
 *   توليد ملف SQL فقط:
 *     node scripts/import_project_locations_from_xlsx.js ^
 *       --file="C:\path\DDD.xlsx" --sheet="Z1_EMAAR_F" --project="Z1_EMAAR_F" --out="scripts/out.sql"
 *
 *   تنفيذ على Neon (يتطلب DATABASE_URL في backend/.env):
 *     node scripts/import_project_locations_from_xlsx.js ^
 *       --file="..." --sheet="Z1_EMAAR_F" --project="Z1_EMAAR_F" --execute
 *
 * --execute يضمن إنشاء المشروع في projects إن لم يكن موجوداً (اسم مطابق لـ --project).
 */
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');
const { Pool } = require('pg');
const {
  parseRowsToStructure,
  buildLocationsSeedSql,
  splitSqlChunks,
} = require('./lib/xlsx_project_locations');

function parseArgs() {
  const a = process.argv.slice(2);
  const get = (key) => {
    const pref = `--${key}=`;
    const exact = `--${key}`;
    for (let i = 0; i < a.length; i++) {
      if (a[i].startsWith(pref)) return a[i].slice(pref.length);
      if (a[i] === exact && a[i + 1] != null) return a[i + 1];
    }
    return null;
  };
  return {
    file: get('file'),
    sheet: get('sheet'),
    project: get('project'),
    out: get('out'),
    execute: a.includes('--execute'),
    help: a.includes('--help') || a.includes('-h'),
  };
}

function createPool() {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl || !String(databaseUrl).trim()) {
    throw new Error('DATABASE_URL غير مضبوط (في backend/.env)');
  }
  return new Pool({
    connectionString: databaseUrl,
    ssl:
      databaseUrl.includes('sslmode=require') || databaseUrl.includes('neon.tech')
        ? { rejectUnauthorized: false }
        : false,
  });
}

async function ensureProject(pool, projectName) {
  await pool.query(
    `INSERT INTO projects (name)
     SELECT $1::text
     WHERE NOT EXISTS (SELECT 1 FROM projects WHERE name = $1)`,
    [projectName],
  );
}

async function runChunks(pool, sqlText) {
  const chunks = splitSqlChunks(sqlText);
  let ran = 0;
  for (const chunk of chunks) {
    const s = chunk.trim();
    if (!s.startsWith('INSERT INTO')) continue;
    await pool.query(s);
    ran += 1;
  }
  return ran;
}

function main() {
  const args = parseArgs();
  if (args.help) {
    console.log(fs.readFileSync(__filename, 'utf8').split('/**')[1].split('*/')[1]);
    process.exit(0);
  }
  if (!args.file || !args.sheet || !args.project) {
    console.error('مطلوب: --file=... --sheet=... --project=...  (اختياري: --out=... أو --execute)');
    process.exit(1);
  }
  const xlsxPath = path.resolve(args.file);
  if (!fs.existsSync(xlsxPath)) {
    console.error('الملف غير موجود:', xlsxPath);
    process.exit(1);
  }

  const wb = XLSX.readFile(xlsxPath);
  const sh = wb.Sheets[args.sheet];
  if (!sh) {
    console.error(
      'الورقة غير موجودة:',
      args.sheet,
      '| المتاح:',
      wb.SheetNames.join(', '),
    );
    process.exit(1);
  }

  const rows = XLSX.utils.sheet_to_json(sh, { header: 1, defval: '' });
  const parsed = parseRowsToStructure(rows);
  const sql = buildLocationsSeedSql(args.project, parsed);

  console.log(
    `المشروع: ${args.project} | مواقع فرعية: ${parsed.folderNames.length} | مواقع عمل: ${parsed.pairs.length}`,
  );

  if (args.out) {
    const outPath = path.resolve(path.join(__dirname, '..'), args.out);
    fs.mkdirSync(path.dirname(outPath), { recursive: true });
    fs.writeFileSync(outPath, sql, 'utf8');
    console.log('تم حفظ SQL:', outPath);
  }

  if (args.execute) {
    return (async () => {
      const pool = createPool();
      try {
        await ensureProject(pool, args.project);
        const ran = await runChunks(pool, sql);
        console.log(`تم التنفيذ على قاعدة البيانات: ${ran} جزء INSERT.`);
        const { rows: c } = await pool.query(
          `SELECT COUNT(*)::int AS c FROM project_locations pl
           INNER JOIN projects p ON p.id = pl.project_id
           WHERE p.name = $1`,
          [args.project],
        );
        console.log(`إجمالي صفوف project_locations للمشروع: ${c[0].c}`);
      } finally {
        await pool.end();
      }
    })();
  }
  if (!args.out && !args.execute) {
    console.log(
      '\nلم يُضبط --out ولا --execute. أضف --out=scripts/my.sql لحفظ الملف أو --execute للتنفيذ على Neon.\n',
    );
  }
  return Promise.resolve();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
