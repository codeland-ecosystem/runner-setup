#!/bash/bin

# Update the package list
sudo apt update

# Install Scala
sudo apt install -y scala

# Verify the installation
scala -version

# Note: No additional package manager is installed as Scala is sourced directly from the package repository.
