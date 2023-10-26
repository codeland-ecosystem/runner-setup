#!/bin/bash

# Update the package list
sudo apt update

# Install Node.js and npm
sudo apt install -y nodejs npm

# Install TypeScript
sudo npm install -g typescript

# Install ts-node
sudo npm install -g ts-node

# Verify the installation
node --version
npm --version
tsc --version
ts-node --version

# Note: No additional package manager is installed, as npm is used for TypeScript.
