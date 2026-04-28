import sys
import os

APP_DIR = '/home/devmvpcodeworks/public_html'

INTERP = os.path.join(APP_DIR, '.venv', 'bin', 'python3')
if sys.executable != INTERP:
    os.execl(INTERP, INTERP, *sys.argv)

sys.path.insert(0, APP_DIR)

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'mvpcodeworks.settings')

from django.core.wsgi import get_wsgi_application
application = get_wsgi_application()
