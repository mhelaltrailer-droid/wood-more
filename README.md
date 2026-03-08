# Wood & More — Run with PostgreSQL on Windows

This guide explains how to run the **Wood & More** Flutter application with **PostgreSQL** on Windows.

---

## Prerequisites

Install the following on your Windows machine:

| Requirement | Purpose |
|------------|---------|
| **PostgreSQL** | Database (e.g. [PostgreSQL for Windows](https://www.postgresql.org/download/windows/)) |
| **Node.js** (LTS) | Backend REST API ([nodejs.org](https://nodejs.org/)) |
| **Flutter SDK** | Flutter app ([Install Flutter](https://docs.flutter.dev/get-started/install)) |

Ensure `node`, `npm`, and `flutter` are on your PATH. In **Command Prompt** or **PowerShell**:

```cmd
node -v
npm -v
flutter doctor
```

Fix any issues reported by `flutter doctor` (e.g. Chrome, Android SDK) before continuing.

---

## 1. Set up PostgreSQL

### 1.1 Install PostgreSQL

- Download the installer from [postgresql.org/download/windows](https://www.postgresql.org/download/windows/).
- Run the installer. Remember the password you set for the `postgres` superuser.
- Keep the default port **5432** unless you need another.

### 1.2 Default database (postgres)

The API uses the **default PostgreSQL database**: database **`postgres`**, user **`postgres`**, password **`password`**. Ensure the `postgres` user has password `password` (e.g. in pgAdmin: Login/Group Roles → postgres → Definition → Password).

### 1.3 Load schema and seed data

Run the init script in the **postgres** database. From the project root:

```cmd
"C:\Program Files\PostgreSQL\16\bin\psql" -U postgres -d postgres -f backend\init-db.sql
```

Enter password `password` when prompted. Or in pgAdmin: connect to database **postgres** as **postgres**, open Query Tool, paste the contents of `backend\init-db.sql`, and execute.

---

## 2. Run the backend API

Open a terminal in the project root and install dependencies, then start the API.

**Command Prompt:**

```cmd
cd backend
npm install
node server.js
```

(Defaults: database **postgres**, user **postgres**, password **password**. Override with `set PGDATABASE=...` etc. if needed.)

**PowerShell:**

```powershell
cd backend
npm install
node server.js
```

Leave this window open. The API will be available at **http://localhost:3000**.

---

## 3. Point the app to the API

The app uses the backend when **`apiBaseUrl`** is set in config:

- **Web** (`flutter run -d chrome`): **`web\config.json`**
- **Windows desktop** (`flutter run -d windows`): **`assets\config.json`**

Set the API URL in both so that web and desktop use PostgreSQL:

```json
{ "apiBaseUrl": "http://localhost:3000" }
```

If you use another port for the API, use that URL (e.g. `http://localhost:3001`). If `apiBaseUrl` is empty, the app uses browser storage (web) or local SQLite (desktop) and data is not stored in PostgreSQL.

---

## 4. Run the Flutter app

Open a **new** Command Prompt or PowerShell in the project root:

```cmd
cd C:\path\to\wood-more
flutter pub get
flutter run -d chrome
```

Or to run the **Windows desktop** app:

```cmd
flutter run -d windows
```

The app will use the API (and PostgreSQL) when `apiBaseUrl` is set in the relevant config file.

**Mobile / desktop with API:** Set `assets\config.json` to `{ "apiBaseUrl": "http://localhost:3000" }` (or your machine IP for a real device). To use config:
   - **Web:** set `web/config.json`: `{ "apiBaseUrl": "http://localhost:3000" }` (or your API URL).
   - **Mobile / desktop:** set `assets/config.json`: `{ "apiBaseUrl": "http://YOUR_API_URL" }`.
     - Android emulator: use `http://10.0.2.2:3000` (emulator’s host = your machine).
     - Real device or other desktop: use your machine’s IP, e.g. `http://192.168.1.10:3000`, and ensure the device can reach that IP (same network, firewall allows port 3000).
3. Run the app (`flutter run` or `flutter run -d chrome`). On startup the app loads config; if `apiBaseUrl` is set, it uses the backend and **all create/update/delete and reports go to PostgreSQL**. If `apiBaseUrl` is empty, web uses browser storage and mobile/desktop use local SQLite (data not in the central database).

**Summary:** Nothing is removed from the old build. When `apiBaseUrl` is set (web: `web/config.json`, mobile/desktop: `assets/config.json`), the app uses the REST API and everything is stored in the database. When it is not set, the app keeps using local storage (SQLite or browser) so data does not persist to PostgreSQL.

---

## 5. Log in

Login is **email + password**. Use one of the seeded users from `backend\init-db.sql`:

| Role           | Example email                    | Password   |
|----------------|----------------------------------|------------|
| Site engineer  | `test-site-engineer@example.com` | `0000`     |
| App admin      | `cipherpath@proton.me`           | `0000`     |
| App admin      | `h@h.com`                        | `123`      |

Default password for other seeded users is **`0000`** unless set otherwise in the database.

---

## Optional: Run everything with Docker (Windows)

If you have **Docker Desktop** for Windows installed, you can run PostgreSQL, the API, and the web app in one go:

```cmd
docker compose up -d --build
```

Then open **http://localhost:8080** in your browser. The app is configured to use the API (and PostgreSQL). Log in with email + password (e.g. `cipherpath@proton.me` / `0000`).

**Backend:** On startup the API runs a small migration that adds the `password` column to `users` if it was missing (e.g. an existing Docker DB created before that column existed). No manual SQL or volume reset needed.

**If you don't see your latest code changes** (e.g. new login screen, new features), Docker may be using a cached image. Rebuild the app image without cache:

```cmd
docker compose build --no-cache app
docker compose up -d
```

To stop:

```cmd
docker compose down
```

---

## Troubleshooting

| Problem | What to check |
|--------|----------------|
| `psql` not found | Add PostgreSQL `bin` to PATH, e.g. `C:\Program Files\PostgreSQL\16\bin` |
| Connection refused (port 5432) | PostgreSQL service is running (Services → postgresql-x64-16) |
| Connection refused (port 3000) | Backend is running (step 2) and no firewall is blocking 3000 |
| **Reports/data missing after closing and reopening the app** | The app only uses PostgreSQL when `apiBaseUrl` is set. Set it in **`web\config.json`** (for web) and **`assets\config.json`** (for Windows desktop) to `"http://localhost:3000"`, and ensure the backend is running before starting the app. |
| App uses browser/SQLite instead of API | Ensure `web\config.json` and `assets\config.json` have `"apiBaseUrl": "http://localhost:3000"` (not empty), then restart the app. |
| **Built app (Docker) doesn't show latest features** | The container uses a built image. After code changes, rebuild without cache: `docker compose build --no-cache app` then `docker compose up -d`. |
| **"column password does not exist" when logging in (Docker)** | The API adds the column automatically on startup. Rebuild and restart the API: `docker compose build api && docker compose up -d`. If it still fails, reset the DB (you lose data): `docker compose down -v` then `docker compose up -d`. |

---

## Summary

1. Install PostgreSQL, Node.js, and Flutter.
2. Ensure PostgreSQL user **postgres** has password **password**, then run **`backend\init-db.sql`** in the **postgres** database.
3. In `backend`, run `npm install` and `node server.js` (API uses database postgres, user postgres, password password by default).
4. Set **`web\config.json`** and **`assets\config.json`** to `{"apiBaseUrl": "http://localhost:3000"}` so the app uses the API.
5. From the project root, run `flutter run -d chrome` or `flutter run -d windows`.
6. Log in with **email + password** (default `0000`; `h@h.com` uses `123`).

Data is stored in PostgreSQL. The backend adds the `users.password` column on startup if it was missing (e.g. existing Docker volume).
