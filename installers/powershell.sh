#!/bin/bash

# Download the Microsoft repository GPG keys
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -

# Register the Microsoft Ubuntu repository
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-focal-prod focal main" > /etc/apt/sources.list.d/microsoft.list'

# Update the package list
sudo apt update

# Install PowerShell Core
sudo apt install -y powershell

# Verify the installation
pwsh --version
