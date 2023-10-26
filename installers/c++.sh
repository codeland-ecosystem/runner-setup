#!/bin/bash

# Update the package list
sudo apt update

# Install g++ (C++ Compiler)
sudo apt install -y g++

# Verify the installation
g++ --version
