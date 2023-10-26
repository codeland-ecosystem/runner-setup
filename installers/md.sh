#!/bin/bash

# Update the package list
sudo apt update

# Install Pandoc
sudo apt install -y pandoc

# Verify the installation
pandoc --version

# Note: No additional package manager is installed, as Pandoc is sourced directly from the package repository.
