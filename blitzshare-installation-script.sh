#!/bin/bash

DEB_PACKAGE="blitzshare_1.0.0_amd64.deb"

echo "Flutter App Installer"
echo "===================="

read -p "Do you want to install the app? (y/N): " install_app

if [[ $install_app =~ ^[Yy]$ ]]; then
    echo "Installing app..."
    sudo dpkg -i "$DEB_PACKAGE"
    sudo apt-get install -f -y
    echo "App installed successfully."
else
    echo "Installation cancelled."
    exit 0
fi

read -p "The app needs ports 7350, 7351, and 7352 to work correctly, do you want to allow them through the firewall (ufw)? (y/N): " allow_ports

if [[ $allow_ports =~ ^[Yy]$ ]]; then
    echo "Configuring firewall..."
    sudo ufw allow 7350
    sudo ufw allow 7351
    sudo ufw allow 7352
    echo "Firewall configured."
else
    echo "Firewall configuration skipped."
fi

echo "Installation finished correctly."
