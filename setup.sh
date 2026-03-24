#!/bin/bash
# n8n Restish CLI — Setup Script
# Configures Restish to talk to your n8n instance via the public API.
#
# Prerequisites:
#   - Restish installed (https://rest.sh)
#   - n8n instance with API enabled
#   - n8n API key (Settings → API → Create API Key)
#
# Usage:
#   ./setup.sh <n8n-base-url> <api-key>
#   ./setup.sh https://n8n.example.com eyJhbGci...

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <n8n-base-url> <api-key>"
  echo "  Example: $0 https://n8n.example.com eyJhbGciOiJIUzI1NiJ9..."
  exit 1
fi

N8N_URL="${1%/}"  # strip trailing slash
N8N_API_KEY="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESTISH_CONFIG="$HOME/.config/restish/apis.json"

# Verify restish is installed
if ! command -v restish &>/dev/null; then
  echo "Error: restish not found. Install from https://rest.sh"
  exit 1
fi

# Verify n8n is reachable
echo "Testing connection to $N8N_URL..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_URL/api/v1/workflows?limit=1" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" != "200" ]; then
  echo "Error: Could not connect to n8n at $N8N_URL (HTTP $HTTP_CODE)"
  echo "Check your URL and API key."
  exit 1
fi
echo "Connection OK."

# Copy bundled spec to restish config dir
SPEC_DEST="$HOME/.config/restish/n8n-openapi.json"
mkdir -p "$(dirname "$SPEC_DEST")"
cp "$SCRIPT_DIR/n8n-openapi.json" "$SPEC_DEST"
echo "Copied OpenAPI spec to $SPEC_DEST"

# Add n8n entry to restish config
if [ ! -f "$RESTISH_CONFIG" ]; then
  echo '{}' > "$RESTISH_CONFIG"
fi

# Use python to merge the n8n config into existing apis.json
python3 - "$N8N_URL" "$N8N_API_KEY" "$SPEC_DEST" "$RESTISH_CONFIG" << 'PYEOF'
import sys, json

n8n_url = sys.argv[1]
api_key = sys.argv[2]
spec_path = sys.argv[3]
config_path = sys.argv[4]

with open(config_path) as f:
    config = json.load(f)

config["n8n"] = {
    "base": f"{n8n_url}/api/v1",
    "spec_files": [spec_path],
    "profiles": {
        "default": {
            "headers": {
                "X-N8N-API-KEY": api_key
            }
        }
    }
}

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

print(f"Added n8n API to {config_path}")
PYEOF

echo ""
echo "Setup complete! Try these commands:"
echo ""
echo "  restish n8n                           # List all available commands"
echo "  restish n8n get-api-v1-workflows      # List workflows"
echo "  restish n8n get-api-v1-executions     # List recent executions"
echo "  restish n8n get-credentials           # List credentials"
echo "  restish n8n get-api-v1-tags           # List tags"
echo ""
