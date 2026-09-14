/**
 * تشغيل الـ API على Postgres المحلي حتى لو DATABASE_URL في .env يشير لـ Neon.
 * الاستخدام: npm run start:local
 * المتطلب: docker compose up -d postgres  (أو Postgres محلي بنفس PG*)
 */
process.env.FORCE_LOCAL_DB = '1';
require('./server.js');
