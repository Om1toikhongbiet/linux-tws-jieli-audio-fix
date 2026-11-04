#!/usr/bin/env bash
#
# Diagnostic script for Bluetooth TWS Audio issues on Linux
# Part of linux-tws-jieli-audio-fix
#

set -e

echo "========================================================"
echo "    Bluetooth TWS Audio Diagnostic Tool (Linux)         "
echo "========================================================"

echo ""
echo "--- [1] Checking Audio Server (PipeWire & WirePlumber) ---"
if command -v wpctl &>/dev/null; then
    wpctl status | head -n 30
else
    echo "wpctl not found. PipeWire/WirePlumber may not be installed."
fi

echo ""
echo "--- [2] Checking Connected Bluetooth Audio Devices ---"
if command -v bluetoothctl &>/dev/null; then
    connected_devs=$(bluetoothctl devices Connected | awk '{print $2}')
    if [ -z "$connected_devs" ]; then
        echo "No Bluetooth device currently connected."
    else
        for dev in $connected_devs; do
            echo "Device: $dev"
            bluetoothctl info "$dev" | grep -E "Name|Alias|Modalias|UUID" || true
            if command -v hcitool &>/dev/null; then
                echo "Link Mode / RSSI:"
                hcitool con | grep "$dev" || true
                hcitool rssi "$dev" 2>/dev/null || true
            fi
        done
    fi
fi

echo ""
echo "--- [3] Checking Bluetooth USB Adapter & TLP Power Status ---"
if command -v lsusb &>/dev/null; then
    echo "USB Bluetooth devices:"
    lsusb | grep -iE "bluetooth|realtek|intel" || true
fi

for dev in /sys/bus/usb/devices/*/power/control; do
    if [ -f "$dev" ]; then
        val=$(cat "$dev" 2>/dev/null || true)
        driver=$(cat "$(dirname "$dev")/../uevent" 2>/dev/null | grep DRIVER || true)
        if echo "$driver" | grep -qi "btusb"; then
            echo "BT Adapter USB power control: $val ($dev)"
        fi
    fi
done

echo ""
echo "--- [4] Active A2DP Bluetooth Sink Configuration ---"
if command -v busctl &>/dev/null; then
    transports=$(busctl tree org.bluez | grep -o "/org/bluez/.*fd[0-9]*" || true)
    if [ -n "$transports" ]; then
        for t in $transports; do
            echo "Transport: $t"
            busctl introspect org.bluez "$t" | grep -E "Codec|Configuration|State" || true
        done
    else
        echo "No active A2DP audio stream running right now."
    fi
fi

echo ""
echo "Diagnostic complete."
