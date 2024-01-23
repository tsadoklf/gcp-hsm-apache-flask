from flask import Flask, render_template, request, redirect, url_for, session
from google.cloud import storage
from datetime import timedelta
from dotenv import load_dotenv
import os
import ssl
import logging
from collections import defaultdict
import datetime

# --- Amir
from flask import Flask, send_file
from flask import send_from_directory

# --- Amir - for sync process
import requests
from bs4 import BeautifulSoup


# Load environment variables from .env file
load_dotenv()

app = Flask(__name__)
app.secret_key = 'tsadok_secret_key'  # Set a secret key for session management

# Mock user data for simplicity
users = {
    "user1": "password1",
    "user2": "password2"
}

# -------------------------------------------
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
    # logger.debug('This is a debug message')
    # logger.info('This is an info message')
    # logger.warning('This is a warning message')
    # logger.error('This is an error message')
    # logger.critical('This is a critical message')

    return logger

# -------------------------------------------
def is_user_logged_in():
    'username' in session

# -------------------------------------------
def parse_blobs(blobs):       
    def insert_into_structure(structure, blob):

        # take the left most part of the path
        path_parts = blob.name.split('/')
        logger.info('path_parts: ' + str(path_parts))

        #  left most part of the path
        # part = path_parts[0]

        logger.info('blob.name: ' + blob.name)
        
        # remove empty string from path_parts
        path_parts = list(filter(None, path_parts))

        logger.info('path_parts: ' + str(path_parts))
        logger.info('path_parts[-1]: ' + path_parts[-1])
        logger.info('path_parts[:-1]: ' + str(path_parts[:-1]))
        
        if not path_parts:  # Add this line to check if path_parts is empty
            logger.info('path_parts is empty')
            return  # Skip this blob as it seems to have an empty name
        
        for part in path_parts[:-1]:  # Add this line to check if part is empty
            if part != '': structure = structure.setdefault(part, {"files": [], "directories": defaultdict(dict)})

        # direcotry name or file name
        path = path_parts[:-1]
        name = path_parts[-1]
        logger.info('name: ' + name)
        
        # if '/' in blob.name:  # It's a directory
        if blob.name.endswith('/'):
            logger.info('It is a directory')
            logger.info('blob.name: ' + blob.name)
            subdirectory_structure = structure["directories"].setdefault(name, {"files": [], "directories": defaultdict(dict)})

            # If the blob is a directory, make a recursive call to insert into the subdirectory structure.
            # insert_into_structure(subdirectory_structure, path_parts[1:], blob)
        else:  # It's a file
            logger.info('It is a file')
            structure["files"].append({
                "name": name,
                "size": blob.size,
                "last_modified": blob.updated.strftime("%Y-%m-%d %H:%M:%S"),
                "url": blob.generate_signed_url(expiration=timedelta(minutes=60)),
                "is_directory": False
            })    

    file_structure = defaultdict(dict)
    for blob in blobs:
        insert_into_structure(file_structure, blob)
        logger.info("")

                # get bucket data as blob
        # blob = bucket.get_blob('testdata.xml')
        # convert to string
        if blob.name.endswith('/'):
            json_data = blob.download_as_string()
            logger.info('json_data: ' + str(json_data))

    return file_structure

# -------------------------------------------
@app.route('/')
def home():
    app.logger.info('Route / accessed')
    return redirect(url_for('browse_files'))
    # return redirect(url_for('list_files'))



# =============================================
@app.route('/sync')
def sync_files():
    # Send a GET request to the remote web page
    url = 'https://update.resec.co'
    response = requests.get(url)

    # Check if the request was successful
    if response.status_code == 200:
        html_content = response.content
        soup = BeautifulSoup(html_content, 'html.parser')

        # Dump the retrieved URL page content to the screen
        # Debug ????????????????????????????????????????
        url_page_dump = f'Retrieved URL page content: {html_content}<br>'

        # Find all HREF links
        all_links = soup.find_all('a', href=True)

        # Dump the parsed soup result to the screen
        # Debug ????????????????????????????????????????
        soup_dump = f'Parsed soup result: {all_links}<br>'
        
        # Create a local folder to save the downloaded files
        local_folder = './../data/'
        if not os.path.exists(local_folder):
            os.makedirs(local_folder)

        # Download all the files into the local folder
        url_page_dump = f'List of files<br>'
        for link in all_links:
            file_url = url + link['href']

            # Dump the list
            # Debug ????????????????????????????????????????
            url_page_dump += f'URLs: {file_url}<br>'
            
            file_name = file_url.split('/')[-1]
            file_path = os.path.join(local_folder, file_name)

            # Send a GET request to download the file
            file_response = requests.get(file_url)

            # Save the file to the local folder
            with open(file_path, 'wb') as file:
                file.write(file_response.content)

        return url_page_dump + soup_dump + url_page_dump + 'Files downloaded successfully!'
    else:
        return url_page_dump + soup_dump + url_page_dump + 'Failed to retrieve web page.'
# =============================================



# -------------------------------------------
@app.route('/login', methods=['GET', 'POST'])
def login():
    app.logger.info('Route /login accessed')
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        if username in users and users[username] == password:
            session['username'] = username  # Store username in session
            # return redirect(url_for('browse'))
            return redirect(url_for('browse_files'))
        else:
            return "Invalid credentials", 401

    return render_template('login.html')

# -------------------------------------------
@app.route('/logout')
def logout():
    session.pop('username', None)  # Remove username from session
    return redirect(url_for('login'))

# -------------------------------------------
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

    blobs = bucket.list_blobs( include_trailing_delimiter=False)
    for blob in blobs:
        if blob.name.endswith('/'):
            logger.info(f'{blob.name} is a directory')
        else:
            logger.info(f'{blob.name} is a file')

    logger.info("===========================================")

    # List files and directories in the bucket
    # blobs = bucket.list_blobs()
    # files = parse_blobs(blobs)
    
    files = [{
        "name": blob.name,
        "url": blob.generate_signed_url(expiration=timedelta(minutes=60))  # URL expires in 60 minutes
    } for blob in blobs]

    return render_template('browse.html', files=files)

# ================================================================

# -------------------------------------------
@app.route('/browse_files')
def browse_files():
    # Replace 'your_directory_path' with the path of your directory
    directory = './../data'
    file_tree = get_file_tree(directory)

    # print("===========================================")
    print(file_tree)
    return render_template('browse_files.html', files=file_tree)

# -------------------------------------------
def get_file_tree(directory, parent_path=''):
    file_tree = {'files': [], 'directories': {}}
    for filename in os.listdir(directory):
        filepath = os.path.join(directory, filename)
        if os.path.isdir(filepath):
            # display folders (not needed on flat structure
            # drill down into sub folders, disabled for now, we only want to show the root
            # file_tree['directories'][filename] = get_file_tree(filepath, os.path.join(parent_path, filename))
            # show folder as is, instead
            file_tree['directories'][filename].append({
                'name': filename,
                'url': 'na' # os.path.join("/download/", parent_path, filename), 
                'size': 'na',
                'last_modified': datetime.datetime.fromtimestamp(file_stats.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
            })
            
            # file_tree['directories'][filename] = get_file_tree(filepath, os.path.join(parent_path, filename))
        else:
            file_stats = os.stat(filepath)
            file_tree['files'].append({
                'name': filename,
                'url': os.path.join("/download/", parent_path, filename), 
                # 'download_url': url_for('download_file', filename=os.path.join(parent_path, 'download', filename)),
                # 'download_url': url_for('/download/', filename=os.path.join(parent_path, filename)),
                
                'size': file_stats.st_size,
                'last_modified': datetime.datetime.fromtimestamp(file_stats.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
            })
    return file_tree

# -------------------------------------------
@app.route('/download/<path:filename>')
def download_file(filename):
    directory = './../data'
    return send_from_directory(directory, filename, as_attachment=True)

# -------------------------------------------
# -------------------------------------------
@app.route('/list_files')
def list_files():
    folder_path = './../data'
    file_list = os.listdir(folder_path)
    list_html += '<h1>Resec AV Files updates</h1>'
    list_html += '<ul>'
    for file in file_list:
        list_html += f'<li><a href="/download/{file}">{file}</a></li>'
    list_html += '</ul>'
    return list_html
    
# -------------------------------------------
@app.route('/download/<path:filename>')
def download_one_file(filename):
    folder_path = './../data'
    return send_from_directory(directory=folder_path, path=filename, as_attachment=True)
# -------------------------------------------
# -------------------------------------------





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







