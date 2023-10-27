#!/bin/bash

# Update the package list
sudo apt update

# Note: No additional package manager is installed as SwiftPM is used to install Swift.

# Download the Swift Package Manager (SwiftPM)
wget https://swift.org/builds/swift-5.5.1-release/ubuntu2004/swift-5.5.1-RELEASE/swift-5.5.1-RELEASE-ubuntu20.04.tar.gz

# Extract the SwiftPM archive
tar -xvzf swift-5.5.1-RELEASE-ubuntu20.04.tar.gz

# Remove the tar
rm swift-5.5.1-RELEASE-ubuntu20.04.tar.gz

# Move SwiftPM to /usr/local
sudo mv swift-5.5.1-RELEASE-ubuntu20.04 /usr/local/swift

# make link
ln -s /usr/local/swift/usr/bin/swift /usr/local/bin/swift

# # Add Swift to the PATH
# echo 'export PATH=$PATH:/usr/local/swift/usr/bin' >> ~/.bashrc

# # Reload the shell environment
# source ~/.bashrc

# Verify the installation
swift --version
