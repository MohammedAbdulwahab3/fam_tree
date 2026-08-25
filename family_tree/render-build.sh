#!/usr/bin/env bash
#
# Builds the Flutter web bundle on Render.
#
# Render's static-site builders ship Node, Python and Ruby but no Flutter SDK,
# so the toolchain has to be fetched here. Runs with family_tree/ as the
# working directory (rootDir in render.yaml).
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.35.6}"
FLUTTER_DIR="${HOME}/flutter"

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  echo "==> Fetching Flutter ${FLUTTER_VERSION}"
  git clone --depth 1 --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"

# The SDK checkout is owned by a different uid than the build process, and git
# refuses to read such a repo. Every flutter command shells out to git, so
# without this the build dies on "detected dubious ownership".
git config --global --add safe.directory "${FLUTTER_DIR}"

flutter --version
flutter config --enable-web --no-analytics
flutter pub get

# The API URL is compiled into the bundle: String.fromEnvironment resolves at
# build time, so pointing the app at a different backend means rebuilding.
# API_HOST comes from render.yaml's fromService block and carries no scheme.
API_BASE_URL="${API_BASE_URL:-https://${API_HOST}}"

echo "==> Building web bundle against ${API_BASE_URL}"
flutter build web --release \
  --dart-define=API_BASE_URL="${API_BASE_URL}" \
  --dart-define=FAMILY_TREE_ID="${FAMILY_TREE_ID:-main-family-tree}"
