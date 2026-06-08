#!/usr/bin/env bash
# Bootstrap the Veil Xcode project on a Mac. Run from the repo root: ./scripts/bootstrap.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Checking tools"
command -v xcodebuild >/dev/null || { echo "Xcode required (xcode-select --install / App Store)"; exit 1; }

if ! command -v xcodegen >/dev/null; then
  echo "==> Installing XcodeGen via Homebrew"
  command -v brew >/dev/null || { echo "Install Homebrew first: https://brew.sh"; exit 1; }
  brew install xcodegen
fi

echo "==> Generating Veil.xcodeproj from project.yml"
xcodegen generate

cat <<'EOF'

==> Done. Next:
  1. Open Veil.xcodeproj in Xcode.
  2. Set your DEVELOPMENT_TEAM (Signing & Capabilities) on BOTH targets (Veil + PacketTunnel).
     NOTE: shipping a VPN app to the App Store needs an ORGANIZATION account (Guideline 5.4).
     For personal/TestFlight builds an individual account is fine.
  3. Build & run on a REAL DEVICE (the packet tunnel needs a device, not just the simulator).
  4. The UI works now; "Connect" fails with "engine not wired" until you build the engine:
     ./scripts/build-libbox.sh   then wire PacketTunnel/LibboxEngine.swift
EOF
