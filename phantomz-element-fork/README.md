# Phantomz Network — Element Web Fork

Custom-branded Element Web client for Phantomz Network.

## Quick Deploy (VPS)

```bash
# 1. Pull the repo onto your VPS
git pull

# 2. (Optional) Drop your logo file in this directory
cp /path/to/your/logo.png ./logo.png

# 3. Run the deploy script
./deploy.sh
```

The deploy script handles everything:
- Generates icon sizes (24, 120, 144, 152, 180, 512, 1024px) from your logo file
- Builds the Docker image from `Dockerfile.phantomz`
- Updates your `docker-compose.yml` to swap the stock Element Web container
- Restarts all containers

## Deploy Options

```bash
./deploy.sh                                    # Auto-detect everything
./deploy.sh --logo /path/to/logo.png           # Use specific logo
./deploy.sh --skip-icons                       # Skip icon generation
./deploy.sh --compose-file /opt/docker-compose.yml  # Specify compose file
./deploy.sh --service element-web              # Compose service name to replace
```

## Configuration

Edit `apps/web/config.json` to configure:
- `default_server_config` — Your Matrix homeserver URL
- `brand` — Display name (default: "Phantomz Network")
- `branding.auth_header_logo_url` — Logo on login page
- `setting_defaults` — Feature toggles

## What's Changed from Stock Element Web

- **Branding**: All "Element" references replaced with "Phantomz Network"
- **Theme**: Dark theme with purple (#7B68EE) accent color
- **Login page**: Dark background, custom welcome text, Element.io links removed
- **Auth footer**: Replaced with "Sovereign. Encrypted. Free." tagline
- **Hidden UI**: Server picker, labs settings, rageshake/feedback, Element.io links
- **Config defaults**: Disabled integrations, analytics, third-party ID prompts

## File Structure

```
├── deploy.sh                          # VPS deployment script
├── Dockerfile.phantomz                # Docker build file
├── apps/web/
│   ├── config.json                    # Runtime config (edit this!)
│   ├── src/
│   │   ├── SdkConfig.ts              # Brand defaults
│   │   ├── vector/index.html          # HTML template
│   │   └── components/views/auth/     # Login/auth components
│   └── res/
│       ├── css/_phantomz-overrides.pcss  # CSS overrides
│       ├── welcome.html               # Welcome page
│       ├── manifest.json              # PWA manifest
│       └── themes/phantomz/           # Theme assets & logos
└── logo.png                           # Drop your logo here
```
