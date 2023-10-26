#!/bin/bash

# Update the package list
sudo apt update

# Install Ruby and RubyGems
sudo apt install -y ruby

# Verify the installation
ruby --version
gem --version
