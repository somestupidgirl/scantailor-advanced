#!/usr/bin/env bash
# Build ScanTailor Advanced and create a signed .ipa for iOS.
# Usage: ./build-ios.sh [build_dir]
# Requires: Qt 6.x with iOS target, Xcode, aqtinstall or Qt Installer
#
# Environment variables (override defaults):
#   QT_IOS_DIR     Path to Qt iOS installation  (e.g. ~/Qt/6.12.0/ios)
#   QT_MACOS_DIR   Path to Qt macOS installation (e.g. ~/Qt/6.12.0/macos)
#   TEAM_ID        Apple Developer Team ID        (e.g. QRT57HMJMV)
#   BUNDLE_ID      App bundle identifier          (e.g. com.yourname.scantailor)
#   DEVICE_ID      Target device UDID for install (optional)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BUILD_DIR="${1:-build-ios}"
mkdir -p "$BUILD_DIR"
BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"

# ── Locate Qt ──────────────────────────────────────────────────────────────────

# Auto-detect Qt if not set via environment
if [[ -z "$QT_IOS_DIR" ]]; then
  QT_IOS_DIR=$(find ~/Qt -name "Qt6Config.cmake" 2>/dev/null \
    | grep "/ios/" | head -1 | sed 's|/lib/cmake/Qt6/Qt6Config.cmake||')
fi
if [[ -z "$QT_MACOS_DIR" ]]; then
  QT_MACOS_DIR=$(find ~/Qt -name "Qt6Config.cmake" 2>/dev/null \
    | grep "/macos/" | head -1 | sed 's|/lib/cmake/Qt6/Qt6Config.cmake||')
fi

if [[ -z "$QT_IOS_DIR" || ! -d "$QT_IOS_DIR" ]]; then
  echo "Error: Could not find Qt iOS installation." >&2
  echo "Install via: aqt install-qt mac ios <version> ios --outputdir ~/Qt" >&2
  echo "Or set QT_IOS_DIR=/path/to/Qt/6.x.x/ios" >&2
  exit 1
fi
if [[ -z "$QT_MACOS_DIR" || ! -d "$QT_MACOS_DIR" ]]; then
  echo "Error: Could not find Qt macOS installation (needed for host tools)." >&2
  echo "Install via: aqt install-qt mac desktop <version> clang_64 --outputdir ~/Qt" >&2
  echo "Or set QT_MACOS_DIR=/path/to/Qt/6.x.x/macos" >&2
  exit 1
fi

echo "Qt iOS:  $QT_IOS_DIR"
echo "Qt macOS: $QT_MACOS_DIR"

# ── Signing identity ───────────────────────────────────────────────────────────

if [[ -z "$TEAM_ID" ]]; then
  # Try to extract from keychain
  TEAM_ID=$(security find-identity -v -p codesigning 2>/dev/null \
    | grep "Apple Development" | head -1 \
    | sed -n 's/.*(\([A-Z0-9]*\)).*/\1/p')
fi
if [[ -z "$TEAM_ID" ]]; then
  echo "Error: Could not determine Team ID." >&2
  echo "Set TEAM_ID=XXXXXXXXXX (10-char code from Apple Developer account)." >&2
  exit 1
fi

BUNDLE_ID="${BUNDLE_ID:-com.yourname.scantailor}"
echo "Team ID:   $TEAM_ID"
echo "Bundle ID: $BUNDLE_ID"

# ── Extract version ────────────────────────────────────────────────────────────

VERSION=$(sed -n 's/^#define VERSION "\([^"]*\)".*/\1/p' version.h.in)
if [[ -z "$VERSION" ]]; then
  echo "Error: could not read VERSION from version.h.in" >&2
  exit 1
fi
echo "Building ScanTailor Advanced ${VERSION} for iOS"

# ── Generate icons ─────────────────────────────────────────────────────────────

if [[ -f "${SCRIPT_DIR}/generate-icons.sh" ]]; then
  echo "Generating icons..."
  bash "${SCRIPT_DIR}/generate-icons.sh"
else
  echo "Warning: generate-icons.sh not found, skipping icon generation." >&2
fi

# ── Configure ─────────────────────────────────────────────────────────────────

cd "$BUILD_DIR"
cmake -G Xcode \
  -DQt6_DIR="${QT_IOS_DIR}/lib/cmake/Qt6" \
  -DQT_HOST_PATH="${QT_MACOS_DIR}" \
  -DCMAKE_PREFIX_PATH="${QT_IOS_DIR};${QT_MACOS_DIR}" \
  -DCMAKE_TOOLCHAIN_FILE="${QT_IOS_DIR}/lib/cmake/Qt6/qt.toolchain.cmake" \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH \
  -DMACOSX_BUNDLE_GUI_IDENTIFIER="${BUNDLE_ID}" \
  -DXCODE_ATTRIBUTE_DEVELOPMENT_TEAM="${TEAM_ID}" \
  "$SCRIPT_DIR"

# ── Build ──────────────────────────────────────────────────────────────────────

xcodebuild \
  -project "ScanTailor Advanced.xcodeproj" \
  -scheme "scantailor-advanced" \
  -destination "generic/platform=iOS" \
  -configuration Release \
  -allowProvisioningUpdates \
  build

# ── Package as IPA ────────────────────────────────────────────────────────────

APP=$(find "$BUILD_DIR" -name "scantailor-advanced.app" \
  -not -path "*/simulator/*" | head -1)

if [[ -z "$APP" ]]; then
  echo "Error: could not find built .app" >&2
  exit 1
fi

IPA_DIR="/tmp/scantailor-ipa-$$"
mkdir -p "${IPA_DIR}/Payload"
cp -r "$APP" "${IPA_DIR}/Payload/"

IPA_PATH="${SCRIPT_DIR}/scantailor-advanced_${VERSION}_ios.ipa"
cd "$IPA_DIR"
zip -r "$IPA_PATH" Payload/
rm -rf "$IPA_DIR"

echo "Done: $IPA_PATH"

# ── Optional device install ───────────────────────────────────────────────────

if [[ -n "$DEVICE_ID" ]]; then
  echo "Installing on device $DEVICE_ID ..."
  xcrun devicectl device install app \
    --device "$DEVICE_ID" "$APP"
  echo "Installed."
fi
