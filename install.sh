# Make camera.py executable
chmod +x camera.py

# Create and activate a virtual environment 
python3 -m venv venv
source venv/bin/activate 

# Install the package in development mode
pip install -e .