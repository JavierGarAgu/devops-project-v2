#!/bin/bash

RPM_DIR="$HOME/rpms"

if [[ ! -d "$RPM_DIR" ]]; then
  echo "Directory $RPM_DIR does not exist."
  exit 1
fi

echo "Installing all RPM packages from $RPM_DIR..."

for rpm in "$RPM_DIR"/*.rpm; do
  if [[ -f "$rpm" ]]; then
    echo "Installing $rpm..."
    sudo dnf install -y "$rpm" || {
      echo "Failed to install $rpm"
      exit 1
    }
  else
    echo "No RPM files found in $RPM_DIR."
  fi
done

echo "All RPM packages installed."
