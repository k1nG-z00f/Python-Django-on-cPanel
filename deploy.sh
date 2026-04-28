#!/bin/bash
# cPanel Django deploy script
# Usage: bash deploy.sh [dev|prod]
# Run via SSH or a cPanel cron job to pull latest code and restart the app.

set -e

# ---------------------------------------------------------------------------
# Resolve environment
# ---------------------------------------------------------------------------
ENV="${1:-dev}"
if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
    echo "ERROR: ENV must be 'dev' or 'prod'. Got: $ENV"
    exit 1
fi

case "$ENV" in
    dev)
        CPANEL_USER="devmvpcodeworks"
        DJANGO_SETTINGS_MODULE="mvpcodeworks.settings"
        ;;
    prod)
        CPANEL_USER="mvpcodeworks"
        DJANGO_SETTINGS_MODULE="mvpcodeworks.settings"
        ;;
esac

REPO_DIR="/home/${CPANEL_USER}/repo"
APP_DIR="/home/${CPANEL_USER}/public_html"
VENV_DIR="${APP_DIR}/.venv"
TMP_DIR="${APP_DIR}/tmp"

echo "==> Deploying ENV=$ENV to $APP_DIR"

# ---------------------------------------------------------------------------
# Pull latest code into repo dir
# ---------------------------------------------------------------------------
if [ ! -d "$REPO_DIR/.git" ]; then
    echo "ERROR: Git repo not found at $REPO_DIR"
    echo "       Clone it first: git clone <url> $REPO_DIR"
    exit 1
fi

echo "==> Pulling latest code..."
git -C "$REPO_DIR" pull --ff-only

# ---------------------------------------------------------------------------
# Sync repo → public_html (exclude .git and .env to preserve secrets)
# ---------------------------------------------------------------------------
echo "==> Syncing files to public_html..."
rsync -av \
    --exclude='.git' \
    --exclude='.env' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.venv' \
    --exclude='db.sqlite3' \
    "${REPO_DIR}/" "${APP_DIR}/"

# ---------------------------------------------------------------------------
# Ensure tmp/ exists
# ---------------------------------------------------------------------------
mkdir -p "$TMP_DIR"

# ---------------------------------------------------------------------------
# Activate venv and update dependencies
# ---------------------------------------------------------------------------
if [ ! -f "${VENV_DIR}/bin/activate" ]; then
    echo "ERROR: Virtual environment not found at $VENV_DIR"
    echo "       Run setup_cpanel.sh $ENV first."
    exit 1
fi

# shellcheck disable=SC1090
source "${VENV_DIR}/bin/activate"

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
echo " Deploy complete for ENV=$ENV"
echo " App: $APP_DIR"
echo "============================================================"
