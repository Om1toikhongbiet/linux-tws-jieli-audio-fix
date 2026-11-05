# Linux Bluetooth TWS Audio Stutter Fix (JieLi / Jerry SoC & Realtek Adapters)

> **Fix audio stuttering, crackling, and dropouts after 15–20 seconds on Linux (PipeWire / WirePlumber 0.5+) when using budget True Wireless Stereo (TWS) earbuds.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-blue.svg)](https://kernel.org)
[![Audio: PipeWire](https://img.shields.io/badge/Audio-PipeWire%20%2F%20WirePlumber-red.svg)](https://gitlab.freedesktop.org/pipewire/pipewire)

---

## 🎯 Symptoms / Dấu hiệu nhận biết

You are likely affected by this issue if your Bluetooth earbuds meet these criteria:
* **The 20-Second Stutter:** Audio plays smoothly for the first 15–20 seconds, then degrades into severe skipping, stuttering, and crackling (packets dropping).
* **The Single-Earbud Test:** If you place one earbud back into the charging case and listen with **only one earbud**, the audio plays **completely smoothly** without any stuttering.
* **The Mono Test:** If you force the audio channel to Mono, playback becomes smooth in both ears, but switching back to standard Stereo brings the stuttering back.
* **The Browser / YouTube Music Trap:** Playback is smooth in local players but begins stuttering as soon as a browser (Chromium, Chrome, Brave) or YouTube Music starts playing.
* **Budget TWS Earbuds:** Commonly found on generic or budget earbuds under $10–$20 (e.g., GOOJODOQ, Lenovo, Baseus, Hoco, Amoi, Pro 4/5 clones) powered by **Zhuhai JieLi (Jerry) AC69xx / JL70xx** Bluetooth audio SoCs (`Vendor ID: bluetooth:v05D6p000A`).
* **Host Hardware:** Frequently reproduced on laptops with **Realtek RTL8821CE / RTL8822CE** (`0bda:b00e`) combo Wi-Fi/Bluetooth single-antenna chips running PipeWire on modern distributions (Ubuntu 22.04/24.04/26.04, Arch Linux, Fedora).

---

## 🔬 Root Cause Analysis / Bản chất kỹ thuật

### 1. TWS Master-Slave Relay Starvation
Budget TWS earbuds do not implement independent dual-reception (sniffing). Instead:
1. The **Master earbud** connects to your Linux laptop over Bluetooth A2DP.
2. The Master earbud decodes/relays audio frames to the **Slave earbud** over a secondary wireless link.

### 2. High Bitrate SBC Overload (48 kHz / Bitpool 53)
* On Linux, PipeWire default SBC negotiates at **48.000 Hz Joint Stereo** with maximum bitpool (Bitpool = 53), producing a bitrate of **~357 kbps** using multi-slot DH5 packets.
* The Master earbud's radio is saturated listening to continuous DH5 packets, leaving **insufficient empty radio time-slots** to relay packets to the Slave earbud.
* After ~15–20 seconds, the Slave earbud's local jitter buffer drains completely. Retransmissions cascade between earbuds, backing up the Bluetooth socket on Linux (`written == -EAGAIN` in PipeWire `media-sink.c`), causing severe crackling and disconnection.

### 3. The Browser Quantum Drop Trap (Quantum 512 vs 2048)
* PipeWire dynamically scales its audio buffer ("quantum") based on connected client requests.
* Browsers (Chromium, Chrome, YouTube Music) request a low latency buffer (`node.latency = 512/44100`).
* If `default.clock.min-quantum` is set to `512` (or left unconstrained), PipeWire drops the graph buffer down to **512 samples (~11.6 ms)**.
* On shared single-antenna Wi-Fi/BT adapters, an 11.6 ms buffer headroom is too narrow to survive RF interference, causing instant buffer underruns. Locking **`min-quantum = 2048` (~46.4 ms)** prevents browsers from shrinking the buffer.

### 4. Why AAC Codec is the Ideal Solution
* JieLi chipsets are factory tuned and hardware-optimized for iOS devices, which stream exclusively using **AAC**.
* AAC provides higher fidelity at lower bitrates (**~128–256 kbps** vs ~357 kbps SBC), drastically reducing wireless airtime usage and giving the Master earbud ample room to relay data to the Slave earbud.
* *Note on Ubuntu/Debian:* AAC support is not included in the standard `libspa-0.2-bluetooth` package due to licensing. It is provided in the **`libspa-0.2-modules-extra`** package.

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

The installer will:
1. Install `libspa-0.2-modules-extra` on Debian/Ubuntu for AAC support.
2. Configure WirePlumber to prioritize AAC over SBC and disable buggy profiles.
3. Lock PipeWire clock rate to 44.1 kHz and `min-quantum = 2048`.
4. Apply TLP power management exclusions.

Then disconnect and reconnect your Bluetooth earbuds:
```bash
bluetoothctl disconnect <YOUR_MAC_ADDRESS>
bluetoothctl connect <YOUR_MAC_ADDRESS>
```

---

## 🛠️ Manual Installation / Cấu hình thủ công

If you prefer to configure manually:

### Step 0: Install PipeWire AAC Extra Modules (Ubuntu / Debian)
```bash
sudo apt update
sudo apt install -y libspa-0.2-modules-extra
```

### Step 1: Configure WirePlumber (0.5+)
Create `~/.config/wireplumber/wireplumber.conf.d/50-bluez-fix.conf`:

```spa-json
monitor.bluez.properties = {
  # Prioritize AAC over SBC, disable heavy codecs
  bluez5.codecs = [ aac sbc ]
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
        device.name = "~bluez_card.*"
      }
    ]
    actions = {
      update-props = {
        bluez5.codecs = [ aac sbc ]
      }
    }
  },
  {
    matches = [
      {
        node.name = "~bluez_output.*"
      }
    ]
    actions = {
      update-props = {
        node.latency = "2048/44100"
      }
    }
  }
]
```

### Step 2: Configure PipeWire Clock Rates & Lock Quantum
Create `~/.config/pipewire/pipewire.conf.d/10-rates.conf`:

```spa-json
context.properties = {
  default.clock.rate = 44100
  default.clock.allowed-rates = [ 44100, 48000 ]

  # Lock minimum quantum to 2048 to prevent browsers from dropping the buffer to 512
  default.clock.min-quantum = 2048
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
systemctl --user restart wireplumber pipewire pipewire-pulse
```

---

## 🔍 Diagnostics / Kiểm tra chẩn đoán

Run the included diagnostic script to inspect your active Bluetooth connection, negotiated codec, and power states:

```bash
./scripts/diagnose.sh
```

To verify active quantum and sample rate in real-time:
```bash
pw-top
```

To verify the negotiated Bluetooth codec:
```bash
pactl list cards | grep -E "Active Profile|codec"
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
