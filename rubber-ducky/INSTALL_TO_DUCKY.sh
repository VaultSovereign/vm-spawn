#!/usr/bin/env bash
# INSTALL_TO_DUCKY.sh - Prepare Rubber Ducky with VaultMesh Spawn Elite
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                                                               ║${NC}"
echo -e "${PURPLE}║   🦆  RUBBER DUCKY FORGE INSTALLER                            ║${NC}"
echo -e "${PURPLE}║                                                               ║${NC}"
echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running from correct directory
if [[ ! -f "../spawn.sh" ]]; then
  echo -e "${RED}❌ Error: Run this from the rubber-ducky/ directory${NC}"
  echo "   cd rubber-ducky && ./INSTALL_TO_DUCKY.sh"
  exit 1
fi

# Find Rubber Ducky
echo -e "${CYAN}🔍 Looking for Rubber Ducky...${NC}"
DUCKY_PATH=$(ls -d /Volumes/DUCKY* /Volumes/*DUCKY* 2>/dev/null | head -1 || echo "")

if [[ -z "$DUCKY_PATH" ]]; then
  echo -e "${RED}❌ Rubber Ducky not found!${NC}"
  echo ""
  echo "Available volumes:"
  ls -1 /Volumes/ | sed 's/^/  - /'
  echo ""
  echo -e "${YELLOW}Please:${NC}"
  echo "  1. Plug in your Rubber Ducky"
  echo "  2. Wait for it to mount"
  echo "  3. Run this script again"
  exit 1
fi

echo -e "${GREEN}✅ Found Rubber Ducky at: $DUCKY_PATH${NC}"
echo ""

# Ask user which strategy
echo -e "${CYAN}📦 Choose deployment strategy:${NC}"
echo ""
echo "  1) GitHub Strategy (requires internet, ~2 KB payload)"
echo "  2) Offline Strategy (no internet needed, ~87 KB payload)"
echo ""
read -p "Enter choice [1 or 2]: " STRATEGY

case "$STRATEGY" in
  1)
    echo ""
    echo -e "${CYAN}📡 Installing GitHub Strategy...${NC}"
    echo ""
    
    # Check if encoder available
    if [[ ! -f "duckencoder.jar" ]]; then
      echo -e "${YELLOW}⚠️  DuckEncoder not found${NC}"
      echo ""
      echo "You'll need to encode the payload manually:"
      echo "  1. Get DuckEncoder from: https://github.com/hak5darren/USB-Rubber-Ducky"
      echo "  2. Run: java -jar duckencoder.jar -i payload-github.txt -o inject.bin"
      echo "  3. Copy inject.bin to $DUCKY_PATH/"
      echo ""
      echo "For now, copying raw payload..."
      cp payload-github.txt "$DUCKY_PATH/payload.txt"
      echo -e "${GREEN}✅ Copied payload-github.txt to Rubber Ducky${NC}"
    else
      echo "Encoding payload..."
      java -jar duckencoder.jar -i payload-github.txt -o inject.bin
      cp inject.bin "$DUCKY_PATH/"
      echo -e "${GREEN}✅ Encoded and installed inject.bin${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}🎉 GitHub Strategy installed!${NC}"
    echo ""
    echo "When you plug in the Rubber Ducky, it will:"
    echo "  1. Open terminal"
    echo "  2. Clone from GitHub"
    echo "  3. Run health check"
    echo "  4. Show welcome message"
    ;;
    
  2)
    echo ""
    echo -e "${CYAN}💾 Installing Offline Strategy...${NC}"
    echo ""
    
    # Create PAYLOAD directory
    mkdir -p "$DUCKY_PATH/PAYLOAD"
    
    # Copy entire vm-spawn (from parent directory)
    echo "Copying VaultMesh to USB..."
    cp -r ../ "$DUCKY_PATH/PAYLOAD/vm-spawn/"
    
    # Remove git history to save space
    rm -rf "$DUCKY_PATH/PAYLOAD/vm-spawn/.git" 2>/dev/null || true
    
    # Remove rubber-ducky folder (don't need it on USB)
    rm -rf "$DUCKY_PATH/PAYLOAD/vm-spawn/rubber-ducky" 2>/dev/null || true
    
    echo -e "${GREEN}✅ Copied VaultMesh to USB ($(du -sh "$DUCKY_PATH/PAYLOAD/vm-spawn" | awk '{print $1}'))${NC}"
    
    # Encode payload
    if [[ ! -f "duckencoder.jar" ]]; then
      echo -e "${YELLOW}⚠️  DuckEncoder not found${NC}"
      echo ""
      echo "You'll need to encode the payload manually:"
      echo "  1. Get DuckEncoder from: https://github.com/hak5darren/USB-Rubber-Ducky"
      echo "  2. Run: java -jar duckencoder.jar -i payload-offline.txt -o inject.bin"
      echo "  3. Copy inject.bin to $DUCKY_PATH/"
      echo ""
      echo "For now, copying raw payload..."
      cp payload-offline.txt "$DUCKY_PATH/payload.txt"
      echo -e "${GREEN}✅ Copied payload-offline.txt to Rubber Ducky${NC}"
    else
      echo "Encoding payload..."
      java -jar duckencoder.jar -i payload-offline.txt -o inject.bin
      cp inject.bin "$DUCKY_PATH/"
      echo -e "${GREEN}✅ Encoded and installed inject.bin${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}🎉 Offline Strategy installed!${NC}"
    echo ""
    echo "When you plug in the Rubber Ducky, it will:"
    echo "  1. Open terminal"
    echo "  2. Copy from USB (no internet needed)"
    echo "  3. Run health check"
    echo "  4. Show welcome message"
    echo ""
    echo "USB contents:"
    echo "  - inject.bin (payload)"
    echo "  - PAYLOAD/vm-spawn/ (full system)"
    ;;
    
  *)
    echo -e "${RED}❌ Invalid choice${NC}"
    exit 1
    ;;
esac

# Show final status
echo ""
echo -e "${CYAN}📊 Rubber Ducky Status:${NC}"
echo "  Path: $DUCKY_PATH"
echo "  Free space: $(df -h "$DUCKY_PATH" | tail -1 | awk '{print $4}')"
echo "  Used space: $(df -h "$DUCKY_PATH" | tail -1 | awk '{print $3}')"
echo ""

# Safety reminder
echo -e "${YELLOW}⚠️  SECURITY REMINDER:${NC}"
echo "  - Label your USB clearly: 'VaultMesh Installer'"
echo "  - Use only on your own machines"
echo "  - Keep physical control (don't leave unattended)"
echo "  - Rubber Ducky executes immediately when plugged in"
echo ""

# Eject prompt
echo -e "${CYAN}🦆 Ready to deploy!${NC}"
echo ""
read -p "Eject Rubber Ducky now? [y/N]: " EJECT

if [[ "$EJECT" =~ ^[Yy]$ ]]; then
  diskutil eject "$DUCKY_PATH"
  echo -e "${GREEN}✅ Rubber Ducky ejected safely${NC}"
  echo ""
  echo "🦆 Plug it into any Mac to auto-install VaultMesh!"
else
  echo -e "${YELLOW}⚠️  Remember to eject safely before unplugging${NC}"
fi

echo ""
echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                                                               ║${NC}"
echo -e "${PURPLE}║   🦆  The forge is in your pocket                             ║${NC}"
echo -e "${PURPLE}║   🧠  The memory is portable                                  ║${NC}"
echo -e "${PURPLE}║   ⚔️  The civilization deploys via USB                        ║${NC}"
echo -e "${PURPLE}║                                                               ║${NC}"
echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

