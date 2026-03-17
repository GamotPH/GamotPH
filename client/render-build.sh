#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

FLUTTER_VERSION="3.29.2"
FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_ARCHIVE}"
FLUTTER_DIR="${PWD}/.render-flutter"

echo "Installing Flutter ${FLUTTER_VERSION} for Render build..."

rm -rf "${FLUTTER_DIR}"
mkdir -p "${FLUTTER_DIR}"

curl -L "${FLUTTER_URL}" -o /tmp/${FLUTTER_ARCHIVE}
tar -xf /tmp/${FLUTTER_ARCHIVE} -C "${FLUTTER_DIR}" --strip-components=1

export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release
