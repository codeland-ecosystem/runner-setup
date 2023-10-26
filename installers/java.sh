#!/bin/bash

# Update the package list
sudo apt update

# Install OpenJDK
sudo apt install -y openjdk-11-jre

# Verify the installation
java -version
