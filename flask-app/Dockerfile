# Use an official Python runtime as the base image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app
# WORKDIR /usr/src/app

RUN apt-get update  
# && apt-get install -y python3-pip

# Copy the requirements file into the container
COPY ./requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt && \
    pip install --upgrade flask && \
    pip install --upgrade jinja2 && \
    pip install --upgrade pip && \
    pip install --upgrade setuptools && \
    pip install requests beautifulsoup4 flask_executor 

# Copy the application code into the container
COPY . .

EXPOSE 5000

COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# Set the entrypoint command to run the WSGI server
# CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]

# Run app.py when the container launches
CMD ["python", "app.py"]
