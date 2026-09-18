# 05-wireless-offline — Solution walkthrough

All commands below are run from inside the attacker box (`./lab shell`).
The training capture and wordlist live in `/root/wifi/`. The target
network in `wpa.cap` is ESSID `test`, BSSID `00:0D:93:EB:B0:8C`.

## Route 1: aircrack-ng

```bash
aircrack-ng -w /root/wifi/lab.lst -b 00:0D:93:EB:B0:8C /root/wifi/wpa.cap
# (or against a bigger list) aircrack-ng -w /usr/share/wordlists/rockyou.txt -b 00:0D:93:EB:B0:8C /root/wifi/wpa.cap
```

**Why this works:** `wpa.cap` contains a full WPA 4-way handshake between
a client and the access point. That handshake includes enough material
(the AP and client nonces, MAC addresses, and an EAPOL MIC) for anyone
holding a copy of it to test whether a *candidate* passphrase is the
right one — entirely offline, with no further contact with the network.
For each word in the wordlist, `aircrack-ng` derives a 256-bit PMK from
the passphrase and network SSID via PBKDF2 (4096 iterations — this is why
WPA cracking is comparatively slow per-guess), derives the pairwise
transient key from that PMK plus the captured nonces/MACs, and recomputes
the EAPOL MIC. If the recomputed MIC matches the one seen in the capture,
that passphrase is correct. Here, the correct passphrase — `biscotte` —
is the first entry in the bundled `lab.lst`, so it's found almost
immediately.

## Route 2: hashcat (via hcxpcapngtool)

```bash
hcxpcapngtool -o /root/wifi/wpa.22000 /root/wifi/wpa.cap
hashcat -m 22000 /root/wifi/wpa.22000 /root/wifi/lab.lst
hashcat -m 22000 /root/wifi/wpa.22000 --show
```

**Why this works:** hashcat doesn't parse raw `.cap`/pcap files — it
expects the handshake material pre-extracted into its own hash format.
`hcxpcapngtool` reads the pcap, pulls out the EAPOL handshake (and/or a
PMKID if one was captured), and writes it out in hashcat's mode-`22000`
format (`WPA-PBKDF2-PMKID+EAPOL`), the modern unified format that replaced
the older mode 2500/16800 split. `hashcat -m 22000` then performs the
same PBKDF2 → PTK → MIC-check logic as aircrack-ng, just on a GPU-friendly
hash format and (usually) much faster hardware. `--show` re-prints any
already-cracked result from hashcat's potfile without re-running the
attack — useful once a passphrase has already been found.

A mask attack (`-a 3`) is the next step up from a plain wordlist when you
know something about the *shape* of the password (all-digits, a known
length, a fixed prefix, etc.) rather than the exact value — e.g.
`hashcat -m 22000 -a 3 wpa.22000 ?d?d?d?d?d?d?d?d` for an 8-digit PIN-style
passphrase.

## Recovered passphrase

```
biscotte
```
