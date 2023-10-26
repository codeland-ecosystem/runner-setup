#!/bin/bash

# Update the package list
sudo apt update

# Install Mono for C#
sudo apt install -y mono-complete

# Verify the installation
mono --version

# Note: No package manager is installed as Mono is obtained directly from the package repository.
