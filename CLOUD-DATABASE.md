# Wood & More — Using a Free Cloud PostgreSQL Database

This guide explains how to run Wood & More with a **free cloud PostgreSQL** database instead of a local or Docker Postgres. You keep using the same Node.js backend and Flutter app; only the database runs in the cloud.

---

## Why not Firebase?

**Firebase** does not provide PostgreSQL. It offers Firestore (NoSQL), Realtime Database, and other services. To use Firebase you would have to change the backend and data model. For Wood & More we stay with **PostgreSQL** and use a cloud Postgres host.

---

## Recommended: Neon (free Postgres)

**Neon** ( [neon.tech](https://neon.tech) ) offers a **free tier** that is not a time-limited trial:

- Free forever on the free plan
- **0.5 GB** storage per project (enough for users, projects, reports, attendance)
- Serverless Postgres (scales with use)
- Connection string works with the existing backend

### 1. Sign up and create a project

1. Go to [neon.tech](https://neon.tech) and sign up (GitHub or email).
2. Create a **new project** (e.g. name: `wood-more`).
3. Choose a region close to you.
4. Note the **password** shown for the default user (you won’t see it again; reset in the dashboard if needed).

### 2. Get the connection string

1. In the Neon dashboard, open your project.
2. Click **Connect** (or go to the Connection details).
3. Select **Node.js** and copy the connection string. It looks like:
   ```text
   postgresql://USER:PASSWORD@ep-xxx-xxx.region.aws.neon.tech/neondb?sslmode=require
   ```
4. Optional: create a database named `wood_more` in the Neon SQL Editor and use that name in the URL instead of `neondb` if you prefer.

### 3. Load the schema and seed data

You need to run `backend/init-db.sql` on the Neon database **once**:

**Option A — Neon SQL Editor (easiest)**

1. In the Neon dashboard, open **SQL Editor**.
2. Copy the full contents of `backend/init-db.sql` from this project.
3. Paste into the editor and run it.

**Option B — psql**

1. Install `psql` if you don’t have it.
2. Run (replace with your actual connection string):
   ```bash
   psql "postgresql://USER:PASSWORD@ep-xxx-xxx.region.aws.neon.tech/neondb?sslmode=require" -f backend/init-db.sql
   ```

### 4. Run the backend with the cloud database

Set `DATABASE_URL` to the Neon connection string and start the API:

**Linux / macOS (terminal):**

```bash
cd backend
npm install
export DATABASE_URL="postgresql://USER:PASSWORD@ep-xxx-xxx.region.aws.neon.tech/neondb?sslmode=require"
node server.js
```

**Windows (Command Prompt):**

```cmd
cd backend
npm install
set DATABASE_URL=postgresql://USER:PASSWORD@ep-xxx-xxx.region.aws.neon.tech/neondb?sslmode=require
node server.js
```

**Windows (PowerShell):**

```powershell
cd backend
npm install
$env:DATABASE_URL="postgresql://USER:PASSWORD@ep-xxx-xxx.region.aws.neon.tech/neondb?sslmode=require"
node server.js
```

Use your **real** connection string from the Neon dashboard. The backend reads `DATABASE_URL` and connects with SSL; no need to set `PGHOST`, `PGUSER`, etc. when using it.

### 5. Point the app at the API

- If the API runs on your machine: set `apiBaseUrl` in `web/config.json` and `assets/config.json` to `http://localhost:3000` (or the URL where the backend is reachable).
- If the API is deployed somewhere: use that URL as `apiBaseUrl`.

Then run the Flutter app as usual; it will use the API, which now uses Neon Postgres.

---

## Alternative: Supabase (free Postgres)

**Supabase** ( [supabase.com](https://supabase.com) ) also has a **free tier** with PostgreSQL:

- Free tier with **500 MB** database
- PostgreSQL plus optional auth, storage, and APIs
- For Wood & More you only need the Postgres connection.

### 1. Create a project

1. Sign up at [supabase.com](https://supabase.com).
2. Create a new project (name, database password, region).
3. Wait for the project to be ready.

### 2. Get the connection string

1. In the Supabase dashboard go to **Settings** → **Database**.
2. Under **Connection string** choose **URI** and copy it. It looks like:
   ```text
   postgresql://postgres.[PROJECT-REF]:[YOUR-PASSWORD]@aws-0-REGION.pooler.supabase.com:6543/postgres
   ```
3. For a **direct** connection (e.g. running migrations with psql), use the **Direct connection** string (port 5432) if shown.

### 3. Load the schema and seed data

- Use the **SQL Editor** in the Supabase dashboard: paste the contents of `backend/init-db.sql` and run.
- Or use `psql` with the connection string and `-f backend/init-db.sql`.

### 4. Run the backend

Same as for Neon: set `DATABASE_URL` to the Supabase connection string and start the backend:

```bash
export DATABASE_URL="postgresql://postgres.[REF]:[PASSWORD]@aws-0-REGION.pooler.supabase.com:6543/postgres"
node server.js
```

Use the **Transaction** or **Session** pooler URI from the Supabase dashboard if you run in serverless or need pooling.

---

## Summary

| Service   | Free tier        | Best for                    |
|----------|------------------|-----------------------------|
| **Neon** | 0.5 GB, free     | Simple Postgres, low usage  |
| **Supabase** | 500 MB, free | Postgres + optional extras  |

- **Firebase** is not Postgres; it would require changing the app and backend.
- Use **Neon** or **Supabase** as a free, persistent Postgres in the cloud.
- Backend supports **`DATABASE_URL`**: set it to the connection string from Neon or Supabase and run `node server.js`. No need to set `PGHOST` / `PGUSER` / etc. when `DATABASE_URL` is set.
- Run **`backend/init-db.sql`** once on the cloud database (SQL Editor or psql), then use the app as usual with the API pointing at this backend.
