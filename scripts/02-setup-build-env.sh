#!/bin/bash
# ============================================
# Phantomz Network — Step 2: Setup Build Env
# Run this on the VPS: ssh root@142.171.69.196
# ============================================

set -euo pipefail

echo "=== Setting up build environment ==="

# Ensure swap exists for build process
if [ ! -f /swapfile ]; then
    echo "[1/4] Creating 2GB swap..."
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo "Swap created."
else
    echo "[1/4] Swap already exists."
    swapon /swapfile 2>/dev/null || true
fi

# Install Node.js 20 if not present
if ! command -v node &> /dev/null || [ "$(node -v | cut -d. -f1 | tr -d v)" -lt 20 ]; then
    echo "[2/4] Installing Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
else
    echo "[2/4] Node.js already installed: $(node -v)"
fi

# Install Yarn if not present
if ! command -v yarn &> /dev/null; then
    echo "[3/4] Installing Yarn..."
    npm install -g yarn
else
    echo "[3/4] Yarn already installed: $(yarn -v)"
fi

# Install image tools
echo "[4/4] Installing image processing tools..."
apt-get install -y imagemagick librsvg2-bin

echo ""
echo "=== Environment Ready ==="
echo "Node: $(node -v)"
echo "Yarn: $(yarn -v)"
echo "Swap: $(swapon --show)"
