#!/bin/bash
# ============================================
# Phantomz Network — Step 4: Build & Deploy
# Run this on the VPS: ssh root@142.171.69.196
# ============================================

set -euo pipefail

echo "=== Phantomz Network Build & Deploy ==="

# Clone this repo on the VPS
REPO_DIR="/opt/phantomz-client"
if [ ! -d "$REPO_DIR" ]; then
    echo "[1/6] Cloning repo..."
    git clone https://github.com/efficientlabs-dev/basketball-event-organizer.PH.git "$REPO_DIR"
    cd "$REPO_DIR"
    git checkout claude/phantomz-element-web-build-9GnE8
else
    echo "[1/6] Updating repo..."
    cd "$REPO_DIR"
    git pull origin claude/phantomz-element-web-build-9GnE8
fi

cd "$REPO_DIR/element-web-fork"

# Install dependencies
echo "[2/6] Installing dependencies..."
NODE_OPTIONS="--max-old-space-size=1536" pnpm install 2>&1 | tail -5

# Build
echo "[3/6] Building Phantomz Web (this takes 5-15 minutes)..."
NODE_OPTIONS="--max-old-space-size=1536" pnpm build 2>&1 | tail -10

# Verify build output
if [ ! -f "apps/web/webapp/index.html" ]; then
    echo "ERROR: Build failed — webapp/index.html not found"
    exit 1
fi
echo "Build successful!"

# Copy config into build output
echo "[4/6] Copying config..."
cp /opt/phantomz-matrix/element-config.json apps/web/webapp/config.json

# Build Docker image
echo "[5/6] Building Docker image..."
cd /opt/phantomz-matrix

# Create Dockerfile
cat > Dockerfile.phantomz << 'EOF'
FROM nginx:alpine
COPY phantomz-web/webapp/ /usr/share/nginx/html/
COPY element-config.json /usr/share/nginx/html/config.json
EOF

# Create symlink
ln -sf "$REPO_DIR/element-web-fork/apps/web" /opt/phantomz-matrix/phantomz-web

docker build -f Dockerfile.phantomz -t phantomz-web:latest .

# Update docker-compose.yml element service
echo "[6/6] Restarting element container..."
docker compose up -d element

echo ""
echo "=== Build & Deploy Complete ==="
docker compose ps
echo ""
echo "Verify at: https://element.phantomznetwork.xyz"
