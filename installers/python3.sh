#!/bin/bash

# Update the package list
sudo apt update

# Install Python 3
sudo apt install -y python3

# Install Python 3 pip
sudo apt install -y python3-pip

# Verify the installation
python3 --version
pip3 --version
