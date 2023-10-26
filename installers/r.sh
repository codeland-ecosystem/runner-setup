#!/bin/bash

# Update the package list
sudo apt update

# Install R and Rscript
sudo apt install -y r-base

# Verify the installation
R --version

# Note: No additional package manager is installed as R and Rscript are sourced directly from the package repository.
