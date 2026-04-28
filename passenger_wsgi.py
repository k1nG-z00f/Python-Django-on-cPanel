import sys
import os

# Absolute path to the virtual environment python interpreter
INTERP = os.path.join(os.environ['HOME'], 'devmvpcodeworks', 'public_html', '.venv', 'bin', 'python3')
if sys.executable != INTERP:
    os.execl(INTERP, INTERP, *sys.argv)

# Add the project root (the directory containing the 'mvpcodeworks' package) to path
sys.path.insert(0, os.path.join(os.environ['HOME'], 'devmvpcodeworks', 'public_html'))

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'mvpcodeworks.settings')

from django.core.wsgi import get_wsgi_application
application = get_wsgi_application()
