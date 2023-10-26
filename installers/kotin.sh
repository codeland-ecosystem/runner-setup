#!/bin/bash

# Update the package list
sudo apt update

# Install Kotlin's Kotlin command-line compiler (kotlinc)
sudo apt install -y openjdk-11-jdk-headless
sudo apt install -y kotlin

# Verify the installation
kotlin -version

# Note: No additional package manager is installed as Kotlin is sourced directly from the package repository.
