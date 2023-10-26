#!/bin/bash

# Update the package list
sudo apt update

# Install the Solidity compiler (solc) and its dependencies
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:ethereum/ethereum
sudo apt update
sudo apt install -y solc

# Verify the installation
solc --version

# Note: No additional package manager is installed as solc and its dependencies are sourced directly from the package repository.
