from flask import Flask, render_template, request, redirect, url_for, session
from google.cloud import storage
from datetime import timedelta
from dotenv import load_dotenv
import os
import ssl
import logging

# context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
# context.load_cert_chain('/etc/apache2/ssl/my-self-signed-certificate.crt', 'pkcs11:object=resec-hsm-key')

# Load environment variables from .env file
load_dotenv()

app = Flask(__name__)
app.secret_key = 'tsadok_secret_key'  # Set a secret key for session management

# Mock user data for simplicity
users = {
    "user1": "password1",
    "user2": "password2"
}

def set_logging():

    # Create a logger
    logger = logging.getLogger('my_logger')
    logger.setLevel(logging.DEBUG)  # Set to lowest level to capture all messages

    # Create file handler which logs debug messages
    fh = logging.FileHandler('debug.log')
    fh.setLevel(logging.DEBUG)  # Set level to debug to capture all messages for the file

    # Create console handler with a higher log level
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)  # Set level to info or higher for console

    # Create formatter and add it to the handlers
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    fh.setFormatter(formatter)
    ch.setFormatter(formatter)

    # Add the handlers to the logger
    logger.addHandler(fh)
    logger.addHandler(ch)

    # Test messages
    logger.debug('This is a debug message')
    logger.info('This is an info message')
    logger.warning('This is a warning message')
    logger.error('This is an error message')
    logger.critical('This is a critical message')

    return logger


def is_user_logged_in():
    return 'username' in session

@app.route('/')
def home():
    app.logger.info('Route / accessed')
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    app.logger.info('Route /login accessed')
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        if username in users and users[username] == password:
            session['username'] = username  # Store username in session
            return redirect(url_for('browse'))
        else:
            return "Invalid credentials", 401

    return render_template('login.html')

@app.route('/logout')
def logout():
    session.pop('username', None)  # Remove username from session
    return redirect(url_for('login'))

@app.route('/browse')
def browse():
    app.logger.info('Route /browse accessed')

    # Ensure the user is logged in
    if not is_user_logged_in():  # Replace with your actual login check
        logger.error("User not logged in")
        return redirect(url_for('login'))

    key_file_path = os.getenv('STORAGE_SERVICE_ACCOUNT_PRIVATE_KEY')
    if not os.path.exists(key_file_path):
        logger.error("STORAGE_SERVICE_ACCOUNT_PRIVATE_KEY environment variable not set")
        return "STORAGE_SERVICE_ACCOUNT_PRIVATE_KEY environment variable not set", 500

    # Initialize Google Cloud Storage client using explicit credentials (instead of application default credentials)
    client = storage.Client.from_service_account_json(key_file_path)

    bucket_name = os.getenv('GCP_BUCKET_NAME')
    if not bucket_name:
        logger.error("GCP_BUCKET_NAME environment variable not set")
        return "GCP_BUCKET_NAME environment variable not set", 500

    bucket = client.get_bucket(bucket_name)  

    # List files and directories in the bucket
    blobs = bucket.list_blobs()
    
    files = [{
        "name": blob.name,
        "url": blob.generate_signed_url(expiration=timedelta(minutes=60))  # URL expires in 60 minutes
    } for blob in blobs]

    return render_template('browse.html', files=files)

if __name__ == '__main__':
  
    # Set up basic logging
    # logging.basicConfig(filename='flaskapp.log', level=logging.DEBUG)
    # logging.basicConfig(filename='flaskapp.log', level=logging.INFO)

    # Log to stderr in development
    # app.logger.addHandler(logging.StreamHandler())
    # app.logger.setLevel(logging.INFO)

    logger = set_logging()
    logger.info('Starting flask-app...')
    
    app.run(host=os.getenv('APP_HOST'),port=os.getenv('APP_PORT'),debug=True)
