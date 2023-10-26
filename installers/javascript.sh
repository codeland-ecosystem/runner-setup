#!/bin/bash

# Update the package list
sudo apt update

# Install Node.js and npm (Node Package Manager)
sudo apt install -y nodejs npm

# Verify the installation
node --version
npm --version

# Note: No additional package manager is installed as Node.js and npm are used for JavaScript.
