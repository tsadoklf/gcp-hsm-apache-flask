# Use an official Python runtime as the base image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Update package list and install required system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy the requirements file into the container
COPY ./requirements.txt .

# Install Python dependencies from requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Additional Python packages installed and upgraded
RUN pip install --no-cache-dir --upgrade \
    flask \
    jinja2 \
    pip \
    setuptools \
    requests \
    beautifulsoup4 \
    flask_executor

# Copy the application code into the container
COPY . .

# Expose the port the app runs on
EXPOSE 5000

# Copy and make the entrypoint script executable
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set the entrypoint script
ENTRYPOINT ["entrypoint.sh"]

# Run the application when the container starts
CMD ["python", "app.py"]
