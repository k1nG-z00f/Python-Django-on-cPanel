#!/bin/bash
# cPanel Django deploy script
# Usage: bash deploy.sh [dev|prod] [--setup]
#
#   dev|prod   Target environment (default: dev)
#   --setup    Run first-time setup (create venv, .env skeleton) before deploying
#
# All project-specific settings live in deploy.config — edit that file, not this one.
#
# Examples:
#   bash deploy.sh prod --setup   # first-time provision + deploy on prod
#   bash deploy.sh prod           # routine deploy on prod
#   bash deploy.sh dev            # routine deploy on dev

set -e

# ---------------------------------------------------------------------------
# Load project config
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/deploy.config"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: deploy.config not found at $CONFIG_FILE"
    echo "       Copy deploy.config.example to deploy.config and fill in your values."
    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

# Validate required config keys
for var in DEV_CPANEL_USER PROD_CPANEL_USER DEV_HOSTS PROD_HOSTS DJANGO_SETTINGS_MODULE; do
    if [ -z "${!var}" ]; then
        echo "ERROR: $var is not set in deploy.config"
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
ENV="${1:-dev}"
SETUP_MODE=false
for arg in "$@"; do
    [[ "$arg" == "--setup" ]] && SETUP_MODE=true
done

if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
    echo "ERROR: ENV must be 'dev' or 'prod'. Got: $ENV"
    exit 1
fi

# ---------------------------------------------------------------------------
# Resolve per-environment values
# ---------------------------------------------------------------------------
case "$ENV" in
    dev)
        CPANEL_USER="$DEV_CPANEL_USER"
        DJANGO_DEBUG="True"
        DEFAULT_HOSTS="$DEV_HOSTS"
        ;;
    prod)
        CPANEL_USER="$PROD_CPANEL_USER"
        DJANGO_DEBUG="False"
        DEFAULT_HOSTS="$PROD_HOSTS"
        ;;
esac

REPO_DIR="/home/${CPANEL_USER}/repo"
APP_DIR="/home/${CPANEL_USER}/public_html"
VENV_DIR="${APP_DIR}/.venv"
TMP_DIR="${APP_DIR}/tmp"
ENV_FILE="${APP_DIR}/.env"

echo "============================================================"
echo " ENV=$ENV | SETUP=$SETUP_MODE | USER=$CPANEL_USER"
echo " App: $APP_DIR"
echo "============================================================"

# ---------------------------------------------------------------------------
# Ensure tmp/ exists (required for Passenger restart)
# ---------------------------------------------------------------------------
mkdir -p "$TMP_DIR"

# ---------------------------------------------------------------------------
# Pull latest code
# ---------------------------------------------------------------------------
if [ ! -d "$REPO_DIR/.git" ]; then
    echo "ERROR: Git repo not found at $REPO_DIR"
    echo "       Clone it first: git clone <url> $REPO_DIR"
    exit 1
fi

echo "==> Pulling latest code..."
git -C "$REPO_DIR" pull --ff-only

# ---------------------------------------------------------------------------
# Sync repo → public_html
# Excludes .env and db.sqlite3 to preserve live secrets and data.
# ---------------------------------------------------------------------------
echo "==> Syncing files to $APP_DIR..."
rsync -a \
    --exclude='.git' \
    --exclude='.env' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.venv' \
    --exclude='db.sqlite3' \
    "${REPO_DIR}/" "${APP_DIR}/"

# ---------------------------------------------------------------------------
# First-time setup: create venv and .env skeleton
# ---------------------------------------------------------------------------
if $SETUP_MODE; then
    if [ ! -d "$VENV_DIR" ]; then
        echo "==> Creating virtual environment..."
        virtualenv --python=python3 "$VENV_DIR"
    else
        echo "==> Virtual environment already exists, skipping creation."
    fi

    if [ ! -f "$ENV_FILE" ]; then
        echo "==> Creating skeleton .env file..."
        cat > "$ENV_FILE" <<EOF
DJANGO_SECRET_KEY=CHANGE_ME_$(openssl rand -hex 32)
DJANGO_DEBUG=${DJANGO_DEBUG}
DJANGO_ALLOWED_HOSTS=${DEFAULT_HOSTS}
DJANGO_SETTINGS_MODULE=${DJANGO_SETTINGS_MODULE}
EOF
        echo "    Written to $ENV_FILE"
        echo "    *** Update DJANGO_SECRET_KEY before going live! ***"
    else
        echo "==> .env already exists, skipping creation."
    fi
fi

# ---------------------------------------------------------------------------
# Activate venv (must exist by this point)
# ---------------------------------------------------------------------------
if [ ! -f "${VENV_DIR}/bin/activate" ]; then
    echo "ERROR: Virtual environment not found at $VENV_DIR"
    echo "       Run: bash deploy.sh $ENV --setup"
    exit 1
fi

# shellcheck disable=SC1090
source "${VENV_DIR}/bin/activate"

# ---------------------------------------------------------------------------
# Install / upgrade dependencies
# ---------------------------------------------------------------------------
echo "==> Installing/upgrading dependencies..."
pip install --quiet --upgrade pip
pip install --quiet -r "${APP_DIR}/requirements.txt"

# ---------------------------------------------------------------------------
# Django management commands
# ---------------------------------------------------------------------------
export DJANGO_SETTINGS_MODULE="${DJANGO_SETTINGS_MODULE}"

echo "==> Running database migrations..."
python "${APP_DIR}/manage.py" migrate --noinput

echo "==> Collecting static files..."
python "${APP_DIR}/manage.py" collectstatic --noinput

# ---------------------------------------------------------------------------
# Restart Passenger
# ---------------------------------------------------------------------------
echo "==> Restarting Passenger app..."
touch "${TMP_DIR}/restart.txt"

echo ""
echo "============================================================"
if $SETUP_MODE; then
    echo " Setup + Deploy complete for ENV=$ENV"
    echo ""
    echo " Next steps:"
    echo "  1. Edit $ENV_FILE — set a strong DJANGO_SECRET_KEY"
    echo "  2. In cPanel -> Setup Python App:"
    echo "     - App root    : $APP_DIR"
    echo "     - Startup file: passenger_wsgi.py"
    echo "     - Add env vars from $ENV_FILE"
else
    echo " Deploy complete for ENV=$ENV"
fi
echo "============================================================"

REPO_DIR="/home/${CPANEL_USER}/repo"
APP_DIR="/home/${CPANEL_USER}/public_html"
VENV_DIR="${APP_DIR}/.venv"
TMP_DIR="${APP_DIR}/tmp"
ENV_FILE="${APP_DIR}/.env"

echo "============================================================"
echo " ENV=$ENV | SETUP=$SETUP_MODE | USER=$CPANEL_USER"
echo " App: $APP_DIR"
echo "============================================================"

# ---------------------------------------------------------------------------
# Ensure tmp/ exists (required for Passenger restart)
# ---------------------------------------------------------------------------
mkdir -p "$TMP_DIR"

# ---------------------------------------------------------------------------
# Pull latest code
# ---------------------------------------------------------------------------
if [ ! -d "$REPO_DIR/.git" ]; then
    echo "ERROR: Git repo not found at $REPO_DIR"
    echo "       Clone it first: git clone <url> $REPO_DIR"
    exit 1
fi

echo "==> Pulling latest code..."
git -C "$REPO_DIR" pull --ff-only

# ---------------------------------------------------------------------------
# Sync repo → public_html
# Excludes .env and db.sqlite3 to preserve live secrets and data.
# ---------------------------------------------------------------------------
echo "==> Syncing files to $APP_DIR..."
rsync -a \
    --exclude='.git' \
    --exclude='.env' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.venv' \
    --exclude='db.sqlite3' \
    "${REPO_DIR}/" "${APP_DIR}/"

# ---------------------------------------------------------------------------
# First-time setup: create venv and .env skeleton
# ---------------------------------------------------------------------------
if $SETUP_MODE; then
    if [ ! -d "$VENV_DIR" ]; then
        echo "==> Creating virtual environment..."
        virtualenv --python=python3 "$VENV_DIR"
    else
        echo "==> Virtual environment already exists, skipping creation."
    fi

    if [ ! -f "$ENV_FILE" ]; then
        echo "==> Creating skeleton .env file..."
        cat > "$ENV_FILE" <<EOF
DJANGO_SECRET_KEY=CHANGE_ME_$(openssl rand -hex 32)
DJANGO_DEBUG=${DJANGO_DEBUG}
DJANGO_ALLOWED_HOSTS=${DEFAULT_HOSTS}
DJANGO_SETTINGS_MODULE=${DJANGO_SETTINGS_MODULE}
EOF
        echo "    Written to $ENV_FILE"
        echo "    *** Update DJANGO_SECRET_KEY before going live! ***"
    else
        echo "==> .env already exists, skipping creation."
    fi
fi

# ---------------------------------------------------------------------------
# Activate venv (must exist by this point)
# ---------------------------------------------------------------------------
if [ ! -f "${VENV_DIR}/bin/activate" ]; then
    echo "ERROR: Virtual environment not found at $VENV_DIR"
    echo "       Run: bash deploy.sh $ENV --setup"
    exit 1
fi

# shellcheck disable=SC1090
source "${VENV_DIR}/bin/activate"

# ---------------------------------------------------------------------------
# Install / upgrade dependencies
# ---------------------------------------------------------------------------
echo "==> Installing/upgrading dependencies..."
pip install --quiet --upgrade pip
pip install --quiet -r "${APP_DIR}/requirements.txt"

# ---------------------------------------------------------------------------
# Django management commands
# ---------------------------------------------------------------------------
export DJANGO_SETTINGS_MODULE="${DJANGO_SETTINGS_MODULE}"

echo "==> Running database migrations..."
python "${APP_DIR}/manage.py" migrate --noinput

echo "==> Collecting static files..."
python "${APP_DIR}/manage.py" collectstatic --noinput

# ---------------------------------------------------------------------------
# Restart Passenger
# ---------------------------------------------------------------------------
echo "==> Restarting Passenger app..."
touch "${TMP_DIR}/restart.txt"

echo ""
echo "============================================================"
if $SETUP_MODE; then
    echo " Setup + Deploy complete for ENV=$ENV"
    echo ""
    echo " Next steps:"
    echo "  1. Edit $ENV_FILE — set a strong DJANGO_SECRET_KEY"
    echo "  2. In cPanel -> Setup Python App:"
    echo "     - App root    : $APP_DIR"
    echo "     - Startup file: passenger_wsgi.py"
    echo "     - Add env vars from $ENV_FILE"
else
    echo " Deploy complete for ENV=$ENV"
fi
echo "============================================================"
