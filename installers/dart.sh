#!/bin/bash

# Update the package list
sudo apt update

# Install Dart
sudo apt install -y apt-transport-https
sudo sh -c 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -'
sudo sh -c 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'
sudo apt update
sudo apt install -y dart

# Verify the installation
dart --version

# Note: No additional package manager is installed as Dart is sourced directly from the package repository.
