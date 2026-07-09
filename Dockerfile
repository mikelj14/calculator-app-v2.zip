# Step 1: Use an official minimal Python runtime as a parent image
FROM python:3.10-slim

# Step 2: Set the working directory inside the container
WORKDIR /app

# Step 3: Copy only requirements first to leverage Docker cache layers
# Note: If you don't have a requirements.txt file yet, create one containing: flask
COPY requirements.txt .

# Step 4: Install the required dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Step 5: Copy the rest of your application code into the container
COPY . .

# Step 6: Expose the port your Flask application listens on
EXPOSE 5000

# Step 7: Define the command to run your web application
CMD ["python", "calculator_app.py"]
