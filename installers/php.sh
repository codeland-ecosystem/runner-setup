#!/bin/bash

# Update the package list
sudo apt update

# Install PHP and PHP CLI
sudo apt install -y php-cli

# Verify the installation
php --version
