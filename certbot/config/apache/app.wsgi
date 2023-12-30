import sys
import os

# Add your project directory to the sys.path
project_home = '/usr/src/app'
if project_home not in sys.path:
    sys.path.insert(0, project_home)

# Set environment variable to tell the app where the Flask app is
os.environ['FLASK_APP'] = 'app.py'

from app import app as application  # noqa
