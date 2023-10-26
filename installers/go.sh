#!/bin/bash

# Update the package list
sudo apt update

# Install Go
sudo apt install -y golang

# Verify the installation
go version
