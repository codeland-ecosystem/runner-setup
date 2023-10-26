#!/bin/bash

# Update the package list
sudo apt update

# Install Groovy
sudo apt install -y groovy

# Verify the installation
groovy --version

# Note: No additional package manager is installed as Groovy is sourced directly from the package repository.
