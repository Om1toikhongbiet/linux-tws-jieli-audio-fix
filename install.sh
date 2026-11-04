#!/usr/bin/env bash
#
# Installer for linux-tws-jieli-audio-fix
# Applies PipeWire and WirePlumber 0.5+ configurations for budget TWS earphones.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================================="
echo "  Installing Linux TWS Audio Fix (JieLi/Jerry Chipsets)   "
echo "=========================================================="

echo "[1/4] Creating WirePlumber & PipeWire configuration folders..."
mkdir -p "$HOME/.config/wireplumber/wireplumber.conf.d"
mkdir -p "$HOME/.config/pipewire/pipewire.conf.d"

echo "[2/4] Copying optimized audio configurations..."
cp -v "$SCRIPT_DIR/configs/50-bluez-fix.conf" "$HOME/.config/wireplumber/wireplumber.conf.d/50-bluez-fix.conf"
cp -v "$SCRIPT_DIR/configs/10-rates.conf" "$HOME/.config/pipewire/pipewire.conf.d/10-rates.conf"

echo "[3/4] Checking TLP power management..."
if command -v tlp &>/dev/null && [ -d "/etc/tlp.d" ]; then
    echo "TLP detected. Setting up USB autosuspend exclusion..."
    if [ "$EUID" -eq 0 ]; then
        cp -v "$SCRIPT_DIR/configs/99-bluetooth-fix.conf" "/etc/tlp.d/99-bluetooth-fix.conf"
        tlp start || true
    else
        echo "Note: To prevent TLP from putting your BT adapter to sleep, run:"
        echo "  sudo cp \"$SCRIPT_DIR/configs/99-bluetooth-fix.conf\" /etc/tlp.d/"
        echo "  sudo tlp start"
    fi
fi

echo "[4/4] Restarting user audio services..."
systemctl --user daemon-reload || true
systemctl --user restart wireplumber pipewire

echo ""
echo "=========================================================="
echo "  Installation Successful!                                "
echo "  Please disconnect and reconnect your Bluetooth earbuds. "
echo "=========================================================="
