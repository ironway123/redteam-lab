# 05-wireless-offline — WPA offline cracking

## Objectives

1. Recover the WPA passphrase from `wpa.cap` with `aircrack-ng`.
2. Do the same crack with `hashcat` (convert the capture first).
3. Understand where a real capture would come from in the field — see
   `docs/wireless-hardware.md`.

## Setup

```bash
./lab up 05-wireless-offline
./lab shell
```

A one-shot generator drops the training data into the shared volume before
the attacker box is ready to use it; give it a few seconds after `up`. The
files land in `/root/wifi/`:

- `wpa.cap` — a capture containing a WPA 4-way handshake for network
  `test` (BSSID `00:0D:93:EB:B0:8C`).
- `lab.lst` — a small wordlist to crack it against.

## Hints

<details><summary>Hint 1</summary>The capture holds a WPA 4-way
handshake — the exchange a client and access point perform when
associating. You can't crack the passphrase by attacking the handshake
directly; instead you test candidate passphrases <em>offline</em> against
it, one at a time, using a wordlist.</details>

<details><summary>Hint 2</summary>For the aircrack-ng route, the flag you
want is <code>-w</code> (wordlist) together with <code>-b</code> (target
BSSID) against the capture file. For the hashcat route, hashcat doesn't
read `.cap` files directly — convert it first with
<code>hcxpcapngtool</code>, then crack the result with hashcat mode
<code>22000</code> (the modern combined WPA-PBKDF2/PMKID format).</details>

<details><summary>Hint 3</summary>

```bash
# aircrack-ng
aircrack-ng -w /root/wifi/lab.lst -b 00:0D:93:EB:B0:8C /root/wifi/wpa.cap

# hashcat
hcxpcapngtool -o /root/wifi/wpa.22000 /root/wifi/wpa.cap
hashcat -m 22000 /root/wifi/wpa.22000 /root/wifi/lab.lst
```

</details>

## Reality note

This scenario is the **offline cracking half only**. In the field,
capturing a handshake in the first place requires a wireless adapter
capable of monitor mode and packet injection, physical proximity to the
target network, and (usually) either waiting for or forcing a client to
re-associate so a handshake is exchanged while you're listening. None of
that is simulated here — Docker containers don't have real radios, so
this lab hands you an already-captured handshake and focuses purely on
the offline dictionary-attack step that follows it. See
`docs/wireless-hardware.md` for what real capture hardware and workflow
look like.

## Checkpoint

`aircrack-ng` (or hashcat's `--show`) prints the recovered passphrase:

```
KEY FOUND! [ biscotte ]
```
