#!/bin/bash

# Update the package list
sudo apt update

# Install EJS (Embedded JavaScript) via npm (Node Package Manager)
sudo apt install -y nodejs npm
sudo npm install -g ejs

# Verify the installation
ejs --version

# Note: No additional package manager is installed as EJS is sourced via npm.
