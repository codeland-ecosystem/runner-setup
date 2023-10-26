#!/bin/bash

# Update the package list
sudo apt update

# Install Perl
sudo apt install -y perl

# Verify the installation
perl --version

# Note: No additional package manager is installed as Perl is sourced directly from the package repository.
