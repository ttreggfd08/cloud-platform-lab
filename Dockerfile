# Use official Python lightweight image
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Create and set working directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Expose the port the app runs on
EXPOSE 8080

# Command to run the application using Gunicorn (production server)
# Only using 1 worker makes it easier to simulate CPU bottlenecks to trigger HPA later
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "app:app"]
