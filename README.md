# Django cPanel Template

A GitHub template for deploying a Django application to **cPanel shared hosting** via Phusion Passenger (WSGI). Supports **dev** and **prod** environments out of the box, with a single `deploy.sh` script that handles both first-time provisioning and routine deployments.

[![Django CI](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/django-ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/django-ci.yml)

---

## Using this template

Click **"Use this template"** on GitHub, then follow these steps to customise it for your project.

### 1. Rename the Django app package

The Django project lives in `app/`. Rename it to match your app name (e.g. `myapp/`):

```bash
mv app myapp
```

Then update every reference to `app` in these files:

| File | Change |
|---|---|
| `manage.py` | `'app.settings'` → `'myapp.settings'` |
| `passenger_wsgi.py` | `'app.settings'` → `'myapp.settings'` |
| `app/settings.py` | `ROOT_URLCONF`, `WSGI_APPLICATION`, `TEMPLATES DIRS` |
| `app/wsgi.py` | settings module default |
| `deploy.config` | `DJANGO_SETTINGS_MODULE` |

### 2. Configure deploy.config

Edit `deploy.config` — this is the **only file** with project-specific deployment values:

```bash
DEV_CPANEL_USER="devmyproject"       # cPanel username for staging
PROD_CPANEL_USER="myproject"         # cPanel username for production
DEV_HOSTS="dev.myproject.com,localhost,127.0.0.1"
PROD_HOSTS="myproject.com,www.myproject.com,localhost,127.0.0.1"
DJANGO_SETTINGS_MODULE="myapp.settings"
```

### 3. Update the CI workflow

In `.github/workflows/django-ci.yml`, replace `app.settings` with your renamed module if you renamed the app package.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Django 4.2 |
| WSGI server | Phusion Passenger (cPanel) |
| Static files | WhiteNoise |
| Environment | python-dotenv |
| Database | SQLite (default) |
| CI | GitHub Actions |
| Python | 3.10 / 3.11 / 3.12 |

---

## Project Structure

```
.
├── .github/
│   ├── workflows/
│   │   └── django-ci.yml          # CI: test, migrate check, collectstatic
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml
│   │   └── feature_request.yml
│   └── PULL_REQUEST_TEMPLATE.md
├── app/                       # Django project package — rename to your app
│   ├── settings.py                # All config via environment variables
│   ├── urls.py
│   ├── wsgi.py
│   └── templates/
├── static/                        # Source static assets
├── deploy.config                  # ✏️  Project-specific deploy settings (edit this)
├── deploy.sh                      # Unified setup + deploy script
├── manage.py
├── passenger_wsgi.py              # Passenger entry point (env-aware)
├── requirements.txt
├── .htaccess                      # Passenger directives (app type + startup file)
└── .env.example                   # Copy to .env and fill in secrets
```

---

## Local Development

```bash
# 1. Clone / create from template
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO

# 2. Create virtual environment
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Configure environment
cp .env.example .env
# Edit .env — set DJANGO_SECRET_KEY, DJANGO_DEBUG=True

# 5. Apply migrations and run
python manage.py migrate
python manage.py runserver
```

Open [http://127.0.0.1:8000](http://127.0.0.1:8000).

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `DJANGO_SECRET_KEY` | ✅ | Long random string — never commit the real value |
| `DJANGO_DEBUG` | ✅ | `True` for dev, `False` for prod |
| `DJANGO_ALLOWED_HOSTS` | ✅ | Comma-separated hostnames |
| `DJANGO_SETTINGS_MODULE` | — | Defaults to `app.settings` |

Generate a strong secret key:

```bash
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

> `.env` and `.env.production` are in `.gitignore` and are never synced to `public_html` by `deploy.sh`.

---

## Deployment

### Prerequisites

- SSH access to the cPanel account
- Git cloned to `~/repo` on the server:

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git ~/repo
```

- `deploy.config` committed and pushed with your cPanel usernames and domains

### First-Time Setup (`--setup`)

Run once per environment — creates the venv, installs deps, generates `.env`, migrates, collects static, restarts Passenger:

```bash
bash ~/repo/deploy.sh prod --setup
bash ~/repo/deploy.sh dev --setup
```

After running, **edit `.env` on the server** to set a strong secret key:

```bash
nano ~/public_html/.env
touch ~/public_html/tmp/restart.txt
```

### Routine Deploys

```bash
bash ~/repo/deploy.sh prod
```

Each run: `git pull` → `rsync` → `pip install` → `migrate` → `collectstatic` → restart Passenger.

### Cron-Based Auto-Deploy

In **cPanel → Cron Jobs**:

```
*/15 * * * * /bin/bash /home/myproject/repo/deploy.sh prod >> /home/myproject/logs/deploy.log 2>&1
```

---

## cPanel Configuration

In **cPanel → Setup Python App**:

| Setting | Value |
|---|---|
| Python version | 3.x (latest available) |
| Application root | `/home/myproject/public_html` |
| Application startup file | `passenger_wsgi.py` |
| Application entry point | `application` |

> `PassengerEnabled On` must be set by cPanel here — it cannot live in `.htaccess`. The `.htaccess` in this repo only contains `PassengerAppType` and `PassengerStartupFile`, which are allowed in htaccess context.

---

## Static Files

- Source files: `static/` (committed)
- Collected output: `staticfiles/` (generated, gitignored)
- Served by WhiteNoise with compression + long-lived cache headers
- Runs automatically on every deploy

---

## Database

SQLite by default (`db.sqlite3`), excluded from `rsync` to protect live data. `migrate` runs on every deploy.

For production workloads requiring concurrent writes, switch to MySQL:

```python
# app/settings.py
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': os.environ.get('DB_NAME'),
        'USER': os.environ.get('DB_USER'),
        'PASSWORD': os.environ.get('DB_PASSWORD'),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '3306'),
    }
}
```

Add `mysqlclient` to `requirements.txt`.

---

## CI / GitHub Actions

The workflow at `.github/workflows/django-ci.yml` runs on every push and pull request to `main`:

- Installs dependencies
- Checks for unapplied migrations
- Runs `python manage.py test`
- Dry-runs `collectstatic`
- Tests against Python 3.10, 3.11, and 3.12

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| HTTP 400 Bad Request | Domain not in `ALLOWED_HOSTS` | Add domain to `DJANGO_ALLOWED_HOSTS` in `~/.env`, then `touch tmp/restart.txt` |
| HTTP 500 after deploy | Migration error or import error | SSH in, activate venv, run `python manage.py migrate` and check output |
| Static files 404 | `collectstatic` not run | Run `python manage.py collectstatic --noinput` |
| Passenger not starting | `PassengerEnabled On` in `.htaccess` | Remove it — configure via cPanel → Setup Python App |
| Changes not live | Passenger not restarted | `touch ~/public_html/tmp/restart.txt` |
| Venv not found | `--setup` never run | Run `bash deploy.sh prod --setup` |
| `deploy.config not found` | File missing from repo | Commit `deploy.config` with your values |

---

## License

See [LICENSE](LICENSE).

---

## Table of Contents

- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Local Development](#local-development)
- [Environment Variables](#environment-variables)
- [Deployment](#deployment)
  - [Prerequisites](#prerequisites)
  - [First-Time Setup](#first-time-setup)
  - [Routine Deploys](#routine-deploys)
  - [Cron-Based Auto-Deploy](#cron-based-auto-deploy)
- [cPanel Configuration](#cpanel-configuration)
- [Static Files](#static-files)
- [Database](#database)
- [Troubleshooting](#troubleshooting)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Django 4.2 |
| WSGI server | Phusion Passenger (cPanel) |
| Static files | WhiteNoise |
| Environment | python-dotenv |
| Database | SQLite (default) |
| Python | 3.x (via `virtualenv`) |

---

## Project Structure

```
MVPCodeworks.com/
├── deploy.sh               # Unified setup + deploy script
├── manage.py
├── passenger_wsgi.py       # Passenger entry point (auto-detects APP_DIR)
├── requirements.txt
├── .htaccess               # Passenger directives (app type + startup file)
├── .env.example            # Template — copy to .env and fill in values
├── mvpcodeworks/
│   ├── settings.py         # All config driven by environment variables
│   ├── urls.py
│   ├── wsgi.py
│   └── templates/
└── static/                 # Source static assets (collected to staticfiles/)
```

---

## Local Development

```bash
# 1. Clone the repo
git clone https://github.com/k1nG-z00f/MVPCodeworks.com.git
cd MVPCodeworks.com

# 2. Create and activate a virtual environment
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Configure environment
cp .env.example .env
# Edit .env — set DJANGO_SECRET_KEY, DJANGO_DEBUG=True, DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1

# 5. Apply migrations and run
python manage.py migrate
python manage.py runserver
```

Open [http://127.0.0.1:8000](http://127.0.0.1:8000).

---

## Environment Variables

Copy `.env.example` to `.env` and set the following:

| Variable | Required | Description |
|---|---|---|
| `DJANGO_SECRET_KEY` | ✅ | Long random string — never commit the real value |
| `DJANGO_DEBUG` | ✅ | `True` for dev, `False` for prod |
| `DJANGO_ALLOWED_HOSTS` | ✅ | Comma-separated hostnames, e.g. `mvpcodeworks.com,www.mvpcodeworks.com` |
| `DJANGO_SETTINGS_MODULE` | — | Defaults to `mvpcodeworks.settings` |

> **Security:** `.env` and `.env.production` are in `.gitignore` and are never synced to `public_html` by `deploy.sh`. Set them once on the server and they persist across deployments.

Generate a strong secret key:

```bash
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

---

## Deployment

### Prerequisites

- SSH access to the cPanel account
- Git installed on the server
- The repo cloned to `~/repo`:

```bash
git clone https://github.com/k1nG-z00f/MVPCodeworks.com.git ~/repo
```

### First-Time Setup

Run once per environment to create the virtual environment, install dependencies, generate a skeleton `.env`, run migrations, collect static files, and restart Passenger:

```bash
# Production
bash ~/repo/deploy.sh prod --setup

# Development / staging
bash ~/repo/deploy.sh dev --setup
```

After `--setup`, **edit the generated `.env`** and replace the placeholder secret key:

```bash
nano ~/public_html/.env
# Set DJANGO_SECRET_KEY to a strong random value
```

Then restart Passenger to pick up the new key:

```bash
touch ~/public_html/tmp/restart.txt
```

### Routine Deploys

For every subsequent deployment (no `--setup` flag needed):

```bash
bash ~/repo/deploy.sh prod
```

This will:
1. `git pull --ff-only` in `~/repo`
2. `rsync` changed files to `~/public_html/` (skips `.env`, `.git`, `db.sqlite3`, `.venv`)
3. `pip install` any new/updated dependencies
4. `python manage.py migrate --noinput`
5. `python manage.py collectstatic --noinput`
6. `touch tmp/restart.txt` to reload Passenger

### Cron-Based Auto-Deploy

In **cPanel → Cron Jobs**, add an entry to deploy automatically (e.g. every 15 minutes):

```
*/15 * * * * /bin/bash /home/mvpcodeworks/repo/deploy.sh prod >> /home/mvpcodeworks/logs/deploy.log 2>&1
```

---

## cPanel Configuration

In **cPanel → Setup Python App**:

| Setting | Value |
|---|---|
| Python version | 3.x (latest available) |
| Application root | `/home/mvpcodeworks/public_html` |
| Application startup file | `passenger_wsgi.py` |
| Application entry point | `application` |

> **Important:** `PassengerEnabled On` must be set by cPanel via this UI — it is a VirtualHost-level Apache directive and cannot live in `.htaccess`. The `.htaccess` in this repo only contains the safe, htaccess-allowed directives (`PassengerAppType`, `PassengerStartupFile`).

---

## Static Files

Static assets are served by **WhiteNoise** with compression and cache headers baked in.

- Source files: `static/` (committed to the repo)
- Collected output: `staticfiles/` (generated on deploy, gitignored)
- URL prefix: `/static/`

`collectstatic` runs automatically on every deploy. To run manually:

```bash
python manage.py collectstatic --noinput
```

---

## Database

The default database is **SQLite** (`db.sqlite3`), stored in the project root on the server. It is excluded from `rsync` syncs to prevent deployments from overwriting live data.

`migrate` runs automatically on every deploy. To run manually:

```bash
python manage.py migrate
```

> For production workloads requiring concurrent writes, consider migrating to MySQL (available on cPanel) by updating the `DATABASES` setting in `settings.py` and adding `mysqlclient` to `requirements.txt`.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| HTTP 400 Bad Request | Domain not in `ALLOWED_HOSTS` | Add domain to `DJANGO_ALLOWED_HOSTS` in `~/.env`, then `touch tmp/restart.txt` |
| HTTP 500 after deploy | Migration error or import error | SSH in, activate venv, run `python manage.py migrate` manually and check output |
| Static files returning 404 | `collectstatic` not run or wrong `STATIC_ROOT` | Run `python manage.py collectstatic --noinput` |
| Passenger not starting | `.htaccess` has `PassengerEnabled On` | Remove it — configure via cPanel → Setup Python App instead |
| Changes not live after deploy | Passenger not restarted | `touch ~/public_html/tmp/restart.txt` |
| `venv` not found error | `--setup` never run | Run `bash deploy.sh prod --setup` |

---

## License

See [LICENSE](LICENSE).