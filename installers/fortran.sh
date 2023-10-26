#!/bin/bash

# Update the package list
sudo apt update

# Install the GNU Fortran compiler (gfortran)
sudo apt install -y gfortran

# Verify the installation
gfortran --version

# Note: No additional package manager is installed as gfortran is sourced directly from the package repository.
