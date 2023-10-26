#!/bin/bash

# Update the package list
sudo apt update

# Install Python 2 and pip for Python 2
sudo apt install -y python python-pip

# Verify the installation
python --version
pip --version
