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

# Get bucket name from environment variable
BUCKET_NAME = os.getenv('GCP_BUCKET_NAME')

app = Flask(__name__)
app.secret_key = 'tsadok_secret_key'  # Set a secret key for session management

# Mock user data for simplicity
users = {
    "user1": "password1",
    "user2": "password2"
}

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
        return redirect(url_for('login'))

    # Initialize Google Cloud Storage client
    # client = storage.Client()

    # Specify the path to your service account JSON key file
    key_file_path = os.getenv('STORAGE_SERVICE_ACCOUNT_PRIVATE_KEY')

    # Create a client using explicit credentials
    client = storage.Client.from_service_account_json(key_file_path)

    bucket = client.get_bucket(BUCKET_NAME)  # Use the bucket name from environment variable

    # List files in the bucket
    blobs = bucket.list_blobs()
    
    files = [{
        "name": blob.name,
        "url": blob.generate_signed_url(expiration=timedelta(minutes=60))  # URL expires in 60 minutes
    } for blob in blobs]

    return render_template('browse.html', files=files)

if __name__ == '__main__':
  
    # Set up basic logging
    logging.basicConfig(filename='flaskapp.log', level=logging.DEBUG)
    
    # Log to stderr in development
    app.logger.addHandler(logging.StreamHandler())
    app.logger.setLevel(logging.INFO)

    app.run(host=os.getenv('APP_HOST'),port=os.getenv('APP_PORT'),debug=True)
