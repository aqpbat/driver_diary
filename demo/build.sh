#!/bin/sh
# Rebuilds demo/web/ — the ready-made web client that demo/start.command and
# demo/start.bat serve. Run it after changing the client, then commit the
# result. Needs the Flutter SDK; people who only start the demo do not.
set -eu

# The demo talks to the deployed API, so nothing has to run locally.
API_BASE_URL="${API_BASE_URL:-https://api-production-ab4d.up.railway.app}"

cd "$(dirname "$0")/../mobile"
flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL"

# canvaskit/ (36 MB) stays out: the page loads the renderer from Google's CDN,
# the local copy is only a fallback for builds made with --no-web-resources-cdn.
rsync -a --delete --exclude canvaskit/ --exclude .last_build_id \
  build/web/ ../demo/web/

du -sh ../demo/web
