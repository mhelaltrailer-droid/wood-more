# Wood & More

A Flutter application for construction/site management: attendance, daily reports, projects, zones, buildings, materials, finance, and admin. The app is **Arabic-first** (RTL). It can run with **local storage** (SQLite on mobile/desktop, browser storage on web) or with a **PostgreSQL backend** (REST API) when using Docker Compose.

---

## Features

- **Authentication**  Login by email (no password; users are pre-seeded).
- **Roles**  Site engineer, site engineer manager, app admin.
- **Attendance**  Check-in/check-out with optional location and project.
- **Daily reports**  Multi-step reports with work place, report text, materials, expenses, documents, and images.
- **Projects & structure**  Projects ? Zones ? Buildings ? Units; project stores (materials stock); building materials and cutlists.
- **Admin**  Users, projects, zones, buildings, supervisors, contractors, materials, cutlists, project stores.
- **Finance**  Engineer balances, custody (contract), salary deductions.
- **Reports**  Attendance and daily report filters and exports (e.g. PDF).
- **Localization**  Arabic (default) and English.

---

## Prerequisites

- **Flutter SDK**  [Install Flutter](https://docs.flutter.dev/get-started/install) and ensure `flutter` is on your `PATH`.
- **Supported platforms** (pick one to run locally):
  - **Mobile:** Android device/emulator or iOS device/simulator
  - **Desktop:** macOS, Windows, or Linux
  - **Web:** Chrome (or any modern browser)

Check your setup:

```bash
flutter doctor
```

Resolve any reported issues (e.g. Android SDK, Xcode, Chrome) before continuing.

---

## Step-by-step: Run the app locally

### 1. Open the project

```bash
cd /path/to/wood-more
```

(Use the actual path to the `wood-more` folder on your machine.)

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Choose a device

- **Android:** Start an emulator or connect a device with USB debugging.
- **iOS:** Open Simulator or connect an iPhone (macOS only).
- **macOS/Windows/Linux:** Use the host machine as the target.
- **Web:** Use Chrome.

List available devices:

```bash
flutter devices
```

### 4. Run the app

**Mobile (Android / iOS):**

```bash
flutter run
```

Or specify a device, for example:

```bash
flutter run -d chrome          # Web
flutter run -d macos          # macOS
flutter run -d windows        # Windows
flutter run -d linux          # Linux
flutter run -d <device_id>    # Use ID from `flutter devices`
```

The app will build and launch. The first screen is the **login screen**.

### 5. Log in (test users)

Login is by **email only** (no password). Use one of the seeded emails:

| Role                  | Example email                    |
| --------------------- | -------------------------------- |
| Site engineer         | `hany.samir1708@gmail.com`       |
| Site engineer         | `mouhammed.helal@gmail.com`      |
| Site engineer         | `test-site-engineer@example.com` |
| Site engineer manager | `mouhamedhelal.cor@gmail.com`    |
| App admin             | `mouhammedhelal@gmail.com`       |
| App admin             | `cipherpath@proton.me`           |

Any other seeded user from the database (see `lib/services/database_service.dart` or `lib/services/web_storage_service.dart`) will also work.

### 6. Optional: Create assets (if missing)

The app expects `assets/images/` and uses `assets/images/logo.png` in the app bar. If you removed them and see asset errors, ensure the folder exists and add a `logo.png`:

```bash
mkdir -p assets/images
# Then add your logo.png into assets/images/
```

Then run `flutter pub get` again and restart the app.

---

## Use local PostgreSQL with Flutter run (web)

To run the app locally with **`flutter run -d chrome`** (or another browser) and have it use your **local PostgreSQL** instead of browser storage:

### 1. Set up your local PostgreSQL

Create the database and user (if you don't have them yet). For example, in `psql` or Beekeeper:

```sql
CREATE USER wood_more WITH PASSWORD 'wood_more';
CREATE DATABASE wood_more OWNER wood_more;
```

Then run the schema and seed script once:

```bash
psql -U wood_more -d wood_more -f backend/init-db.sql
```

(Or in Beekeeper: open a SQL tab, paste the contents of `backend/init-db.sql`, and run it.)

### 2. Run the backend locally

In a terminal, from the project root:

```bash
cd backend
npm install
PGHOST=localhost PGPORT=5432 PGDATABASE=wood_more PGUSER=wood_more PGPASSWORD=wood_more PORT=3000 node server.js
```

Leave this running. The API will be at **http://localhost:3000**. Use your own DB name/user/password if different; set `PGDATABASE`, `PGUSER`, `PGPASSWORD` (and `PGHOST`/`PGPORT` if needed) accordingly.

### 3. Point the web app at the local API

Set `web/config.json` so the app uses the local backend:

```json
{ "apiBaseUrl": "http://localhost:3000" }
```

If you use a different port for the backend, use that URL (e.g. `http://localhost:3001`).

### 4. Run the Flutter web app

In another terminal, from the project root:

```bash
flutter run -d chrome
```

The app will load `config.json`, see `apiBaseUrl`, and use the API (and thus your local PostgreSQL). Log in with any [seeded email](#5-log-in-test-users).

**To switch back to browser-only storage:** set `web/config.json` to `{"apiBaseUrl": ""}` and restart the app.

---

## Run with Docker Compose (PostgreSQL)

To run the **app + API + PostgreSQL** together (shared database, suitable for team deployment).

**PostgreSQL connection (Beekeeper / any client):** Host `localhost`, Port `5432`, Database `wood_more`, User `wood_more`, Password `wood_more`. See [step 3](#3-connect-with-beekeeper-studio-inspect-the-database) for Beekeeper Studio steps.

### 1. Start all services

From the project root:

```bash
docker compose up -d --build
```

This builds and starts:

- **PostgreSQL** � database (port **5432** exposed on host; data in volume `postgres_data`)
- **api** � Node.js REST API (connects to PostgreSQL)
- **app** � Flutter web app served by nginx (port **8080**)

The app is configured to use the API via `config.api.json` (mounted as `config.json` in the container).

### 2. Open the app

Open **http://localhost:8080** in your browser. Log in with any [seeded email](#5-log-in-test-users) (e.g. `cipherpath@proton.me` or `test-site-engineer@example.com`). Data is stored in PostgreSQL.

### 3. Connect with Beekeeper Studio (inspect the database)

With Docker Compose running, you can connect to PostgreSQL from your machine using [Beekeeper Studio](https://www.beekeeperstudio.io/) (or any PostgreSQL client):

| Field        | Value       |
| ------------ | ----------- |
| **Host**     | `localhost` |
| **Port**     | `5432`      |
| **Database** | `wood_more` |
| **User**     | `wood_more` |
| **Password** | `wood_more` |

**In Beekeeper Studio:**

1. Click **New connection** and choose **PostgreSQL**.
2. Enter the values above (Host: `localhost`, Port: `5432`, User: `wood_more`, Password: `wood_more`, Database: `wood_more`).
3. Click **Test** to verify, then **Connect**.
4. In the left sidebar you'll see tables: `users`, `projects`, `zones`, `buildings`, `attendance_records`, `daily_reports`, `materials`, `engineer_balance`, `engineer_custody`, `supervisors`, `contractors`, `project_stock`, `units`, `building_materials`, `building_cutlist_images`. Open any table to view or query data.

### 4. Stop services

```bash
docker compose down
```

To remove the database volume as well:

```bash
docker compose down -v
```

### Notes

- The API is available only inside the Docker network (proxied at `/api` by nginx). The Flutter app talks to `/api`; nginx forwards to the `api` service.
- PostgreSQL is exposed on **localhost:5432** so you can connect with Beekeeper Studio or `psql` (see step 3 above). Default DB credentials: user `wood_more`, password `wood_more`, database `wood_more`. Override with environment variables in `docker-compose.yml` if needed.
- Backend code: `backend/` (Node.js + Express + `pg`). Schema and seed: `backend/init-db.sql`.

---

## Run with Docker (app only)

You can run **only the web app** in a container (no PostgreSQL; data in browser storage). No Flutter SDK required.

### 1. Build the image

From the project root (`wood-more/`):

```bash
docker build -t wood-more .
```

This builds the Flutter web app and packages it with nginx. The first build may take several minutes while the Flutter toolchain runs.

### 2. Run the container

```bash
docker run -p 8080:80 wood-more
```

Then open **http://localhost:8080** in your browser. You should see the login screen; log in with any of the [seeded emails](#5-log-in-test-users) (e.g. `cipherpath@proton.me` for app admin).

To run in the background (detached):

```bash
docker run -d -p 8080:80 --name wood-more-app wood-more
```

To stop the container:

```bash
docker stop wood-more-app
```

### Notes

- This runs only the **web** app (same behavior as `flutter run -d chrome`). Data is stored in the browser (e.g. localStorage), not in PostgreSQL. For a shared database, use [Docker Compose](#run-with-docker-compose-postgresql) above.
- To use a different host port, change `8080` in `-p 8080:80` (e.g. `-p 3000:80` for port 3000).

---

## Project structure (overview)

```
wood-more/
   lib/
      main.dart                 # App entry, theme, locale (Arabic default)
      core/
         app_theme.dart        # Theme and colors
      data/
         default_materials.dart
      models/                   # User, Project, Attendance, DailyReport, etc.
      screens/                  # Login, Home, Attendance, Reports, Admin, Finance, etc.
      services/
          storage_service.dart  # Init + getStorage: Web/DB or ApiStorageService when config.json has apiBaseUrl
          database_service.dart # SQLite (sqflite) for mobile/desktop
        ?api_storage_service.dart  # REST client when using PostgreSQL backend
          web_storage_service.dart # SharedPreferences-based for web
          location_service.dart
          ...
   assets/
      images/
          logo.png
   pubspec.yaml
   android/  ios/  macos/  windows/  linux/  web/  # Platform folders
   README.md
```

---
