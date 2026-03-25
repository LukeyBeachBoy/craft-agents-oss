#!/bin/bash
set -e

# Build "Luke Agents" — a personal remix of Craft Agents
# Runs alongside the official app with its own data directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ELECTRON_DIR="$SCRIPT_DIR"
ROOT_DIR="$(dirname "$(dirname "$ELECTRON_DIR")")"

echo "=== Building Luke Agents ==="

# 1. Build everything (shared + core + electron)
echo "Building..."
cd "$ROOT_DIR"
bun install
bun run electron:build

# 2. Patch electron-builder config for personal build
# Create a temporary override config
cat > "$ELECTRON_DIR/electron-builder-luke.yml" << 'EOF'
extends: electron-builder.yml

appId: com.lukeybeachboy.luke-agents
productName: Luke Agents

mac:
  category: public.app-category.productivity
  icon: resources/icon.icns
  extendInfo:
    CFBundleIconName: AppIcon
  target:
    - target: dmg
      arch:
        - arm64
  artifactName: "Luke-Agents-${arch}.${ext}"

dmg:
  artifactName: "Luke-Agents-${arch}.dmg"
  title: "Luke Agents"
  background: resources/dmg-background.tiff
  icon: resources/icon.icns
  iconSize: 80
  contents:
    - x: 130
      y: 200
    - x: 410
      y: 200
      type: link
      path: /Applications
  window:
    width: 540
    height: 380

# Disable auto-update (we build manually)
publish: null
EOF

# 3. Set CRAFT_CONFIG_DIR so the app uses a separate data directory
# This prevents conflicts with the official Craft Agents app
export CRAFT_CONFIG_DIR="$HOME/.luke-agents"

# 4. (Post-packaging patch will be applied after electron-builder, see step 9)

# 5. Copy SDK (same as official build)
SDK_SOURCE="$ROOT_DIR/node_modules/@anthropic-ai/claude-agent-sdk"
if [ -d "$SDK_SOURCE" ]; then
  echo "Copying SDK..."
  mkdir -p "$ELECTRON_DIR/node_modules/@anthropic-ai"
  cp -r "$SDK_SOURCE" "$ELECTRON_DIR/node_modules/@anthropic-ai/"
fi

# 6. Copy interceptor
for f in unified-network-interceptor.ts interceptor-common.ts feature-flags.ts interceptor-request-utils.ts; do
  if [ -f "$ROOT_DIR/packages/shared/src/$f" ]; then
    mkdir -p "$ELECTRON_DIR/packages/shared/src"
    cp "$ROOT_DIR/packages/shared/src/$f" "$ELECTRON_DIR/packages/shared/src/"
  fi
done

# 7. Download bundled Bun (if not already present)
if [ ! -f "$ELECTRON_DIR/vendor/bun/bun" ]; then
  BUN_VERSION="bun-v1.3.9"
  echo "Downloading Bun ${BUN_VERSION}..."
  mkdir -p "$ELECTRON_DIR/vendor/bun"
  TEMP_DIR=$(mktemp -d)
  curl -fSL "https://github.com/oven-sh/bun/releases/download/${BUN_VERSION}/bun-darwin-aarch64.zip" -o "$TEMP_DIR/bun.zip"
  unzip -o "$TEMP_DIR/bun.zip" -d "$TEMP_DIR"
  cp "$TEMP_DIR/bun-darwin-aarch64/bun" "$ELECTRON_DIR/vendor/bun/"
  chmod +x "$ELECTRON_DIR/vendor/bun/bun"
  rm -rf "$TEMP_DIR"
fi

# 8. Package with electron-builder using our override config
echo "Packaging Luke Agents..."
cd "$ELECTRON_DIR"
npx electron-builder --mac --arm64 --config electron-builder-luke.yml

# 9. Patch the packaged app's app name so Electron uses a separate userData dir and instance lock
# This lets Luke Agents run alongside official Craft Agents simultaneously.
# We do NOT patch ".craft-agent" — both apps share the same data directory (~/.craft-agent)
# for sources, skills, workspaces, preferences, conversations, etc.
PACKAGED_MAIN="$ELECTRON_DIR/release/mac-arm64/Luke Agents.app/Contents/Resources/app/dist/main.cjs"
if [ -f "$PACKAGED_MAIN" ]; then
  sed -i '' 's|Craft Agents|Luke Agents|g' "$PACKAGED_MAIN"
  echo "Patched app name → Luke Agents (shared data dir: ~/.craft-agent)"
else
  echo "WARNING: Could not find packaged main.cjs to patch"
fi

# 10. Re-sign after patching (ad-hoc, since we modified the binary)
codesign --force --deep --sign - "$ELECTRON_DIR/release/mac-arm64/Luke Agents.app" 2>/dev/null || true

# 11. Clean up temp config
rm -f "$ELECTRON_DIR/electron-builder-luke.yml"

# 12. Done
DMG_PATH="$ELECTRON_DIR/release/Luke-Agents-arm64.dmg"
if [ -f "$DMG_PATH" ]; then
  echo ""
  echo "=== Build Complete ==="
  echo "DMG: $DMG_PATH"
  echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
  echo ""
  echo "Data directory: ~/.luke-agents"
  echo "Install: Open the DMG and drag to Applications"
  echo ""
  echo "IMPORTANT: After installing, remove macOS quarantine:"
  echo "  xattr -cr /Applications/Luke\\ Agents.app"
  echo ""
  echo "First run: Your workspaces/sources/preferences will be empty."
  echo "To copy your existing config:"
  echo "  cp -r ~/.craft-agent/* ~/.luke-agents/"
else
  echo "ERROR: DMG not found at $DMG_PATH"
  ls -la "$ELECTRON_DIR/release/" 2>/dev/null
  exit 1
fi
