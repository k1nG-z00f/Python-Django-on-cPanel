#!/bin/bash
# cPanel Django one-time setup script
# Usage: bash setup_cpanel.sh [dev|prod]
# Run once via SSH after cloning the project to ~/repo on the cPanel account.

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
        DJANGO_DEBUG="True"
        ;;
    prod)
        CPANEL_USER="mvpcodeworks"
        DJANGO_SETTINGS_MODULE="mvpcodeworks.settings"
        DJANGO_DEBUG="False"
        ;;
esac

REPO_DIR="/home/${CPANEL_USER}/repo"
APP_DIR="/home/${CPANEL_USER}/public_html"
VENV_DIR="${APP_DIR}/.venv"
TMP_DIR="${APP_DIR}/tmp"

echo "==> Environment  : $ENV"
echo "==> cPanel user  : $CPANEL_USER"
echo "==> App directory: $APP_DIR"
echo ""

# ---------------------------------------------------------------------------
# Ensure tmp/ exists (required for Passenger restart)
# ---------------------------------------------------------------------------
mkdir -p "$TMP_DIR"

# ---------------------------------------------------------------------------
# Sync repo → public_html (first-time copy)
# ---------------------------------------------------------------------------
if [ -d "$REPO_DIR" ]; then
    echo "==> Syncing repo to public_html..."
    rsync -av --exclude='.git' "${REPO_DIR}/" "${APP_DIR}/"
else
    echo "WARNING: $REPO_DIR not found — skipping sync. Ensure code is in $APP_DIR."
fi

# ---------------------------------------------------------------------------
# Virtual environment
# ---------------------------------------------------------------------------
if [ ! -d "$VENV_DIR" ]; then
    echo "==> Creating virtual environment..."
    virtualenv --python=python3 "$VENV_DIR"
else
    echo "==> Virtual environment already exists, skipping creation."
fi

echo "==> Activating virtual environment..."
# shellcheck disable=SC1090
source "${VENV_DIR}/bin/activate"

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------
echo "==> Installing/upgrading dependencies..."
pip install --upgrade pip
pip install -r "${APP_DIR}/requirements.txt"

# ---------------------------------------------------------------------------
# .env file
# ---------------------------------------------------------------------------
ENV_FILE="${APP_DIR}/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "==> Creating skeleton .env file (edit before use)..."
    cat > "$ENV_FILE" <<EOF
DJANGO_SECRET_KEY=CHANGE_ME_$(openssl rand -hex 32)
DJANGO_DEBUG=${DJANGO_DEBUG}
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1
DJANGO_SETTINGS_MODULE=${DJANGO_SETTINGS_MODULE}
EOF
    echo "    Written to $ENV_FILE — update DJANGO_SECRET_KEY and DJANGO_ALLOWED_HOSTS."
else
    echo "==> .env file already exists, skipping creation."
fi

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
echo " Setup complete for ENV=$ENV"
echo "============================================================"
echo "  App root   : $APP_DIR"
echo "  Startup    : passenger_wsgi.py"
echo "  Venv       : $VENV_DIR"
echo ""
echo "  Next steps:"
echo "  1. Edit $ENV_FILE and set a strong DJANGO_SECRET_KEY"
echo "     and correct DJANGO_ALLOWED_HOSTS for your domain."
echo "  2. In cPanel -> Setup Python App:"
echo "     - App root: $APP_DIR"
echo "     - Startup file: passenger_wsgi.py"
echo "     - Add env vars from $ENV_FILE"
echo "============================================================"
