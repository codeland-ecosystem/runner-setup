#!/bin/bash

# Update the package list
sudo apt update

# Install GCC (C Compiler)
sudo apt install -y gcc

# Verify the installation
gcc --version
