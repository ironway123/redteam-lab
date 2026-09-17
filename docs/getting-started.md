# Getting Started

## ⚠️ Safety & authorization — read first

This lab is for **your own practice against the bundled targets only**. Every
target lives on the lab's isolated private network (`172.28.0.0/24`) and is
not reachable from your LAN or the internet. **Never** point any tool in
this lab — or any tool you learn here — at a host, network, or account you
do not own or lack **explicit written authorization** to test. Doing so is
illegal. Targets are deliberately, intentionally vulnerable; treat them
accordingly and keep them isolated.

## Prerequisites

- **Docker** and the **Docker Compose plugin** (`docker compose`, not the
  standalone `docker-compose`). Confirm both are present:

  ```bash
  docker version
  docker compose version
  ```

- Enough disk space to build/pull ~6 images (Kali attacker box, DVWA, Juice
  Shop, Samba, a couple of small custom Debian/Alpine targets).
- A terminal. Nothing else runs on your host — every attack tool lives
  inside the `redteam-lab-attacker` container.

## The daily loop

```bash
./lab list              # see available scenarios and which one (if any) is active
./lab up 01-recon        # bring up the attacker + network + this scenario's targets
./lab shell              # drop into the Kali attacker box
#   ... do the work from inside the shell ...
./lab verify 01-recon    # run the scenario's automated checkpoint
./lab reset 01-recon     # wipe the scenario back to a clean starting state
./lab down               # tear down everything the lab owns
```

Notes on this loop:

- The lab runs **one scenario at a time**. Running `./lab up <scenario>` while
  a different scenario is active tears down the old one first — state (loot,
  shells, cracked passwords) does not carry over between scenarios.
- `./lab reset <scenario>` is the fast way to get a fully clean environment
  for the *same* scenario again (useful after you've broken something, or
  for `04-privesc`, to roll a new escalation path — see that scenario's
  README).
- `./lab down` stops and removes only this project's containers, network,
  and volumes (everything is scoped under the `redteam-lab` Compose project
  name); it does not touch anything else running on your machine.
- Teardown/reset always use `docker compose down -v`, so scenario state
  (e.g. a DVWA database you initialized) does not survive a reset — that's
  intentional, so every attempt starts from the same known-clean baseline.

## How each scenario is structured

Every scenario under `scenarios/NN-name/` follows the same shape:

- **`docker-compose.yml`** — the scenario's targets, merged on top of
  `docker-compose.base.yml` (which provides the shared Kali attacker box and
  the `172.28.0.0/24` private network the attacker sits on at `172.28.0.5`).
- **`README.md`** — objectives, setup notes, a **checkpoint** (what "solved"
  looks like), and tiered **hints**: Hint 1 nudges you toward the right
  category of attack, Hint 2 names the specific technique/tool, and Hint 3
  gives the literal command(s). Open them in order — try to solve with less
  before revealing more.
- **`SOLUTION.md`** — the full, annotated walkthrough: every command run
  end-to-end with an explanation of *why* it works. Use it to check your
  work or get unstuck completely, not as the first thing you read.
- **`verify.sh`** — an automated, scriptable check for the scenario's
  checkpoint(s), run via `./lab verify <scenario>`. It's the same signal the
  full-lab integration check (`./lab verify --all`) uses.

## The `verify` command

```bash
./lab verify 01-recon     # run this scenario's checkpoint against whatever
                           # is currently up (does NOT reset it first — run
                           # `./lab up`/`./lab reset` beforehand if you need
                           # a clean state)
./lab verify --all        # run every scenario's verify.sh in sequence
```

`verify --all` iterates every scenario under `scenarios/`, resetting and
bringing each one up in turn (so it's a real end-to-end pass, not just a
lint check), then runs that scenario's `verify.sh`. Each scenario prints a
`PASS: <name>` line on success; the command exits `0` only if every
scenario passed.

## Scenario reference

All targets below live on the lab's private network, `172.28.0.0/24`, and
are reachable only from inside the attacker box (`./lab shell`) except where
a host port is explicitly published for browser access.

| Scenario | Targets (IP) | Checkpoint |
|---|---|---|
| `01-recon` | web `.10`, ssh `.11`, smb `.12`, multi-service `.13` | `curl` a file under `/backup/` on the web host whose contents start with `RECON-FLAG{` |
| `02-web` | DVWA `.20` (host `http://localhost:8080`), Juice Shop `.21` (host `http://localhost:3000`) | Dump the DVWA `users` table via SQL injection, then get RCE via a web-shell upload (see `SOLUTION.md` for the fully verified chain; `verify.sh` checks that both apps are up and responding) |
| `03-services` | ftp `.30`, smb `.31`, ssh `.32` (user `svc`), web `.33` | `FTP-FLAG{...}` from FTP, `SMB-FLAG{...}` from the SMB share, SSH password cracked with hydra **and** a Metasploit `ssh_login` session opened, `WEB-FLAG{...}` via command injection on the web `ping` page |
| `04-privesc` | privesc target `.40` (SSH as `lowpriv`) | Escalate to root and read `/root/flag.txt`, starting with `PRIVESC-FLAG{` |
| `05-wireless-offline` | wifi-gen `.50` (drops capture into the shared `/root/wifi` volume — this is an offline artifact, not a network service to attack) | Recover the WPA passphrase from `wpa.cap` for network `test` (BSSID `00:0D:93:EB:B0:8C`) using `aircrack-ng` and/or `hashcat` — `KEY FOUND! [ biscotte ]` |

For the live-RF half of wireless attacks (capturing a real handshake in the
field, rather than cracking the pre-captured one in `05-wireless-offline`),
see [`docs/wireless-hardware.md`](wireless-hardware.md) — that half requires
physical monitor-mode hardware and cannot run inside Docker.

## Getting help mid-scenario

1. Re-read the objectives and Hint 1.
2. Open hints in order — don't skip straight to Hint 3.
3. Check the scenario's "Verify note" or "Reality note" section, if present,
   for known quirks (e.g. `02-web`'s DVWA database-initialization caveat).
4. Read `SOLUTION.md` for the full walkthrough.
5. Run `./lab reset <scenario>` if the environment feels broken — it starts
   over from a known-clean state.
