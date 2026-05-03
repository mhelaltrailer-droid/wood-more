# Deploying Wood & More on Render

This guide explains how [Render](https://render.com) fits **this** project (Flutter web frontend, Node.js API in `backend/`, PostgreSQL via connection string—often [Neon](https://neon.tech)) and how to get started with the Render dashboard.

---

## Troubleshooting: `bash: flutter: command not found`

Render **Static Site** build images are a small **Ubuntu + Node** (or similar) stack. They do **not** include the **Flutter SDK**, so any build command that runs `flutter` will fail—this is expected, not a misconfiguration on your side.

Setting **Publish directory** to `build/web` or removing a stray **`$`** from the build line does **not** fix this: the builder still has no `flutter` binary.

**Fix:** do **not** use a Static Site for this repo’s main web build. Use one of these instead:

1. **Web Service (Docker)** — **New +** → **Web Service** → **Docker** → root directory empty → **Dockerfile path** `Dockerfile`. This uses the repo’s root `Dockerfile` (Flutter inside the image), same idea as the `app` service in Docker Compose.
2. **Blueprint** — Commit and push the repo’s **`render.yaml`**, then in Render: **New +** → **Blueprint** → connect the repo. You will get two Docker web services (`wood-more-api`, `wood-more-web`). Set **`DATABASE_URL`** on the API when Render prompts.
3. **CI-built Static Site** — Build `flutter build web` in **GitHub Actions** (or locally), commit or upload only **`build/web`**, and point a Static Site at a folder that does not need `flutter` on Render (advanced; still need correct `apiBaseUrl` in `config.json`).

After switching to Docker for the frontend, update **`web/config.json`** with your real **`wood-more-api` URL** before deploying, or the app will not reach the API (see section 6). On Render, `/api/` in nginx still targets hostname `api`, which only exists in Compose—in production the Flutter app should call the **public API URL** via `apiBaseUrl`, not rely on nginx `proxy_pass` to `api`.

---

## 1. Create a Render account

1. Open [https://render.com](https://render.com) and choose **Get Started** or **Sign Up**.
2. Sign up with **GitHub**, **GitLab**, **Bitbucket**, or email. Connecting a Git host is recommended so you can deploy from your repository with automatic builds.
3. Complete email verification if prompted.
4. After login you land on the **Render Dashboard** (`dashboard.render.com`): this is where you create services, view logs, manage environment variables, and monitor deploys.

---

## 2. What Render can do for Wood & More

| Render product | Use for this application |
|----------------|---------------------------|
| **Web Service** | Run the **Node API** (`backend/server.js`). Render runs your server, assigns an HTTPS URL, and scales/restarts on failure. Build can use **Docker** (`backend/Dockerfile`) or **Native Node** (`npm install` + `npm start`). |
| **Static Site** | Host **pre-built** static files only. Render’s builder **cannot** run `flutter`; use only if `build/web` is produced elsewhere (CI/local). Fast CDN, custom domain; set **`apiBaseUrl`** for your API (see section 6). |
| **Web Service (Docker)** | Alternative: deploy the **root Dockerfile** (Flutter build + nginx) as one container so the SPA and nginx live together; still configure nginx/API routing carefully. |
| **PostgreSQL** | Optional **managed Postgres** if you do *not* want Neon. You would create a Render Postgres instance and set `DATABASE_URL` on the API to Render’s internal or external connection string. Your repo already supports `DATABASE_URL` with SSL. |
| **Environment groups** | Share the same env vars (e.g. `DATABASE_URL`) across multiple services if you split API and worker later. |
| **Cron Jobs** | Run scheduled scripts later (backups, cleanup)—not required for the baseline app. |
| **TLS / custom domains** | Free TLS on `*.onrender.com`; attach your own domain in the service **Settings**. |

**Typical split for this repo:** keep **Neon** (or Render Postgres) for data, deploy **`backend/` as a Web Service**, deploy **Flutter web** via a **Docker Web Service** (root `Dockerfile`, recommended) or a **Static Site** only if you can produce `build/web` on Render (see section 5).

---

## 3. Prerequisites before deploying

- Code in a **Git** repository Render can access (GitHub/GitLab/Bitbucket).
- **Database URL:** `DATABASE_URL` for PostgreSQL (your Neon pooler URL with `sslmode=require` works with the existing API code).
- **API listens on `PORT`:** Render sets `PORT` automatically; your API should use `process.env.PORT` (your `server.js` should bind to that in production—verify before deploy).

---

## 4. Deploy the API (Web Service)

1. In the dashboard, click **New +** → **Web Service**.
2. Connect the repository that contains `wood-more` (or monorepo root), then select it.
3. Configure:
   - **Name:** e.g. `wood-more-api`.
   - **Region:** choose closest to users or to Neon.
   - **Branch:** `main` (or your default branch).
   - **Runtime:** **Docker** if deploying from `backend/Dockerfile`, or **Node** if you set root directory to `backend` and use build/start commands.
   - **Root directory:** `backend` (when using Node native build from subfolder).
   - **Docker:** If using Docker, set **Dockerfile path** to `backend/Dockerfile` (paths depend on repo layout).
4. **Instance type:** Free tier is fine for testing; paid tiers for production traffic.
5. **Environment variables** ( **Environment** tab ):
   - `DATABASE_URL` — your Neon (or Render Postgres) connection string.
   - Do **not** commit secrets; paste only in the dashboard or use **Secret Files** if you prefer.
6. Click **Create Web Service**. Wait for the first build and deploy.
7. Note the service URL, e.g. `https://wood-more-api.onrender.com`.

**Health checks:** Optional—add a path your API exposes (e.g. `GET /`) so Render can verify the service is up.

---

## 5. Deploy the Flutter web app

### 5a. Recommended: Web Service (Docker) — full Flutter build on Render

Render’s default build machines for **Static Site** do **not** ship with the Flutter SDK, so `flutter` commands usually fail there. This repo’s root **`Dockerfile`** already runs `flutter build web` inside the image and serves files with nginx.

**Shortcut:** use the repo’s **`render.yaml`** (**New +** → **Blueprint**) to create both Docker services, or follow the steps below manually.

1. **New +** → **Web Service** (not Static Site).
2. Connect repo **`mhelaitrailer-droid/wood-more`** (or your fork), branch **`main`**.
3. **Root directory:** leave **empty** if `pubspec.yaml` is at the repository root; if the app lives in a subfolder, set that folder here.
4. **Runtime:** **Docker**.
5. **Dockerfile path:** `Dockerfile` (repo root).
6. In the service **Settings**, set **Docker / Instance** details as Render prompts; ensure the service listens on the port Render expects (often **80** for this nginx image—confirm **Health Check Path** if you add one, e.g. `/`).
7. Before building the image, set **`web/config.json`** `apiBaseUrl` to your live API URL (see section 6). On web, the app loads **`/config.json`** from the same origin as the site; `docker-compose` uses a bind mount of `config.api.json` over `config.json`, but the root **`Dockerfile`** does not—production URL must be in **`web/config.json`** (or you extend the Dockerfile to copy a Render-specific config).

This path matches “build like Docker Compose’s `app` service” without needing Flutter on a Static Site builder.

### 5b. Static Site (only if `build/web` is produced on Render)

Use this when you are sure the **build** step can run `flutter` (custom image, Nixpacks with Flutter, or the build command is replaced by something that only publishes prebuilt files).

| Field | Value |
|--------|--------|
| **Root directory** | Empty if `pubspec.yaml` is at repo root; otherwise the app subfolder. |
| **Build command** | `flutter pub get && flutter build web --release` — do not type a leading dollar sign; that is a shell prompt, not part of the command. |
| **Publish directory** | **`build/web`** (required; leaving it blank will fail or publish the wrong folder). |

**Important:** On a normal Render **Static Site**, `flutter` is **not** installed. The build will error with “command not found” unless you change the approach. Prefer **5a (Docker Web Service)**, or build in **GitHub Actions** and deploy only the `build/web` artifact (e.g. push `build/web` to a branch or use an action that uploads to Render).

### 5c. Database and Static Sites

A **Static Site** has **no** server-side runtime: it cannot read `DATABASE_URL` or run `docker-compose`. The browser talks only to **HTTPS endpoints** you configure (your **API Web Service**). Keep **`DATABASE_URL`** on the **API** service only.

---

## 6. Frontend API URL (`config.api.json`)

Locally, `config.api.json` may use a relative path such as `/api` when nginx proxies to the API. On Render, the static site and API usually have **different hostnames**, so the Flutter build must use the **full public API URL**, for example:

```json
{"apiBaseUrl": "https://wood-more-api.onrender.com"}
```

Rebuild the web app after changing this, then redeploy the static site (or Docker image). Adjust if your client code expects a trailing path or `/api` prefix—match what `server.js` actually exposes.

---

## 7. CORS

If the browser calls the API from another origin (static site on `*.onrender.com` vs API hostname), ensure `server.js` **CORS** allows your static site origin. Update CORS settings if you see blocked requests in the browser console.

---

## 8. Optional: Render PostgreSQL instead of Neon

1. **New +** → **PostgreSQL**. Create the database.
2. Copy the **External Database URL** (or internal URL if API is also on Render in the same region/account—follow Render docs).
3. Set `DATABASE_URL` on the Web Service to that URL.
4. Run migrations / load schema: execute `init-db.sql` once against the new DB (Render shell, local `psql`, or a one-off script).

---

## 9. Day-to-day use of the dashboard

- **Logs:** Stream runtime logs for debugging.
- **Shell:** Open a shell into the running Web Service (paid plans / feature availability per Render).
- **Manual deploy:** **Manual Deploy** → deploy latest commit.
- **Environment:** Edit env vars and **restart** the service to apply.
- **Alerts:** Configure notifications for deploy failures or downtime.

### Branch (e.g. `main` vs `feature/render`)

Under the service **Settings** → **Build** (or equivalent), **Branch** controls which Git ref is cloned for each deploy. Your team can deploy from **`feature/render`** until you merge; Docker Web Services and Blueprints use the same branch setting. After merge, switch the branch to **`main`** (or your release branch) so production tracks stable code.

### Auto-deploy and deploy hooks

- **Auto-Deploy:** Usually **On commit**—every push to the connected branch triggers a build. You can disable it and deploy only from the dashboard when you need tighter control.
- **Deploy Hook:** A secret URL you can call from **GitHub Actions**, scripts, or another CI system to trigger a deploy without relying on a git push.

### Build filters

**Included paths** / **Ignored paths** limit which file changes trigger a deploy. Useful to **ignore** paths such as `RENDER.MD`, `README.md`, or docs-only edits so documentation changes do not queue a full Flutter Docker build.

### Custom domains and Render URL

**Custom Domains** adds your own hostname; the **Render subdomain** (e.g. `https://wood-more-static.onrender.com`) stays available unless you turn it off. For production, prefer a **Docker Web Service** hostname for the app and a separate one for the API.

### PR previews

**PR Previews** can spin up temporary instances for pull requests (automatic or only when the PR title contains a marker such as `[render preview]`). Optional; turn on when you want review apps. Preview environments can clone a **group** of services (e.g. API + DB) per PR—see [Render docs](https://render.com/docs) for workspace limits.

---

## 10. Summary

- **Sign up** at Render and connect Git.
- Use a **Web Service** for **`backend/`** with `DATABASE_URL` pointing at Neon or Render Postgres.
- Use a **Docker Web Service** (or Blueprint **`render.yaml`**) for the Flutter web build; use a **Static Site** only with **pre-built** `build/web`. Set **`apiBaseUrl`** in **`web/config.json`** to your live API URL.
- Manage secrets only in the dashboard or your CI secrets—never commit production `DATABASE_URL` to the repo.

For official, up-to-date UI steps, refer to [Render Documentation](https://render.com/docs).
