#!/bin/bash

echo "=== Installing Cron Service ==="

# Detect the Linux distribution
if [ -f /etc/debian_version ]; then
    # Debian/Ubuntu
    echo "Detected Debian/Ubuntu system"
    sudo apt-get update
    sudo apt-get install -y cron
    sudo systemctl enable cron
    sudo systemctl start cron
    echo "✅ Cron installed and started"
elif [ -f /etc/redhat-release ]; then
    # RHEL/CentOS/Fedora
    echo "Detected RHEL/CentOS/Fedora system"
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y cronie
    else
        sudo yum install -y cronie
    fi
    sudo systemctl enable crond
    sudo systemctl start crond
    echo "✅ Cron installed and started"
elif [ -f /etc/alpine-release ]; then
    # Alpine Linux
    echo "Detected Alpine Linux system"
    sudo apk add --no-cache dcron
    sudo rc-update add dcron
    sudo rc-service dcron start
    echo "✅ Cron installed and started"
else
    echo "❌ Unsupported Linux distribution"
    echo "Please install cron manually for your system"
    exit 1
fi

echo ""
echo "Now you can set up monitoring with:"
echo "./monitoring/monitor-stats.sh setup"