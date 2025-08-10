#!/bin/bash

echo "=== Installing Cron Service ==="

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/system-release ]; then
        if grep -q "Amazon Linux" /etc/system-release; then
            echo "amzn"
        else
            echo "unknown"
        fi
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/alpine-release ]; then
        echo "alpine"
    else
        echo "unknown"
    fi
}

# Detect the Linux distribution
DISTRO=$(detect_distro)

case "$DISTRO" in
    "ubuntu"|"debian")
        echo "Detected Debian/Ubuntu system"
        sudo apt-get update
        sudo apt-get install -y cron
        sudo systemctl enable cron
        sudo systemctl start cron
        echo "✅ Cron installed and started"
        ;;
    "amzn")
        # Amazon Linux (both AL2 and AL2023)
        if grep -q "Amazon Linux 2023" /etc/system-release 2>/dev/null; then
            echo "Detected Amazon Linux 2023 system"
            sudo dnf install -y cronie
        elif grep -q "Amazon Linux 2" /etc/system-release 2>/dev/null; then
            echo "Detected Amazon Linux 2 system"
            sudo yum install -y cronie
        else
            echo "Detected Amazon Linux system"
            # Try dnf first (AL2023), fallback to yum (AL2)
            if command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y cronie
            else
                sudo yum install -y cronie
            fi
        fi
        sudo systemctl enable crond
        sudo systemctl start crond
        echo "✅ Cron installed and started"
        ;;
    "rhel"|"centos"|"fedora"|"rocky"|"almalinux")
        echo "Detected RHEL/CentOS/Fedora/Rocky/AlmaLinux system"
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y cronie
        else
            sudo yum install -y cronie
        fi
        sudo systemctl enable crond
        sudo systemctl start crond
        echo "✅ Cron installed and started"
        ;;
    "alpine")
        echo "Detected Alpine Linux system"
        sudo apk add --no-cache dcron
        sudo rc-update add dcron
        sudo rc-service dcron start
        echo "✅ Cron installed and started"
        ;;
    "arch")
        echo "Detected Arch Linux system"
        sudo pacman -S --noconfirm cronie
        sudo systemctl enable cronie
        sudo systemctl start cronie
        echo "✅ Cron installed and started"
        ;;
    *)
        echo "❌ Unsupported or unknown Linux distribution: $DISTRO"
        echo ""
        echo "Manual installation options:"
        echo "  Debian/Ubuntu: sudo apt-get install cron"
        echo "  RHEL/CentOS:   sudo yum install cronie"
        echo "  Fedora:        sudo dnf install cronie"
        echo "  Amazon Linux:  sudo yum install cronie (AL2) or sudo dnf install cronie (AL2023)"
        echo "  Alpine:        sudo apk add dcron"
        echo "  Arch:          sudo pacman -S cronie"
        echo ""
        echo "After installation, enable and start the service:"
        echo "  sudo systemctl enable crond && sudo systemctl start crond"
        exit 1
        ;;
esac

echo ""
echo "🔍 Verifying cron installation..."

# Check if cron service is running
if systemctl is-active --quiet crond 2>/dev/null || systemctl is-active --quiet cron 2>/dev/null; then
    echo "✅ Cron service is running"
elif rc-service dcron status >/dev/null 2>&1; then
    echo "✅ Cron service is running (Alpine)"
else
    echo "⚠️  Cron service may not be running properly"
    echo "   Try: sudo systemctl status crond"
fi

# Check if crontab command is available
if command -v crontab >/dev/null 2>&1; then
    echo "✅ Crontab command is available"
    echo ""
    echo "🚀 Installation complete! Now you can set up monitoring with:"
    echo "   ./monitoring/monitor-stats.sh setup"
else
    echo "❌ Crontab command not found"
    echo "   Installation may have failed"
fi