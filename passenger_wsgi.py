import sys
import os

# Add the application directory to the path
INTERP = os.path.join(os.environ['HOME'], 'mvpcodeworks.com', 'venv', 'bin', 'python3')
if sys.executable != INTERP:
    os.execl(INTERP, INTERP, *sys.argv)

sys.path.insert(0, os.path.join(os.environ['HOME'], 'mvpcodeworks.com'))

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'mvpcodeworks.settings')

from django.core.wsgi import get_wsgi_application
application = get_wsgi_application()
