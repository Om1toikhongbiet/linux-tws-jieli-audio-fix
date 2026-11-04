#!/usr/bin/env bash
#
# Uninstaller for linux-tws-jieli-audio-fix
# Reverts WirePlumber and PipeWire configurations.
#

set -e

echo "Reverting audio configurations..."
rm -vf "$HOME/.config/wireplumber/wireplumber.conf.d/50-bluez-fix.conf"
rm -vf "$HOME/.config/pipewire/pipewire.conf.d/10-rates.conf"

if [ -f "/etc/tlp.d/99-bluetooth-fix.conf" ]; then
    echo "To remove the TLP override, run:"
    echo "  sudo rm -f /etc/tlp.d/99-bluetooth-fix.conf && sudo tlp start"
fi

echo "Restarting audio services..."
systemctl --user restart wireplumber pipewire

echo "Uninstallation complete."
