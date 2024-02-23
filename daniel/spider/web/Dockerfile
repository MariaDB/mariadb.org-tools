FROM python:latest

# Set the working directory within the container
WORKDIR /api-flask

# Copy the necessary files and directories into the container
COPY app.py requirements.txt /api-flask/

# Upgrade pip and install Python dependencies
RUN pip3 install --upgrade pip && pip install --no-cache-dir -r requirements.txt

# Expose port 80 for the Flask application
EXPOSE 80

# Define the command to run the Flask application using Gunicorn
CMD ["gunicorn", "app:app", "-b", "0.0.0.0:80", "-w", "4", "--worker-tmp-dir=/dev/shm"]
