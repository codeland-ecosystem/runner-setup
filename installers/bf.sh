#!/bin/bash

# Update the package list
sudo apt update

# Install a Brainfuck interpreter
sudo apt install -y bf

# Verify the installation
bf --version

# Note: No additional package manager is installed as bf is sourced directly from the package repository.
