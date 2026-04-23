# Wood & More Application - Full Technical Documentation

## 1. Project Overview

### What the application does
`wood_and_more_app` is a role-based construction operations platform for Wood & More teams. It supports field execution tracking, attendance, daily and detailed reports, project structure management, warehouse and material workflows, and financial custody and balance operations.

The system consists of:
- A Flutter client in `lib/` for web, desktop, and mobile.
- A Node.js + Express backend in `backend/` with PostgreSQL persistence.
- A configurable storage strategy that can switch between API mode and local storage mode based on runtime configuration.

### Core purpose and business logic
The app digitizes day-to-day site operations and internal administration:
- Manage users, projects, locations, zones, buildings, units, contractors, supervisors, and materials.
- Track attendance for site engineers.
- Capture daily and detailed field reports.
- Track warehouse stock, material allocation, and withdrawal movements.
- Track engineer balances, custody, and finance-related records.
- Generate printable and shareable operational reports.
- Maintain an API-level activity log for traceability.

---

## 2. System Architecture

### High-level architecture
The application follows a client-service-database architecture:

1. Flutter presentation layer
   - Screen-driven UI built with Flutter Material widgets.
   - Arabic-first localization and role-specific navigation.

2. Storage abstraction layer
   - `lib/services/storage_service.dart` chooses the active persistence implementation at startup:
     - `ApiStorageService` when `apiBaseUrl` is configured.
     - `WebStorageService` for web local persistence when no API is configured.
     - `DatabaseService` for SQLite persistence on desktop/mobile when no API is configured.

3. Backend API layer
   - Express-based REST API in `backend/server.js`.
   - Handles domain operations for users, projects, reports, stock, finance, and audit logs.

4. Persistence layer
   - PostgreSQL schema created via `backend/init-db.sql`.
   - Incremental schema evolution through `backend/migrations/*.sql`.
   - Some backend startup guards automatically add missing columns or tables.

### How components interact
- `lib/main.dart` initializes Firebase and the storage layer.
- The auth gate restores the persisted user and validates it in API mode.
- UI screens call methods on the active storage implementation.
- In API mode, Flutter service methods translate screen actions into HTTP requests.
- The backend applies business rules, persists data, and returns JSON payloads mapped into Dart models.

---

## 3. Folder Structure Explanation

### Top-level folders
- `lib/`: Main Flutter application source code.
- `backend/`: Node.js backend, SQL schema, and migrations.
- `assets/`: App assets and non-web runtime configuration.
- `web/`: Web entry files and web runtime configuration.
- `android/`, `ios/`, `windows/`, `linux/`, `macos/`: Flutter platform runner folders.
- `test/`: Flutter test files.

### Important root files
- `pubspec.yaml`: Flutter dependencies, assets, and project metadata.
- `README.md`: Main setup and local run documentation.
- `docker-compose.yml`: Full stack orchestration for Postgres, API, and web app.
- `Dockerfile`: Root container build for the Flutter web application.
- `BUILD_SIGN_README.md`, `RELEASE_APK_STEPS.md`, `DEPLOYMENT_GUIDE.md`: Deployment/build notes.

### `lib/` structure
- `main.dart`: Bootstrap, theme, localization, auth gate, route restore logic.
- `screens/`: UI screens for engineers, managers, accountants, and admins.
- `services/`: API, SQLite, web storage, persistence helpers, geolocation, route restore.
- `models/`: Domain models used across the application.
- `core/`: Theme and route observer support.
- `utils/`: Cross-platform PDF share helpers.
- `data/`: Static/default data sources.
- `firebase_options.dart`: Firebase configuration scaffold.

### `backend/` structure
- `server.js`: Main REST API and business logic.
- `init-db.sql`: Core schema and seed data.
- `migrations/`: Manual SQL migration scripts.
- `Dockerfile`: Backend service image definition.
- `README-DATABASE.md`: Database setup guidance.

---

## 4. Features Breakdown

### Authentication and role-based access
User perspective:
- Users log in with email and password.
- The app home menu changes based on user role.

System perspective:
- Login is handled by `POST /auth/login`.
- Roles include `site_engineer`, `site_engineer_manager`, `app_admin`, and `accountant`.
- Session data is persisted locally and restored on next launch.

### Attendance management
User perspective:
- Site engineers record attendance and departure events.
- Supervisors/managers can review attendance reports.

System perspective:
- Attendance is stored through `/attendance` endpoints.
- Geolocation support is available through `geolocator`.

### Daily reports
User perspective:
- Engineers complete a multi-step daily report with work summary, materials, expenses, and attachments.

System perspective:
- Reports are stored through `POST /daily-reports`.
- Expenses may affect engineer balance.
- Materials may trigger stock deductions and ledger entries.

### Detailed reports
User perspective:
- Engineers can create structured reports with multiple work lines, phases, contractor allocations, worker counts, and optional financial entries.

System perspective:
- Stored in `detailed_reports` and `detailed_report_lines`.
- Supports project-linked or custom project-name reporting.
- Supports attachments and expense tracking.

### Admin project and structure management
User perspective:
- Admin users manage projects, zones, buildings, units, materials, contractors, supervisors, and users.
- Admin can define project location trees and warehouse structures.

System perspective:
- CRUD flows are implemented through dedicated backend endpoint groups and mirrored in Flutter admin screens.

### Warehouse and stock workflows
User perspective:
- Users manage project stock, assign materials to locations, and perform site withdrawals.

System perspective:
- Stock is tracked through `project_stock` and `project_stock_ledger`.
- Location-level allocation is tracked through `location_materials`.
- One-time site withdrawal is tracked through `location_withdrawal`.

### Finance and custody
User perspective:
- Accountants and managers can inspect engineer balances, register custody, and review finance reports.

System perspective:
- Balance and custody flows use `/engineer-balance`, `/custody`, and `/balance-movement`.
- Expense entries in reports can automatically reduce balance.

### Activity logging
User perspective:
- Authorized admin can inspect operational activity.

System perspective:
- Backend middleware writes request activity metadata into `activity_logs`.

### PDF/export/reporting
User perspective:
- Users can generate printable or shareable reports.

System perspective:
- Implemented using `pdf`, `printing`, and `share_plus`.

---

## 5. User Flow

### Primary flow
1. The app starts and initializes Firebase plus storage selection.
2. The app restores the last stored user session.
3. In API mode, the user is validated against backend data.
4. If no valid session exists, the user logs in.
5. The user lands on a role-specific home screen.
6. The user performs relevant tasks:
   - Site engineer: attendance, daily reports, detailed reports, stock withdrawal.
   - Manager: report review and custody oversight.
   - Accountant: finance and balance operations.
   - Admin: data and structure management.
7. The user can later review, filter, print, or share reports.
8. The app restores the last route on the next launch when possible.

### Example engineer workflow
1. Log in.
2. Record attendance.
3. Open assigned project data.
4. Submit a daily report or detailed report.
5. Withdraw materials from an assigned work-site if needed.
6. Manager/accountant reviews financial impact and reporting output.

---

## 6. API / Backend Integration

### Backend stack
- Node.js
- Express
- PostgreSQL via `pg`
- CORS + JSON API

### Root and system endpoints
- `GET /`
- `GET /system-lock`
- `PUT /system-lock`

### Authentication
- `POST /auth/login`

### Users
- `GET /users/by-email`
- `GET /users`
- `GET /users/site-engineers`
- `POST /users`
- `PUT /users/:id`
- `DELETE /users/:id`

### Projects and hierarchy
- `GET /projects`
- `POST /projects`
- `PUT /projects/:id`
- `DELETE /projects/:id`
- `GET /project-locations`
- `POST /project-locations`
- `PUT /project-locations/:id`
- `DELETE /project-locations/:id`
- `GET /zones`
- `POST /zones`
- `PUT /zones/:id`
- `DELETE /zones/:id`
- `GET /buildings`
- `POST /buildings`
- `PUT /buildings/:id`
- `DELETE /buildings/:id`
- `GET /units`
- `POST /units`
- `PUT /units/:id`
- `DELETE /units/:id`

### Attendance
- `POST /attendance`
- `GET /attendance`
- `GET /attendance/by-user/:userId`
- `DELETE /attendance/:id`

### Materials and stock
- `GET /materials`
- `GET /materials/with-ids`
- `POST /materials`
- `PUT /materials/:id`
- `DELETE /materials/:id`
- `GET /project-stock`
- `POST /project-stock`
- `PUT /project-stock/:id`
- `DELETE /project-stock/:id`
- `POST /project-stock-ledger`
- `GET /project-stock-ledger`

### Daily reports
- `POST /daily-reports`
- `GET /daily-reports`
- `DELETE /daily-reports/:id`

### Detailed reports and phases
- `GET /work-phases`
- `POST /detailed-reports`
- `GET /detailed-reports`
- `DELETE /detailed-reports/:id`

### Supervisors and contractors
- `GET /supervisors`
- `POST /supervisors`
- `PUT /supervisors/:id`
- `DELETE /supervisors/:id`
- `GET /contractors`
- `POST /contractors`
- `PUT /contractors/:id`
- `DELETE /contractors/:id`

### Finance and custody
- `GET /engineer-balance/:userId`
- `POST /engineer-balance`
- `POST /custody`
- `POST /balance-movement`
- `GET /custody`

### Location materials and withdrawals
- `GET /location-materials`
- `POST /location-materials`
- `PUT /location-materials/:id`
- `DELETE /location-materials/:id`
- `GET /location-withdrawal`
- `POST /location-withdrawal`
- `DELETE /location-withdrawal`
- `GET /location-withdrawals-for-period`

### Audit
- `GET /activity-logs`

### Frontend-backend data flow
- Screen action in Flutter.
- Call into `ApiStorageService`.
- HTTP request to backend.
- Backend route applies validations and business rules.
- Data stored in PostgreSQL.
- JSON mapped back into Dart models and rendered in UI.

---

## 7. Data Models

### Main backend entities
- `users`
- `projects`
- `app_settings`
- `attendance_records`
- `materials`
- `daily_reports`
- `zones`
- `buildings`
- `units`
- `supervisors`
- `contractors`
- `project_locations`
- `project_stock`
- `project_stock_ledger`
- `building_materials`
- `building_cutlist_images`
- `engineer_balance`
- `engineer_custody`
- `work_phases`
- `detailed_reports`
- `detailed_report_lines`
- `location_materials`
- `location_withdrawal`
- `activity_logs`

### Main Flutter models
- `UserModel`
- `ProjectModel`
- `ZoneModel`
- `BuildingModel`
- `UnitModel`
- `ProjectLocationModel`
- `AttendanceRecordModel`
- `DailyReportData`
- `DetailedReportModel`
- `WorkPhaseModel`
- `ProjectStockModel`
- `ProjectStockLedgerModel`
- `LocationMaterialModel`
- `LocationWithdrawalModel`
- `LocationWithdrawalForPeriodModel`
- `SupervisorModel`
- `ContractorModel`
- `BuildingMaterialModel`
- `BuildingCutlistModel`
- `ActivityLogModel`

### Schema evolution
The backend schema has evolved through explicit migrations, including:
- engineer custody movement tracking
- daily report contractor JSON support
- detailed report tables
- project location hierarchy
- detailed report summary and location updates
- project-name support for detailed reports
- location material and withdrawal tables
- contractor optionality and phase refinement

---

## 8. State Management

### Current pattern
- The app primarily uses local widget state with `StatefulWidget`.
- Async screen loading is handled through direct service calls and `FutureBuilder`.
- No centralized state framework such as Riverpod, BLoC, or Provider appears to be the primary architecture.

### Session and route persistence
- User session is persisted with SharedPreferences.
- Last visited route is also persisted and restored.
- `main.dart` uses an auth gate plus route restore wrapper to avoid unnecessary navigation flash.

### Storage state modes
- API mode is the central multi-user mode.
- Web local storage mode is a browser-based fallback.
- SQLite mode is a local-device fallback.

---

## 9. External Services

### Third-party integrations and packages
- Firebase Core
- Cloud Firestore
- Firebase Auth
- Geolocator
- HTTP client
- SQLite via `sqflite`
- SharedPreferences
- PDF generation via `pdf`
- Printing via `printing`
- File sharing via `share_plus`
- File picker via `file_picker`
- URL launcher via `url_launcher`
- Flutter localization delegates

### Observed integration usage
- Firebase is initialized at startup.
- Geolocation is used in attendance-related flows.
- PDF and sharing packages are used in reporting/finance export flows.
- API communication is handled through the `http` package.

---

## 10. Environment Setup

### Prerequisites
- Flutter SDK
- Node.js
- PostgreSQL

### Local development flow
1. Create the PostgreSQL application database, typically `wood_more`.
2. Run `backend/init-db.sql`.
3. Start the backend:
   - `cd backend`
   - `npm install`
   - `node server.js`
4. Configure API URL:
   - `web/config.json` for web
   - `assets/config.json` for desktop/mobile
5. Start Flutter app:
   - `flutter pub get`
   - `flutter run -d chrome`
   - or `flutter run -d windows`

### Docker-based flow
1. Run `docker compose up -d --build`
2. Stack includes:
   - PostgreSQL
   - Backend API
   - Flutter web app
3. Web app is exposed at `http://localhost:8080`

### Runtime behavior
- If `apiBaseUrl` is present, the app uses centralized backend mode.
- If absent, the app falls back to local persistence.

---

## 11. Deployment Notes

### Build and deployment approach
- Flutter web is containerized from the root `Dockerfile`.
- Backend is containerized from `backend/Dockerfile`.
- `docker-compose.yml` coordinates service startup and database health checks.

### Operational notes
- Backend startup includes schema guard functions to reduce failure from missing tables or columns.
- Some authorization controls are implemented in UI flow or hardcoded backend checks rather than standardized middleware.
- Production hardening would benefit from:
  - token-based auth
  - centralized authorization middleware
  - secure secret management
  - stricter CORS and HTTPS enforcement
  - structured monitoring/logging

### Supporting project docs
- `README.md`
- `backend/README-DATABASE.md`
- `DEPLOYMENT_GUIDE.md`
- `BUILD_SIGN_README.md`
- `RELEASE_APK_STEPS.md`

---

## Conclusion

The `wood_and_more_app` repository is a fairly mature operations platform for construction/site workflows. It combines Flutter-based multi-role UI, a flexible storage strategy, and a PostgreSQL-backed REST API to support attendance, reporting, stock control, finance, and administration in a single system. The architecture favors pragmatic feature growth with direct service access and route-driven UI organization, while maintaining enough backend structure to support centralized deployment and future scaling.
# Wood & More Application - Full Technical Documentation

## 1. Project Overview

### What the application does
`wood_and_more_app` is a role-based construction operations platform for Wood & More teams. It supports field execution tracking, attendance, daily and detailed reports, project structure management, warehouse and material workflows, and financial custody and balance operations.

The system consists of:
- A Flutter client in `lib/` for web, desktop, and mobile.
- A Node.js + Express backend in `backend/` with PostgreSQL persistence.
- A configurable storage strategy that can switch between API mode and local storage mode based on runtime configuration.

### Core purpose and business logic
The app digitizes day-to-day site operations and internal administration:
- Manage users, projects, locations, zones, buildings, units, contractors, supervisors, and materials.
- Track attendance for site engineers.
- Capture daily and detailed field reports.
- Track warehouse stock, material allocation, and withdrawal movements.
- Track engineer balances, custody, and finance-related records.
- Generate printable and shareable operational reports.
- Maintain an API-level activity log for traceability.

---

## 2. System Architecture

### High-level architecture
The application follows a client-service-database architecture:

1. Flutter presentation layer
   - Screen-driven UI built with Flutter Material widgets.
   - Arabic-first localization and role-specific navigation.

2. Storage abstraction layer
   - `lib/services/storage_service.dart` chooses the active persistence implementation at startup:
     - `ApiStorageService` when `apiBaseUrl` is configured.
     - `WebStorageService` for web local persistence when no API is configured.
     - `DatabaseService` for SQLite persistence on desktop/mobile when no API is configured.

3. Backend API layer
   - Express-based REST API in `backend/server.js`.
   - Handles domain operations for users, projects, reports, stock, finance, and audit logs.

4. Persistence layer
   - PostgreSQL schema created via `backend/init-db.sql`.
   - Incremental schema evolution through `backend/migrations/*.sql`.
   - Some backend startup guards automatically add missing columns or tables.

### How components interact
- `lib/main.dart` initializes Firebase and the storage layer.
- The auth gate restores the persisted user and validates it in API mode.
- UI screens call methods on the active storage implementation.
- In API mode, Flutter service methods translate screen actions into HTTP requests.
- The backend applies business rules, persists data, and returns JSON payloads mapped into Dart models.

---

## 3. Folder Structure Explanation

### Top-level folders
- `lib/`: Main Flutter application source code.
- `backend/`: Node.js backend, SQL schema, and migrations.
- `assets/`: App assets and non-web runtime configuration.
- `web/`: Web entry files and web runtime configuration.
- `android/`, `ios/`, `windows/`, `linux/`, `macos/`: Flutter platform runner folders.
- `test/`: Flutter test files.

### Important root files
- `pubspec.yaml`: Flutter dependencies, assets, and project metadata.
- `README.md`: Main setup and local run documentation.
- `docker-compose.yml`: Full stack orchestration for Postgres, API, and web app.
- `Dockerfile`: Root container build for the Flutter web application.
- `BUILD_SIGN_README.md`, `RELEASE_APK_STEPS.md`, `DEPLOYMENT_GUIDE.md`: Deployment/build notes.

### `lib/` structure
- `main.dart`: Bootstrap, theme, localization, auth gate, route restore logic.
- `screens/`: UI screens for engineers, managers, accountants, and admins.
- `services/`: API, SQLite, web storage, persistence helpers, geolocation, route restore.
- `models/`: Domain models used across the application.
- `core/`: Theme and route observer support.
- `utils/`: Cross-platform PDF share helpers.
- `data/`: Static/default data sources.
- `firebase_options.dart`: Firebase configuration scaffold.

### `backend/` structure
- `server.js`: Main REST API and business logic.
- `init-db.sql`: Core schema and seed data.
- `migrations/`: Manual SQL migration scripts.
- `Dockerfile`: Backend service image definition.
- `README-DATABASE.md`: Database setup guidance.

---

## 4. Features Breakdown

### Authentication and role-based access
User perspective:
- Users log in with email and password.
- The app home menu changes based on user role.

System perspective:
- Login is handled by `POST /auth/login`.
- Roles include `site_engineer`, `site_engineer_manager`, `app_admin`, and `accountant`.
- Session data is persisted locally and restored on next launch.

### Attendance management
User perspective:
- Site engineers record attendance and departure events.
- Supervisors/managers can review attendance reports.

System perspective:
- Attendance is stored through `/attendance` endpoints.
- Geolocation support is available through `geolocator`.

### Daily reports
User perspective:
- Engineers complete a multi-step daily report with work summary, materials, expenses, and attachments.

System perspective:
- Reports are stored through `POST /daily-reports`.
- Expenses may affect engineer balance.
- Materials may trigger stock deductions and ledger entries.

### Detailed reports
User perspective:
- Engineers can create structured reports with multiple work lines, phases, contractor allocations, worker counts, and optional financial entries.

System perspective:
- Stored in `detailed_reports` and `detailed_report_lines`.
- Supports project-linked or custom project-name reporting.
- Supports attachments and expense tracking.

### Admin project and structure management
User perspective:
- Admin users manage projects, zones, buildings, units, materials, contractors, supervisors, and users.
- Admin can define project location trees and warehouse structures.

System perspective:
- CRUD flows are implemented through dedicated backend endpoint groups and mirrored in Flutter admin screens.

### Warehouse and stock workflows
User perspective:
- Users manage project stock, assign materials to locations, and perform site withdrawals.

System perspective:
- Stock is tracked through `project_stock` and `project_stock_ledger`.
- Location-level allocation is tracked through `location_materials`.
- One-time site withdrawal is tracked through `location_withdrawal`.

### Finance and custody
User perspective:
- Accountants and managers can inspect engineer balances, register custody, and review finance reports.

System perspective:
- Balance and custody flows use `/engineer-balance`, `/custody`, and `/balance-movement`.
- Expense entries in reports can automatically reduce balance.

### Activity logging
User perspective:
- Authorized admin can inspect operational activity.

System perspective:
- Backend middleware writes request activity metadata into `activity_logs`.

### PDF/export/reporting
User perspective:
- Users can generate printable or shareable reports.

System perspective:
- Implemented using `pdf`, `printing`, and `share_plus`.

---

## 5. User Flow

### Primary flow
1. The app starts and initializes Firebase plus storage selection.
2. The app restores the last stored user session.
3. In API mode, the user is validated against backend data.
4. If no valid session exists, the user logs in.
5. The user lands on a role-specific home screen.
6. The user performs relevant tasks:
   - Site engineer: attendance, daily reports, detailed reports, stock withdrawal.
   - Manager: report review and custody oversight.
   - Accountant: finance and balance operations.
   - Admin: data and structure management.
7. The user can later review, filter, print, or share reports.
8. The app restores the last route on the next launch when possible.

### Example engineer workflow
1. Log in.
2. Record attendance.
3. Open assigned project data.
4. Submit a daily report or detailed report.
5. Withdraw materials from an assigned work-site if needed.
6. Manager/accountant reviews financial impact and reporting output.

---

## 6. API / Backend Integration

### Backend stack
- Node.js
- Express
- PostgreSQL via `pg`
- CORS + JSON API

### Root and system endpoints
- `GET /`
- `GET /system-lock`
- `PUT /system-lock`

### Authentication
- `POST /auth/login`

### Users
- `GET /users/by-email`
- `GET /users`
- `GET /users/site-engineers`
- `POST /users`
- `PUT /users/:id`
- `DELETE /users/:id`

### Projects and hierarchy
- `GET /projects`
- `POST /projects`
- `PUT /projects/:id`
- `DELETE /projects/:id`
- `GET /project-locations`
- `POST /project-locations`
- `PUT /project-locations/:id`
- `DELETE /project-locations/:id`
- `GET /zones`
- `POST /zones`
- `PUT /zones/:id`
- `DELETE /zones/:id`
- `GET /buildings`
- `POST /buildings`
- `PUT /buildings/:id`
- `DELETE /buildings/:id`
- `GET /units`
- `POST /units`
- `PUT /units/:id`
- `DELETE /units/:id`

### Attendance
- `POST /attendance`
- `GET /attendance`
- `GET /attendance/by-user/:userId`
- `DELETE /attendance/:id`

### Materials and stock
- `GET /materials`
- `GET /materials/with-ids`
- `POST /materials`
- `PUT /materials/:id`
- `DELETE /materials/:id`
- `GET /project-stock`
- `POST /project-stock`
- `PUT /project-stock/:id`
- `DELETE /project-stock/:id`
- `POST /project-stock-ledger`
- `GET /project-stock-ledger`

### Daily reports
- `POST /daily-reports`
- `GET /daily-reports`
- `DELETE /daily-reports/:id`

### Detailed reports and phases
- `GET /work-phases`
- `POST /detailed-reports`
- `GET /detailed-reports`
- `DELETE /detailed-reports/:id`

### Supervisors and contractors
- `GET /supervisors`
- `POST /supervisors`
- `PUT /supervisors/:id`
- `DELETE /supervisors/:id`
- `GET /contractors`
- `POST /contractors`
- `PUT /contractors/:id`
- `DELETE /contractors/:id`

### Finance and custody
- `GET /engineer-balance/:userId`
- `POST /engineer-balance`
- `POST /custody`
- `POST /balance-movement`
- `GET /custody`

### Location materials and withdrawals
- `GET /location-materials`
- `POST /location-materials`
- `PUT /location-materials/:id`
- `DELETE /location-materials/:id`
- `GET /location-withdrawal`
- `POST /location-withdrawal`
- `DELETE /location-withdrawal`
- `GET /location-withdrawals-for-period`

### Audit
- `GET /activity-logs`

### Frontend-backend data flow
- Screen action in Flutter.
- Call into `ApiStorageService`.
- HTTP request to backend.
- Backend route applies validations and business rules.
- Data stored in PostgreSQL.
- JSON mapped back into Dart models and rendered in UI.

---

## 7. Data Models

### Main backend entities
- `users`
- `projects`
- `app_settings`
- `attendance_records`
- `materials`
- `daily_reports`
- `zones`
- `buildings`
- `units`
- `supervisors`
- `contractors`
- `project_locations`
- `project_stock`
- `project_stock_ledger`
- `building_materials`
- `building_cutlist_images`
- `engineer_balance`
- `engineer_custody`
- `work_phases`
- `detailed_reports`
- `detailed_report_lines`
- `location_materials`
- `location_withdrawal`
- `activity_logs`

### Main Flutter models
- `UserModel`
- `ProjectModel`
- `ZoneModel`
- `BuildingModel`
- `UnitModel`
- `ProjectLocationModel`
- `AttendanceRecordModel`
- `DailyReportData`
- `DetailedReportModel`
- `WorkPhaseModel`
- `ProjectStockModel`
- `ProjectStockLedgerModel`
- `LocationMaterialModel`
- `LocationWithdrawalModel`
- `LocationWithdrawalForPeriodModel`
- `SupervisorModel`
- `ContractorModel`
- `BuildingMaterialModel`
- `BuildingCutlistModel`
- `ActivityLogModel`

### Schema evolution
The backend schema has evolved through explicit migrations, including:
- engineer custody movement tracking
- daily report contractor JSON support
- detailed report tables
- project location hierarchy
- detailed report summary and location updates
- project-name support for detailed reports
- location material and withdrawal tables
- contractor optionality and phase refinement

---

## 8. State Management

### Current pattern
- The app primarily uses local widget state with `StatefulWidget`.
- Async screen loading is handled through direct service calls and `FutureBuilder`.
- No centralized state framework such as Riverpod, BLoC, or Provider appears to be the primary architecture.

### Session and route persistence
- User session is persisted with SharedPreferences.
- Last visited route is also persisted and restored.
- `main.dart` uses an auth gate plus route restore wrapper to avoid unnecessary navigation flash.

### Storage state modes
- API mode is the central multi-user mode.
- Web local storage mode is a browser-based fallback.
- SQLite mode is a local-device fallback.

---

## 9. External Services

### Third-party integrations and packages
- Firebase Core
- Cloud Firestore
- Firebase Auth
- Geolocator
- HTTP client
- SQLite via `sqflite`
- SharedPreferences
- PDF generation via `pdf`
- Printing via `printing`
- File sharing via `share_plus`
- File picker via `file_picker`
- URL launcher via `url_launcher`
- Flutter localization delegates

### Observed integration usage
- Firebase is initialized at startup.
- Geolocation is used in attendance-related flows.
- PDF and sharing packages are used in reporting/finance export flows.
- API communication is handled through the `http` package.

---

## 10. Environment Setup

### Prerequisites
- Flutter SDK
- Node.js
- PostgreSQL

### Local development flow
1. Create the PostgreSQL application database, typically `wood_more`.
2. Run `backend/init-db.sql`.
3. Start the backend:
   - `cd backend`
   - `npm install`
   - `node server.js`
4. Configure API URL:
   - `web/config.json` for web
   - `assets/config.json` for desktop/mobile
5. Start Flutter app:
   - `flutter pub get`
   - `flutter run -d chrome`
   - or `flutter run -d windows`

### Docker-based flow
1. Run `docker compose up -d --build`
2. Stack includes:
   - PostgreSQL
   - Backend API
   - Flutter web app
3. Web app is exposed at `http://localhost:8080`

### Runtime behavior
- If `apiBaseUrl` is present, the app uses centralized backend mode.
- If absent, the app falls back to local persistence.

---

## 11. Deployment Notes

### Build and deployment approach
- Flutter web is containerized from the root `Dockerfile`.
- Backend is containerized from `backend/Dockerfile`.
- `docker-compose.yml` coordinates service startup and database health checks.

### Operational notes
- Backend startup includes schema guard functions to reduce failure from missing tables or columns.
- Some authorization controls are implemented in UI flow or hardcoded backend checks rather than standardized middleware.
- Production hardening would benefit from:
  - token-based auth
  - centralized authorization middleware
  - secure secret management
  - stricter CORS and HTTPS enforcement
  - structured monitoring/logging

### Supporting project docs
- `README.md`
- `backend/README-DATABASE.md`
- `DEPLOYMENT_GUIDE.md`
- `BUILD_SIGN_README.md`
- `RELEASE_APK_STEPS.md`

---

## Conclusion

The `wood_and_more_app` repository is a fairly mature operations platform for construction/site workflows. It combines Flutter-based multi-role UI, a flexible storage strategy, and a PostgreSQL-backed REST API to support attendance, reporting, stock control, finance, and administration in a single system. The architecture favors pragmatic feature growth with direct service access and route-driven UI organization, while maintaining enough backend structure to support centralized deployment and future scaling.
# Wood & More Application - Full Technical Documentation

## 1. Project Overview

### What the application does
`wood_and_more_app` is a role-based construction operations platform for Wood & More teams. It supports field execution tracking, attendance, daily and detailed reports, project structure management, warehouse/material workflows, and financial custody/balance operations.

The system consists of:
- A Flutter client (`lib/`) for web/desktop/mobile.
- A Node.js + Express backend (`backend/server.js`) with PostgreSQL persistence.
- A configurable storage strategy that can switch between API mode and local storage mode (SQLite/browser storage) based on runtime configuration.

### Core purpose and business logic
The app is designed to digitize site operations and reporting:
- Manage organizational and project master data (users, projects, locations, zones, buildings, units, contractors, supervisors, materials).
- Track attendance with geolocation for site engineers.
- Capture operational reports:
  - Daily report flow (multi-step narrative + materials + expenses + attachments).
  - Detailed report flow (structured line items by phase/location/contractor/workers).
- Track stock and warehouse movements (project-level and location-level).
- Track financial movements (engineer balances, custody, balance movements).
- Generate/print/share reporting documents (PDF workflows).
- Log user/system activity at API level for auditability.

---

## 2. System Architecture

### High-level architecture
The application follows a client-service-database architecture:

1. **Flutter Presentation Layer**
   - Screen-based UI with role-specific navigation and menus.
   - Arabic-first localization with RTL-oriented usage.
   - Stateful widgets handling screen-level state and async workflows.

2. **Storage Abstraction Layer**
   - `initStorage()` in `lib/services/storage_service.dart` chooses backend dynamically:
     - `ApiStorageService` when `apiBaseUrl` is configured.
     - `WebStorageService` fallback for web if no API URL.
     - `DatabaseService` fallback for mobile/desktop if no API URL.

3. **Backend API Layer**
   - Express REST API in `backend/server.js`.
   - Endpoint-oriented domain operations (users, projects, reports, stock, custody, etc.).
   - Activity logging middleware captures request metadata and writes to `activity_logs`.
   - Startup schema-guard methods ensure required columns/tables are available.

4. **Persistence Layer**
   - PostgreSQL schema initialized by `backend/init-db.sql` and extended via `backend/migrations/*.sql`.
   - Relational model with foreign keys for most business entities.
   - JSON text fields used for variable-length collections (expenses/material lines/images/attachments).

### Component interaction
- App startup (`lib/main.dart`) initializes Firebase and storage provider.
- Auth gate restores persisted user, optionally validates user against API (`/users/by-email`) when in API mode.
- UI screens call storage service methods.
- In API mode, service methods map to REST endpoints in `backend/server.js`.
- Backend processes data, applies business rules (e.g., stock deduction, balance updates), persists to PostgreSQL, and returns normalized JSON.

---

## 3. Folder Structure Explanation

### Root folders
- `lib/`: Main Flutter application source.
- `backend/`: Node.js API service and SQL database scripts.
- `assets/`: App assets, including `assets/config.json` (non-web API configuration).
- `web/`: Web entry assets and `web/config.json` (web API configuration).
- `android/`, `ios/`, `windows/`, `linux/`, `macos/`: Platform runners/build configurations.
- `.agents/`: Agent skill metadata (not part of runtime app behavior).

### Root-level important files
- `pubspec.yaml`: Flutter dependencies and assets declaration.
- `README.md`: Primary run/setup guidance.
- `docker-compose.yml`: Full stack orchestration (Postgres + API + web app).
- `Dockerfile`: Flutter web build + Nginx serving container.
- `BUILD_SIGN_README.md`, `RELEASE_APK_STEPS.md`, `DEPLOYMENT_GUIDE.md`: Build/deployment notes.

### `lib/` substructure
- `main.dart`: App bootstrap, theme/localization setup, auth gate, route restore entry.
- `screens/`: UI screens (admin, engineer, manager, accountant, reporting, dashboards).
- `services/`: Storage/API/database services, location service, auth persistence, route persistence/restore.
- `models/`: Domain entities and DTO mapping.
- `core/`: App theme and route observer.
- `utils/`: PDF sharing abstractions for web/io.
- `data/`: Default static data (e.g., default materials).
- `firebase_options.dart`: Firebase platform configuration scaffold.

### `backend/` substructure
- `server.js`: Main API application and business logic.
- `init-db.sql`: Base schema + seed data.
- `migrations/`: Incremental SQL migrations.
- `01-create-database.sql`, `00-drop-database.sql`: DB management utilities.
- `Dockerfile`: Backend service image.
- `package.json`: Backend dependencies and scripts.

---

## 4. Features Breakdown

### 4.1 Authentication and role-based access
**User perspective**
- User logs in via email/password.
- Menu options and reachable features depend on role.

**System perspective**
- Login calls `POST /auth/login`.
- Roles supported in models/seeds: `site_engineer`, `site_engineer_manager`, `app_admin`, `accountant`.
- Session persisted locally via SharedPreferences.
- In API mode, restored session is validated by querying user existence.

### 4.2 Attendance tracking
**User perspective**
- Site engineer records check-in/check-out with optional location and notes.
- Managers/admins can view attendance reports and related sub-reports.

**System perspective**
- Geolocation fetched via `geolocator` service.
- Attendance stored via `POST /attendance`.
- Reports read via `/attendance` and `/attendance/by-user/:userId`.

### 4.3 Daily reports (multi-step)
**User perspective**
- Engineers fill report through steps (work details, materials, expenses, files/images).
- Reports can be reviewed/exported/shared.

**System perspective**
- Persisted through `POST /daily-reports`.
- Server calculates expense totals and adjusts engineer balance.
- Server may deduct used materials from project stock and write stock ledger movements.

### 4.4 Detailed reports (structured)
**User perspective**
- Engineer records structured line items by project/location/phase/contractor/worker counts.
- Supports financial line details and file attachments.
- Aggregated reports available across periods.

**System perspective**
- Persisted via `POST /detailed-reports`.
- Child lines stored in `detailed_report_lines`.
- Expenses can impact engineer balance.
- Query supports filters by date/user/project (`GET /detailed-reports`).

### 4.5 Project structure and master-data administration
**User perspective**
- Admin can maintain projects and their hierarchy:
  - Project -> zones -> buildings -> units
  - Project locations tree (`folder` / `work_site`)
- Admin can manage users, contractors, supervisors, materials.

**System perspective**
- CRUD endpoint families: `/users`, `/projects`, `/zones`, `/buildings`, `/units`, `/project-locations`, `/contractors`, `/supervisors`, `/materials`.

### 4.6 Warehouse and materials workflows
**User perspective**
- Manage project stock items and monitor movement history.
- Assign materials per project location.
- Execute one-time location withdrawal with permit attachments.

**System perspective**
- Stock entities: `project_stock`, `project_stock_ledger`.
- Location material entities: `location_materials`, `location_withdrawal`.
- Withdrawal flow deducts stock and writes ledger entries.
- Rollback endpoint can restore stock and remove withdrawal ledger rows.

### 4.7 Finance and custody
**User perspective**
- Managers/accountants can track engineer balances, add custody, and view records.
- Additional financial forms/reports supported (e.g., salary deduction PDF output).

**System perspective**
- Balance/custody endpoints:
  - `/engineer-balance/:userId`, `/engineer-balance`
  - `/custody`, `/balance-movement`
- Daily and detailed report expenses can automatically reduce balances.

### 4.8 Activity logs and operational auditing
**User perspective**
- Authorized admin can view activity log feed.

**System perspective**
- Middleware records endpoint, method, user context, status code, and timing.
- Queried via `GET /activity-logs` (email-restricted at backend level).

### 4.9 Reporting and document export
**User perspective**
- Multiple report screens allow filtering, review, printing, and sharing.

**System perspective**
- PDF generated using `pdf` and `printing` packages.
- Shared through `share_plus`.
- Web/IO platform-specific share adapters in `lib/utils`.

---

## 5. User Flow

### Primary end-user flow
1. Application starts and initializes Firebase + storage strategy.
2. Auth gate restores local session (if present).
3. In API mode, stored user is validated against backend.
4. User logs in (if no valid session).
5. Home screen shows role-appropriate navigation.
6. User executes role-specific operations:
   - Site engineer: attendance, daily/detailed reports, withdrawals.
   - Manager/accountant: finance/custody and reports.
   - Admin: master data and structure administration.
7. User opens reports, filters by date/project/user, and exports as needed.
8. Last route is saved/restored to improve continuity between sessions.

### Example operational flow: engineer daily activity
1. Check-in attendance (location + project).
2. Submit daily report with narrative/materials/expenses.
3. Optionally submit detailed report for structured productivity tracking.
4. Withdraw location materials if required for assigned work site.
5. Manager/accountant reviews resulting balances/reports.

---

## 6. API / Backend Integration

## Backend technology
- Node.js, Express, CORS, `pg` PostgreSQL client.
- JSON API with endpoint groups by domain.
- No token-based auth middleware detected; role restrictions are mostly client flow and selective endpoint checks.

## Endpoint catalog

### Health / Root
- `GET /` - API status/info.

### Auth and system lock
- `POST /auth/login`
- `GET /system-lock`
- `PUT /system-lock`

### Users
- `GET /users/by-email`
- `GET /users`
- `GET /users/site-engineers`
- `POST /users`
- `PUT /users/:id`
- `DELETE /users/:id`

### Projects and structure
- `GET /projects`
- `POST /projects`
- `PUT /projects/:id`
- `DELETE /projects/:id`
- `GET /project-locations`
- `POST /project-locations`
- `PUT /project-locations/:id`
- `DELETE /project-locations/:id`
- `GET /zones`
- `POST /zones`
- `PUT /zones/:id`
- `DELETE /zones/:id`
- `GET /buildings`
- `POST /buildings`
- `PUT /buildings/:id`
- `DELETE /buildings/:id`
- `GET /units`
- `POST /units`
- `PUT /units/:id`
- `DELETE /units/:id`

### Attendance
- `POST /attendance`
- `GET /attendance`
- `GET /attendance/by-user/:userId`
- `DELETE /attendance/:id`

### Materials and stock
- `GET /materials`
- `GET /materials/with-ids`
- `POST /materials`
- `PUT /materials/:id`
- `DELETE /materials/:id`
- `GET /project-stock`
- `POST /project-stock`
- `PUT /project-stock/:id`
- `DELETE /project-stock/:id`
- `POST /project-stock-ledger`
- `GET /project-stock-ledger`

### Daily reports
- `POST /daily-reports`
- `GET /daily-reports`
- `DELETE /daily-reports/:id`

### Detailed reports and phases
- `GET /work-phases`
- `POST /detailed-reports`
- `GET /detailed-reports`
- `DELETE /detailed-reports/:id`

### Supervisors and contractors
- `GET /supervisors`
- `POST /supervisors`
- `PUT /supervisors/:id`
- `DELETE /supervisors/:id`
- `GET /contractors`
- `POST /contractors`
- `PUT /contractors/:id`
- `DELETE /contractors/:id`

### Finance and custody
- `GET /engineer-balance/:userId`
- `POST /engineer-balance`
- `POST /custody`
- `POST /balance-movement`
- `GET /custody`

### Location materials and withdrawals
- `GET /location-materials`
- `POST /location-materials`
- `PUT /location-materials/:id`
- `DELETE /location-materials/:id`
- `GET /location-withdrawal`
- `POST /location-withdrawal`
- `DELETE /location-withdrawal`
- `GET /location-withdrawals-for-period`

### Audit
- `GET /activity-logs`

## Data flow summary
- Flutter screen -> `ApiStorageService` -> REST endpoint -> SQL operations -> JSON response -> model mapping -> UI rendering.
- Some endpoints enforce additional domain logic:
  - Report creation updates balance/stock.
  - Withdrawal creation/rollback adjusts inventory and ledger.
  - Startup ensures missing schema parts exist.

---

## 7. Data Models

## Core backend entities (PostgreSQL)
- `users` (identity, role, password)
- `projects`
- `app_settings` (system lock flag)
- `attendance_records`
- `materials`
- `daily_reports`
- `zones`
- `buildings`
- `units`
- `supervisors`
- `contractors`
- `project_locations` (tree: `parent_id`, `type`, `display_order`)
- `project_stock`
- `project_stock_ledger`
- `building_materials`
- `building_cutlist_images`
- `engineer_balance`
- `engineer_custody`
- `work_phases`
- `detailed_reports`
- `detailed_report_lines`
- `location_materials`
- `location_withdrawal`
- `activity_logs`

## Flutter model layer (`lib/models`)
- Access and identity: `UserModel`, `ActivityLogModel`
- Structural entities: `ProjectModel`, `ZoneModel`, `BuildingModel`, `UnitModel`, `ProjectLocationModel`
- Operations and reports: `AttendanceRecordModel`, `DailyReportData`, `DetailedReportModel`, `WorkPhaseModel`
- Resource/warehouse: `ProjectStockModel`, `ProjectStockLedgerModel`, `LocationMaterialModel`, `LocationWithdrawalModel`, `LocationWithdrawalForPeriodModel`
- Supporting entities: `SupervisorModel`, `ContractorModel`, `BuildingMaterialModel`, `BuildingCutlistModel`

## Migration evolution
- `001_add_engineer_custody_movement_type.sql`
- `002_add_daily_reports_contractors_json.sql`
- `003_detailed_reports.sql`
- `004_project_locations.sql`
- `005_detailed_reports_summary_and_location.sql`
- `006_detailed_reports_project_name.sql`
- `007_location_materials_and_withdrawal.sql`
- `008_detailed_report_phases_and_contractor_nullable.sql`
- `RUN_ME_create_detailed_reports.sql` (repair/create helper script)

---

## 8. State Management

## Current approach
- Screen-local mutable state using Flutter `StatefulWidget` patterns.
- Async loading via `FutureBuilder`, direct service invocations, and imperative updates.
- No global state framework (e.g., BLoC/Riverpod/Provider) as the primary architecture.

## Persistence/state continuity
- User session and last route persisted in `SharedPreferences`.
- Route history persistence handled by `route_persistence.dart`.
- Route restoration mapping handled by `route_restore.dart`.
- `main.dart` boot sequence ensures state providers are ready before UI starts.

## Storage mode state behavior
- API mode is authoritative for data persistence.
- Fallback local modes (WebStorageService/DatabaseService) provide offline/local behavior if API base URL is absent.

---

## 9. External Services

## Integrated third-party services/libraries
- **Firebase Core**: initialized at app startup (`Firebase.initializeApp`).
- **Cloud Firestore / Firebase Auth**: dependencies present in `pubspec.yaml` (primary business flow currently uses REST backend + local persistence).
- **Geolocation**: `geolocator` for attendance/location workflows.
- **HTTP Client**: `http` for backend API communication.
- **SQLite**: `sqflite` for non-API local persistence mode.
- **Shared Preferences**: session and route persistence.
- **PDF/Printing**: `pdf`, `printing` for document/report generation.
- **Sharing**: `share_plus` for file/report sharing.
- **File selection**: `file_picker` for attachments/images.
- **URL launch**: `url_launcher` for map/location links.
- **Localization**: Flutter localization delegates with Arabic/English support.

---

## 10. Environment Setup

## Prerequisites
- Flutter SDK (Dart SDK compatible with project constraint).
- Node.js LTS.
- PostgreSQL (local or cloud, including Neon-compatible connection).

## Option A: Local run (recommended for development)
1. Create/use PostgreSQL database (recommended: `wood_more`).
2. Run `backend/init-db.sql` against the app database.
3. Start backend from `backend/`:
   - `npm install`
   - `node server.js`
4. Set API URL:
   - `web/config.json` for web runs.
   - `assets/config.json` for desktop/mobile runs.
5. Start Flutter app from project root:
   - `flutter pub get`
   - `flutter run -d chrome` or `flutter run -d windows` (or target device).

## Option B: Docker stack
1. From project root run: `docker compose up -d --build`
2. Services:
   - Postgres on `5432`
   - API on internal `3000`
   - Web app exposed at `http://localhost:8080`
3. DB is initialized automatically via mounted `backend/init-db.sql`.

## Configuration behavior
- If `apiBaseUrl` is set -> app uses backend API and PostgreSQL.
- If empty -> app falls back to local storage mode.

---

## 11. Deployment Notes

## Build and packaging considerations
- Flutter web deployment is containerized via root `Dockerfile` and served by Nginx.
- Backend is containerized separately via `backend/Dockerfile`.
- `docker-compose.yml` defines service orchestration and startup ordering with DB health checks.

## Operational notes
- Backend startup includes schema guards (`ensure*` functions) to reduce migration drift risk.
- Certain authorization checks are hardcoded on specific endpoints (e.g., activity logs requester email); broader API auth middleware is not present.
- For production hardening, consider:
  - Standard auth tokens and role middleware.
  - Secret management for DB credentials.
  - HTTPS termination and CORS tightening.
  - Structured logging and monitoring.

## Existing deployment docs in repository
- `DEPLOYMENT_GUIDE.md`
- `BUILD_SIGN_README.md`
- `RELEASE_APK_STEPS.md`
- `README.md` and `backend/README-DATABASE.md`

---

## Additional Notes for Maintainers

- The codebase includes some duplicated Windows-style path indexing artifacts (e.g., both `lib/screens/...` and `lib\\screens\\...` shown by tooling). Validate actual filesystem uniqueness before automation scripts rely on raw index output.
- The repository contains both API-backed and local-storage operation modes; always confirm target mode in QA/testing.
- The backend centralizes many business rules directly in route handlers; refactoring into service layers may improve long-term maintainability.

# Wood & More — المستند المرجعي الشامل (الحالة الحالية)

مستند مرجعي يلخّص **وظائف التطبيق** و**مسار البناء** من البداية حتى الوضع الحالي، وفقًا لبنية المشروع الحالية.

---

## 1) تعريف سريع بالمشروع

تطبيق **Wood & More** هو نظام تشغيل ميداني وإداري لمشاريع الأخشاب وWPC، ويغطي:

- إدارة المستخدمين والأدوار.
- الحضور والانصراف.
- التقارير اليومية والتقارير المفصلة.
- العهدة والماليات (أرصدة مهندسي الموقع).
- مخازن المشاريع وحركة الخامات.
- هيكلة مواقع العمل داخل المشروع.
- سحب خامات من مواقع فرعية مع تتبع الحركة.
- لوحة تحكم إدارية شاملة.

التطبيق مبني بـ **Flutter** مع واجهة عربية افتراضيًا، ويدعم التشغيل حسب المنصة على:
- Web
- Android / iOS
- Desktop

---

## 2) المعمارية العامة (Architecture)

### 2.1 طبقات التطبيق

- **UI Layer**: شاشات Flutter داخل `lib/screens`.
- **Domain Models**: نماذج البيانات داخل `lib/models`.
- **Data/Storage Layer**: طبقة موحدة للوصول للبيانات عبر `getStorage()` في `lib/services/storage_service.dart`.

### 2.2 آلية اختيار مصدر البيانات (Storage Strategy)

عند بدء التطبيق (`lib/main.dart`):

1. يتم تهيئة Firebase.
2. يتم استدعاء `initStorage()`.
3. اختيار مصدر البيانات يتم كالتالي:
   - إذا يوجد `apiBaseUrl` في `assets/config.json` (أو `config.json` على الويب) ➜ استخدام `ApiStorageService` (REST API + PostgreSQL).
   - إذا لا يوجد API وعلى الويب ➜ استخدام `WebStorageService` (SharedPreferences).
   - إذا لا يوجد API وعلى الموبايل/سطح المكتب ➜ استخدام `DatabaseService` (SQLite).

هذا التصميم يعطي نفس الوظائف تقريبًا في كل البيئات مع مرونة عالية.

---

## 3) الأدوار وصلاحيات التشغيل

النظام يعتمد الأدوار التالية:

- `site_engineer` (مهندس موقع)
- `site_engineer_manager` (مدير مهندسين)
- `app_admin` (مسؤول تطبيق)
- `accountant` (محاسب)

ومنطق الصلاحيات يوزّع الشاشات والعمليات حسب الدور في `home_screen.dart` وباقي الشاشات.

---

## 4) وظائف التطبيق (حسب الوحدات الوظيفية)

## 4.1 المصادقة والدخول

- شاشة الدخول: `login_screen.dart`
- التحقق: بريد + كلمة سر.
- الجلسة: حفظ المستخدم الحالي عبر `auth_persistence`.
- استعادة آخر مسار شاشة: `route_persistence` + `route_restore`.
- دعم وضع الصيانة/القفل العام:
  - مفتاح تشغيل/إيقاف من لوحة الأدمن.
  - عند القفل، أي محاولة تسجيل دخول (عدا حساب الأدمن المحدد) تؤدي لعرض صفحة مستقلة برسالة:
    `System Locked for maintainance please try again later`

## 4.2 الحضور والانصراف

- تسجيل الحضور: `attendance_screen.dart`
- تقارير الحضور:
  - `attendance_reports_screen.dart`
  - `attendance_sub_report_screen.dart`

## 4.3 التقارير اليومية

تدفق متعدد الخطوات:

- `daily_report_step1_screen.dart`
- `daily_report_step2_screen.dart`
- `daily_report_step3_screen.dart`

ويتضمن: المشروع، موقع العمل، ملخص التنفيذ، خطة الغد، المقاولين/العمال، مرفقات، خامات، مصروفات.

## 4.4 التقارير المفصلة

- `detailed_report_screen.dart`
- `detailed_report_finances_screen.dart`
- `aggregated_detailed_daily_report_screen.dart`
- `site_engineer_reports_screen.dart`

الهيكل يدعم:
- بنود متعددة لكل تقرير.
- مراحل عمل متعددة لنفس الموقع.
- ربط بمواقع المشروع المهيكلة (`project_locations`).
- دعم مصروفات ومرفقات.

## 4.5 الماليات والعهدة

- `accountant_finance_screen.dart`
- `accountant_custody_screen.dart`
- `finance_screen.dart`
- `manager_custody_screen.dart`
- `user_custody_report_screen.dart`
- `salary_deduction_screen.dart`

المنطق المالي يشمل:
- رصيد كل مهندس.
- تسجيل حركات (عهدة/إضافة رصيد/سحب رصيد).
- تأثير المصروفات على الرصيد.

## 4.6 إدارة المشاريع والبنية المكانية

إداريًا:

- `admin_projects_screen.dart`
- `admin_zones_screen.dart`
- `admin_buildings_screen.dart`
- `admin_units_screen.dart`
- `admin_project_structure_screen.dart`

ويشمل:
- مشروع > Zone > Building > Unit
- هيكل شجري لمواقع المشروع عبر `project_locations` (folder/work_site)

## 4.7 إدارة المخازن والخامات

- أرصدة مخازن المشاريع: `admin_project_stores_screen.dart`
- هيكلة مخازن المواقع الفرعية: `admin_warehouse_structure_screen.dart`
- سحب خامات بواسطة مهندس الموقع: `engineer_withdraw_materials_screen.dart`
- شاشة إدارية لإلغاء/استرجاع السحب: `admin_warehouse_withdraw_screen.dart`
- إدارة خامات مرتبطة بالموقع: `admin_location_materials_screen.dart`

المنطق:
- خصم من مخزون المشروع عند السحب.
- تسجيل حركة بالسجل.
- دعم إلغاء السحب واستعادة المخزون (بصلاحيات محددة).

## 4.8 إدارة البيانات المرجعية

من لوحة الأدمن:

- المستخدمون: `admin_users_screen.dart`
- المشرفون: `admin_supervisors_screen.dart`
- المقاولون: `admin_contractors_screen.dart`
- الخامات: `admin_materials_screen.dart`
- تشوينات المباني: `admin_building_materials_screen.dart`
- قطعيات/صور: `admin_cutlists_screen.dart`

---

## 5) لوحة التحكم الإدارية (Admin Dashboard)

الشاشة: `admin_dashboard_screen.dart`

تجمع كل أدوات الإدارة السابقة، وحاليًا تتضمن أيضًا:

- **System Lock (Maintenance) On/Off** لمستخدم واحد فقط:
  - البريد: `mouhammedhelal@gmail.com`
- عند التفعيل:
  - قفل تسجيل الدخول لباقي المستخدمين.
  - إظهار صفحة الصيانة المنفصلة بعد محاولة الدخول.

---

## 6) الخلفية (Backend) — Node.js + PostgreSQL

المجلد: `backend/`

### 6.1 الملف الرئيسي

- `backend/server.js` (Express + pg)

### 6.2 ما يقدمه الخادم

- Endpoints للمصادقة والمستخدمين.
- Endpoints لإدارة المشاريع والبنية (zones/buildings/units/project_locations).
- Endpoints للحضور.
- Endpoints للتقارير اليومية والمفصلة.
- Endpoints للماليات والعهدة والأرصدة.
- Endpoints للمخازن وحركة الخامات.
- Endpoints لوضع القفل:
  - `GET /system-lock`
  - `PUT /system-lock`

### 6.3 التهيئة والترقيات

الخادم يحتوي دوال `ensure...` لإنشاء/ترقية الجداول تلقائيًا (مثل:
`ensurePasswordColumn`, `ensureDetailedReportsTables`, `ensureLocationMaterialsTables`, `ensureSystemLockTable`).

---

## 7) قاعدة البيانات والتهيئة الأولية

### 7.1 PostgreSQL

- ملف تأسيس: `backend/init-db.sql`
- يحتوي إنشاء الجداول الأساسية + بيانات seed.
- يتضمن `app_settings` وحقل `system_locked`.

### 7.2 SQLite (تشغيل محلي)

- داخل `DatabaseService`.
- إصدار قاعدة البيانات وصل حاليًا إلى نسخة تدعم:
  - التقرير المفصل ومرفقاته
  - هيكلة مواقع المشروع
  - هيكلة المخازن والسحب
  - قفل النظام عبر `app_settings`

### 7.3 Web Local Storage

- داخل `WebStorageService`.
- يحتفظ بنفس منطق البيانات تقريبًا مع مفاتيح SharedPreferences.

---

## 8) المسار التطوري (من الأساس حتى الوضع الحالي)

هذا التسلسل يوضح رحلة بناء المنتج وظيفيًا:

1. **الأساس**: Flutter app + ثيم + تسجيل دخول + أدوار.
2. **التخزين المحلي**: SQLite للموبايل/سطح المكتب.
3. **تدفق الحضور**: تسجيل وقراءة تقارير الحضور.
4. **التقارير اليومية**: نموذج متعدد الخطوات + حفظ بيانات تشغيلية.
5. **الإدارة الأساسية**: مستخدمين/مشاريع/مناطق/مباني/خامات.
6. **الماليات والعهدة**: أرصدة مهندسين + حركات محاسبية.
7. **المخزن**: أرصدة مشروع + Ledger للحركات.
8. **هيكلة مواقع المشروع**: شجرة مواقع لدعم تشغيل ميداني أدق.
9. **التقرير المفصل**: خطوط عمل متعددة + مراحل + مواقع + مصروفات + مرفقات.
10. **هيكلة مخازن المواقع الفرعية**: خامات لكل موقع مع سحب وتتبّع.
11. **خادم API PostgreSQL**: توحيد البيانات مركزيًا مع نفس وظائف التطبيق.
12. **وضع الصيانة System Lock**: تحكم مباشر من الأدمن المعتمد مع تجربة مستخدم مخصصة عند محاولة الدخول.

---

## 9) الملفات والمجلدات الأهم حاليًا

- `lib/main.dart` — نقطة البداية وتهيئة التخزين.
- `lib/services/storage_service.dart` — اختيار مصدر البيانات.
- `lib/services/database_service.dart` — SQLite implementation.
- `lib/services/web_storage_service.dart` — Web local implementation.
- `lib/services/api_storage_service.dart` — REST implementation.
- `lib/screens/` — كل واجهات التشغيل.
- `lib/models/` — نماذج البيانات.
- `backend/server.js` — API server.
- `backend/init-db.sql` — تهيئة قاعدة PostgreSQL.
- `backend/migrations/` — ترحيلات SQL إضافية حسب التحديثات.

---

## 10) الحالة الحالية (Current State)

المشروع حاليًا في مرحلة **تشغيل متقدم** وليس MVP:

- نظام أدوار متكامل.
- وحدات تشغيل يومي + إداري + مالي.
- دعم تخزين متعدد البيئات.
- دعم backend PostgreSQL كامل تقريبًا.
- دعم وضع صيانة مركزي قابل للتحكم.
- جاهزية للتوسع مع الحفاظ على نفس واجهة الخدمات.

---

## 11) ملاحظة تشغيلية مهمة

عند العمل بنمط API:

- أي تحديث في `backend/server.js` (مثل وضع القفل) يحتاج **Restart للـ backend**.
- تأكد من صحة `apiBaseUrl` في ملف الإعدادات حتى يعمل التطبيق على الخادم بدل التخزين المحلي.

---

**تم إعداد هذا المستند ليتوافق مع بنية المشروع الحالية كما هي داخل المستودع الآن.**
# Wood & More — تفاصيل التطبيق ومراحل التطوير

مستند مرجعي يلخص **وظائف التطبيق** و**مسار البناء** من الأساس حتى الوضع الحالي (حسب بنية المشروع الحالية في المستودع).

---

## 1. نظرة عامة

تطبيق **Wood & More** لإدارة عمل **مهندسي المواقع** في مشاريع إنشاءات/تشطيبات خشبية و WPC: حضور، تقارير يومية ومفصلة، عهدة وماليات، مخازن مشاريع، سحب خامات من مواقع فرعية، ولوحة تحكم لمسؤول التطبيق لإدارة البيانات المرجعية والهيكل.

- **واجهة:** Flutter (عربي افتراضياً)، دعم Android / iOS / Web / Desktop حسب المنصة.
- **مصادقة:** Firebase (تهيئة في `main.dart`؛ قد يتأثر الويب بتوفر `gstatic`).
- **تخزين البيانات:**
  - إن وُجد **`apiBaseUrl`** في `assets/config.json` (أو `config.json` على الويب) → **REST API** + **PostgreSQL** (خادم Node في `backend/`).
  - وإلا على **الويب** → تخزين محلي بالمتصفح (`WebStorageService`).
  - وإلا على **الجوال/سطح المكتب** → **SQLite** (`DatabaseService`).
- **استعادة المسار:** حفظ آخر شاشة للمستخدم (`route_restore`).

---

## 2. الأدوار (Roles)

| الدور | الوصف المختصر |
|--------|----------------|
| `site_engineer` | مهندس موقع — التقارير، المشروعات، المخزن، الحضور |
| `site_engineer_manager` | مدير مهندسين — تقارير حضور، تقارير يومية، عهدة؛ وقد يشترك مع المسؤول في بعض الشاشات |
| `app_admin` | مسؤول التطبيق — لوحة التحكم + هيكلة مشروعات + صلاحيات إضافية محددة بالبريد حيث يُطبَّق |
| `accountant` | محاسب — عهدة وماليات |

---

## 3. وظائف التطبيق حسب المستخدم

### 3.1 مهندس الموقع (`HomeScreen` → `_EngineerHome`)

| الوظيفة | الشاشة / المسار | ملخص |
|---------|------------------|------|
| تسجيل الحضور والانصراف | `AttendanceScreen` | تسجيل مع مشروع/ملاحظات حسب التصميم |
| التقرير اليومي | `DailyReportStep1Screen` → خطوات لاحقة | تقرير يومي بالمشروع، مكان العمل، المشرف، المقاولون وعدد العمال، تنفيذ اليوم، مرفقات، ثم خطوات إضافية حسب التدفق |
| التقرير المفصل | `DetailedReportScreen` → `DetailedReportFinancesScreen` | مشروع (أو «أخرى»)، موقع عمل (هيكلة مواقع أو زون/مبنى)، مقاول، **عدة مراحل لنفس الموقع** (عدد عمال لكل مرحلة؛ عند إضافة مرحلة جديدة يُنسخ عدد العمال من آخر مرحلة لنفس الطاقم)، مشرف، ملخص، **مرفقات اختيارية** (صور/ملفات)، ثم بنود ماليات وحفظ |
| المشروعات | `EngineerProjectsScreen` | مشروع → زون → مبنى → تشوينات، نماذج، قطعيات |
| المخزن (سحب خامات) | `EngineerWithdrawMaterialsScreen` | مواقع فرعية بخامات؛ سحب مرة واحدة لكل موقع مع أذونات صرف/تسليم؛ خصم من مخزن المشروع |

### 3.2 المحاسب

| الوظيفة | الشاشة |
|---------|--------|
| العهدة | `AccountantCustodyScreen` — تقارير حسب المستخدم والمدة، PDF |
| الماليات | `AccountantFinanceScreen` — أرصدة، إضافة/سحب رصيد، حركات |

### 3.3 مدير المهندسين / مسؤول التطبيق (`_ManagerHome`)

| الوظيفة | ملاحظات |
|---------|----------|
| تقارير الحضور والانصراف | `AttendanceReportsScreen` |
| التقارير (اليومية) | `ReportsScreen` — فلترة مهندس/تاريخ/مشروع، PDF، صلاحيات تعديل/حذف لمستخدم محدد حسب الكود |
| هيكلة المشروعات | لـ `app_admin`: `AdminProjectStructureScreen` — شجرة `project_locations` (مجلدات + مواقع عمل) |
| لوح التحكم | لـ `app_admin`: `AdminDashboardScreen` |

### 3.4 لوحة التحكم — مسؤول التطبيق (`AdminDashboardScreen`)

إدارة مركزية لـ: المستخدمين، المشاريع، المناطق (زون)، المباني، الوحدات، التشوينات لكل مبنى، القطعيات، المشرفين، المقاولين، الخامات العامة، **أرصدة مخازن المشاريع**، **هيكلة المخازن** (خامات لكل موقع فرعي)، واختياريًا لحساب محدد: **المخزن (سحب الخامات)** لإلغاء سحب واسترجاع المخزن (`AdminWarehouseWithdrawScreen` + `canManageWarehouseWithdrawalReset`).

---

## 4. شاشات ووظائف إضافية (في المشروع)

تُستخدم حسب التوجيه والمسارات: `LoginScreen`، `SubReportsScreen`، `WorkersReportScreen`، `ContractorReportScreen`، `AttendanceSubReportScreen`، `SalaryDeductionScreen`، `FinanceScreen`، `ManagerCustodyScreen`، `UserCustodyReportScreen`، شاشات إدارية للمواد داخل موقع (`admin_location_materials_screen`)، إلخ.

---

## 5. الخادم (Backend)

- **ملف رئيسي:** `backend/server.js` (Express + `pg`).
- **تهيئة جداول:** دوال مثل `ensureDetailedReportsTables` لإنشاء/تعديل جداول التقرير المفصل وغيرها عند التشغيل.
- **مجلد migrations:** ملفات SQL مرقمة (حضور، تقارير يومية، تقرير مفصل، مواقع مشروع، خامات وسحب، إلخ) للتشغيل اليدوي على PostgreSQL عند الحاجة.
- **init-db.sql:** لقطة أولية لقاعدة كاملة.

**أمثلة مجالات API:** مستخدمون، مشاريع، مناطق، مباني، وحدات، تقارير يومية، تقارير مفصلة (مع `expenses_json`، `attachments_json`)، حضور، عهدة، أرصدة مهندسين، مخزون مشروع، سجل مخزون، مواقع مشروع، خامات مواقع، سحب مواقع، مراحل عمل، إلخ.

---

## 6. نماذج بيانات مهمة

- **تقرير مفصل:** رأس `DetailedReportModel` + سطور `DetailedReportLineModel` (مقاول، موقع، مرحلة، عدد عمال، …) + مصاريف + **مرفقات** `DetailedReportAttachment`.
- **مخزن المشروع:** `project_stock` + `project_stock_ledger`.
- **سحب خامات:** `location_withdrawal` + `location_materials` مرتبطة بـ `project_locations`.

---

## 7. مراحل البناء والتطوير (منطقياً — حسب طبقات المشروع)

1. **أساس التطبيق:** Flutter، ثيم، تسجيل دخول، جلسة مستخدم، توجيه حسب الدور.
2. **تخزين مزدوج:** SQLite محلي + لاحقاً طبقة **API** و**ويب تخزين** مع `getStorage()` موحّد.
3. **الحضور والتقارير اليومية:** جداول، شاشات متعددة الخطوات، PDF، تقارير للمدير.
4. **الإدارة:** مشاريع، زون، مباني، وحدات، تشوينات، قطعيات، مشرفون، مقاولون، خامات.
5. **المالية:** أرصدة مهندسين، عهدة، محاسب، خصم من التقارير عند الصرف.
6. **مخازن المشاريع:** رصيد خامات باسم المشروع، سجل حركات.
7. **هيكلة مواقع المشروع:** `project_locations` للتقرير المفصل والربط مع المخزن.
8. **هيكلة المخازن + سحب الخامات:** خامات لكل موقع فرعي، سحب لمرة واحدة، خصم مخزن، ولوحة مسؤول لإلغاء السحب واسترجاع الرصيد (صلاحية محدودة).
9. **التقرير المفصل:** تطور من سطور بسيطة إلى **مواقع متداخلة + عدة مراحل لنفس الموقع** + مراحل ثابتة بالواجهة + مرفقات + عمود `attachments_json` في القاعدة.
10. **تقارير فرعية** (مقاولين، عمال، …) و**Firebase** كطبقة مصادقة/جاهزية.

---

## 8. ملاحظة لتقارير المقاولين والمالية (لاحقاً)

عند تجميع **عدد العمال أو تكلفة اليوم** لمقاول معيّن:

- كل **سطر** في التقرير المفصل يمثل **مرحلة + عدد عمال** في نفس الموقع؛ طاقم واحد قد يظهر في **عدة سطور** (مراحل متتابعة) بنفس العدد إذا نُسخ عمداً — **لا يجب جمع الأعداد سطراً بسطر** كأنها عمال إضافيين.
- يُنصح بتعريف قاعدة تقرير واضحة: مثلاً **أقصى عدد عمال** للمقاول في (مشروع + موقع + يوم)، أو **عدّ الطاقم مرة واحدة** ثم ربط المراحل به، حسب سياسة الشركة.

---

## 9. ملفات إعداد

- `assets/config.json` — `apiBaseUrl` للاتصال بالخادم.
- `pubspec.yaml` — الاعتماديات (مثل `file_picker`, `pdf`, `printing`, Firebase, …).

---

*آخر تحديث للمستند يتوافق مع تعديل سلوك «إضافة مرحلة» لنسخ عدد العمال من آخر مرحلة في نفس موقع العمل.*
