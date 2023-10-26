#!/bin/bash

# Update the package list
sudo apt update

# Install Rust using `apt`
sudo apt install -y rustc

# Verify the installation
rustc --version
