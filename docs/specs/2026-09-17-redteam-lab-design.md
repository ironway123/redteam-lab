# Red Team Training Lab — Design Spec

**Date:** 2026-09-17
**Status:** Approved design — ready for implementation planning
**Author:** itdojo (with Claude)

## Purpose

A local, container-based training environment for practicing Linux and
red-team penetration-testing skills in a controlled, isolated lab. The lab
lets a student learn and drill offensive techniques against deliberately
vulnerable targets that live entirely inside a private Docker network, with
guided exercises and full solution walkthroughs so no one gets stuck with no
way forward.

**Scope boundary:** every target is a self-contained, deliberately vulnerable
practice image, attacked only inside the lab's private network. The lab never
scans, touches, or exploits anything outside itself.

## Goals

- Practice five skill areas: **recon/enumeration, web app exploitation,
  network service exploitation, Linux privilege escalation, and wireless
  (offline cracking)**.
- Goal-driven exercises: concrete objectives, tiered hints, full annotated
  solutions, and a verifiable checkpoint per scenario.
- Instant, safe reset to a pristine state; maximum aggression allowed inside a
  provably contained blast radius.
- Reproducible and disposable via Docker Compose; runs alongside the user's
  existing Docker work without interference.

## Non-goals

- **Live wireless / RF attacks** (handshake capture, deauth, rogue AP, monitor
  mode) — these require real radio hardware and cannot run in Docker. They are
  documented as a separate hardware track only (`docs/wireless-hardware.md`).
- **Kernel-exploit privilege escalation** — the privesc scenario is
  container-root via misconfiguration, which covers the large majority of
  real-world Linux privesc. True kernel-exploit practice would need a full VM
  and is out of scope for this Docker lab (noted in docs).
- Cloud hosting, multi-user access, or CTF scoring infrastructure.

## Host context (verified 2026-09-17)

- Ubuntu 26.04, 16 cores, 91 GB RAM, 1.7 TB free.
- Docker 29.8.0, Docker Compose v5.5.1, daemon reachable.
- Existing unrelated containers running (`vendor-scorecard_*`) — the lab must
  stay namespaced and never touch them.

## Architecture

Single repo, `redteam-lab/`, organized as independent **scenarios**. Each
scenario is a self-contained folder with its own Compose file, targets, and
docs. A shared control script and a shared attacker box tie them together.

```
redteam-lab/
├── lab                      # control script (the one command you run)
├── README.md                # overview, setup, SAFETY notes
├── docker-compose.base.yml  # shared: attacker box + lab network
├── attacker/                # Kali attacker container (Dockerfile + tools)
├── scenarios/
│   ├── 01-recon/            # multi-host subnet to enumerate
│   ├── 02-web/              # DVWA / Juice Shop
│   ├── 03-services/         # vulnerable FTP/SMB/SSH/web
│   ├── 04-privesc/          # custom Linux privesc box
│   └── 05-wireless-offline/ # aircrack-ng/hashcat vs. sample handshakes
│       ├── docker-compose.yml
│       ├── README.md        # objectives + tiered hints
│       ├── SOLUTION.md      # full annotated walkthrough
│       └── (target build files)
└── docs/
    ├── getting-started.md
    └── wireless-hardware.md  # live-RF steps requiring a real adapter
```

### The `lab` control script

The single user interface — a small, readable script wrapping Docker/Compose:

```
./lab list                 # show all scenarios + status
./lab up <scenario>        # start a scenario (+ attacker + network)
./lab shell                # exec into the Kali attacker box
./lab reset <scenario>     # wipe scenario back to a clean state
./lab down <scenario>      # stop it
./lab down --all           # stop everything (lab resources ONLY)
./lab verify <scenario>    # scripted smoke test (also: verify --all)
```

Design rationale:
- One scenario at a time; each `up` ensures the attacker box + private network
  exist.
- Numbered progression (01→05) gives a natural curriculum order.
- Everything for a topic lives in one folder; adding scenario #06 later is just
  a new folder.
- All resources named `redteam-lab_*`, isolated from other Docker work.

## Scenarios

Each scenario has 2–4 concrete objectives and a verifiable checkpoint.

### 01 — Recon & enumeration
- **Targets:** 3–4 lightweight containers with a mix of exposed services (web,
  SSH, SMB, a multi-port host) so there is a real network to map.
- **Practice:** host discovery, `nmap` port/service/version scans, NSE scripts,
  directory brute-forcing (`gobuster`/`ffuf`), banner grabbing.
- **Objectives:** enumerate every live host, identify every service+version,
  find the hidden web directory, produce a target list for later scenarios.

### 02 — Web app exploitation
- **Targets:** **DVWA** (`vulnerables/web-dvwa`) as the guided ladder
  (SQLi, XSS, command injection, file upload, CSRF; adjustable difficulty),
  plus **OWASP Juice Shop** (`bkimminich/juice-shop`) as a modern SPA challenge
  with a built-in scoreboard.
- **Practice:** SQL injection → data extraction, reflected/stored XSS, command
  injection, malicious file upload → web shell, auth bypass.
- **Objectives:** dump the DVWA user table via SQLi, land a web shell via
  upload, complete a set of Juice Shop challenges.

### 03 — Network service exploitation
- **Targets:** deliberately vulnerable services — vulnerable **FTP**
  (anonymous / known-CVE), **Samba/SMB**, an outdated **web service**, weak
  **SSH** — from known-vulnerable (Vulhub-style) images so real exploits and
  Metasploit modules land.
- **Practice:** enumeration → version-to-exploit matching → foothold, both
  manually and via **Metasploit**.
- **Objectives:** get a shell on each target through its service, capture a
  `flag.txt` in each, do at least one both manually and with Metasploit.

### 04 — Linux privilege escalation
- **Target:** a custom-built box where the student starts low-privileged and
  must reach root. Seeded with a rotating set of classic paths: **SUID** binary,
  writable **cron** job, dangerous **capability** (e.g. `cap_setuid`), **sudo
  misconfig**, world-writable sensitive file.
- **Practice:** manual enumeration and automated (`LinPEAS`), spotting the
  misconfig, exploiting to root.
- **Objectives:** escalate to root via each seeded path; read `/root/flag.txt`.
  A config toggle selects the active path(s); reset can re-roll it into a fresh
  puzzle.
- **Note:** container-root via misconfiguration, not kernel exploitation.

### 05 — Wireless (offline cracking)
- **Target:** a container pre-loaded with **self-generated** sample WPA/WPA2
  handshake captures (`.cap`/`.hccapx`) and **PMKID** samples (created against
  throwaway test passwords) plus curated wordlists.
- **Practice:** `aircrack-ng` and `hashcat` cracking workflows — converting
  captures, dictionary/rule/mask attacks, reading the crack.
- **Objectives:** recover the passphrase from each sample using both
  `aircrack-ng` and `hashcat`; crack a PMKID; run a mask attack against a
  known-pattern password.
- **Companion doc** (`docs/wireless-hardware.md`): the live-RF half (handshake
  capture, deauth, PMKID grab) as a hardware-only reference, clearly marked as
  requiring a monitor-mode adapter and the student's own network.

## Guidance model (answer/help system)

Each scenario ships two docs so a student can self-rescue at any level and
never hit a dead end:

- **`README.md` — guided path with progressive disclosure.** Objectives, then
  tiered hints under collapsible `<details>` sections:
  - Hint 1 (nudge): points at the right area.
  - Hint 2 (technique): names the approach without the command.
  - Hint 3 (near-spoiler): the specific tool/module and roughly how.
- **`SOLUTION.md` — complete annotated walkthrough.** Command-by-command path
  to the checkpoint, explaining *why* at each step, so reading it teaches.
- **Verifiable checkpoints.** Each scenario seeds unambiguous proof of success
  (`flag.txt`, dumped table, Juice Shop scoreboard) so success is never
  ambiguous.

Loop: **objectives → try → tiered hints → full annotated solution →
checkpoint to confirm.**

## Networking

- **Private lab network:** dedicated Docker bridge `redteam-lab-net`, private
  subnet (e.g. `172.28.0.0/24`). Targets/attacker addressed like a real range.
- **Containment:** targets are not reachable from the LAN or internet; targets
  do not need outbound internet (a compromised target cannot phone home).
  Separate from all other Docker work.
- **Recon benefit:** a genuine multi-host subnet to sweep.

### Kali attacker box
- Built from `kalilinux/kali-rolling` via Dockerfile, pre-provisioned:
  - Recon: `nmap`, `gobuster`/`ffuf`, `netcat`, `whatweb`
  - Exploitation: `metasploit-framework`, `sqlmap`, `hydra`
  - Cracking: `hashcat`, `john`, `aircrack-ng` + wordlists
  - Post/privesc: `LinPEAS` staged for transfer to targets
- Entered via `./lab shell` (`docker exec -it`). Reproducible (rebuild
  identically) and disposable (reset for a clean toolbox); an optional
  persistent volume keeps loot/notes.

### Host access (dual — "Both")
1. **Inside the attacker box** — `./lab shell`, the self-contained default.
2. **From the host** — scenarios publish key ports to `localhost` (e.g. DVWA at
   `http://localhost:8080`) so a real browser and host-installed tools can hit
   targets.

**Trade-off:** published ports are reachable from the host by design; all other
target traffic stays inside the private network. Exact published ports are
documented per scenario.

## Reset & state model

- **`./lab reset <scenario>`** = `docker compose down -v` then `up -d` —
  rebuilds the target from its image, wiping all attack traces in seconds.
- **Targets hold no data worth keeping** — reset freely, even mid-exercise.
- **`04-privesc` re-rolls** its active path on reset for a fresh puzzle.
- **Persists across reset:** an optional named volume `redteam-loot` mounted in
  the attacker box (hashes, notes, downloads); scenario docs are repo files,
  untouched.
- Rule: **targets are throwaway, work product persists.**

## Safety design

1. **Network containment (primary).** Targets live on the private network,
   exposed only via `localhost` practice ports; never reachable from LAN or
   internet; no outbound internet for targets.
2. **Loud safety notice.** README opens with the ground rules: practice on
   *these* targets only; attacker tools point *only* at the lab subnet; never
   target systems without ownership or written authorization.
3. **Scoped teardown.** `./lab down --all` filters by the lab's own Compose
   project name and never touches non-lab containers (e.g. `vendor-scorecard`).
4. **No host privilege bleed.** No `--privileged`, no host mounts, except a
   documented minimum capability where a scenario genuinely needs it.
5. **Self-generated / standard data only.** Wireless captures are generated
   against throwaway test passwords; no real captured data ships.

## Build order & testing plan

1. **Skeleton** — repo layout, `lab` script, `docker-compose.base.yml`
   (network + attacker box). Verify `./lab shell` reaches a throwaway target on
   the private subnet.
2. **Attacker box** — build Dockerfile, confirm every listed tool runs.
3. **Scenarios one at a time (01→05)** — each not "done" until it passes its
   check.

### Per-scenario verification (key discipline)
For every scenario, perform an **end-to-end solve**: bring it up, follow its own
`SOLUTION.md` command-for-command from the attacker box, confirm it reaches the
checkpoint. This proves the target is genuinely vulnerable, the solution guide
is accurate and complete, and the checkpoint triggers. Also verify reset returns
to pristine, and that `04-privesc` re-roll produces a different active path.

### Automated smoke test
`./lab verify <scenario>` / `verify --all`: target comes up healthy, expected
ports respond, and where feasible a scripted exploit reaches the checkpoint —
a one-command way to confirm the lab still works after any change or on a fresh
machine.

### Reporting
For each scenario built: report what came up, the exact solve run, and the
checkpoint output — evidence, not bare assertions.

## Open items for implementation planning

- Pin exact base image tags/digests for reproducibility.
- Finalize the per-scenario published-port map.
- Choose specific vulnerable-service images/CVEs for scenario 03.
- Decide the `04-privesc` path-selection mechanism (env var / build arg).
- Confirm wordlist sourcing/size for the attacker box and scenario 05.
