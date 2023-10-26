#!/bin/bash

# Update the package list
sudo apt update

# Install Lua interpreter and LuaRocks
sudo apt install -y lua5.3 luarocks

# Verify the installation
lua5.3 --version
luarocks --version
