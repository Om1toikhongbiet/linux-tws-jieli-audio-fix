# Linux Bluetooth TWS Audio Stutter Fix (JieLi / Jerry SoC & Realtek Adapters)

> **Fix audio stuttering, crackling, and dropouts after 15–20 seconds on Linux (PipeWire / WirePlumber 0.5+) when using budget True Wireless Stereo (TWS) earbuds.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-blue.svg)](https://kernel.org)
[![Audio: PipeWire](https://img.shields.io/badge/Audio-PipeWire%20%2F%20WirePlumber-red.svg)](https://gitlab.freedesktop.org/pipewire/pipewire)

---

## 🎯 Symptoms / Dấu hiệu nhận biết

You are likely affected by this issue if your Bluetooth earbuds meet these criteria:
* **The 20-Second Stutter:** Audio plays perfectly for the first 15–20 seconds, then degrades into severe skipping, stuttering, and crackling (packets dropping).
* **The Single-Earbud Test:** If you place one earbud back into the charging case and listen with **only one earbud**, the audio plays **completely smoothly** without any stuttering.
* **The Mono Test:** If you force the audio channel to Mono, playback becomes smooth in both ears, but switching back to standard Stereo brings the stuttering back.
* **Budget TWS Earbuds:** Commonly found on generic or budget earbuds under $10–$20 (e.g., GOOJODOQ, Lenovo, Baseus, Hoco, Amoi, Pro 4/5 clones) powered by **Zhuhai JieLi (Jerry) AC69xx / JL70xx** Bluetooth audio SoCs (`Vendor ID: bluetooth:v05D6p000A`).
* **Host Hardware:** Frequently reproduced on laptops with **Realtek RTL8821CE / RTL8822CE** (`0bda:b00e`) combo Wi-Fi/Bluetooth single-antenna chips running PipeWire on modern distributions (Ubuntu 22.04/24.04/26.04, Arch Linux, Fedora).

---

## 🔬 Root Cause Analysis / Bản chất kỹ thuật

### 1. TWS Master-Slave Relay Starvation
Budget TWS earbuds do not implement independent dual-reception (sniffing). Instead:
1. The **Master earbud** connects to your Linux laptop over Bluetooth A2DP.
2. The Master earbud decodes/relays audio frames to the **Slave earbud** over a secondary wireless link.

### 2. High Bitrate SBC Overload (48 kHz / Bitpool 53)
* On Linux, PipeWire negotiates standard SBC at **48.000 Hz Joint Stereo** with maximum bitpool (Bitpool = 53), producing a bitrate of **~357 kbps** using multi-slot DH5 packets.
* The Master earbud's radio is saturated listening to the laptop's continuous DH5 packets, leaving **insufficient empty radio time-slots** to relay packets to the Slave earbud.
* After ~15–20 seconds, the Slave earbud's local jitter buffer drains completely. Retransmission requests (ARQ/NAK) cascade between the earbuds, backing up the Bluetooth socket on Linux (`written == -EAGAIN` in PipeWire `media-sink.c`), causing both earbuds to glitch and drop audio.

### 3. Why 44.1 kHz Native Stereo Solves It
* Switching the Bluetooth negotiation to **44.100 Hz** reduces the A2DP bandwidth by **8%–10%** (~328 kbps).
* This 10% breathing room provides the Master earbud enough idle radio slots to relay data to the Slave earbud without starving its buffer.
* **Bonus:** 99% of streaming music (YouTube, Spotify, MP3) is natively 44.1 kHz. Playing at 44.1 kHz is **bit-perfect (1:1)** and eliminates host resampling artifacts!

---

## ⚡ Quick Fix / Cài đặt nhanh

### Automatic Installation
Clone this repository and run the installer:

```bash
git clone https://github.com/Om1toikhongbiet/linux-tws-jieli-audio-fix.git ~/repo/linux-tws-jieli-audio-fix
cd ~/repo/linux-tws-jieli-audio-fix
chmod +x install.sh uninstall.sh scripts/*.sh
./install.sh
```

Then disconnect and reconnect your Bluetooth earbuds:
```bash
bluetoothctl disconnect <YOUR_MAC_ADDRESS>
bluetoothctl connect <YOUR_MAC_ADDRESS>
```

---

## 🛠️ Manual Installation / Cấu hình thủ công

If you prefer to configure manually:

### Step 1: Configure WirePlumber (0.5+)
Create `~/.config/wireplumber/wireplumber.conf.d/50-bluez-fix.conf`:

```spa-json
monitor.bluez.properties = {
  bluez5.default.rate = 44100
  bluez5.enable-sbc-xq = false
  bluez5.enable-msbc = false
  bluez5.enable-hw-volume = false
  bluez5.roles = [ a2dp_source ]
}

monitor.bluez.rules = [
  {
    matches = [
      {
        node.name = "~bluez_output.*"
      }
    ]
    actions = {
      update-props = {
        node.latency = "2048/44100"
        audio.rate = 44100
      }
    }
  }
]
```

### Step 2: Configure PipeWire Clock Rates
Create `~/.config/pipewire/pipewire.conf.d/10-rates.conf`:

```spa-json
context.properties = {
  default.clock.rate = 44100
  default.clock.allowed-rates = [ 44100, 48000 ]
  default.clock.min-quantum = 512
  default.clock.quantum = 2048
  default.clock.max-quantum = 4096
}
```

### Step 3: Prevent TLP Autosuspend on Bluetooth Radio (Optional but Recommended)
If you use TLP, create `/etc/tlp.d/99-bluetooth-fix.conf`:

```bash
echo -e 'USB_EXCLUDE_BTUSB=1\nUSB_DENYLIST="0bda:b00e"' | sudo tee /etc/tlp.d/99-bluetooth-fix.conf
sudo tlp start
```

### Step 4: Restart Audio Services
```bash
systemctl --user restart wireplumber pipewire
```

---

## 🔍 Diagnostics / Kiểm tra chẩn đoán

Run the included diagnostic script to inspect your active Bluetooth connection, negotiated codec, and power states:

```bash
./scripts/diagnose.sh
```

To verify that your earbuds negotiated 44.1 kHz Joint Stereo (`0x21`):
```bash
busctl introspect org.bluez $(busctl tree org.bluez | grep -o "/org/bluez/.*fd0") | grep Configuration
# Expected output:
# .Configuration property ay 4 33 21 2 53
# (0x21 = 44100 Hz Joint Stereo)
```

---

## 🗑️ Uninstallation / Gỡ cài đặt

To revert all changes back to your system defaults:
```bash
cd ~/repo/linux-tws-jieli-audio-fix
./uninstall.sh
```

---

## 📜 License
Distributed under the [MIT License](LICENSE).
