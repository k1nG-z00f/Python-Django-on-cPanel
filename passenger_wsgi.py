import sys
import os

# Derive home dir from the actual user running the process so this file
# works unchanged on both the dev (devmvpcodeworks) and prod (mvpcodeworks)
# cPanel accounts.
APP_DIR = os.path.dirname(os.path.abspath(__file__))

INTERP = os.path.join(APP_DIR, '.venv', 'bin', 'python3')
if sys.executable != INTERP:
    os.execl(INTERP, INTERP, *sys.argv)

sys.path.insert(0, APP_DIR)

# Load .env so environment variables are available before Django initialises.
try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(APP_DIR, '.env'))
except ImportError:
    pass  # dotenv not yet installed; rely on cPanel env vars

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'app.settings')

from django.core.wsgi import get_wsgi_application  # noqa: E402
application = get_wsgi_application()
