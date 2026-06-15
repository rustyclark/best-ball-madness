#!/bin/bash

# Exit on error
set -e

# Get directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

# Load environment variables from .env or .env.local if present
load_env() {
  local env_file="$1"
  if [ -f "$env_file" ]; then
    echo "Loading environment variables from $(basename "$env_file")..."
    # Export vars, ignoring comments and blank lines
    export $(grep -v '^#' "$env_file" | grep -v '^[[:space:]]*$' | xargs)
  fi
}

# Check .env first, then override with .env.local if exists
load_env "$PROJECT_ROOT/.env"
load_env "$PROJECT_ROOT/.env.local"

# Allow override via arguments
# Usage: ./trigger_sync_stats.sh [SUPABASE_URL] [SERVICE_ROLE_KEY]
URL="${1:-$SUPABASE_URL}"
KEY="${2:-$SUPABASE_SERVICE_ROLE_KEY}"

# Fallback to SUPABASE_SECRET_KEY if SUPABASE_SERVICE_ROLE_KEY is not set
if [ -z "$KEY" ]; then
  KEY="$SUPABASE_SECRET_KEY"
fi

if [ -z "$URL" ] || [ -z "$KEY" ]; then
  echo "Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (or SUPABASE_SECRET_KEY) must be set in env or passed as arguments."
  echo "Usage: $0 [SUPABASE_URL] [SERVICE_ROLE_KEY]"
  exit 1
fi

# Normalize URL (remove trailing slash)
URL="${URL%/}"

echo "Triggering update-golfer-stats on: $URL"
echo "Sending POST request..."

curl -i -X POST "$URL/functions/v1/update-golfer-stats" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{}'

echo ""
echo "Done."
