#!/bin/bash

# Update the package list
sudo apt update

# Install GHC (Glasgow Haskell Compiler)
sudo apt install -y ghc

# Verify the installation
ghc --version

# Note: No additional package manager is installed as GHC is sourced directly from the package repository.
