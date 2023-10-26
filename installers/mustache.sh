#!/bin/bash

# Update the package list
sudo apt update

# Install the Mustache command-line tool
sudo apt install -y ruby-mustache

# Verify the installation
mustache --version

# Note: No additional package manager is installed as Mustache is sourced directly from the package repository.
