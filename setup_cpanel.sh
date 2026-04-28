#!/bin/bash
# cPanel Django setup script
# Run this once via SSH after uploading the project to your cPanel home directory

APP_DIR="/home/devmvpcodeworks/public_html"
VENV_DIR="$APP_DIR/.venv"

echo "==> Creating virtual environment..."
virtualenv --python=python3 "$VENV_DIR"

echo "==> Activating virtual environment..."
source "$VENV_DIR/bin/activate"

echo "==> Installing dependencies..."
pip install -r "$APP_DIR/requirements.txt"

echo "==> Collecting static files..."
python "$APP_DIR/manage.py" collectstatic --noinput

echo "==> Running migrations..."
python "$APP_DIR/manage.py" migrate

echo ""
echo "Setup complete. Next steps:"
echo "  1. In cPanel -> Setup Python App, point the app root to: $APP_DIR"
echo "     and set the startup file to: passenger_wsgi.py"
echo "  2. Set DJANGO_SECRET_KEY and DJANGO_ALLOWED_HOSTS environment variables"
echo "     in cPanel -> Setup Python App -> Environment Variables"
echo "  3. Touch $APP_DIR/tmp/restart.txt to restart the app"
