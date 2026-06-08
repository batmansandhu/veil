#!/usr/bin/env bash
# Build Libbox.xcframework from sing-box using gomobile.
# Run on a Mac with Xcode + Go 1.21+ installed. Produces ./Frameworks/Libbox.xcframework.
#
# This embeds the GPLv3 sing-box engine. If you ship a closed-source client you MUST instead
# use an Apache/MIT engine (e.g. leaf) — see README "Engine bake-off".
set -euo pipefail
cd "$(dirname "$0")/.."

SINGBOX_REF="${SINGBOX_REF:-v1.11.0}"     # pin a release; bump deliberately
WORK="engine-src/sing-box"
OUT="Frameworks"

echo "==> Checking tools"
command -v go >/dev/null || { echo "Go 1.21+ required: https://go.dev/dl"; exit 1; }
command -v git >/dev/null || { echo "git required"; exit 1; }

echo "==> Installing gomobile"
go install golang.org/x/mobile/cmd/gomobile@latest
go install golang.org/x/mobile/cmd/gobind@latest
GOBIN_PATH="$(go env GOPATH)/bin"
export PATH="$PATH:$GOBIN_PATH"
gomobile init

echo "==> Fetching sing-box @ ${SINGBOX_REF}"
rm -rf "$WORK"; mkdir -p "$(dirname "$WORK")"
git clone --depth 1 --branch "$SINGBOX_REF" https://github.com/SagerNet/sing-box "$WORK"

echo "==> Building Libbox.xcframework (iOS, memory-trimmed)"
mkdir -p "$OUT"
pushd "$WORK" >/dev/null
# Keep build tags MINIMAL — every extra protocol costs binary + runtime memory in the NE.
# Add tags (with_quic, with_wireguard, with_utls, ...) only as you ship those protocols.
TAGS="with_gvisor,with_clash_api"
gomobile bind -v \
  -target ios \
  -tags "$TAGS" \
  -trimpath \
  -ldflags "-s -w" \
  -o "../../$OUT/Libbox.xcframework" \
  ./experimental/libbox
popd >/dev/null

echo "==> Done: $OUT/Libbox.xcframework"
echo "    Next: uncomment the framework dependency in project.yml, run 'xcodegen generate',"
echo "    and wire PacketTunnel/LibboxEngine.swift to the Libbox API."
