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

# for white listsing of authorized callers of /sync method
from functools import wraps
from flask import jsonify
import socket

# for returning 200 in sync and processing in the background
import threading
from flask_executor import Executor

# -------------------------------------------
# Load environment variables from .env file
load_dotenv()

app = Flask(__name__)
executor = Executor(app)
app.secret_key = 'tsadok_secret_key'  # Set a secret key for session management

# Mock user data for simplicity
users = {
    "user1": "password1",
    "user2": "password2",
    "amir" : "1111",
    "yaar" : "1111",
    "oren" : "1111"
}

# used for analytics events
current_username = "No User"

# -------------------------------------------
# Define a custom decorator for IP and domain whitelisting
def whitelist(ip_whitelist, domain_whitelist):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            # client_ip = request.remote_addr
            # client_ip = request.environ.get('HTTP_X_REAL_IP', request.remote_addr)
            client_ip = request.environ.get('HTTP_X_FORWARDED_FOR', request.environ.get('HTTP_X_REAL_IP', request.remote_addr))
            client_domain = request.environ.get('REMOTE_HOST', '')
            host = 'unset'
            
            # if the IP is not in the whitelist - try by host name
            if client_ip not in ip_whitelist:
                try:
                    # resolve hostname
                    host = socket.gethostbyaddr(client_ip)[0]
                    
                    # the host is not in the whitelist - return forbidden
                    if host not in domain_whitelist:
                        return jsonify({'host not authorized': host + ' -> ' + client_ip + ' -> ' + client_domain + ' -> ' + Unauthorized'}), 403  # Return a 403 Forbidden status
                except socket.herror:
                    # cannot resolve the host name, and the IP is not in the whitelist - return forbidden
                    return jsonify({'unidentified host': host + ' -> ' + client_ip + ' -> ' + client_domain + ' -> ' + 'Unauthorized'}), 403  # Return a 403 Forbidden status

            # The IP or the host name are is  in the whitelist - allow access
            return jsonify({'OK host': host + ' -> ' + client_ip + ' -> ' + client_domain + ' -> ' + ' Authorized !!!'}), 403  # Return a 403 Forbidden status
            # return func(*args, **kwargs)
            
        return wrapper
    return decorator

# Define the set of allowed IP addresses
#                AmirHome                       update.resec.co 
allowed_ips = {'147.235.218.40', '20.216.132.35'} 
# I keep getting apache-server.app-network for host and 192.168.128.3, 192.168.112.3, for IP
# because of the network container abstraction

# Define the set of allowed domains
allowed_domains = {'updates.resec.co'}

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
    return 'username' in session

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
    global current_username 

    # this variable is used for the google analytics in the template file.
    # needed for google analytics
    try:
        current_username = session['username']
    except KeyError:
        # if not current_username:
        current_username = 'No Session'
    
    return redirect(url_for('browse_files'))

# -------------------------------------------
@app.route('/login', methods=['GET', 'POST'])
def login():
    app.logger.info('Route /login accessed')

    if is_user_logged_in():
        return redirect(url_for('private_area'))
    
    global current_username         
    
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        if username in users and users[username] == password:
            # Store username in session
            session['username'] = username
            # needed for google analytics
            current_username = username
            # go to user's private area
            return redirect(url_for('private_area'))
        else:
            return "Invalid credentials", 401

    return render_template('login.html')

# -------------------------------------------
@app.route('/logout')
def logout():
    global current_username 
    app.logger.info('Route /logout accessed')
    
    # Remove username from session
    session.pop('username', None)  
    # needed for google analytics
    current_username = 'Logged-out'
    return redirect(url_for('browse_files'))

# -------------------------------------------
@app.route('/sync')
@whitelist(allowed_ips, allowed_domains)
def trigger_file_downloads():
    app.logger.info('Route /sync accessed')
    
    if 'debug' in request.args and request.args.get('debug') == '1':
        return jsonify({'message': 'Debug mode is active. Skipping file download.'})
    else:
        # Run the download_files_async function asynchronously
        executor.submit(sync_files)  
        return jsonify({'message': 'File download process started'})

# -------------------------------------------
def sync_files():
    app.logger.info('Route /Sync file thread started')
    # Send a GET request to the remote web page
    url = 'https://update.resec.co'
    response = requests.get(url)

    debug = False
    # debug switch, used to show the results
    if 'debug' in request.args and request.args.get('debug') == '1':
        debug = True
    
    # Check if the request was successful
    if response.status_code == 200:
        html_content = response.content
        soup = BeautifulSoup(html_content, 'html.parser')

        # Dump the retrieved URL page content to the screen
        if debug:
            url_page_dump = f'Retrieved URL page content: {html_content}<br>'
        else:
            url_page_dump = ''

        # Find all HREF links
        all_links = soup.find_all('a', href=True)

        # Dump the parsed soup result to the screen
        if debug:
            soup_dump = f'Parsed soup result: {all_links}<br>'
        else:
            soup_dump = ''
        
        # Create a local folder to save the downloaded files
        local_folder = './../data/'
        if not os.path.exists(local_folder):
            os.makedirs(local_folder)

        # Download all the files into the local folder
        url_page_dump = f'List of files<br>'
        
        for link in all_links:
            file_url = url + link['href']

            # Dump the list
            if debug:
                url_page_dump += f'URLs: {file_url}<br>'
            else:
                url_page_dump = ''
            
            file_name = file_url.split('/')[-1]
            file_path = os.path.join(local_folder, file_name)

            # Send a GET request to download the file
            file_response = requests.get(file_url)

            # Save the file to the local folder
            with open(file_path, 'wb') as file:
                file.write(file_response.content)

        app.logger.info('Route /Sync file thread ended')
        pass

    #        return url_page_dump + soup_dump + url_page_dump + 'Files downloaded successfully!'
    #    else:
    #        return url_page_dump + soup_dump + url_page_dump + 'Failed to retrieve web page.'

# -------------------------------------------
@app.route('/browse_files')
def browse_files():
    app.logger.info('Route /browse_files accessed')
    # path of your directory
    directory = './../data'
    file_tree = get_file_tree(directory)

    # print("===========================================")
    print(file_tree)
    return render_template('browse_files.html', files=file_tree, title='Resec AV Updates')

# -------------------------------------------
@app.route('/private')
def private_area():
    global current_username 

    app.logger.info('Route /private accessed')
    
    # Ensure the user is logged in
    if not is_user_logged_in():
        return redirect(url_for('login'))
    
    # Create a local folder for the logged on user if it does not yet exists
    local_folder = './../data/' + session['username']
    if not os.path.exists(local_folder):
        os.makedirs(local_folder)

    # Write "hello user" content to a text file in the created folder
    file_path = os.path.join(local_folder, session['username'] + '-ReadMe.txt')
    with open(file_path, 'w') as file:
        file.write('Dear ' + session['username'] + '. This folder will contain only files meant for you alone.')
    
    directory = './../data/' + session['username']
    file_tree = get_file_tree(directory)

    # print("===========================================")
    print(file_tree)
    return render_template('browse_files.html', files=file_tree, title='Resec Private Area (' + current_username + ')')

# -------------------------------------------
def get_file_tree(directory, parent_path='', go_deep = False):
    app.logger.info('Route /det_file_tree called')

    file_tree = {'files': [], 'directories': {}}
    files = sorted(os.listdir(directory))
    
    for filename in files:
        filepath = os.path.join(directory, filename)
        if os.path.isdir(filepath):
            # display folders (not needed on flat structure)
            # drill down into sub folders, disabled for now, we only want to show the root
            
            if go_deep:
                file_tree['directories'][filename] = get_file_tree(filepath, os.path.join(parent_path, filename, go_deep))
            else:            
                # we do not want to see sub folders
                continue
                
        else:

            # canonize all sub folder links to direct to the download route
            if 'data/' in directory:
                dowload_path = directory.replace('data/', 'download/')            
            else:
                dowload_path = 'download/'
            
            file_stats = os.stat(filepath)
            file_tree['files'].append({
                'user': current_username,
                'name': filename,
                'url': os.path.join(dowload_path, parent_path, filename), 
                # 'url': os.path.join("/download/", directory, parent_path, filename), 
                
                # 'url': os.path.join("/download/", parent_path, filename), 
                # 'download_url': url_for('/download/', filename=os.path.join(parent_path, filename)),
                
                'size': file_stats.st_size,
                'last_modified': datetime.datetime.fromtimestamp(file_stats.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
            })
    return file_tree

# -------------------------------------------
@app.route('/download/<path:filename>')
def download_file(filename):
    app.logger.info('Route /download accessed')
    directory = './../data'
    return send_from_directory(directory, filename, as_attachment=True)

# -------------------------------------------
@app.route('/browse')
def browse():
    app.logger.info('Route /browse accessed')

    # Ensure the user is logged in
    if not is_user_logged_in():
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







