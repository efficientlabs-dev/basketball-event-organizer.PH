#!/bin/bash
# ============================================
# Phantomz Network — Step 1: Apply VPS Config
# Run this on the VPS: ssh root@142.171.69.196
# ============================================

set -euo pipefail

echo "=== Phantomz Network VPS Config Setup ==="

cd /opt/phantomz-matrix

# Backup existing configs
echo "[1/4] Backing up existing configs..."
cp -f element-config.json element-config.json.bak 2>/dev/null || true
cp -f synapse-data/homeserver.yaml synapse-data/homeserver.yaml.bak 2>/dev/null || true

# Copy new element-config.json
echo "[2/4] Writing element-config.json..."
cat > element-config.json << 'ELEMENT_EOF'
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://matrix.phantomznetwork.xyz",
            "server_name": "phantomznetwork.xyz"
        }
    },
    "brand": "Phantomz Network",
    "disable_custom_urls": true,
    "disable_guests": true,
    "disable_login_language_selector": false,
    "disable_3pid_login": true,
    "default_country_code": "US",
    "default_theme": "dark",
    "room_directory": {
        "servers": ["phantomznetwork.xyz"]
    },
    "show_labs_settings": false,
    "default_federate": false,
    "enable_presence_by_hs_url": {
        "https://matrix.phantomznetwork.xyz": false
    },
    "setting_defaults": {
        "breadcrumbs": true,
        "custom_themes": [
            {
                "name": "Phantomz Dark",
                "is_dark": true,
                "colors": {
                    "accent-color": "#7B68EE",
                    "primary-color": "#7B68EE",
                    "warning-color": "#FF4444",
                    "sidebar-color": "#0A0A0A",
                    "roomlist-background-color": "#0F0F0F",
                    "roomlist-text-color": "#E0E0E0",
                    "roomlist-text-secondary-color": "#808080",
                    "roomlist-highlights-color": "#1A1A2E",
                    "roomlist-separator-color": "#2A2A2A",
                    "timeline-background-color": "#0D0D0D",
                    "timeline-text-color": "#E8E8E8",
                    "timeline-text-secondary-color": "#888888",
                    "timeline-highlights-color": "#1E1E3F",
                    "reaction-row-button-selected-bg-color": "#7B68EE33"
                }
            }
        ]
    },
    "features": {}
}
ELEMENT_EOF

# Copy new homeserver.yaml
echo "[3/4] Writing homeserver.yaml..."
cat > synapse-data/homeserver.yaml << 'SYNAPSE_EOF'
server_name: "phantomznetwork.xyz"
pid_file: /data/homeserver.pid
public_baseurl: https://matrix.phantomznetwork.xyz/

listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    resources:
      - names: [client, federation]
        compress: false

database:
  name: psycopg2
  args:
    user: synapse
    password: phantomz_db_2026
    database: synapse
    host: postgres
    cp_min: 2
    cp_max: 5

log_config: "/data/phantomznetwork.xyz.log.config"
media_store_path: /data/media_store
signing_key_path: "/data/phantomznetwork.xyz.signing.key"

registration_shared_secret: "phantomz_reg_secret_2026"
report_stats: false
enable_registration: false
enable_registration_without_verification: false

password_config:
  enabled: true
  localdb_enabled: true

encryption_enabled_by_default_for_room_type: all
federation_domain_whitelist: []

presence:
  enabled: false

retention:
  enabled: true
  default_policy:
    min_lifetime: 1d
    max_lifetime: 3d
  purge_jobs:
    - longest_max_lifetime: 3d
      interval: 12h

url_preview_enabled: false

rc_message:
  per_second: 5
  burst_count: 20

rc_login:
  address:
    per_second: 0.5
    burst_count: 5
  account:
    per_second: 0.5
    burst_count: 5

caches:
  global_factor: 0.5

enable_metrics: false
max_upload_size: 50M
max_image_pixels: 32M

user_directory:
  enabled: true
  search_all_users: true
  prefer_local_users: true

trusted_key_servers: []
suppress_key_server_warning: true
SYNAPSE_EOF

# Restart containers
echo "[4/4] Restarting containers..."
docker compose restart synapse element
sleep 5
docker compose ps

# Verify
echo ""
echo "=== Verification ==="
curl -s https://matrix.phantomznetwork.xyz/_matrix/client/versions | head -1
echo ""
echo "Done! Open https://element.phantomznetwork.xyz to verify branding."
