# Red Team Training Lab

A local, container-based lab for practicing Linux and red-team skills against
deliberately vulnerable targets on an **isolated private network**.

## ⚠️ SAFETY & AUTHORIZATION — READ FIRST

- This lab is for **your own practice on these bundled targets only**.
- The attacker tools inside this lab are pointed **only** at the lab's private
  subnet (`172.28.0.0/24`).
- **Never** point these tools at any host, network, or account you do not own
  or lack **explicit written authorization** to test. Doing so is illegal.
- Targets are intentionally vulnerable. They are contained to the private
  network and are not reachable from your LAN or the internet.

## Quick start

    ./lab list              # see scenarios
    ./lab up 01-recon       # start a scenario
    ./lab shell             # enter the Kali attacker box
    ./lab reset 01-recon    # wipe it back to a clean state
    ./lab down --all        # stop everything (lab only)
    ./lab verify 01-recon   # run the scenario's self-check

See `docs/getting-started.md` for the full walkthrough.

## Scenarios

| Scenario | Description |
|---|---|
| [`01-recon`](scenarios/01-recon/README.md) | Host discovery, port/service scanning, and web directory brute-forcing to find a hidden flag. |
| [`02-web`](scenarios/02-web/README.md) | Web app exploitation against DVWA (SQL injection, file-upload RCE) and OWASP Juice Shop challenges. |
| [`03-services`](scenarios/03-services/README.md) | Network service attacks: anonymous FTP, SMB null sessions, SSH password cracking with hydra + Metasploit, and web command injection. |
| [`04-privesc`](scenarios/04-privesc/README.md) | Linux privilege escalation from a low-privilege shell to root, with four re-rollable escalation paths (SUID, sudo, cron, capabilities). |
| [`05-wireless-offline`](scenarios/05-wireless-offline/README.md) | Offline WPA handshake cracking with `aircrack-ng` and `hashcat` against a pre-captured packet capture. |

See [`docs/getting-started.md`](docs/getting-started.md) for prerequisites,
the daily workflow, and full details on each scenario's targets and
checkpoints. Live-RF wireless capture hardware/workflow (not run in this
lab) is documented separately in
[`docs/wireless-hardware.md`](docs/wireless-hardware.md).
