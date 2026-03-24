#!/usr/bin/env bash
#
# deploy.sh — Phantomz Network Element Web deployment script
#
# Run this on the VPS after pulling the repo. It handles:
#   1. Generating icon sizes from a logo file you drop in
#   2. Building the Docker image
#   3. Updating docker-compose.yml to use the new image
#   4. Restarting containers
#
# Usage:
#   ./deploy.sh                     # Build and deploy
#   ./deploy.sh --logo logo.png     # Use a specific logo file for icon generation
#   ./deploy.sh --skip-icons        # Skip icon generation
#   ./deploy.sh --compose-file /path/to/docker-compose.yml
#
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
IMAGE_NAME="phantomz-web"
IMAGE_TAG="latest"
CONTAINER_NAME="element-web"
COMPOSE_SERVICE="element-web"
COMPOSE_FILE=""
LOGO_FILE=""
SKIP_ICONS=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON_SIZES=(24 120 144 152 180 512 1024)

# ─── Color output ─────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

log()   { echo -e "${PURPLE}[phantomz]${NC} $*"; }
ok()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*" >&2; }

# ─── Parse arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --logo)         LOGO_FILE="$2"; shift 2 ;;
        --skip-icons)   SKIP_ICONS=true; shift ;;
        --compose-file) COMPOSE_FILE="$2"; shift 2 ;;
        --image-name)   IMAGE_NAME="$2"; shift 2 ;;
        --image-tag)    IMAGE_TAG="$2"; shift 2 ;;
        --service)      COMPOSE_SERVICE="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --logo FILE          Path to logo file (PNG/SVG) for icon generation"
            echo "  --skip-icons         Skip icon generation step"
            echo "  --compose-file FILE  Path to docker-compose.yml (auto-detected if omitted)"
            echo "  --image-name NAME    Docker image name (default: phantomz-web)"
            echo "  --image-tag TAG      Docker image tag (default: latest)"
            echo "  --service NAME       Docker Compose service name to replace (default: element-web)"
            echo "  -h, --help           Show this help"
            exit 0
            ;;
        *) err "Unknown option: $1"; exit 1 ;;
    esac
done

# ─── Auto-detect logo file ───────────────────────────────────────────────────
if [[ -z "$LOGO_FILE" ]] && [[ "$SKIP_ICONS" == false ]]; then
    # Look for common logo files in the repo root
    for candidate in \
        "$SCRIPT_DIR/logo.png" \
        "$SCRIPT_DIR/logo.svg" \
        "$SCRIPT_DIR/phantomz-logo.png" \
        "$SCRIPT_DIR/phantomz-logo.svg" \
        "$SCRIPT_DIR/icon.png" \
        "$SCRIPT_DIR/icon.svg"; do
        if [[ -f "$candidate" ]]; then
            LOGO_FILE="$candidate"
            log "Auto-detected logo file: $LOGO_FILE"
            break
        fi
    done
fi

# ─── Auto-detect docker-compose.yml ──────────────────────────────────────────
if [[ -z "$COMPOSE_FILE" ]]; then
    for candidate in \
        "$SCRIPT_DIR/docker-compose.yml" \
        "$SCRIPT_DIR/docker-compose.yaml" \
        "$SCRIPT_DIR/../docker-compose.yml" \
        "$SCRIPT_DIR/../docker-compose.yaml" \
        "/opt/matrix/docker-compose.yml" \
        "/opt/docker-compose.yml" \
        "$HOME/docker-compose.yml"; do
        if [[ -f "$candidate" ]]; then
            COMPOSE_FILE="$(realpath "$candidate")"
            log "Auto-detected compose file: $COMPOSE_FILE"
            break
        fi
    done
fi

# ─── Step 1: Generate icons from logo ────────────────────────────────────────
generate_icons() {
    if [[ "$SKIP_ICONS" == true ]]; then
        warn "Skipping icon generation (--skip-icons)"
        return 0
    fi

    if [[ -z "$LOGO_FILE" ]] || [[ ! -f "$LOGO_FILE" ]]; then
        warn "No logo file found. Drop a logo.png or logo.svg in the repo root, or pass --logo <file>"
        warn "Using placeholder icons for now."
        return 0
    fi

    log "Generating icons from: $LOGO_FILE"

    # Check for required tools
    local converter=""
    if command -v magick &>/dev/null; then
        converter="magick"
    elif command -v convert &>/dev/null; then
        converter="convert"
    else
        warn "ImageMagick not found. Installing..."
        if command -v apt-get &>/dev/null; then
            sudo apt-get update -qq && sudo apt-get install -y -qq imagemagick >/dev/null 2>&1
            converter="convert"
        elif command -v apk &>/dev/null; then
            sudo apk add --no-cache imagemagick >/dev/null 2>&1
            converter="convert"
        else
            err "Cannot install ImageMagick. Please install it manually."
            warn "Continuing with placeholder icons."
            return 0
        fi
    fi

    local icon_dir="$SCRIPT_DIR/apps/web/res/vector-icons-custom"
    mkdir -p "$icon_dir"

    for size in "${ICON_SIZES[@]}"; do
        log "  Generating ${size}x${size} icon..."
        if [[ "$converter" == "magick" ]]; then
            magick "$LOGO_FILE" -resize "${size}x${size}" -background none -gravity center -extent "${size}x${size}" "$icon_dir/${size}.png"
        else
            convert "$LOGO_FILE" -resize "${size}x${size}" -background none -gravity center -extent "${size}x${size}" "$icon_dir/${size}.png"
        fi
    done

    # Also copy into the existing vector-icons dir for the build
    cp "$icon_dir"/*.png "$SCRIPT_DIR/apps/web/res/vector-icons/" 2>/dev/null || true

    ok "Generated ${#ICON_SIZES[@]} icon sizes"
}

# ─── Step 2: Build Docker image ──────────────────────────────────────────────
build_image() {
    log "Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"
    log "This may take a few minutes on the first build..."

    cd "$SCRIPT_DIR"

    docker build \
        -f Dockerfile.phantomz \
        -t "${IMAGE_NAME}:${IMAGE_TAG}" \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        . 2>&1 | while IFS= read -r line; do
            # Show progress without flooding terminal
            if [[ "$line" == *"Step "* ]] || [[ "$line" == *"Successfully"* ]] || [[ "$line" == *"ERROR"* ]]; then
                log "  $line"
            fi
        done

    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        err "Docker build failed!"
        exit 1
    fi

    ok "Docker image built: ${IMAGE_NAME}:${IMAGE_TAG}"
}

# ─── Step 3: Update docker-compose.yml ────────────────────────────────────────
update_compose() {
    if [[ -z "$COMPOSE_FILE" ]]; then
        warn "No docker-compose.yml found."
        warn "You can run the container manually:"
        echo ""
        echo "  docker run -d --name phantomz-web -p 8080:80 ${IMAGE_NAME}:${IMAGE_TAG}"
        echo ""
        return 0
    fi

    log "Updating docker-compose.yml: $COMPOSE_FILE"

    # Backup the original
    cp "$COMPOSE_FILE" "${COMPOSE_FILE}.bak.$(date +%s)"
    ok "Backed up compose file"

    # Check if the service exists in the compose file
    if grep -q "$COMPOSE_SERVICE" "$COMPOSE_FILE"; then
        # Replace the image line for the element-web service
        # This handles both "image: vectorim/element-web" and "image: vectorim/element-web:latest" etc.
        # We use a Python snippet for reliable YAML manipulation if available, otherwise sed
        if command -v python3 &>/dev/null && python3 -c "import yaml" 2>/dev/null; then
            python3 - "$COMPOSE_FILE" "$COMPOSE_SERVICE" "$IMAGE_NAME" "$IMAGE_TAG" <<'PYEOF'
import sys, yaml

compose_file, service_name, image_name, image_tag = sys.argv[1:5]

with open(compose_file, 'r') as f:
    data = yaml.safe_load(f)

if 'services' in data and service_name in data['services']:
    data['services'][service_name]['image'] = f"{image_name}:{image_tag}"
    # Remove any build context if it was pointing to element-web
    data['services'][service_name].pop('build', None)
    with open(compose_file, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)
    print(f"Updated service '{service_name}' image to {image_name}:{image_tag}")
else:
    print(f"Service '{service_name}' not found, checking alternative names...")
    # Try common variations
    for svc in data.get('services', {}):
        img = data['services'][svc].get('image', '')
        if 'element' in img.lower() or 'element' in svc.lower():
            data['services'][svc]['image'] = f"{image_name}:{image_tag}"
            data['services'][svc].pop('build', None)
            with open(compose_file, 'w') as f:
                yaml.dump(data, f, default_flow_style=False, sort_keys=False)
            print(f"Updated service '{svc}' image to {image_name}:{image_tag}")
            break
    else:
        print("WARNING: No Element Web service found in compose file")
PYEOF
        else
            # Fallback: sed-based replacement
            # Match lines like "image: vectorim/element-web:latest" or "image: vectorim/element-web"
            sed -i -E "/(^[[:space:]]*${COMPOSE_SERVICE}:|element-web|element_web)/{
                n
                /image:/{
                    s|image:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|
                }
            }" "$COMPOSE_FILE"

            # Also do a direct image line replacement for any element-web image references
            sed -i -E "s|image:.*vectorim/element-web.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|g" "$COMPOSE_FILE"
            sed -i -E "s|image:.*element-web.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|g" "$COMPOSE_FILE"
        fi

        ok "Updated compose file"
    else
        warn "Service '$COMPOSE_SERVICE' not found in compose file."
        warn "Adding Phantomz service to compose file..."

        cat >> "$COMPOSE_FILE" <<YAML

  # Phantomz Network (Element Web fork)
  phantomz-web:
    image: ${IMAGE_NAME}:${IMAGE_TAG}
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - ./phantomz-config.json:/app/config.json:ro
YAML
        ok "Added phantomz-web service to compose file"
    fi
}

# ─── Step 4: Restart containers ───────────────────────────────────────────────
restart_containers() {
    if [[ -z "$COMPOSE_FILE" ]]; then
        # No compose file — just restart the standalone container if it exists
        if docker ps -a --format '{{.Names}}' | grep -q "phantomz-web"; then
            log "Restarting standalone container..."
            docker stop phantomz-web 2>/dev/null || true
            docker rm phantomz-web 2>/dev/null || true
            docker run -d --name phantomz-web -p 8080:80 "${IMAGE_NAME}:${IMAGE_TAG}"
            ok "Container restarted on port 8080"
        else
            log "Starting container..."
            docker run -d --name phantomz-web -p 8080:80 "${IMAGE_NAME}:${IMAGE_TAG}"
            ok "Container started on port 8080"
        fi
        return 0
    fi

    local compose_dir
    compose_dir="$(dirname "$COMPOSE_FILE")"

    log "Restarting containers from: $COMPOSE_FILE"

    cd "$compose_dir"

    # Determine docker compose command
    local dc_cmd
    if docker compose version &>/dev/null 2>&1; then
        dc_cmd="docker compose"
    elif command -v docker-compose &>/dev/null; then
        dc_cmd="docker-compose"
    else
        err "Neither 'docker compose' nor 'docker-compose' found!"
        exit 1
    fi

    $dc_cmd -f "$COMPOSE_FILE" up -d --force-recreate

    ok "Containers restarted"
}

# ─── Step 5: Cleanup old images ──────────────────────────────────────────────
cleanup() {
    log "Cleaning up dangling images..."
    docker image prune -f --filter "label!=keep" >/dev/null 2>&1 || true
    ok "Cleanup done"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║       PHANTOMZ NETWORK — Deploy          ║${NC}"
    echo -e "${PURPLE}║    Sovereign. Encrypted. Free.            ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════╝${NC}"
    echo ""

    # Verify Docker is available
    if ! command -v docker &>/dev/null; then
        err "Docker is not installed or not in PATH"
        exit 1
    fi

    generate_icons
    echo ""
    build_image
    echo ""
    update_compose
    echo ""
    restart_containers
    echo ""
    cleanup
    echo ""

    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Phantomz Network deployed successfully!${NC}"
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    echo ""

    if [[ -n "$COMPOSE_FILE" ]]; then
        log "Compose file: $COMPOSE_FILE"
    fi
    log "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
    log ""
    log "Next steps:"
    log "  1. Drop your logo as logo.png in this directory and re-run"
    log "  2. Edit apps/web/config.json to set your homeserver URL"
    log "  3. Access your instance and verify the branding"
    echo ""
}

main "$@"
