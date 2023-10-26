#!/bin/bash

# Update the package list
sudo apt update

# Install Clojure
sudo apt install -y openjdk-11-jdk-headless
sudo apt install -y leiningen

# Verify the installation
clojure --version

# Note: No additional package manager is installed as Clojure is sourced via Leiningen.
