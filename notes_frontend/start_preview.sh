#!/usr/bin/env bash
set -euo pipefail

# Preview entrypoint for this Flutter container.
# It builds Flutter Web output into ./build/web and serves it over HTTP.
#
# Usage:
#   ./start_preview.sh <port>
#
# Notes:
# - We bind to 0.0.0.0 so the preview system can reach the server.
# - We use Python's http.server to serve static build output.
# - The preview manager will replace <port> in the manifest and pass it here.

PORT="${1:-3001}"

cd "$(dirname "$0")"

# Ensure dependencies are available (idempotent).
flutter pub get

# Build for web. --release is smaller/faster to serve and avoids dev-server complexities.
flutter build web --release

# Serve the built static files.
cd build/web

# Prefer python3, fall back to python if needed.
if command -v python3 >/dev/null 2>&1; then
  exec python3 -m http.server "${PORT}" --bind 0.0.0.0
else
  exec python -m http.server "${PORT}" --bind 0.0.0.0
fi
