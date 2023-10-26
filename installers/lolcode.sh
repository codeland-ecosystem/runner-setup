#!/bin/bash

# Update the package list
sudo apt update

# Install a LOLCODE interpreter (lci)
sudo apt install -y lci

# Verify the installation
lci --version

# Note: No additional package manager is installed as the LOLCODE interpreter is sourced directly from the package repository.
