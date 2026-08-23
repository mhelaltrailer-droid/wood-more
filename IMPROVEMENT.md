# Wood & More — Application Improvement Plan

This review covers the Flutter app, Node/Express API, PostgreSQL/Neon database, Docker, CI, and documentation.

Writing this document does not change the application. Future improvements should be implemented in small phases, tested locally first, and approved before any user-visible or operational change.

## Priority summary

### P0 — Do first

- Rotate passwords found in tracked SQL data and sanitize `backend/init-db.sql`.
- Hash user passwords and add real authentication and server-side authorization.
- Stop trusting `userId` or `requesterEmail` sent by the client as proof of identity.
- Require a dedicated WebDAV signing secret.
- Stop applying the full `init-db.sql` dump to production on every push to `main`.
- Stop returning internal database error messages to clients.

### P1 — Do next

- Validate environment variables at API startup.
- Add structured logging and centralized error handling.
- Add real backend integration tests.
- Configure database connection limits.
- Harden Docker containers and restrict database exposure.
- Automate database backups and regularly test restoration.

### P2 — Improve gradually

- Split large files into smaller modules without changing behavior.
- Move large attachments to object storage.
- Remove verified-unused code, dependencies, assets, scripts, and files.
- Consolidate setup, deployment, architecture, and recovery documentation.

---

## 1. Hardcoded values

### Current issue

- The primary administrator email is repeated in `backend/server.js` and several backend modules.
- The production API URL is stored directly in `web/config.json`, `assets/config.json`, and a test.
- Database credentials have development defaults in Docker and backend configuration.
- Upload limits, ports, token lifetime, and other operational values are mixed with application code.

### How to improve

- Create one backend configuration module that reads and validates environment variables.
- Use variables such as `PRIMARY_ADMIN_EMAIL`, `ALLOWED_ORIGINS`, `API_PORT`, `MAX_UPLOAD_MB`, and `TOKEN_TTL`.
- Supply the Flutter API URL using runtime configuration or `--dart-define`.
- Keep true business constants in clearly named Dart or JavaScript constant files.
- Do not move every constant to `.env`; labels, role names, and fixed business rules can remain in code.

### Behavior impact

No functional change is required. Start with the same current values and only change where they are loaded from.

---

## 2. Secret management

### Current issue

- `backend/init-db.sql` contains production-like user records and plaintext passwords.
- Passwords are stored and compared as plaintext.
- `backend/projects_dashboard.js` can use `DATABASE_URL` or a hardcoded development value as its WebDAV signing secret.
- `.env` files are ignored correctly, but there is no automated secret scanning.

### How to improve

- Treat credentials contained in Git as exposed and rotate them.
- Replace the full tracked dump with a schema file and sanitized development seed.
- Consider removing sensitive dump history using a carefully planned Git history cleanup.
- Hash passwords using Argon2id or bcrypt; never log passwords.
- Require dedicated production secrets such as `SESSION_SECRET` and `PD_WEBDAV_SECRET`.
- Store production secrets only in Render, GitHub Actions, and Neon secret settings.
- Add secret scanning with Gitleaks, TruffleHog, or GitHub secret scanning.

### Behavior impact

Password hashing is a major migration. Preserve login behavior by either:

1. accepting a valid legacy password once and replacing it with a hash, or
2. requiring a controlled password reset.

Existing roles and screens should remain unchanged. Rotating credentials may require updating Render and operator access.

---

## 3. Environment configuration

### Current issue

- Development, testing, and production variables are not defined in one place.
- The backend silently uses default database credentials when variables are missing.
- The root and backend `.env.example` files describe different sets of variables.
- Production client configuration is committed directly into app configuration files.

### How to improve

- Document a single environment matrix for local, test, and production.
- Validate required production variables during API startup and fail with a clear message when missing.
- Keep safe local defaults only in Docker Compose or a development env file.
- Add all supported variables to `backend/.env.example` without real values.
- Use separate variables for:
  - application database pooler URL;
  - direct database URL for migrations and backups;
  - allowed web origins;
  - secrets and admin configuration;
  - upload and connection limits;
  - logging level.

### Behavior impact

Keep current URLs, ports, and defaults during the first phase. Production startup will become stricter only after all required variables are configured.

---

## 4. Database security

### Current issue

- API authorization often trusts `userId` or `requesterEmail` supplied by the client.
- Some write endpoints are not protected by authenticated server-side role checks.
- User passwords are plaintext.
- The API uses one database role and does not define least-privilege permissions.
- TLS is enabled with certificate verification disabled.
- Schema changes are split between a full dump, manual migrations, and runtime `ensure*` functions.

### How to improve

- Issue a signed session or JWT after login and authenticate every protected request.
- Read the user identity and role from the verified token, not request fields.
- Add reusable authorization middleware for each role and action.
- Hash passwords and rate-limit login attempts.
- Create a least-privilege database role for the API; use a separate role for migrations.
- Verify Neon TLS certificates using supported connection settings.
- Restrict Neon access using available IP/network controls where practical.
- Keep parameterized queries; this is already a good pattern in much of the backend.
- Select one migration system as the schema source of truth.

### Behavior impact

This is a major but necessary change. Introduce authenticated identity first, temporarily verify old `userId` and `requesterEmail` fields against it, update Flutter requests, and remove the old trust model afterward. API routes and response formats can remain compatible during migration.

---

## 5. Error handling

### Current issue

- Most routes repeat `try/catch` and return raw `e.message`.
- Database and internal error details can reach users.
- Some failures are silently ignored.
- Flutter screens handle and display errors differently.
- There is no shared request ID for tracing a failure.

### How to improve

- Add one Express error middleware.
- Define safe error codes such as `validation_error`, `not_found`, `forbidden`, and `internal_error`.
- Return a stable response containing an error code and request ID.
- Log full technical details only on the server.
- Add request validation for body, path, and query values.
- Route all Flutter HTTP methods through one error-mapping helper.
- Add one shared Flutter function for user-friendly error messages.
- Log ignored background failures instead of using empty catches.

### Behavior impact

Business behavior remains the same. Error text may become safer and more consistent. Keep existing status codes where clients currently depend on them.

---

## 6. Structured and centralized logging

### Current issue

- Backend operational logging uses scattered `console.log`, `console.warn`, and `console.error`.
- Logs do not consistently include request IDs, route, status, duration, or user.
- The `activity_logs` database table is a business audit trail, not a replacement for operational logs.
- There is no documented retention or centralized search process.

### How to improve

- Use Pino with JSON logs in production and readable output locally.
- Add a request ID to every request and response.
- Log method, route, status, duration, authenticated user ID, and error code.
- Redact passwords, tokens, authorization headers, database URLs, and attachment data.
- Keep business audit logs separate from application logs.
- Send Render logs to a central service such as Better Stack, Datadog, or Grafana Loki.
- Define log levels and retention periods.

### Behavior impact

No application behavior change. Logging should be added around existing logic and should never delay or fail requests.

---

## 7. Docker optimization

### Current issue

- The web build context includes unnecessary backend and large SQL content.
- There are two API Dockerfiles that can drift.
- Base images use floating tags.
- The rebuild script disables caching by default.
- Package and Flutter caches are not fully reused.

### How to improve

- Exclude `backend/`, SQL dumps, local artifacts, and unused platform files from the web build context.
- Consolidate API Dockerfiles or generate both from one maintained source.
- Pin image versions and periodically update them.
- Use normal cached builds by default; keep `--no-cache` as an explicit troubleshooting option.
- Use BuildKit cache mounts for npm and Flutter dependencies.
- Keep the current multi-stage Flutter build.
- Compare image sizes before and after each change.

### Behavior impact

No runtime behavior change is intended. Verify the Flutter web build, nginx configuration, API startup, and required Docker `COPY` files after every optimization.

---

## 8. Container security

### Current issue

- API and web containers run as root.
- Local PostgreSQL is published on all host interfaces with a simple password.
- CORS accepts every origin.
- The general JSON body limit is 120 MB.
- Containers do not use read-only filesystems, dropped capabilities, or resource limits.
- CI builds images but does not scan them.

### How to improve

- Run the API as the Node user and nginx with an unprivileged setup.
- Bind local PostgreSQL to `127.0.0.1` or do not publish its port.
- Restrict production CORS to approved web origins.
- Use small general request limits and dedicated streaming upload routes.
- Add `no-new-privileges`, dropped capabilities, resource limits, and read-only filesystems where supported.
- Add Trivy/Grype and Hadolint checks.
- Make `/healthz` verify database access and return `503` when unavailable.
- Add graceful shutdown that stops accepting requests and closes the database pool.

### Behavior impact

Container hardening can break startup or file writes if permissions are incorrect. Test nginx writable paths, uploads, health checks, and startup locally before production deployment.

---

## 9. Automated database backup and restore testing

### Current issue

- There is no automated `pg_dump` backup job.
- There is no regular restore test.
- The 39 MB `init-db.sql` file is a seed/dump, not a reliable operational backup.
- `.github/workflows/init-postgres.yml` applies the full dump on every push to `main`.
- Neon point-in-time restore exists, but the recovery process is not documented or tested.

### How to improve

- Stop running the full dump automatically on every `main` push.
- Apply controlled, numbered migrations instead.
- Schedule encrypted custom-format `pg_dump` backups using a direct Neon connection.
- Store backups outside the application repository with retention and access controls.
- Alert when a backup fails or is too old.
- Test restoration regularly into an isolated database or Neon branch.
- After restoring, verify:
  - schema and migration version;
  - important tables;
  - expected row-count ranges;
  - a read-only API smoke test.
- Document recovery point objective, recovery time objective, owner, and rollback steps.
- Keep Neon point-in-time restore as an additional recovery layer.

### Behavior impact

Changing the deployment migration process is operationally significant but should not change app features. Test against a Neon branch or local clone, back up production, run migrations, verify, and keep a rollback procedure.

---

## 10. Testing locally first, then CI

### Current issue

- The repository has useful Flutter tests, but limited widget and integration coverage.
- The backend has no formal test script or test framework.
- Existing backend scripts are manual and are not a complete regression suite.
- CI mainly checks JavaScript syntax and Docker builds.
- The backend Docker smoke command should be corrected and should test a real HTTP request.

### How to improve

### Local phase

1. Add one command for Flutter analysis, tests, and web build.
2. Export `createApp()` so the API can be tested without starting production startup tasks.
3. Add backend unit and HTTP tests using Node's test runner and Supertest.
4. Run API integration tests against disposable PostgreSQL.
5. Test migrations against an empty database and an upgraded database.
6. Start Docker Compose and test `/healthz`, login, and a small set of critical workflows.

### CI phase

After the commands work reliably locally, run the exact same commands in pull-request CI. Add coverage gradually for authentication, permissions, attendance, reports, inventory, attachments, and database transactions.

### Behavior impact

Tests do not change runtime behavior. Characterization tests should record current behavior before any refactor, including unusual behavior that must remain temporarily compatible.

---

## 11. Code structure and separation of concerns

### Current issue

- `backend/server.js` is roughly 7,000 lines and combines configuration, schema creation, routes, business rules, and data access.
- Some domains are already modules, but many remain in the main file.
- User lookup and authorization logic are duplicated.
- Schema definitions exist in multiple systems.
- Large Flutter storage implementations repeat API/local behavior.
- Many screens repeat loading, error, and SnackBar patterns.

### How to improve

- Move one domain at a time into:
  - routes;
  - controllers;
  - services;
  - repositories;
  - validation;
  - authorization middleware.
- Add shared user and role helpers.
- Keep SQL migrations separate from API startup.
- Define a clear Dart storage interface and test all implementations against it.
- Extract shared Flutter request, loading, and error helpers.
- Consider an OpenAPI contract later to reduce route/model drift.

### Behavior impact

Refactor by moving existing code without rewriting it. Keep route paths, request bodies, responses, database queries, and Flutter workflows unchanged. Run characterization tests after each extracted domain.

---

## 12. Scalability and connection limits

### Current issue

- The shared PostgreSQL pool has no explicit size or timeout configuration.
- Multiple API replicas could create too many database connections.
- WebDAV locks are stored in process memory and are not shared between instances.
- Large JSON/base64 uploads consume application memory and database storage.
- Health checks do not currently confirm database availability.

### How to improve

- Use the Neon pooled connection string for normal web traffic.
- Use a direct connection only for migrations, backup, and restore tools.
- Configure pool size, idle timeout, connection timeout, and query timeout using environment variables.
- Calculate the pool budget as: API instances multiplied by pool size, with spare database capacity.
- Move WebDAV locks to PostgreSQL or Redis with expiry.
- Move large files and APKs to object storage such as S3 or Cloudflare R2.
- Store file metadata and URLs in PostgreSQL.
- Add pagination and limits to large list/report endpoints.
- Keep the API stateless so instances can be added safely.

### Behavior impact

WebDAV lock storage and file storage are major migrations. Preserve existing endpoints. For files, use dual-read/dual-write, copy and verify existing content, switch reads, and remove database blobs only after explicit approval.

---

## 13. Documentation

### Current issue

- `README.md` contains stale database names, passwords, and login examples.
- Setup documents disagree about Docker credentials and Compose profiles.
- Production deployment information is mainly in `RENDER.MD` and is not clearly linked from the main README.
- Migration, backup, restore, and security operations are not documented in one reliable location.
- Some architecture details no longer match the current files.

### How to improve

- Make `README.md` the start page with links to detailed documents.
- Add a short quick start for local Docker and Flutter development.
- Add an environment-variable matrix.
- Keep one canonical deployment guide and mark old guides as archived.
- Document the architecture and main data flows.
- Document migrations, backup, restore testing, incident response, and secret rotation.
- Remove real/default production-style credentials from documentation.
- Update documentation in the same change as code or configuration.

### Behavior impact

No application behavior change. Correct documentation reduces deployment and data-loss risk.

---

## 14. Application size and code optimization

### Current issue

Potential size and maintenance problems include:

- a large production-like SQL dump tracked in Git;
- two API Dockerfiles;
- repeated backend constants and user lookup code;
- large Flutter API, SQLite, and web storage implementations;
- manual or one-off scripts that may no longer be needed;
- old or contradictory documentation;
- dependencies whose current use is unclear;
- assets, fonts, images, and platform files that may be bundled unnecessarily;
- large base64 files stored in PostgreSQL and transferred through JSON.

These are candidates, not automatic deletion targets. Runtime-loaded files can appear unused during a simple code search.

### How to improve

1. Measure repository size, Git history size, Docker image sizes, web bundle size, and APK size.
2. Run dependency checks for Dart and npm, then confirm every candidate with source searches and builds.
3. Check `pubspec.yaml` assets, dynamic imports, platform configuration, Docker `COPY` commands, deployment scripts, and operator docs.
4. Classify every candidate:
   - **safe to remove** — proven unused and tests/build pass;
   - **needs runtime verification** — dynamically loaded or operational;
   - **keep** — active or required.
5. Remove one item at a time and compare behavior and build sizes.
6. Extract small shared helpers where duplication is real; avoid creating unnecessary abstractions.
7. Move large dumps, backups, and binaries out of Git and Docker build contexts.
8. Optimize images and include only required fonts/assets.
9. Remove unused dependencies to reduce attack surface and build size.
10. Use lazy loading or code splitting only where Flutter/web support and measured results justify it.

### Likely review candidates

- `backend/init-db.sql`: replace with schema plus sanitized minimal seed; do not delete until database setup is replaced.
- `Dockerfile.api` and `backend/Dockerfile`: consolidate after Compose and Render builds use one verified approach.
- Old deployment/setup Markdown files: archive or merge after confirming no operator relies on them.
- Backend one-off scripts: document active scripts; move completed scripts to an archive or remove with approval.
- Firebase packages/configuration: confirm whether Firebase is actively used before keeping or removing dependencies.
- Repeated Flutter storage code: reduce through shared interfaces and helpers, not a risky full rewrite.

### Behavior impact

No file, dependency, or asset should be removed based only on static search. Every deletion requires explicit approval, a passing local test/build, and a rollback through Git. Uncertain files should be listed for manual review and kept.

---

## Safe implementation sequence

1. Create characterization tests and record current behavior.
2. Rotate exposed credentials and sanitize tracked data.
3. Add password hashing, authentication, and authorization in a compatible migration.
4. Centralize configuration, error handling, and logging.
5. Formalize database migrations, backups, and restore tests.
6. Add local backend integration tests, then mirror them in CI.
7. Harden and optimize containers.
8. Refactor one backend or Flutter domain at a time.
9. Migrate large attachments and distributed locks only when required.
10. Measure and remove verified-unused code/files incrementally.
11. Update documentation after every phase.

Before every major phase:

- test locally;
- back up affected data;
- document rollback;
- keep existing routes and data formats when possible;
- explain any user-visible or operational change;
- obtain approval before destructive or disruptive work.
