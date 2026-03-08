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

### 1.2 Create database and user

Open **Command Prompt** or **PowerShell** and run (adjust the path if your PostgreSQL `bin` is elsewhere):

```cmd
"C:\Program Files\PostgreSQL\16\bin\psql" -U postgres
```

(Use your PostgreSQL version number if different, e.g. `15` instead of `16`.)

In the `psql` prompt, run:

```sql
CREATE USER wood_more WITH PASSWORD 'wood_more';
CREATE DATABASE wood_more OWNER wood_more;
\q
```

**Alternative:** Use **pgAdmin** (installed with PostgreSQL): create a new login/role `wood_more` with password `wood_more`, then create a database `wood_more` owned by `wood_more`.

### 1.3 Load schema and seed data

From the project root (the `wood-more` folder), run:

```cmd
"C:\Program Files\PostgreSQL\16\bin\psql" -U wood_more -d wood_more -f backend\init-db.sql
```

Enter password `wood_more` when prompted. Or in pgAdmin: open a Query Tool, paste the contents of `backend\init-db.sql`, and execute.

---

## 2. Run the backend API

Open a terminal in the project root and install dependencies, then start the API.

**Command Prompt:**

```cmd
cd backend
npm install
set PGHOST=localhost
set PGPORT=5432
set PGDATABASE=wood_more
set PGUSER=wood_more
set PGPASSWORD=wood_more
set PORT=3000
node server.js
```

**PowerShell:**

```powershell
cd backend
npm install
$env:PGHOST="localhost"; $env:PGPORT="5432"; $env:PGDATABASE="wood_more"; $env:PGUSER="wood_more"; $env:PGPASSWORD="wood_more"; $env:PORT="3000"; node server.js
```

Leave this window open. The API will be available at **http://localhost:3000**.

---

## 3. Point the app to the API

Edit **`web\config.json`** in the project root so the app uses your local backend:

```json
{ "apiBaseUrl": "http://localhost:3000" }
```

If you use another port for the API, change the URL (e.g. `http://localhost:3001`).

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

The app will load `web\config.json`, use the API, and store data in PostgreSQL.

---

## 5. Log in

Login is **email only** (no password). Use one of the seeded users, for example:

| Role           | Example email                    |
|----------------|----------------------------------|
| Site engineer  | `test-site-engineer@example.com` |
| App admin      | `cipherpath@proton.me`           |

Other seeded users are defined in `backend\init-db.sql`.

---

## Optional: Run everything with Docker (Windows)

If you have **Docker Desktop** for Windows installed, you can run PostgreSQL, the API, and the web app in one go:

```cmd
docker compose up -d --build
```

Then open **http://localhost:8080** in your browser. The app in the container is already configured to use the API and PostgreSQL. To stop:

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
| App uses browser storage instead of API | Ensure `web\config.json` has `"apiBaseUrl": "http://localhost:3000"` and you restarted the app after changing it |

---

## Summary

1. Install PostgreSQL, Node.js, and Flutter.
2. Create user `wood_more` and database `wood_more`, then run `backend\init-db.sql`.
3. In `backend`, run `npm install` and start the server with the env vars above.
4. Set `web\config.json` to `{"apiBaseUrl": "http://localhost:3000"}`.
5. From the project root, run `flutter run -d chrome` or `flutter run -d windows`.

Data is then stored in your local PostgreSQL instance.
